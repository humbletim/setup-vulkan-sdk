_NOTE: this is WIP documentation for upcoming v1.2.0 release in main branch; current stable version is v1.0.3 see [humbletim/setup-vulkan-sdk@v1.0.3](https://github.com/humbletim/setup-vulkan-sdk/tree/v1.0.3)._
# setup-vulkan-sdk v1.2.0

<p align="left">
  <a href="https://github.com/humbletim/setup-vulkan-sdk"><img alt="GitHub Actions status" src="https://github.com/humbletim/setup-vulkan-sdk/workflows/Setup/badge.svg"></a>
</p>

This action can be used to automatically build and integrate Vulkan SDK components from source.

## Usage

_note: if new to GitHub Actions please see GitHub Help Documentation [Quickstart](https://docs.github.com/en/actions/quickstart) or [Creating a workflow file](https://docs.github.com/en/actions/using-workflows#creating-a-workflow-file)._

### Example integration

```yaml
  -name: Install Vulkan SDK
   uses: humbletim/setup-vulkan-sdk@v1.2.0
   with:
     vulkan-remote-version: 1.2.198.1
     vulkan-components: Vulkan-Headers, Vulkan-Loader
     vulkan-use-cache: true
```

## Action Parameters

- `vulkan-remote-version`: *(optional)* valid SDK release number (eg: 1.2.161.1). Default: `latest`.
    - Officially supported release numbers can be found here: https://vulkan.lunarg.com/sdk/home
- `vulkan-config-file`: *(optional)* project-local config.json file path. (note: this will override `vulkan-remote-version` if both are specified)
    - Documentation on querying config.json SDK specs can be found here: https://vulkan.lunarg.com/content/view/latest-sdk-version-api
- `vulkan-use-cache`: *(optional)* if `true` VULKAN_SDK will be automatically cached and restored across repeat builds (using [actions/cache](https://github.com/actions/cache)). Default: `false`.
    - note: cache is unique per each runner operating system + vulkan-* action parameters combination.
- `vulkan-components`: *(required)* individual Vulkan component selections.
  - Integrated components:
    - `Vulkan-Headers` - [KhronosGroup/Vulkan-Headers](https://github.com/KhronosGroup/Vulkan-Headers)
    - `Vulkan-Loader` - [KhronosGroup/Vulkan-Loader](https://github.com/KhronosGroup/Vulkan-Loader)
    - `Glslang` - [KhronosGroup/Glslang](https://github.com/KhronosGroup/Glslang)
    - `SPIRV-Cross` - [KhronosGroup/SPIRV-Cross](https://github.com/KhronosGroup/SPIRV-Cross)
    - `SPIRV-Tools` - [KhronosGroup/SPIRV-Tools](https://github.com/KhronosGroup/SPIRV-Tools)
    - `SPIRV-Reflect` - [KhronosGroup/SPIRV-Reflect](https://github.com/KhronosGroup/SPIRV-Reflect)
    - `SPIRV-Headers` - [KhronosGroup/SPIRV-Headers](https://github.com/KhronosGroup/SPIRV-Headers)
    - `Vulkan-ValidationLayers` - [KhronosGroup/Vulkan-ValidationLayers](https://github.com/KhronosGroup/Vulkan-ValidationLayers)

### Custom SDK configuration

It is also possible to specify either a URL or local relative path to an in-repo SDK configuration file.

And example Workflow integration:
```yaml
  - name: Fetch Vulkan SDK component version spec
    shell: bash
    run: |
      curl -o vulkan-sdk-config.json https://vulkan.lunarg.com/sdk/config/1.2.198.1/linux/config.json
  - name: Configure Vulkan SDK using local config
    uses: humbletim/setup-vulkan-sdk@v1.2.0
    with:
      vulkan-config-file: vulkan-sdk-config.json
      vulkan-components: Vulkan-Headers, Vulkan-Loader
      vulkan-use-cache: true
```

## Notes

Additional action integration examples can be found as part of this project's CI test suite: [.github/workflows/ci.yml](.github/workflows/ci.yml).

## References
- [Vulkan SDK](https://www.lunarg.com/vulkan-sdk/)
- [Vulkan SDK web services API](https://vulkan.lunarg.com/content/view/latest-sdk-version-api)

