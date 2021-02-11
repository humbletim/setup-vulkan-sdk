# setup-vulkan-sdk v1.0.1

<p align="left">
  <a href="https://github.com/humbletim/setup-vulkan-sdk"><img alt="GitHub Actions status" src="https://github.com/humbletim/setup-vulkan-sdk/workflows/Setup/badge.svg"></a>
</p>

This action builds a subset of the Vulkan SDK from source and makes it available to later build steps through an exported `VULKAN_SDK` environment variable.

*note: currently only x64 windows and x64 linux environments are supported (if you need another configuration added let me know)*

# Basic Usage

To build against the latest Vulkan SDK:
```yaml
  -name: Install Vulkan SDK
   uses: humbletim/setup-vulkan-sdk@v1.0.1
```

## Parameters

- `vulkan-version`:
*(Optional)* valid SDK release number (eg: 1.2.161.1). Default: `latest`
    - Available release numbers can be found here: https://vulkan.lunarg.com/sdk/home

## Specifying an exact SDK version:
```yaml
  -name: Install Vulkan SDK
   uses: humbletim/setup-vulkan-sdk@v1.0.1
   with:
     vulkan-version: 1.2.161.1
```

## How it works

First [action.yml](action.yml) installs the minimum dependencies needed to compile Vulkan SDK from source. It then delegates to [install_vulkan_sdk.sh](install_vulkan_sdk.sh), which resolves `vulkan-version` into a corresponding git branch using the official Vulkan SDK [web services](https://vulkan.lunarg.com/content/view/latest-sdk-version-api). 

[KhronosGroup/Vulkan-Headers](https://github.com/KhronosGroup/Vulkan-Headers) and [KhronosGroup/Vulkan-Loader](https://github.com/KhronosGroup/Vulkan-Loader) repos are then cloned locally to that branch point, built, and installed into `$PWD/VULKAN_SDK`. And finally a `VULKAN_SDK` environment variable is exported for later build tools to discover to SDK's location through.

The entire process takes around a minute or so to complete and the installed artifacts consume around a dozen megabytes of storage space (as opposed to the 1GB+ required for a full Vulkan SDK prebuilt install). Note that this approach only provides enough to compile and link Vulkan applications against -- it _does not_ provide the other utilities, documentation, or code samples that normally ship with the [Full Vulkan SDK](https://www.lunarg.com/vulkan-sdk/).
