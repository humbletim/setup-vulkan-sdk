#!/bin/bash

test -d VULKAN_SDK/_vulkan_tmp || mkdir VULKAN_SDK/_vulkan_tmp
# note: certain Vulkan SDK internal dependencies require ninja
curl -L -o VULKAN_SDK/_vulkan_tmp/ninja-win.zip https://github.com/ninja-build/ninja/releases/download/v1.10.2/ninja-win.zip
unzip -d VULKAN_SDK/_vulkan_tmp VULKAN_SDK/_vulkan_tmp/ninja-win.zip
export PATH=$PWD/VULKAN_SDK/_vulkan_tmp:$PATH
# test -w $GITHUB_ENV && echo VK_VERSION=${{ inputs.vulkan-version-windows }} >> $GITHUB_ENV || true
export CC=cl.exe
export CXX=cl.exe
export PreferredToolArchitecture=x64
unset TEMP
unset TMP
