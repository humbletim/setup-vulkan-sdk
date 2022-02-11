#!/bin/bash

# linux (ubuntu) operating system dependencies needed to compile Vulkan SDK
test -f /etc/os-release && . /etc/os-release
echo "VERSION_ID=$VERSION_ID"
case $VERSION_ID in
  # legacy builds using 16.04
  16.04)
    apt-get -qq update 
    apt-get -qq install -y jq curl git make build-essential ninja-build
    cat /etc/issue
    test -d VULKAN_SDK/_vulkan_tmp || mkdir -v VULKAN_SDK/_vulkan_tmp
    curl -s -L https://github.com/Kitware/CMake/releases/download/v3.20.3/cmake-3.20.3-Linux-x86_64.tar.gz | tar --strip 1 -C VULKAN_SDK/_vulkan_tmp -xzf -
    ls VULKAN_SDK/_vulkan_tmp || true
    ls VULKAN_SDK/_vulkan_tmp/bin/cmake || true
    export PATH=$PWD/VULKAN_SDK/_vulkan_tmp/bin:$PATH
    # [[ -f "$GITHUB_PATH" ]] && echo $PWD/VULKAN_SDK/_vulkan_tmp/bin >> $GIHUB_PATH
    hash
    cmake --version
    ;;
  *)
    apt-get -qq install -y ninja-build
    # modern builds using 18.04+
  ;;
esac
