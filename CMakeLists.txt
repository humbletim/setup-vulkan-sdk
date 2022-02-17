# Vulkan SDK config.json cmake wrapper
# 2022.02.16 humbletim MIT license
# see: https://github.com/humbletim/setup-vulkan-sdk

# cmake variables:
#  -DVULKAN_SDK -- where to install SDK components
#  -DVULKAN_SDK_CONFIG -- config.json that specifies repos/branches
#  -DVULKAN_SDK_COMPONENTS -- which SDK components to install

#  note: a Vulkan SDK config.json can be downloaded using the template:
#   https://vulkan.lunarg.com/sdk/config/VERSION/PLATFORM/config.json
#  (see: https://vulkan.lunarg.com/content/view/latest-sdk-version-api)

cmake_minimum_required(VERSION 3.19)
# note: 3.19+ needed for JSON parsing

include(FetchContent)
set(FETCHCONTENT_QUIET OFF)

project(VulkanSDKComponents)

set(AVAILABLE_COMPONENTS
  Vulkan-Headers Vulkan-Loader Vulkan-ValidationLayers
  SPIRV-Headers SPIRV-Cross SPIRV-Tools SPIRV-Reflect
  Glslang shaderc
)
list(JOIN AVAILABLE_COMPONENTS " " COMPONENT_DEBUG_LIST)
# TODO (pending integration testing) Vulkan-ExtensionLayer Khronos-Tools LunarG-Tools DXC gfxreconstruct MoltenVK Vulkan-Docs robin-hood-hashing

macro(_assert varname)
  if (NOT ${varname})
    message(FATAL_ERROR "assertion failed (${varname}):\n" ${ARGN})
  endif()
endmacro()

_assert(VULKAN_SDK "define -DVULKAN_SDK=<path> to desired VULKAN_SDK installation folder")
_assert(VULKAN_SDK_CONFIG "define -DVULKAN_SDK_CONFIG=<file> to Vulkan SDK config.json")
_assert(VULKAN_SDK_COMPONENTS "define -DVULKAN_SDK_COMPONENTS=\"Vulkan-Headers;Vulkan-Loader;etc.\"\n"
                              "available: ${COMPONENT_DEBUG_LIST}")

if (DEFINED CMAKE_INSTALL_PREFIX)
  message(STATUS "CMAKE_INSTALL_PREFIX=${CMAKE_INSTALL_PREFIX} -- replacing with VULKAN_SDK=${VULKAN_SDK}")
  set(CMAKE_INSTALL_PREFIX ${VULKAN_SDK})
endif()

##############################################################################
# config.json SPIRV-Tools incorrectly suggests '-DSPIRV_HEADERS_INSTALL_DIR'
# but SPIRV-Tools itself seems to only check for '-DSPIRV-Headers_SOURCE_DIR'
# set(SPIRV-Tools_cmake_extra "-DSPIRV-Headers_SOURCE_DIR=${VULKAN_SDK}")

# attempting to get shaderc to build faster by disabling unnecessary stuff
# set(shaderc_cmake_extra "
#   -DBUILD_SHARED_LIBS:BOOL=OFF 
#   -DSHADERC_SKIP_TESTS=ON -DSHADERC_SKIP_EXAMPLES=ON 
#   -DSKIP_GLSLANG_INSTALL=ON -DENABLE_GLSLANG_BINARIES:BOOL=OFF 
#   -DSPIRV_SKIP_EXECUTABLES=ON -DSPIRV_SKIP_TESTS=ON -DSKIP_SPIRV_TOOLS_INSTALL=ON 
#   -DSPIRV_HEADERS_SKIP_INSTALL=ON -DSPIRV_HEADERS_SKIP_EXAMPLES=ON 
#   -DEFFCEE_BUILD_SAMPLES:BOOL=OFF -DEFFCEE_BUILD_TESTING:BOOL=OFF 
#   -DINSTALL_GTEST:BOOL=OFF
# ")

# example: get_subprops("${configJson}" "repos" "${name}" PROPERTIES url branch tag commit dependencies)
function(get_subprops configJson)
    cmake_parse_arguments(_sub "" "" "PROPERTIES" ${ARGN})
    foreach(arg IN LISTS _sub_PROPERTIES)
        string(JSON value ERROR_VARIABLE jsonerror GET "${configJson}" ${_sub_UNPARSED_ARGUMENTS} "${arg}")
        set(${arg} ${value} PARENT_SCOPE)
    endforeach()
