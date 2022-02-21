# setup-vulkan-sdk v1.2.0

[![test setup-vulkan-sdk](https://github.com/humbletim/setup-vulkan-sdk/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/humbletim/setup-vulkan-sdk/actions/workflows/ci.yml)

This action builds and integrates individual Vulkan SDK components directly from Khronos source repos.

For projects that only depend on Vulkan SDK headers and loader to compile and link against, this action is likely the lightest weight option. It typically takes around a minute or so of build prep time and the resulting VULKAN_SDK folder consumes around ~20MB of disk storage (which can be automatically cached for even faster repeat builds).

## Usage

_note: if new to GitHub Actions please see GitHub Help Documentation [Quickstart](https://docs.github.com/en/actions/quickstart) or [Creating a workflow file](https://docs.github.com/en/actions/using-workflows#creating-a-workflow-file)._

### Example integration

```yaml
  -name: Prepare Vulkan SDK
   uses: humbletim/setup-vulkan-sdk@v1.2.0
   with:
     vulkan-query-version: 1.2.198.1
     vulkan-components: Vulkan-Headers, Vulkan-Loader
     vulkan-use-cache: true
```

Vulkan SDK version numbers are resolved into corresponding Khronos GitHub repos and commit points using the official LunarG [Vulkan SDK web services API](https://vulkan.lunarg.com/content/view/latest-sdk-version-api).

As of now the following SDK release numbers are known to be usable across all three primary platforms (linux/mac/windows):
- 1.2.162.0
- 1.2.162.1
- 1.2.170.0
- 1.2.189.0
- 1.2.198.1
- 1.3.204.0

It is also possible to specify `latest` and the action will attempt to resolve automatically.

NOTE: For production workflows it is recommended to create project-local copies of the desired SDK config.json(s) instead (see [Advanced](#Advanced-integration) example below).

## Including Vulkan SDK command line tools

It is now possible to include Glslang and SPIRV-* command line tools as part of this action.

However, depending on your project's needs, it might make more sense to use unattended installation of an official Vulkan SDK binary releases instead. An alternative action is provided for that [humbletim/install-vulkan-sdk](https://github.com/marketplace/actions/install-vulkan-sdk) (note that using full SDK binary releases consume a lot more runner disk space (600MB+)).

## Action Parameters

- `vulkan-query-version`: *(optional)* valid SDK release number (eg: 1.2.161.1). Default: `latest`.
    - Officially supported release numbers can be found here: https://vulkan.lunarg.com/sdk/home
- `vulkan-config-file`: *(optional)* project-local config.json file path. (note: this will override `vulkan-query-version` if both are specified)
    - Documentation on querying config.json SDK specs can be found here: https://vulkan.lunarg.com/content/view/latest-sdk-version-api
- `vulkan-use-cache`: *(optional)* if `true` then the resulting VULKAN_SDK folder will be automatically cached and restored across builds (using [actions/cache](https://github.com/actions/cache)). Default: `false`.
    - note: the cache is unique per each runner operating system + vulkan-* action parameters combination.
- `vulkan-components`: *(required)* a space or comma delimited list of individual Vulkan component selections:
    - `Vulkan-Headers` - [KhronosGroup/Vulkan-Headers](https://github.com/KhronosGroup/Vulkan-Headers)
    - `Vulkan-Loader` - [KhronosGroup/Vulkan-Loader](https://github.com/KhronosGroup/Vulkan-Loader)
    - `Glslang` - [KhronosGroup/Glslang](https://github.com/KhronosGroup/Glslang)
    - `SPIRV-Cross` - [KhronosGroup/SPIRV-Cross](https://github.com/KhronosGroup/SPIRV-Cross)
    - `SPIRV-Tools` - [KhronosGroup/SPIRV-Tools](https://github.com/KhronosGroup/SPIRV-Tools)
    - `SPIRV-Reflect` - [KhronosGroup/SPIRV-Reflect](https://github.com/KhronosGroup/SPIRV-Reflect)
    - `SPIRV-Headers` - [KhronosGroup/SPIRV-Headers](https://github.com/KhronosGroup/SPIRV-Headers)

## Advanced integration

```yaml
  - name: Fetch Vulkan SDK version spec
    shell: bash
    run: |
      curl -o vulkan-sdk-config.json https://vulkan.lunarg.com/sdk/config/1.2.198.1/linux/config.json

  - name: Configure Vulkan SDK using the downloaded spec
    uses: humbletim/setup-vulkan-sdk@v1.2.0
    with:
      vulkan-config-file: vulkan-sdk-config.json
      vulkan-components: Vulkan-Headers, Vulkan-Loader
      vulkan-use-cache: true
```

To "lock in" the Khronos repos and commit points (and avoid any ongoing dependency on LunarG web services), commit a copy of the config.json(s) into your local project repo and reference them similarly to above.

Additional integration examples can also be found as part of this project's CI test suite: [.github/workflows/ci.yml](.github/workflows/ci.yml).

## References
- [Vulkan SDK](https://www.lunarg.com/vulkan-sdk/)
- [Vulkan SDK web services API](https://vulkan.lunarg.com/content/view/latest-sdk-version-api)
- [humbletim/install-vulkan-sdk](https://github.com/humbletim/install-vulkan-sdk)
