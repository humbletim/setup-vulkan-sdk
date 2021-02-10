#!/bin/bash
# helper script to clone, build and install the Vulkan SDK on headless CI systems
# currently outputs into VULKAN_SDK in the current directory
# 2021.02 humbletim -- released under the MIT license

# usage: ./install_vulkan_sdk.sh <SDK_release_version>
#    eg: ./install_vulkan_sdk.sh 1.2.162.1

# log messages will be printed to STDERR (>&2)
# these sourcable environment variables will be printed to STDOUT on success:
#   VULKAN_SDK=...
#   VULKAN_SDK_VERSION=...

test -d VULKAN_SDK || mkdir VULKAN_SDK || true

set -e

VK_VERSION=${1:-latest}

os=unknown
case `uname -s` in
  Darwin) echo "TODO=Darwin" ;  exit 5 ;;
  Linux)
    os=linux
    ;;
  *)
    os=windows
    CC=cl.exe
    CXX=cl.exe
    PreferredToolArchitecture=x64
    unset TEMP
    unset TMP
    ;;
esac
echo os=$os >&2

# convert an official SDK Release Number into an actual git commit tag (eg: 1.2.162.1 => sdk-1.2.162)
BRANCH=$(curl https://vulkan.lunarg.com/sdk/config/$VK_VERSION/$os/config.json | jq '.repos["Vulkan-Headers"].branch' --raw-output)
echo BRANCH=$BRANCH >&2

mkdir VULKAN_SDK/_build
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

# export these so that "sourcing" this file directly also works
export VULKAN_SDK_VERSION=$BRANCH
export VULKAN_SDK=$PWD/VULKAN_SDK

# also print to STDOUT for eval'ing or appending to $GITHUB_ENV:
echo VULKAN_SDK_VERSION=$VULKAN_SDK_VERSION
echo VULKAN_SDK=$VULKAN_SDK

# cleanup _build artifacts which are no longer needed after cmake --installs above
rm -rf VULKAN_SDK/_build >&2

echo "VULKAN_SDK/" >&2
ls VULKAN_SDK >&2
du -hs VULKAN_SDK >&2
