#!/bin/bash
# helper script to clone, build and install the Vulkan SDK on headless CI systems
# currently outputs into VULKAN_SDK in the current directory
# depends on typical github actions environment tools (bash, grep, jq, curl, awk)

# 2021.02 humbletim -- released under the MIT license
# 2022.02 humbletim -- revamped to support components and prebuilt SDKs

__version__=1.1.0-alpha

set -e

os=unknown
case `uname -s` in
  Darwin) os=mac ext=dmg build_dir=$PWD ;;
  Linux) os=linux ext=tar.gz build_dir=$PWD ;;
  MINGW*) os=windows ext=exe build_dir=$(pwd -W) ;;
esac

if [[ "$*" == *--help ]] ; then
  echo "Vulkan SDK install helper v$__version__"
  echo ""
  echo "usage for SDK version:"
  echo "   ./install_vulkan_sdk.sh --release <VERSION> <component,component,...> [options]"
  echo "usage for SDK version:"
  echo "   ./install_vulkan_sdk.sh --config <sdk-specs.json> <component,component,...> [options]"
  echo ""
  echo "  options:"
  echo "    --help                this help text"
  echo "    --query-versions [os] check web services API for available <os>-specific versions (windows|macos|linux; defaults to $os)"
  echo "    --query-config        check web services API to find corresponding branches/repos for the specified version "
  echo "    --dry-run             resolve parameters using webservice and display what repos/branches would be installed"
  echo "    --config <file.json>  use local SDK specs file (instead of querying webservice API)"
  echo "    --release <VERSION>   Vulkan SDK release number (eg: 1.2.162.1); default: latest"
  echo ""
  echo "    available components (default: headers loader):"
  echo ""
  for x in $(grep "if\ has_component" $0 | awk '{ print $3 }') ; do
    echo "      $x"
  done
  echo ""
  echo "for more information please see: https://github.com/humbletim/setup-vulkan-sdk"
  exit 0
fi

function log() { echo $* >&2 ; }

COMPONENT_MAPING=$(cat << EOF
{
  "Vulkan-Headers": "headers",
  "Vulkan-Loader": "loader",
  "Vulkan-ValidationLayers": "validation",
  "Glslang": "glslang",
  "SPIRV-Cross": "spirv-cross",
  "SPIRV-Tools": "spirv-tools",
  "SPIRV-Headers": "spirv-headers",
  "SPIRV-Reflect": "spirv-reflect",

  "TODO": {
    "Khronos-Tools": "Khronos-Tools",
    "LunarG-Tools": "LunarG-Tools",
    "VulkanSamples": "VulkanSamples",
    "shaderc": "shaderc",
    "DXC": "DXC",
    "gfxreconstruct": "gfxreconstruct",
    "Vulkan-Docs": "Vulkan-Docs"
  }
}
EOF
)
log os=$os
log build_dir=$build_dir

ARGS=()
VK_VERSION=
VK_CONFIG_FILE=
DRY_RUN=
QUERY_VERSIONS=
QUERY_CONFIG=
VULKAN_COMPONENTS=( "headers loader" )

# process command-line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run) DRY_RUN="(dry run)" && shift ;;
    --config) VK_CONFIG_FILE=$2 && shift 2 ;;
    --release) VK_VERSION=$2 && shift 2 ;;
    --query-versions)
      QUERY_VERSIONS=$os && shift
      case $1 in windows|mac|linux) QUERY_VERSIONS=$1 ; shift ;; esac
      ;;
    --query-config) QUERY_CONFIG=1 && shift 1 ;;
    -*|--*) echo "Unknown option $1" ;  exit 1 ;;
    *) ARGS+=("$1") && shift ;;
  esac
done
set -- "${ARGS[@]}" # restore positional parameters

[[ -n $DRY_RUN ]] && log "DRY RUN MODE"
# [[ -n "$1" ]] && { VK_VERSION=$1 ; shift ; }
[[ -n "$1" ]] && VULKAN_COMPONENTS=( " ${*//,/ } " )

export MAKEFLAGS=-j2

