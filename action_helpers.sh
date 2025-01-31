#!/bin/bash

set -e

# prefixed error messages so gha annotations are included in the summary report 
function ERROR() {
  echo "::error::" "$@" >&2
  exit 1
}

function LOG() {
  # echo "::notice::" "$@" >&2
  echo "$@" >&2
}

function lunarg_get_latest_sdk_version() {
  local platform=$1
  local url=https://vulkan.lunarg.com/sdk/latest/$platform.txt
  LOG "[lunarg_get_latest_sdk_version] resolving latest via webservices lookup: $url" >&2
  curl -sL https://vulkan.lunarg.com/sdk/latest/$platform.txt
}

remote_url_used=
function lunarg_fetch_sdk_config() {
  local platform=$1 query_version=$2
  remote_url_used=https://vulkan.lunarg.com/sdk/config/$query_version/$platform/config.json
  curl -sL $remote_url_used || ERROR "[lunarg_fetch_sdk_config] error retrieving $remote_url_used (curl exit code: $?)"
}

function resolve_vulkan_sdk_environment() {
  local query_version=$1
  local config_file=$2
  local sdk_components=$(echo "$3" | xargs echo | sed -e 's@[,; ]\+@;@g')
  local base_dir=$PWD
  local platform=unknown
  
  case `uname -s` in
    Darwin) platform=mac ;;
    Linux) platform=linux ;;
    MINGW*)
      platform=windows
      base_dir=$(pwd -W)
    ;;
  esac
  
  build_dir=$base_dir/_vulkan_build
  test -d $build_dir || mkdir -v $build_dir

  VULKAN_SDK=$base_dir/VULKAN_SDK
  test -d $VULKAN_SDK || mkdir -v $VULKAN_SDK

  if [[ -z "$config_file" && -z "$query_version" ]] ; then
    ERROR "[resolve_vulkan_sdk_environment] either config_file or query_version must be specified"
  fi
  if [[ -z "$config_file" ]] ; then
    test -n "$query_version"
    config_file=$build_dir/config.json
    lunarg_fetch_sdk_config $platform $query_version > $config_file
  fi

  [[ -s "$config_file" ]] || ERROR "zero byte config_file ($remote_url_used)"

  sdk_version=$(jq -re .version $config_file || echo "")
  LOG "[resolve_vulkan_sdk_environment] sdk query version '$query_version' resolved into SDK config JSON version '$sdk_version'" 
  LOG "[resolve_vulkan_sdk_environment] sdk config repos: $(jq -r '[.repos|to_entries|.[].key]|sort|join(";")' $config_file)"

  if [[ -z "$sdk_version" || $sdk_version == "null" ]] ; then
    ERROR "[resolve_vulkan_sdk_environment] error resolving sdk version or retrieving config JSON from $remote_url_used ($(jq .message $config_file))" 
  fi
  
  (
    echo VULKAN_SDK_BUILD_DIR=$build_dir
    echo VULKAN_SDK=$VULKAN_SDK
    echo VULKAN_SDK_PLATFORM=$platform
    echo VULKAN_SDK_QUERY_URL=$remote_url_used
    echo VULKAN_SDK_QUERY_VERSION=$query_version
    echo VULKAN_SDK_CONFIG_FILE=$config_file
    echo VULKAN_SDK_CONFIG_VERSION=$sdk_version
    echo VULKAN_SDK_COMPONENTS=\"$sdk_components\"
  ) > $build_dir/env

  LOG "=== sdk build env ================================================"
  LOG $build_dir/env
  LOG "=================================================================="
  
}

function configure_sdk_prereqs() {
  local vulkan_build_tools=$1
  test -d $vulkan_build_tools/bin || mkdir -p $vulkan_build_tools/bin
  export PATH=$vulkan_build_tools/bin:$PATH
  case `uname -s` in
    Darwin) ;;
    Linux) 
      test -f /etc/os-release && . /etc/os-release
      LOG "[configure_sdk_prereqs] VERSION_ID=$VERSION_ID" 
      case $VERSION_ID in
        # legacy builds using 16.04
        16.04) 
          apt-get -qq -o=Dpkg::Use-Pty=0 update
          apt-get -qq -o=Dpkg::Use-Pty=0 install -y jq curl git make build-essential ninja-build
          curl -s -L https://github.com/Kitware/CMake/releases/download/v3.31.5/cmake-3.31.5-linux-x86_64.tar.gz | tar --strip 1 -C $vulkan_build_tools -xzf -
          hash
          cmake --version
        ;;
        # everything else
        *) sudo apt-get -qq -o=Dpkg::Use-Pty=0 install -y ninja-build ;;
      esac
    ;;
    MINGW*)
     curl -L -o $vulkan_build_tools/ninja-win.zip https://github.com/ninja-build/ninja/releases/download/v1.12.1/ninja-win.zip
     unzip -d $vulkan_build_tools/bin $vulkan_build_tools/ninja-win.zip
    ;;
  esac
}
