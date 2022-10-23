#!/bin/bash

set -e

function lunarg_get_latest_sdk_version() {
  local platform=$1
  local url=https://vulkan.lunarg.com/sdk/latest/$platform.txt
  echo "note: resolving latest via webservices lookup: $url" >&2
  curl -sL https://vulkan.lunarg.com/sdk/latest/$platform.txt
}

remote_url_used=
function lunarg_fetch_sdk_config() {
  local platform=$1 query_version=$2
  remote_url_used=https://vulkan.lunarg.com/sdk/config/$query_version/$platform/config.json
  curl -sL $remote_url_used || { echo "error retrieving $remote_url_used" >&2 ; exit 1 ; }
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

  [[ -n "$config_file" || -n "$query_version" ]] || {
    echo "either config_file or query_version must be specified" >&2 
    exit 9
  }
  if [[ -z "$config_file" ]] ; then
    test -n "$query_version"
    config_file=$build_dir/config.json
    lunarg_fetch_sdk_config $platform $query_version > $config_file
  fi

  test -s $config_file || { echo "!config_file" >&2 ; exit 3 ; }
  sdk_version=$(jq .version $config_file)
  [[ -n $sdk_version && $sdk_version != null ]] || {
    echo "error resolving sdk version or retrieving config JSON ($(jq .message $config_file))" >&2 
    exit 10
  }
  
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
  cat $build_dir/env >&2
}

function configure_sdk_prereqs() {
  local vulkan_build_tools=$1
  test -d $vulkan_build_tools/bin || mkdir -p $vulkan_build_tools/bin
  export PATH=$vulkan_build_tools/bin:$PATH
  case `uname -s` in
    Darwin) ;;
    Linux) 
      test -f /etc/os-release && . /etc/os-release
      echo "VERSION_ID=$VERSION_ID"
      case $VERSION_ID in
        # legacy builds using 16.04
        16.04) 
          apt-get -qq -o=Dpkg::Use-Pty=0 update
          apt-get -qq -o=Dpkg::Use-Pty=0 install -y jq curl git make build-essential ninja-build
          curl -s -L https://github.com/Kitware/CMake/releases/download/v3.20.3/cmake-3.20.3-Linux-x86_64.tar.gz | tar --strip 1 -C $vulkan_build_tools -xzf -
          hash
          cmake --version
        ;;
        # everything else
        *) sudo apt-get -qq -o=Dpkg::Use-Pty=0 install -y ninja-build ;;
      esac
    ;;
    MINGW*)
     curl -L -o $vulkan_build_tools/ninja-win.zip https://github.com/ninja-build/ninja/releases/download/v1.10.2/ninja-win.zip
     unzip -d $vulkan_build_tools/bin $vulkan_build_tools/ninja-win.zip
    ;;
  esac
}
