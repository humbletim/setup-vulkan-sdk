#!/bin/bash
# helper script to download and install the Vulkan SDK on headless CI systems
# (note: currently outputs vulkan_sdk in current directory)
set -ea
VK_VERSION=${1:-latest}

test -d vulkan_sdk || mkdir vulkan_sdk
function detect_sdk_version() {
  local dump=$(find vulkan_sdk -name VkLayer_api_dump.json | head -1)
  test -s $dump && cat $dump /dev/null | grep api_version | sed -e 's/^.*: "//;s/",//;'
}

EXISTING_SDK_VERSION=$(detect_sdk_version)
if [ "$EXISTING_SDK_VERSION" != "" ] ; then
  echo "Existing Vulkan SDK $EXISTING_SDK_VERSION already found in $PWD/vulkan_sdk/ -- aborting installation of $VK_VERSION."
  exit 4
fi
if [ `uname -m` != 'x86_64' ]; then echo 'Error: Not supported platform.' && exit 1; fi
case `uname -s` in
  Linux)
     if [ "$VK_VERSION" == "latest" ]; then
       VULKAN_SDK_FILE=vulkan-sdk.tar.gz
       VULKAN_SDK_URL=https://sdk.lunarg.com/sdk/download/latest/linux/$VULKAN_SDK_FILE?u=
     else
       VULKAN_SDK_FILE=vulkansdk-linux-x86_64-$VK_VERSION.tar.gz
       VULKAN_SDK_URL=https://sdk.lunarg.com/sdk/download/$VK_VERSION/linux/$VULKAN_SDK_FILE
     fi
     if [ -s $VULKAN_SDK_FILE ]; then
       echo "Existing '$VULKAN_SDK_FILE' found." >> /dev/stderr
     else
       echo "Fetching '$VULKAN_SDK_URL' => '$VULKAN_SDK_FILE'"  >> /dev/stderr
       wget -q -O $VULKAN_SDK_FILE $VULKAN_SDK_URL
     fi
     if [ ! -s $VULKAN_SDK_FILE ] ; then
       echo "Error downloading $VK_VERSION from '$VULKAN_SDK_URL'."
       exit 2
     fi
     ls -lh $VULKAN_SDK_FILE
     echo "extracting..."  >> /dev/stderr
     tar -C vulkan_sdk -zxf $VULKAN_SDK_FILE
     echo "... extracted $(du -hs vulkan_sdk)"  >> /dev/stderr
     VULKAN_SDK=$PWD/$(ls vulkan_sdk/*/x86_64 -d)
     VULKAN_SDK_ROOT=$PWD/vulkan_sdk/`echo $(cd vulkan_sdk && ls)`
     # rm -rf vulkan_sdk/source vulkan_sdk/samples
     # find vulkan_sdk -type f | grep -v -E 'vulkan|glslang' | xargs rm
     # rm $VULKAN_SDK_FILE
    ;;
  Darwin)
    ;;
  *) # Windows
     if [ "$VK_VERSION" == "latest" ]; then
       VULKAN_SDK_FILE=vulkan-sdk.exe
       VULKAN_SDK_URL=https://sdk.lunarg.com/sdk/download/latest/windows/vulkan-sdk.exe?u=
     else
       VULKAN_SDK_FILE=VulkanSDK-$VK_VERSION-Installer.exe
       VULKAN_SDK_URL=https://sdk.lunarg.com/sdk/download/$VK_VERSION/windows/VulkanSDK-$VK_VERSION-Installer.exe?Human=true
     fi
     if [ -s $VULKAN_SDK_FILE ]; then
       echo "Existing '$VULKAN_SDK_FILE' found." >> /dev/stderr
     else
       echo "Fetching '$VULKAN_SDK_URL' => '$VULKAN_SDK_FILE'" >> /dev/stderr
       curl -s $VULKAN_SDK_URL -o $VULKAN_SDK_FILE
     fi
     if [ ! -s $VULKAN_SDK_FILE ] ; then
       echo "Error downloading $VK_VERSION from '$VULKAN_SDK_URL'."
       exit 2
     fi
     ls -lh $VULKAN_SDK_FILE
     echo "extracting..."  >> /dev/stderr
     7z x -aoa ./$VULKAN_SDK_FILE -ovulkan_sdk > nul
     echo "... extracted $(du -hs vulkan_sdk)"  >> /dev/stderr
     VULKAN_SDK_ROOT=$PWD/vulkan_sdk
     VULKAN_SDK=$PWD/vulkan_sdk
     # rm $VULKAN_SDK_FILE
     # rm -rf $VULKAN_SDK/{Samples,Third-Party,Tools,Tools32,Bin32,Lib32}
    ;;
esac
VULKAN_SDK_VERSION=$(detect_sdk_version)
echo -e "... vulkan_sdk installed:\n\tVULKAN_SDK_VERSION=$VULKAN_SDK_VERSION\n\tVULKAN_SDK=$VULKAN_SDK" >> /dev/stderr
