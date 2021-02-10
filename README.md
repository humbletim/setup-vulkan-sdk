# setup-vulkan-sdk V1

<p align="left">
  <a href="https://github.com/humbletim/setup-vulkan-sdk"><img alt="GitHub Actions status" src="https://github.com/humbletim/setup-vulkan-sdk/workflows/Setup/badge.svg"></a>
</p>

This action installs the [Vulkan SDK](https://www.lunarg.com/vulkan-sdk/) and makes it available to build tools through the `VULKAN_SDK` environment variable.

# Usage

See [action.yml](action.yml)

To install the latest Vulkan SDK:
```yaml
  -name: Install Vulkan SDK
   uses: humbletim/setup-vulkan-sdk@v1.1
```

*note: currently this action supports x64-windows and x64-linux environments (see [install_vulkan_sdk.sh](install_vulkan_sdk.sh) for details)*

## Parameters

- `vulkan-version`:
*(Optional)* The Vulkan SDK version to be installed. Default: `latest`
    - available SDK versions: https://vulkan.lunarg.com/sdk/home

## To specifying an exact version:
```yaml
  -name: Install Vulkan SDK
   uses: humbletim/setup-vulkan-sdk@v1.1
   with:
     vulkan-version: 1.2.161.1
```
