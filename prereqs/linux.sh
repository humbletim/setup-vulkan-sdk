#!/bin/bash

# linux (ubuntu) operating system level dependencies 
test -f /etc/os-release && . /etc/os-release
echo "VERSION_ID=$VERSION_ID"
case $VERSION_ID in
  # legacy builds using 16.04
  16.04)
    cat /etc/issue
    echo PATH=$PATH
    echo "NOTE: assuming that we are running in a docker container..."
    apt-get -qq update 
    apt-get -qq install -y jq curl git make build-essential
    test -d VULKAN_SDK/_vulkan_tmp || mkdir -v VULKAN_SDK/_vulkan_tmp
    curl -s -L https://github.com/Kitware/CMake/releases/download/v3.20.3/cmake-3.20.3-Linux-x86_64.tar.gz | tar --strip 1 -C VULKAN_SDK/_vulkan_tmp -xzf -
    ls VULKAN_SDK/_vulkan_tmp || true
    ls VULKAN_SDK/_vulkan_tmp/bin/cmake || true
    export PATH=$PWD/VULKAN_SDK/_vulkan_tmp/bin:$PATH
    hash
    cmake --version
    apt-get -qq install -y ninja-build libwayland-dev libxrandr-dev
    ;;
  # modern builds using 18.04+
  *)
    sudo apt-get install -y ninja-build libwayland-dev libxrandr-dev
  ;;
esac

