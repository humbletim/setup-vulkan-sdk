# setup-vulkan-sdk V1

<p align="left">
  <a href="https://github.com/humbletim/setup-vulkan-sdk"><img alt="GitHub Actions status" src="https://github.com/humbletim/setup-vulkan-sdk/workflows/Setup/badge.svg"></a>
</p>

This action installs the [Vulkan SDK](https://www.lunarg.com/vulkan-sdk/) and makes it available to build tools through the `VULKAN_SDK` environment variable export.

# Usage

See [action.yml](action.yml)

To install the latest Vulkan SDK:
```yaml
  -name: Install Vulkan SDK
   uses: humbletim/setup-vulkan-sdk@v1.1
```

*note: currently this action only supports x64-windows and x64-linux environments (see [install_vulkan_sdk.sh](install_vulkan_sdk.sh) for lower level details)*

## Parameters

- `vulkan-version`:
*(Optional)* The Vulkan SDK version to be installed. Default: `latest`
    - available SDK versions per os: https://vulkan.lunarg.com/sdk/home

## To specifying an exact SDK version:
```yaml
  -name: Install Vulkan SDK
   uses: humbletim/setup-vulkan-sdk@v1.1
   with:
     vulkan-version: 1.2.161.1
```

## To specify os-specific SDK versions:

Since not all Vulkan SDK releases are available for all operating systems it is recommended to use separate jobs when targeting multiple platforms (each using its own action reference and `vulkan-version`). However, it is also possible to specify dual SDK versions by appending `-linux` or `-windows` to the version key:
```yaml
  setup-both-with-versions:
    strategy:
      matrix:
        runs-on: [ubuntu-latest, windows-latest]
    runs-on: ${{ matrix.runs-on }}
    steps:
      - uses: actions/checkout@v2
      - name: Install Vulkan SDK
        uses: humbletim/setup-vulkan-sdk@v1.1
        with:
          vulkan-version-linux: 1.2.154.0
          vulkan-version-windows: 1.2.154.1
      - name: Test Vulkan SDK Install
        shell: bash
        run: |
          echo "Vulkan SDK downloaded from '$VULKAN_SDK_URL'"
          echo "Vulkan SDK parsed app_version '$VULKAN_SDK_VERSION'"
          echo "Exported VULKAN_SDK=$VULKAN_SDK"
```