# resolve logical version into SDK release number
function resolve_sdk_version() {
  if [[ $1 == latest ]] ; then
    log -e "resolving '$1' via Vulkan web services API\n  https://vulkan.lunarg.com/sdk/latest.json"
    curl -s https://vulkan.lunarg.com/sdk/latest.json | jq .$os --raw-output
  else
    echo $1
  fi
}

function init() {
  if [[ -d $GITHUB_ACTION_PATH ]] ; then
    # set up os-specific prerequisites
    case $os in
      mac) ;;
      linux) . $GITHUB_ACTION_PATH/prereqs/linux.sh ;;
      windows) . $GITHUB_ACTION_PATH/prereqs/windows-2021.sh ;;
      *)
        fail_if_action "unrecognized os: $os uname=='`uname -s`'"
        exit 10
        ;;
    esac
  fi

  if [[ -n $QUERY_VERSIONS ]] ; then
    QUERY_URL=https://vulkan.lunarg.com/sdk/versions/$QUERY_VERSIONS.json
    log "fetching $QUERY_URL"
    curl -s $QUERY_URL | jq --raw-output '.[]' \
      || fail_if_action "could not fetch $QUERY_URL"
    exit 0
  fi

  [[ -d VULKAN_SDK ]] || mkdir VULKAN_SDK || fail_if_action
  export VULKAN_SDK=$build_dir/VULKAN_SDK

  if [[ -n "$VK_CONFIG_FILE" ]] ; then
    [[ -f "$VK_CONFIG_FILE" ]] || fail_if_action "config file not found: '$VK_CONFIG_FILE'"
      # version is an existing config.json file -- use directly
    config_json=$(realpath "$VK_CONFIG_FILE")
    log -e "using specified config.json:\n  $config_json"
    TARGET_VK_VERSION=$(jq '.version' --raw-output $config_json)
  else
    # version assumed to be SDK release number or 'latest' -- resolve using webservice
    TARGET_VK_VERSION=$(resolve_sdk_version $VK_VERSION)
    # fetch config.json
    config_json=$VULKAN_SDK/config.json
    config_url=https://vulkan.lunarg.com/sdk/config/${TARGET_VK_VERSION}/${os}/config.json
    log -e "asking Vulkan API webservice for ${TARGET_VK_VERSION} config => $config_json:\n  $config_url"
    curl -s -o $config_json $config_url || fail_if_action "could not fetch $config_url"
    if [[ ! -f $config_json || $(jq '.ok' --raw-output $config_json) == 'false' ]] ; then
      display_vulkan_services_error
      exit 5
    fi
  fi

  if [[ -n $QUERY_CONFIG ]] ; then
    echo -e "id\tref\trepo\tname"
    jq --argjson remap "$COMPONENT_MAPING" -r '.repos | to_entries[] | select($remap[.key]) | ($remap[.key] // .key) +"\t" +"\t" + (.value.commit // .value.branch // .value.tag) + "\t" + .value.url +"\t"+.key ' $config_json 
    exit 0
  fi

  export VULKAN_SDK_VERSION=$TARGET_VK_VERSION
  components=( " ${VULKAN_COMPONENTS} " )
  [[ -d VULKAN_SDK/_build ]] || mkdir VULKAN_SDK/_build

  # prebuilt vulkan SDKs do not include a vulkan loader (eg: vulkan-1.dll on windows)
  # if requested still build that part manually even when using a prebuilt SDK
  if true && has_component prebuilt && has_component loader ; then
    log "NOTE: manually building a compatible vulkan-1.dll to use with prebuilt SDK"
    components=${components/ loader / prebuilt+loader }
  fi
  
  log "=============================================================="
  log VK_VERSION=$VK_VERSION
  log VK_CONFIG_FILE=$VK_CONFIG_FILE
  log CONFIG_VK_VERSION=$(jq '.version' --raw-output $config_json)
  log TARGET_VK_VERSION=$TARGET_VK_VERSION
  log VULKAN_SDK=$VULKAN_SDK
  log VULKAN_COMPONENTS=$VULKAN_COMPONENTS
  log components=${components}
  log config_json=$config_json
  log "=============================================================="
  log ""

}

