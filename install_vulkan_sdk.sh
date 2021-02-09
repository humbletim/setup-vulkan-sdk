        #!/bin/bash
        set -ea
        VK_VERSION=$1
        mkdir vulkan_sdk || true
        EXISTING_SDK_VERSION=$(cat `find vulkan_sdk -name VkLayer_api_dump.json` | grep api_version | sed -e 's/^.*: "//;s/",//;' | head -1)
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
             wget -q -O $VULKAN_SDK_FILE $VULKAN_SDK_URL
             if [ test ! -s $VULKAN_SDK_FILE ] ; then
               echo "Error downloading $VK_VERSION from '$VULKAN_SDK_URL'."
               exit 2
             fi
             $VULKAN_SDK_FILE
             tar -C vulkan_sdk -zxf $VULKAN_SDK_FILE
             VULKAN_SDK=$PWD/$(ls vulkan_sdk/*/x86_64 -d)
             VULKAN_SDK_ROOT=$PWD/vulkan_sdk/`echo $(cd vulkan_sdk && ls)`
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
             curl -s $VULKAN_SDK_URL -o $VULKAN_SDK_FILE
             if [ test ! -s $VULKAN_SDK_FILE ] ; then
               echo "Error downloading $VK_VERSION from '$VULKAN_SDK_URL'."
               exit 2
             fi
             7z x -aoa ./$VULKAN_SDK_FILE -ovulkan_sdk > nul
             VULKAN_SDK_ROOT=$PWD/vulkan_sdk
             VULKAN_SDK=$PWD/vulkan_sdk
             # rm $VULKAN_SDK_FILE
            ;;
        esac
        VULKAN_SDK_VERSION=$(cat `find vulkan_sdk -name VkLayer_api_dump.json` | grep api_version | sed -e 's/^.*: "//;s/",//;' | head -1)
