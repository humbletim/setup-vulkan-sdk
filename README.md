# setup-vulkan-sdk V1

<p align="left">
  <a href="https://github.com/humbletim/setup-vulkan-sdk"><img alt="GitHub Actions status" src="https://github.com/humbletim/setup-vulkan-sdk/workflows/Setup/badge.svg"></a>
</p>

This action installs the [Vulkan SDK](https://www.lunarg.com/vulkan-sdk/) and configures the `VULKAN_SDK` environment variable.

# Usage

See [action.yml](action.yml)

To use the latest Vulkan SDK version:
```yaml
uses: humbletim/setup-vulkan-sdk@v1
```
... which is equivalent to:
```yaml
uses: humbletim/setup-vulkan-sdk@v1
with:
  vulkan-version: latest
```

Or specify an exact Vulkan SDK version ([see available versions here](https://vulkan.lunarg.com/sdk/home)):
```yaml
uses: humbletim/setup-vulkan-sdk@v1
with:
  vulkan-version: 1.2.161.1
```

NOTE: currently this aciton only supports windows and linux (if someone needs mac please let me know)