endfunction()

# example: coalesce(VAR first second third) -> first truthy value found
function(coalesce outvar)
    list(FILTER ARGN EXCLUDE REGEX "^$|NOTFOUND")
    list(GET ARGN 0 tmp)
    set(${outvar} ${tmp} PARENT_SCOPE)
endfunction()

function(fetch_component name)
    if (${name}_component_defined)
      message(STATUS "[${ARGN} => ${name}] skipping satisfied dependency")
      return()
    endif()
    # message(">>>>>>>>>>>>>>>>>>>>>> ${name}_component_defined==${${name}_component_defined}")
    get_subprops("${configJson}" "repos" "${name}" PROPERTIES url branch commit tag dependencies)
    _assert(url "could not read URL for name=${name} url=${url}")
    coalesce(ref ${branch} ${commit} ${tag})
    set(cmake_extra "")
    set(deps "")
    if (dependencies)
      json_foreach("${configJson}" "repos;${name};dependencies" "
        set(deps ${deps} \"| {0}\" PARENT_SCOPE)
        fetch_component({0} ${name})
        FetchContent_MakeAvailable({0})
        set(cmake_extra \"${cmake_extra} -D{1}=\${VULKAN_SDK}\" PARENT_SCOPE)
      ")
    endif()
    # message("${name} ${ref} ${url} ${deps} ${cmake_extra}")
    message(STATUS "FetchContent_Declare ${name} ${cmake_extra}")
    set(${name}_component_defined ON PARENT_SCOPE)
    set(VULKAN_HITS ${VULKAN_HITS} ${name} PARENT_SCOPE)
    FetchContent_Declare(
      ${name}
      GIT_REPOSITORY ${url}
      GIT_TAG ${ref}
      GIT_PROGRESS OFF
      CMAKE_ARGS ${cmake_extra} ${${name}_cmake_extra}
    )
endfunction()

function(json_foreach configJson objectName functionName)
  string(JSON n LENGTH "${configJson}" ${objectName})
  MATH(EXPR n "${n}-1")
  foreach(i RANGE 0 ${n})
    string(JSON key MEMBER "${configJson}" ${objectName} ${i})
    string(JSON value GET "${configJson}" ${objectName} ${key})
    if (functionName MATCHES "[(]")
      set(tmp ${functionName})
      string(REPLACE "{0}" ${key} tmp ${tmp})
      string(REPLACE "{1}" ${value} tmp ${tmp})
      cmake_language(EVAL CODE ${tmp})
    else()
      cmake_language(CALL ${functionName} ${key} ${value})
    endif()
  endforeach()
endfunction()

##############################################################################
file(READ ${VULKAN_SDK_CONFIG} configJson)
set(VULKAN_HITS "")

get_subprops("${configJson}" PROPERTIES version release release_date)
message("---------------------------------------------------------------------")
message("sdk components:  ${COMPONENT_DEBUG_LIST}")
message("    build path:  ${CMAKE_BINARY_DIR}")
message("  install path:  ${VULKAN_SDK}")
message(" configuration:  ${VULKAN_SDK_CONFIG}")
message("      .version:  ${version}")
message(" .release_date:  ${release_date}")
message("---------------------------------------------------------------------")

foreach(name ${VULKAN_SDK_COMPONENTS})
  list(FIND AVAILABLE_COMPONENTS ${name} index)
  if (${index} EQUAL -1)
    message(FATAL_ERROR "unknown component: ${name}\navailable: ${COMPONENT_DEBUG_LIST}")
  endif()
  fetch_component(${name} "(user specified)")
endforeach()

FetchContent_MakeAvailable(${VULKAN_SDK_COMPONENTS})

message(STATUS "${VULKAN_SDK_COMPONENTS} /// ${VULKAN_HITS}")
string(TIMESTAMP TIME_T UTC)
file(WRITE
  ${CMAKE_BINARY_DIR}/sdk.env 
  "VULKAN_SDK=${VULKAN_SDK}
VULKAN_SDK_VERSION=${version}
VULKAN_SDK_BUILD_DATE=${TIME_T}
VULKAN_SDK_RELEASE=${release_date}
VULKAN_SDK_CONFIG=${VULKAN_SDK_CONFIG}
VULKAN_SDK_COMPONENTS=\"${VULKAN_SDK_COMPONENTS}\"
")
install(FILES ${CMAKE_BINARY_DIR}/sdk.env DESTINATION .)