# setup-vulkan-sdk V1

<p align="left">
  <a href="https://github.com/humbletim/setup-vulkan-sdk"><img alt="GitHub Actions status" src="https://github.com/humbletim/setup-vulkan-sdk/workflows/Setup/badge.svg"></a>
</p>

This action builds the [Vulkan SDK](https://www.lunarg.com/vulkan-sdk/) from source and makes it available to build tools through the `VULKAN_SDK` environment variable.

# Usage

See [action.yml](action.yml)

To install the latest Vulkan SDK:
```yaml
  -name: Install Vulkan SDK
   uses: humbletim/setup-vulkan-sdk@v1.1
```

*note: currently this action has only been tested on windows and linux x64 environments

## Parameters

- `vulkan-version`:
*(Optional)* The Vulkan SDK release to be built. Default: `latest`
    - Available SDK versions: https://vulkan.lunarg.com/sdk/home

## To specifying an exact version:
```yaml
  -name: Install Vulkan SDK
   uses: humbletim/setup-vulkan-sdk@v1.1
   with:
     vulkan-version: 1.2.161.1
```
