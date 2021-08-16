#!/bin/bash
# helper script to clone, build and install the Vulkan SDK on headless CI systems
# currently outputs into VULKAN_SDK in the current directory
# 2021.02 humbletim -- released under the MIT license

# usage: ./install_vulkan_sdk.sh <SDK_release_version | sdk-x.y.z>
#    eg: ./install_vulkan_sdk.sh 1.2.162.1 # branch resolved via service
#    eg: ./install_vulkan_sdk.sh sdk-1.2.162 # branch used directly

# log messages will be printed to STDERR (>&2)
# these sourcable environment variables will be printed to STDOUT on success:
#   VULKAN_SDK=...
#   VULKAN_SDK_VERSION=...

test -d VULKAN_SDK || mkdir VULKAN_SDK || true

set -e

VK_VERSION=${1:-latest}

os=unknown
build_dir=$PWD
case `uname -s` in
  Darwin) echo "TODO=Darwin" ;  exit 5 ;;
  Linux)
    os=linux
    ;;
  MINGW*)
    os=windows
    CC=cl.exe
    CXX=cl.exe
    PreferredToolArchitecture=x64
    build_dir=$(pwd -W)
    unset TEMP
    unset TMP
    ;;
esac
echo os=$os >&2
echo build_dir=$build_dir >&2

# resolve latest into an actual SDK release number (currently only used for troubleshooting / debug output)
REAL_VK_VERSION=$VK_VERSION
if [[ $VK_VERSION == latest ]] ; then
  REAL_VK_VERSION=$(curl -s https://vulkan.lunarg.com/sdk/latest.json | jq .$os --raw-output)
  echo "resolved $VK_VERSION=$REAL_VK_VERSION" >&2
fi

if [[ $VK_VERSION == sdk-*.*.* ]] ; then
  echo "using specified branch/tag name as-is: $VK_VERSION" >&2
  BRANCH=$VK_VERSION
else
  # convert an official SDK Release Number into an actual git commit tag (eg: 1.2.162.1 => sdk-1.2.162)
  BRANCH=$(curl -s https://vulkan.lunarg.com/sdk/config/$VK_VERSION/$os/config.json | jq '.repos["Vulkan-Headers"].branch' --raw-output)
fi

echo BRANCH=$BRANCH >&2

if [[ $BRANCH == null ]] ; then
  echo "error: could not resolve $VK_VERSION ($REAL_VK_VERSION) into a git branch via Vulkan SDK service" >&2
  echo "raw CURL output (https://vulkan.lunarg.com/sdk/config/$VK_VERSION/$os/config.json)" >&2
  echo "-------------------------------------------------------" >&2
  curl -i https://vulkan.lunarg.com/sdk/config/$VK_VERSION/$os/config.json >&2
  echo -e "\n-------------------------------------------------------" >&2
  echo "NOTE -- according to the web service, these versions are available for os=$os:" >&2
  curl -s https://vulkan.lunarg.com/sdk/versions/$os.json | jq --raw-output '.[]' >&2
  echo -e "\n... aborting" >&2
  exit 1
fi

MAKEFLAGS=-j2

test -d VULKAN_SDK/_build || mkdir VULKAN_SDK/_build
pushd VULKAN_SDK/_build >&2

  git clone https://github.com/KhronosGroup/Vulkan-Headers.git --branch $BRANCH >&2
  pushd Vulkan-Headers >&2
    cmake -DCMAKE_INSTALL_PREFIX=../.. -DCMAKE_BUILD_TYPE=Release . >&2
    cmake --build . --config Release >&2
    cmake --install . >&2
  popd >&2

  git clone https://github.com/KhronosGroup/Vulkan-Loader.git --branch $BRANCH >&2
  pushd Vulkan-Loader >&2
    cmake -DVULKAN_HEADERS_INSTALL_DIR=../.. -DCMAKE_INSTALL_PREFIX=../.. -DCMAKE_BUILD_TYPE=Release . >&2
    cmake --build . --config Release >&2
    cmake --install . >&2
  popd >&2
popd >&2

echo "" >&2

# export these so that "sourcing" this file directly also works
export VULKAN_SDK_VERSION=$BRANCH

export VULKAN_SDK=$build_dir/VULKAN_SDK

# also print to STDOUT for eval'ing or appending to $GITHUB_ENV:
echo VULKAN_SDK_VERSION=$VULKAN_SDK_VERSION
echo VULKAN_SDK=$VULKAN_SDK

# cleanup _build artifacts which are no longer needed after cmake --installs above
rm -rf VULKAN_SDK/_build >&2

# echo "VULKAN_SDK/" >&2
# ls VULKAN_SDK >&2
du -hs VULKAN_SDK >&2
