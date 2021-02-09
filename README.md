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

NOTE 2: not all Vulkan SDK releases are available for all platforms -- if you need to differentiate by platform the recommended approach is use separate jobs (which can then have separate `vulkan-version`s). However, it is also possible to specify os-specific SDK versions by adding (`-linux`|`-windows`) suffix to the version key:
```yaml
  setup-both-with-versions:
    strategy:
      matrix:
        runs-on: [ubuntu-latest, windows-latest]
    runs-on: ${{ matrix.runs-on }}
    steps:
      - uses: actions/checkout@v2
      - uses: humbletim/setup-vulkan-sdk@v1
        with:
          vulkan-version-linux: 1.2.154.0
          vulkan-version-windows: 1.2.154.1
      - name: Test Vulkan SDK Install
        shell: bash
        run: |
          echo "Vulkan SDK downloaded from '$VULKAN_SDK_URL'"
          echo "Vulkan SDK parsed app_version '$VULKAN_SDK_VERSION'"
          test -n "$VULKAN_SDK_VERSION"
```
