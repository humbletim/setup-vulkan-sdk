#!/bin/bash

# helper script to clone, build and install the Vulkan SDK on headless CI systems
# currently outputs into VULKAN_SDK in the current directory
# 2021.02 humbletim -- released under the MIT license

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

BRANCH=$(curl https://vulkan.lunarg.com/sdk/config/$VK_VERSION/$os/config.json | jq '.repos["Vulkan-Headers"].branch' --raw-output)
echo BRANCH=$BRANCH >&2

pushd VULKAN_SDK >&2
  git clone https://github.com/KhronosGroup/Vulkan-Headers.git --branch $BRANCH >&2
  pushd Vulkan-Headers >&2
    cmake -DCMAKE_INSTALL_PREFIX=.. -DCMAKE_BUILD_TYPE=Release . >&2
    cmake --build . --config Release >&2
    cmake --install . >&2
  popd >&2
  git clone https://github.com/KhronosGroup/Vulkan-Loader.git --branch $BRANCH >&2
  pushd Vulkan-Loader >&2
    cmake -DVULKAN_HEADERS_INSTALL_DIR=.. -DCMAKE_INSTALL_PREFIX=.. -DCMAKE_BUILD_TYPE=Release . >&2
    cmake --build . --config Release >&2
    cmake --install . >&2
  popd >&2
popd >&2

echo VULKAN_SDK_VERSION=$BRANCH
echo VULKAN_SDK=$PWD/VULKAN_SDK
