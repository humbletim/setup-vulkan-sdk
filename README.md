# setup-vulkan-sdk v1.1.0

<p align="left">
  <a href="https://github.com/humbletim/setup-vulkan-sdk"><img alt="GitHub Actions status" src="https://github.com/humbletim/setup-vulkan-sdk/workflows/Setup/badge.svg"></a>
</p>

This action installs Vulkan SDK components for compiling and linking Vulkan applications.

By default only the API headers and loader are included, but additional SDK components can be selected using action parameters.

For production workflows it is recommended to create project-local copies of the desired SDK `config.json` revision specs -- see [Advanced](#advanced-integration) below for an example.


## Usage

_note: if new to GitHub Actions please see GitHub Help Documentation [Quickstart](https://docs.github.com/en/actions/quickstart) or [Creating a workflow file](https://docs.github.com/en/actions/using-workflows#creating-a-workflow-file)._

### Default integration

To use the latest release versions of Vulkan SDK headers and loader:
```yaml
  -name: Install Vulkan SDK
   uses: humbletim/setup-vulkan-sdk@v1.1.0
```

As of this moment, the `latest` SDK release is `1.2.198.1` -- so expanding default values the above is equivalent to:
```yaml
  - name: Install Vulkan SDK
    uses: humbletim/setup-vulkan-sdk@v1.1.0
    with:
      vulkan-version: 1.2.198.1
      vulkan-components: headers, loader
      vulkan-use-cache: false
```

### Custom integration
To target a different Vulkan SDK release number, include glslangValidator tooling, and enable caching across repeated action runs:
```yaml
  - name: Install Vulkan SDK
    uses: humbletim/setup-vulkan-sdk@v1.1.0
    with:
      vulkan-version: 1.2.161.1
      vulkan-components: headers, loader, glslang
      vulkan-use-cache: true
```

## Action Parameters

- `vulkan-version`: *(optional)* valid SDK release number (eg: 1.2.161.1). Default: `latest`.
    - Officially supported release numbers can be found here: https://vulkan.lunarg.com/sdk/home
- `vulkan-config-file`: *(optional)* project-local config.json file path. (note: this will override `vulkan-version` if both are specified)
    - Documentation on querying config.json SDK specs can be found here: https://vulkan.lunarg.com/content/view/latest-sdk-version-api
- `vulkan-use-cache`: *(optional)* if `true` VULKAN_SDK will be automatically cached and restored across repeat builds (using [actions/cache](https://github.com/actions/cache)). Default: `false`.
    - note: cache is unique per each runner operating system + vulkan-* action parameters combination.
- `vulkan-components`: *(optional)* individual Vulkan component selections. Default: `headers, loader`.
  - Available options:
    - `headers` - [KhronosGroup/Vulkan-Headers](https://github.com/KhronosGroup/Vulkan-Headers)
    - `loader` - [KhronosGroup/Vulkan-Loader](https://github.com/KhronosGroup/Vulkan-Loader)
    - `glslang` - [KhronosGroup/Glslang](https://github.com/KhronosGroup/Glslang)
    - `spirv-cross` - [KhronosGroup/SPIRV-Cross](https://github.com/KhronosGroup/SPIRV-Cross)
    - `spirv-tools` - [KhronosGroup/SPIRV-Tools](https://github.com/KhronosGroup/SPIRV-Tools)
    - `spirv-reflect` - [KhronosGroup/SPIRV-Reflect](https://github.com/KhronosGroup/SPIRV-Reflect)
    - `spirv-headers` - [KhronosGroup/SPIRV-Headers](https://github.com/KhronosGroup/SPIRV-Headers)
    - `validation` - [KhronosGroup/Vulkan-ValidationLayers](https://github.com/KhronosGroup/Vulkan-ValidationLayers)

### Advanced integration
Building Vulkan SDK components from source requires finding compatible releases across Khronos repos (which move at different paces).

Fortunately LunarG provides an official version API [web service](https://vulkan.lunarg.com/content/view/latest-sdk-version-api) that can resolve release numbers into corresponding source. By default this action relies on the service to map revision inputs, but it is also possible to lock-in a specific source set by creating a local copy of the corresponding `config.json` in your project tree.

As a reference point here is what the `config.json` specs look like for the Vulkan SDK Linux v1.2.198.1 release:
- in-tree version: [tests/vulkan_sdk_specs/linux.json](tests/vulkan_sdk_specs/linux.json)
- retrieved from: https://vulkan.lunarg.com/sdk/config/1.2.198.1/linux/config.json

Example steps for adding to the project tree:
```sh
mkdir vulkan_sdk_specs
curl -o vulkan_sdk_specs/linux.json https://vulkan.lunarg.com/sdk/config/1.2.198.1/linux/config.json
git add vulkan_sdk_specs/linux.json
git commit -m "pinned vulkan sdk version for linux"
```
And example Workflow integration:
```yaml
  - name: Configure Vulkan SDK using in-repo config
    uses: humbletim/setup-vulkan-sdk@v1.1.0
    with:
      vulkan-config-file: vulkan_sdk_specs/linux.json
      vulkan-components: headers, loader
      vulkan-use-cache: true
```

## Notes

As of v1.1.0 logic has been consolidated into [install_vulkan_sdk.sh](install_vulkan_sdk.sh), which could also be used standalone for local installs or as part of similar CI/CD build environments:
```sh
# show available command-line arguments
./install_vulkan_sdk.sh --help

# query Vulkan webservice for available SDK versions
./install_vulkan_sdk.sh --query-versions

# query corresponding SDK component repos/refs specific to an SDK release
./install_vulkan_sdk.sh 1.2.161.1 --query-config

# install a specific SDK version (saving VULKAN_SDK environment var into 'output.env')
env GITHUB_ENV=output.env ./install_vulkan_sdk.sh 1.2.161.1 headers loader
. output.env
echo "VULKAN_SDK=$VULKAN_SDK"
```

Additional action integration examples can be found as part of this project's CI test suite: [.github/workflows/ci.yml](.github/workflows/ci.yml).

## References
- [Vulkan SDK](https://www.lunarg.com/vulkan-sdk/)
- [Vulkan SDK web services API](https://vulkan.lunarg.com/content/view/latest-sdk-version-api)

------------------------------

## Experimental

### Using prebuilt Vulkan SDKs

This action now also supports unattended installation of official Vulkan SDK binary releases; however, this is only meant only as a fallback strategy to consider alongside building just the components you need from source. Note that SDK binary releases currently include over a gigabyte of expanded content that is typically unnecessary for automated builds.

Additional ~component parameter option:
- `prebuilt` - [LunarG Vulkan SDK binaries](https://www.lunarg.com/vulkan-sdk/) (automated download/unpacking)
  - _note: the prebuilt option is meant to be mutually-exclusive with all other options except loader_

To perform an unattended install of a specific Vulkan SDK binary release:
```yaml
  - name: Install Monolithic Vulkan SDK binary release
    uses: humbletim/setup-vulkan-sdk@v1.1.0
    with:
      vulkan-version: 1.2.161.1
      vulkan-components: prebuilt
```
