# setup-vulkan-sdk v1.3.0

[![test setup-vulkan-sdk](https://github.com/humbletim/setup-vulkan-sdk/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/humbletim/setup-vulkan-sdk/actions/workflows/ci.yml)

This action builds and integrates individual Vulkan SDK components directly from Khronos source repos.

It is meant to offer a more lightweight option for CI/CD than installing the full Vulkan SDK, especially for projects that only need the Vulkan headers and loader available. Building those two SDK components from Khronos source usually takes around a minute and afterwards only uses around ~20MB of disk space (compared to the 600M-1.8GB that a full SDK install would require).

## Usage

_note: if new to GitHub Actions please see GitHub Help Documentation [Quickstart](https://docs.github.com/en/actions/quickstart) or [Creating a workflow file](https://docs.github.com/en/actions/using-workflows#creating-a-workflow-file)._

### Example integration

```yaml
  -name: Prepare Vulkan SDK
   uses: humbletim/setup-vulkan-sdk@v1.3.0
   with:
     vulkan-query-version: 1.4.304.0
     vulkan-components: Vulkan-Headers, Vulkan-Loader
     vulkan-use-cache: true
```

SDK version numbers are resolved into corresponding Khronos repos and commit points using the official LunarG [SDK web API](https://vulkan.lunarg.com/content/view/latest-sdk-version-api).

As of now the following SDK release numbers are known to be usable across all three primary platforms (linux/mac/windows):
- 1.2.162.0
- 1.2.162.1
- 1.2.170.0
- 1.2.189.0
- 1.2.198.1
- 1.3.204.0
- 1.4.304.0

It is also possible to specify `latest` and the action will attempt to resolve automatically.

NOTE: For production workflows it is recommended to create project-local copies of sdk config.json(s); see [Advanced](#Advanced-integration) example below.

## Including Vulkan SDK command line tools

It is now possible to include Glslang and SPIRV-* command line tools as part of this action.

However, depending on your project's needs, it might make more sense to use unattended installation of an official Vulkan SDK binary releases instead. An alternative action is provided for that [humbletim/install-vulkan-sdk](https://github.com/marketplace/actions/install-vulkan-sdk) (note that using full SDK binary releases consume a lot more runner disk space (600MB+)).

## Action Parameters

- **`vulkan-query-version`**: valid SDK release number (eg: `1.2.161.1` or `latest`). *[required]*
- **`vulkan-config-file`**: project-local config.json file path. *[optional; default: '']*
  - note: config.json files already contain versioning info, so when specified vulkan-query-version will be ignored
- **`vulkan-use-cache`**: if `true` the VULKAN_SDK folder is cached and restored across builds. *[optional; default=false]*
- **`vulkan-components`**: a space or comma delimited list of individual Vulkan component selections *[required]*:
    - `Vulkan-Headers` - [KhronosGroup/Vulkan-Headers](https://github.com/KhronosGroup/Vulkan-Headers)
    - `Vulkan-Loader` - [KhronosGroup/Vulkan-Loader](https://github.com/KhronosGroup/Vulkan-Loader)
    - `Glslang` - [KhronosGroup/Glslang](https://github.com/KhronosGroup/Glslang)
    - `SPIRV-Cross` - [KhronosGroup/SPIRV-Cross](https://github.com/KhronosGroup/SPIRV-Cross)
    - `SPIRV-Tools` - [KhronosGroup/SPIRV-Tools](https://github.com/KhronosGroup/SPIRV-Tools)
    - `SPIRV-Reflect` - [KhronosGroup/SPIRV-Reflect](https://github.com/KhronosGroup/SPIRV-Reflect)
    - `SPIRV-Headers` - [KhronosGroup/SPIRV-Headers](https://github.com/KhronosGroup/SPIRV-Headers)

- Officially supported release numbers can be found here: https://vulkan.lunarg.com/sdk/home
- Documentation on querying config.json SDK specs can be found here: https://vulkan.lunarg.com/content/view/latest-sdk-version-api

## Advanced integration

```yaml
  - name: Fetch Vulkan SDK version spec
    shell: bash
    run: |
      curl -o vulkan-sdk-config.json https://vulkan.lunarg.com/sdk/config/1.4.304.0/linux/config.json

  - name: Configure Vulkan SDK using the downloaded spec
    uses: humbletim/setup-vulkan-sdk@v1.2.0
    with:
      vulkan-config-file: vulkan-sdk-config.json
      vulkan-components: Vulkan-Headers, Vulkan-Loader
      vulkan-use-cache: true
```

To "lock in" the Khronos repos and commit points (and avoid any ongoing dependency on LunarG web services), commit a copy of the config.json(s) into your local project and then reference them similarly to above.

Additional integration examples can be found as part of this project's CI test suite: [.github/workflows/ci.yml](.github/workflows/ci.yml).

## References
- [Vulkan SDK](https://www.lunarg.com/vulkan-sdk/)
- [Vulkan SDK web services API](https://vulkan.lunarg.com/content/view/latest-sdk-version-api)
- [humbletim/install-vulkan-sdk](https://github.com/humbletim/install-vulkan-sdk)
