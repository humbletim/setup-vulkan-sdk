function install_linux() {
  local sdk_version=$1 VULKAN_SDK=$2
  curl -s -L -o vulkan_sdk.tar.gz https://sdk.lunarg.com/sdk/download/$sdk_version/linux/vulkan_sdk.tar.gz?Human=true
  echo "extract just the SDK's prebuilt binaries (x86_64) into $VULKAN_SDK" >&2
  tar -C "$VULKAN_SDK" --strip-components 2 -xf vulkan_sdk.tar.gz $sdk_version/x86_64
  rm -v vulkan_sdk.tar.gz
}

function install_windows() {
  local sdk_version=$1 VULKAN_SDK=$2
  curl -s -L -o vulkan_sdk.exe https://sdk.lunarg.com/sdk/download/$sdk_version/windows/vulkan_sdk.tar.gz?Human=true
  7z x vulkan_sdk.exe -aoa -o$VULKAN_SDK
  rm -v vulkan_sdk.exe
}

function install_mac() {
  local sdk_version=$1 VULKAN_SDK=$2
  curl -s -L -o vulkan_sdk.dmg https://sdk.lunarg.com/sdk/download/$sdk_version/mac/vulkan_sdk.dmg?Human=true
  local mountpoint=$(hdiutil attach vulkan_sdk.dmg | grep vulkansdk | awk 'END {print $NF}')
  if [[ -d $mountpoint ]] ; then
    echo "mounted dmg image: 'vulkan_sdk.dmg' (mountpoint=$mountpoint)" >&2
  else
    echo "could not mount dmg image: vulkan_sdk.exe (mountpoint=$mountpoint)" >&2
    exit 7
  fi
  local sdk_temp=$VULKAN_SDK.tmp
  sudo $mountpoint/InstallVulkan.app/Contents/MacOS/InstallVulkan --root "$sdk_temp" --accept-licenses --default-answer --confirm-command install
  cp -r $sdk_temp/macOS/* $VULKAN_SDK/
  hdiutil detach $mountpoint
  sudo rm -rf "$sdk_temp"
  rm -v vulkan_sdk.dmg
}

function install_prebuilt() {
  local os=$1 sdk_version=$2 VULKAN_SDK=$3
  test -n "$VULKAN_SDK" || exit 7
  test -d $VULKAN_SDK || mkdir -pv $VULKAN_SDK
  install_${os} $sdk_version $VULKAN_SDK
  (
    echo VULKAN_SDK=$VULKAN_SDK
    echo VULKAN_SDK_VERSION=$sdk_version
  ) | tee $VULKAN_SDK/sdk.env
}
