#!/bin/bash
# helper script to download and install the Vulkan SDK on headless CI systems
# (note: currently outputs vulkan_sdk in current directory)
#set -e
VK_VERSION=${1:-latest}

test -d vulkan_sdk || mkdir vulkan_sdk || true

function detect_sdk_version() {
  local dump=$(find vulkan_sdk -name VkLayer_api_dump.json | head -1)
  test -s $dump && cat $dump /dev/null | grep api_version | sed -e 's/^.*: "//;s/",//;'
}

function get_windows_filename() {
  if [ "$1" == "latest" ]; then
    echo vulkan-sdk.exe
  else
    echo VulkanSDK-$1-Installer.exe
  fi
}

function get_windows_url() {
  if [ "$1" == "latest" ]; then
    echo https://sdk.lunarg.com/sdk/download/latest/windows/$(get_windows_filename $1)?u=
  else
    echo https://sdk.lunarg.com/sdk/download/$1/windows/$(get_windows_filename $1)?Human=true
  fi
}

function fetch_windows() {
  local VULKAN_SDK_URL=$1
  local VULKAN_SDK_FILE=$2
  if [ -s $VULKAN_SDK_FILE ]; then
    echo "Existing '$VULKAN_SDK_FILE' found." >&2
  else
    echo "Fetching '$VULKAN_SDK_URL' => '$VULKAN_SDK_FILE'"  >&2
    curl -s $VULKAN_SDK_URL -o $VULKAN_SDK_FILE
  fi
  if [ ! -s $VULKAN_SDK_FILE ] ; then
    echo "Error downloading $VK_VERSION from '$VULKAN_SDK_URL'." >&2
    exit 2
  fi
  if [ $(stat --format=%s "$VULKAN_SDK_FILE") -lt 100000 ]; then
    echo "Error downloading $VK_VERSION from '$VULKAN_SDK_URL'." >&2
    ls -l $VULKAN_SDK_FILE >&2
    file $VULKAN_SDK_FILE >&2
    exit 3
  fi
}

function get_linux_filename() {
  if [ "$1" == "latest" ]; then
    echo vulkan-sdk.tar.gz
  else
    echo vulkansdk-linux-x86_64-$1.tar.gz
  fi
}

function get_linux_url() {
  if [ "$1" == "latest" ]; then
    echo https://sdk.lunarg.com/sdk/download/latest/linux/$(get_linux_filename $1)?u=
  else
    echo https://sdk.lunarg.com/sdk/download/$1/linux/$(get_linux_filename $1)
  fi
}

function fetch_linux() {
  local VULKAN_SDK_URL=$1
  local VULKAN_SDK_FILE=$2
  if [ -s $VULKAN_SDK_FILE ]; then
    echo "Existing '$VULKAN_SDK_FILE' found." >&2
  else
    echo "Fetching '$VULKAN_SDK_URL' => '$VULKAN_SDK_FILE'"  >&2
    wget -q -O $VULKAN_SDK_FILE $VULKAN_SDK_URL
  fi
  if [ ! -s $VULKAN_SDK_FILE ] ; then
    echo "Error downloading $VK_VERSION from '$VULKAN_SDK_URL'." >&2
    exit 2
  fi
  if [ $(stat --format=%s "$VULKAN_SDK_FILE") -lt 100000 ]; then
    echo "Error downloading $VK_VERSION from '$VULKAN_SDK_URL'." >&2
    ls -l $VULKAN_SDK_FILE >&2
    file $VULKAN_SDK_FILE >&2
    exit 3
  fi
}

# EXISTING_SDK_VERSION=$(detect_sdk_version)
# if [ "$EXISTING_SDK_VERSION" != "" ] ; then
#   echo "Existing Vulkan SDK $EXISTING_SDK_VERSION already found in $PWD/vulkan_sdk/ -- aborting installation of $VK_VERSION." >&2
#   exit 4
# fi
if [ `uname -m` != 'x86_64' ]; then echo 'Error: Not supported platform.' && exit 1; fi
case `uname -s` in
  Linux)
    export VULKAN_SDK_URL=$(get_linux_url $VK_VERSION)
    export VULKAN_SDK_FILE=$(get_linux_filename $VK_VERSION)
    fetch_linux $VULKAN_SDK_URL $VULKAN_SDK_FILE
    if [ "$(ls -A vulkan_sdk)" == "" ]; then
        ls -lh $VULKAN_SDK_FILE >&2
        echo "extracting..."  >&2
        tar -C vulkan_sdk -zxf $VULKAN_SDK_FILE 2>&1 >&2
        echo "... extracted $(du -hs vulkan_sdk)"  >&2
    fi
    export VULKAN_SDK=$PWD/$(ls vulkan_sdk/*/x86_64 -d)
    export VULKAN_SDK_ROOT=$PWD/vulkan_sdk/`echo $(cd vulkan_sdk && ls)`
    # rm $VULKAN_SDK_FILE
    # rm -rf vulkan_sdk/source vulkan_sdk/samples
    # find vulkan_sdk -type f | grep -v -E 'vulkan|glslang' | xargs rm
    ;;
  Darwin)
    echo "TODO=Darwin"
    exit 5
    ;;
  *) # Windows
    export VULKAN_SDK_FILE=$(get_windows_filename $VK_VERSION)
    export VULKAN_SDK_URL=$(get_windows_url $VK_VERSION)
    fetch_windows $VULKAN_SDK_URL $VULKAN_SDK_FILE
    if [ "$(ls -A vulkan_sdk)" == "" ]; then
      ls -lh $VULKAN_SDK_FILE >&2
      echo "extracting..."  >&2
      7z x -aoa ./$VULKAN_SDK_FILE -ovulkan_sdk 2>&1 > /dev/null
      echo "... extracted $(du -hs vulkan_sdk)" >&2
    fi
    export VULKAN_SDK_ROOT=$PWD/vulkan_sdk
    export VULKAN_SDK=$PWD/vulkan_sdk
    # rm $VULKAN_SDK_FILE
    # rm -rf $VULKAN_SDK/{Samples,Third-Party,Tools,Tools32,Bin32,Lib32}
    ;;
esac
export VULKAN_SDK_VERSION=$(detect_sdk_version)

echo VULKAN_SDK=$VULKAN_SDK
echo VULKAN_SDK_VERSION=$VULKAN_SDK_VERSION
echo VULKAN_SDK_URL=$VULKAN_SDK_URL

# echo -e "... vulkan_sdk installed:\n\tVULKAN_SDK_VERSION=$VULKAN_SDK_VERSION\n\tVULKAN_SDK=$VULKAN_SDK" >&2