function has_component() {
  for c in $* ; do
    [[ " ${components} " =~ " $c " ]] && return 0
  done
  return 1
}

########################################################
function install_components() {

  # Vulkan-Headers
  if has_component headers || has_component validation loader ; then
    push_vulkan_repo_branch Vulkan-Headers
      run_cmake
    pop_vulkan_repo_branch headers
    export VULKAN_HEADERS_INSTALL_DIR=$VULKAN_SDK
  fi

  # Vulkan-Loader
  if has_component loader ; then
    push_vulkan_repo_branch Vulkan-Loader
      run_cmake
    pop_vulkan_repo_branch loader
    export VULKAN_LOADER_INSTALL_DIR=$VULKAN_SDK
  fi

  # Glslang
  if has_component glslang || has_component validation; then
    python3 -V || fail_if_action "building glslangValidator from source requires Python3"
    push_vulkan_repo_branch Glslang
      run_cmake
    pop_vulkan_repo_branch glslang
    export GLSLANG_INSTALL_DIR=$VULKAN_SDK
    $VULKAN_SDK/bin/glslangValidator --version    
  fi

  # SPIRV-Cross
  if has_component spirv-cross ; then
    push_vulkan_repo_branch SPIRV-Cross
      run_cmake
    pop_vulkan_repo_branch spirv-cross
  fi

  # SPIRV-Headers
  if has_component spirv-headers || has_component validation spirv-tools ; then
    push_vulkan_repo_branch SPIRV-Headers
      run_cmake
    pop_vulkan_repo_branch spirv-headers
    export SPIRV_HEADERS_INSTALL_DIR=$VULKAN_SDK
  fi

  # SPIRV-Tools
  if has_component spirv-tools ; then
    push_vulkan_repo_branch SPIRV-Tools
      run_cmake -DSPIRV-Headers_SOURCE_DIR=$VULKAN_SDK
    pop_vulkan_repo_branch spirv-tools
  fi

  # Vulkan-ValidationLayers
  if has_component validation ; then
    push_vulkan_repo_branch Vulkan-ValidationLayers
      run_cmake
    pop_vulkan_repo_branch validation
    export VULKAN_VALIDATIONLAYERS_INSTALL_DIR=$VULKAN_SDK
  fi

  # SPIRV-Reflect
  if has_component spirv-reflect ; then
    push_vulkan_repo_branch SPIRV-Reflect
      run_cmake
    pop_vulkan_repo_branch spirv-reflect
  fi

  # LunarG Prebuilt
  if has_component prebuilt || has_component prebuilt+loader ; then
      components=${components/ prebuilt / }
      vulkan_ext=vulkan_sdk.${ext}
      log $DRY_RUN download: https://sdk.lunarg.com/sdk/download/${TARGET_VK_VERSION}/${os}/$vulkan_ext?Human=true
      if [[ ! -n $DRY_RUN ]] ; then
        [[ -f $vulkan_ext ]] || curl -o $vulkan_ext https://sdk.lunarg.com/sdk/download/${TARGET_VK_VERSION}/${os}/$vulkan_ext?Human=true
        case $os in
          linux)
            # extract just the SDK's prebuilt binaries directly into VULKAN_SDK
            tar -C $VULKAN_SDK --strip-components 2 -xf $vulkan_ext ${TARGET_VK_VERSION}/x86_64
            ;;
          mac)
            MOUNT=$(hdiutil attach $vulkan_ext | grep vulkansdk | awk 'END {print $NF}')
            [[ -d $MOUNT ]] || fail_if_action "could not mount dmg image: '$vulkan_ext' (MOUNT=${MOUNT})"
            [[ -d $MOUNT ]] && log "mounted dmg image: '$vulkan_ext' (MOUNT=${MOUNT})"
            ls -lR $MOUNT/
            sudo $MOUNT/InstallVulkan.app/Contents/MacOS/InstallVulkan --root "${VULKAN_SDK}_" --accept-licenses --default-answer --confirm-command install
            cp -r ${VULKAN_SDK}_/macOS/* ${VULKAN_SDK}/
            hdiutil detach $MOUNT
            sudo rm -rf ${VULKAN_SDK}_
            rm -v $vulkan_ext
            ;;
          windows)
            7z x $vulkan_ext -aoa -o$VULKAN_SDK
            ls -lR $VULKAN_SDK
            rm -v $vulkan_ext
          ;;
        esac
      fi

      if has_component prebuilt+loader ; then
        export VULKAN_HEADERS_INSTALL_DIR=$VULKAN_SDK
        push_vulkan_repo_branch Vulkan-Loader
          run_cmake
        pop_vulkan_repo_branch prebuilt+loader
        export VULKAN_LOADER_INSTALL_DIR=$VULKAN_SDK
      fi

  fi
}

function fail_if_action() {
  log "==== fail_if_action $*"
  [[ -d $GITHUB_ACTION_PATH ]] && exit 1
  return 0
}

############################################ 

function run_cmake() {
  [[ -n $DRY_RUN ]] && return 0
  pushd _build
    cmake -DCMAKE_INSTALL_PREFIX=$VULKAN_SDK -DCMAKE_BUILD_TYPE=Release .. $*
    cmake --build . --config Release
    cmake --install .
  popd
}

function push_vulkan_repo_branch() {
  # log "components='${components}'"
  # determine corresponding repo and branch/commit point
  local BRANCH=$(jq '.repos[$component].branch' --arg component "$1" --raw-output $config_json)
  local COMMIT=$(jq '.repos[$component].commit // .repos[$component].tag' --arg component "$1" --raw-output $config_json)
  local URL=$(jq '.repos[$component].url' --arg component "$1" --raw-output $config_json)
  local SUBDIR=$(basename -s .git "$URL")

  log "$DRY_RUN cloning $URL @ branch=$BRANCH commit=$COMMIT subdir=$SUBDIR"
  [[ -n $DRY_RUN ]] && return 0
  if [[ -n $BRANCH && $BRANCH != null ]] ; then
    git clone --single-branch "$URL" --branch $BRANCH || fail_if_action
  elif [[ -n $COMMIT && $COMMIT != null ]] ; then
    git clone "$URL" >&2 || fail_if_action
    git -C $SUBDIR checkout $COMMIT
  else
    display_vulkan_services_error
    log -e "\n... aborting"
    exit 1
  fi
  [[ -d $SUBDIR/_build ]] || mkdir $SUBDIR/_build >&2
  pushd $SUBDIR >&2
}

function pop_vulkan_repo_branch() {
  components=${components/ $1 / }
  # log "//components='${components}'"
  [[ -n $DRY_RUN ]] && return 0
  popd >&2
}
############################################ 

function display_vulkan_services_error() {
  log "error: could not resolve $VK_VERSION ($TARGET_VK_VERSION) into a git branch via Vulkan SDK service"
  log "raw CURL output:"
  log "-------------------------------------------------------"
  cat $config_json >&2
  log -e "\n-------------------------------------------------------"
  log "NOTE -- according to the web service, these versions are available for os=$os:"
  curl -s https://vulkan.lunarg.com/sdk/versions/$os.json | jq --raw-output '.[]' >&2
}

############################################ 

init
pushd VULKAN_SDK/_build > /dev/null
  install_components
popd > /dev/null

[[ $components =~ [[:alpha:]] ]] && fail_if_action "unknown component(s): '$components'"

[[ -n $DRY_RUN ]] && exit 0

# export environment variables for github actions
if [[ -n "$GITHUB_ENV" ]] ; then
  echo VULKAN_SDK_VERSION=$VULKAN_SDK_VERSION | tee -a $GITHUB_ENV
  echo VULKAN_SDK=$VULKAN_SDK | tee -a $GITHUB_ENV
fi

if [[ -d "$GITHUB_ACTION_PATH" ]] ; then
  # cleanup _build artifacts
  [[ -d VULKAN_SDK/_build ]] && rm -rf VULKAN_SDK/_build
  [[ -d VULKAN_SDK/_vulkan_tmp ]] && rm -rf VULKAN_SDK/_vulkan_tmp
fi

du -hs VULKAN_SDK >&2
