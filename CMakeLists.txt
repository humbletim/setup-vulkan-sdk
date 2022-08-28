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

include(ExternalProject)
include(cmake/json_utils.cmake)

project(VulkanSDKComponents)

set(AVAILABLE_COMPONENTS "Vulkan-Headers Vulkan-Loader SPIRV-Headers SPIRV-Cross SPIRV-Tools SPIRV-Reflect Glslang shaderc")
# TODO: Vulkan-ExtensionLayer Khronos-Tools LunarG-Tools DXC gfxreconstruct MoltenVK Vulkan-Docs Vulkan-ValidationLayers robin-hood-hashing shaderc

macro(_assert varname)
  if (NOT ${varname})
    message(FATAL_ERROR "assertion failed (${varname}):\n" ${ARGN})
  endif()
endmacro()

_assert(VULKAN_SDK "define -DVULKAN_SDK=<path> to desired VULKAN_SDK installation folder")
_assert(VULKAN_SDK_CONFIG "define -DVULKAN_SDK_CONFIG=<file> to Vulkan SDK config.json")
_assert(VULKAN_SDK_COMPONENTS "define -DVULKAN_SDK_COMPONENTS=\"Vulkan-Headers;Vulkan-Loader;etc.\"\n"
                              "available: ${AVAILABLE_COMPONENTS}")

STRING(REGEX REPLACE "[, ]+" ";" VULKAN_SDK_COMPONENTS "${VULKAN_SDK_COMPONENTS}")

if (DEFINED CMAKE_INSTALL_PREFIX)
  message(STATUS "CMAKE_INSTALL_PREFIX=${CMAKE_INSTALL_PREFIX} -- replacing with VULKAN_SDK=${VULKAN_SDK}")
  set(CMAKE_INSTALL_PREFIX ${VULKAN_SDK})
endif()

##############################################################################
# manual Vulkan SDK build overrides

# manually list SPIRV-Headers as SPIRV-Tools dependency
set_property(GLOBAL APPEND PROPERTY SPIRV-Tools_deps_extra "SPIRV-Headers\;SPIRV-Headers_SOURCE_DIR")

# manually list robin-hood-hashing as Vulkan-ValidationLayers dependency
set_property(GLOBAL APPEND PROPERTY Vulkan-ValidationLayers_deps_extra "robin-hood-hashing\;ROBIN_HOOD_HASHING_INSTALL_DIR")

# setup shaderc depends
set_property(GLOBAL APPEND PROPERTY shaderc_deps_extra "SPIRV-Tools\;spirv-tools_SOURCE_DIR;Glslang\;glslang_SOURCE_DIR")
set_property(GLOBAL APPEND PROPERTY shaderc_cmake_extra -DSHADERC_SKIP_TESTS:BOOL=ON)
set_property(GLOBAL APPEND PROPERTY shaderc_cmake_extra -DSHADERC_ENABLE_SHARED_CRT:BOOL=ON)
set_property(GLOBAL APPEND PROPERTY shaderc_cmake_extra -DSHADERC_SKIP_COPYRIGHT_CHECK:BOOL=ON)
set_property(GLOBAL APPEND PROPERTY shaderc_commit "1bbf43f210941ba69a2cd05cf3529063f1ff5bb9")

# robin-hood-hashing is odd in Vulkan SDK config.json's -- but only the header is actually needed
set_property(GLOBAL APPEND PROPERTY robin-hood-hashing_install_command 
  test -d ${VULKAN_SDK}/include/ || mkdir -v ${VULKAN_SDK}/include/ &&
  cp -av ../robin-hood-hashing/src/include/robin_hood.h ${VULKAN_SDK}/include/
  
)
set_property(GLOBAL APPEND PROPERTY robin-hood-hashing_cmake_extra -DRH_STANDALONE_PROJECT:BOOL=OFF)

# if SPIRV-Tools-opt is available as part of installed components enable Glslang to locate it
if(VULKAN_SDK_COMPONENTS MATCHES "Glslang.*SPIRV-Tools|SPIRV-Tools.*Glslang|shaderc")
  message("Glslang + SPIRV-Tools -- patching Glslang dependency on SPIRV-Tools-opt")
  set_property(GLOBAL APPEND PROPERTY Glslang_deps_extra "SPIRV-Tools\;spirv-tools_SOURCE_DIR")
  file(WRITE ${CMAKE_BINARY_DIR}/Glslang_SPIRV_patch.cmake [====[
    add_library(SPIRV-Tools-opt INTERFACE)
    set_property(TARGET SPIRV-Tools-opt APPEND PROPERTY INTERFACE_LINK_DIRECTORIES ${CMAKE_INSTALL_PREFIX}/lib )
    set_property(TARGET SPIRV-Tools-opt APPEND PROPERTY INTERFACE_INCLUDE_DIRECTORIES ${CMAKE_INSTALL_PREFIX}/include )
    install(TARGETS SPIRV-Tools-opt EXPORT SPIRV-Tools-opt)
    install(EXPORT SPIRV-Tools-opt DESTINATION lib/cmake)
    set(spirv_tools NOTFOUND)
    set(spirv_tools_opt NOTFOUND)
    find_library(spirv_tools NAMES SPIRV-Tools SPIRV-Toolsd PATHS ${CMAKE_INSTALL_PREFIX}/lib REQUIRED NO_DEFAULT_PATH NO_PACKAGE_ROOT_PATH NO_CMAKE_PATH NO_CMAKE_ENVIRONMENT_PATH NO_SYSTEM_ENVIRONMENT_PATH NO_CMAKE_SYSTEM_PATH NO_CMAKE_FIND_ROOT_PATH)
    find_library(spirv_tools_opt NAMES SPIRV-Tools-opt SPIRV-Tools-optd PATHS ${CMAKE_INSTALL_PREFIX}/lib REQUIRED NO_DEFAULT_PATH NO_PACKAGE_ROOT_PATH NO_CMAKE_PATH NO_CMAKE_ENVIRONMENT_PATH NO_SYSTEM_ENVIRONMENT_PATH NO_CMAKE_SYSTEM_PATH NO_CMAKE_FIND_ROOT_PATH)
    set_property(TARGET SPIRV-Tools-opt APPEND PROPERTY INTERFACE_LINK_LIBRARIES ${spirv_tools_opt} ${spirv_tools})
  ]====])
  set_property(GLOBAL APPEND PROPERTY Glslang_patch_command bash "-c" "sed -i \'44 a include(${CMAKE_BINARY_DIR}/Glslang_SPIRV_patch.cmake)\' CMakeLists.txt")
  set_property(GLOBAL APPEND PROPERTY Glslang_cmake_extra -DENABLE_OPT:BOOL=ON)
else()
  # otherwise disable External completely 
  set_property(GLOBAL APPEND PROPERTY Glslang_cmake_extra -DBUILD_EXTERNAL:BOOL=OFF)
endif()

function(ls_path path)
      if(WIN32)
        execute_process(COMMAND powershell "-c" "ls ${path}")
      else()
        execute_process(COMMAND bash "-c" "ls ${path}")
      endif()
endfunction(ls_path path)

if(VULKAN_SDK_COMPONENTS MATCHES "shaderc")

  file(WRITE ${CMAKE_BINARY_DIR}/shaderc_patch.cmake  [====[
# message(STATUS "glslang_SOURCE_DIR "../../SPIRV-Tools-preficx")
    message(STATUS "spirv-tools_SOURCE_DIR ${spirv-tools_SOURCE_DIR}")
    # set(spirv-tools_SOURCE_DIR "${CMAKE_INSTALL_PREFIX}/include" CACHE FILEPATH "" FORCE)
    # set(SPIRV-Headers_SOURCE_DIR "${CMAKE_INSTALL_PREFIX}/include" CACHE FILEPATH "" FORCE)
    # set(glslang_SOURCE_DIR "${CMAKE_INSTALL_PREFIX}/include")

    function(ls_path path)
      if(WIN32)
        execute_process(COMMAND powershell "-c" "ls ${path}")
      else()
        execute_process(COMMAND bash "-c" "ls ${path}")
      endif()
    endfunction(ls_path path)

    ls_path(".")
    ls_path("..")
    ls_path("../..")


    ls_path(${CMAKE_CURRENT_BINARY_DIR})
    ls_path(${CMAKE_CURRENT_SOURCE_DIR})

    message(STATUS "======================== SHADERC PATCH ========================")

    if(MSVC)
      set(SHADERC_ENABLE_SHARED_CRT ON CACHE BOOL "" FORCE)
    endif()

    if(CMAKE_BUILD_TYPE STREQUAL "Debug")
      message(STATUS "config debug strqual")
      set(CMAKE_DEBUG_POSTFIX "")
      set(CMAKE_STATIC_LIBRARY_SUFFIX "d${CMAKE_STATIC_LIBRARY_SUFFIX}")
      set(CMAKE_SHARED_LIBRARY_SUFFIX "d${CMAKE_SHARED_LIBRARY_SUFFIX}")
    endif()

  ]====])

  # set_property(GLOBAL APPEND PROPERTY shaderc_patch_command bash "-c" "sed -i -e \'17a include(${CMAKE_BINARY_DIR}/shaderc_patch.cmake)\' CMakeLists.txt && sed -i -e \'52a include(${CMAKE_BINARY_DIR}/shaderc_util_patch.cmake)\' libshaderc_util/CMakeLists.txt && sed \'\'")
  set_property(GLOBAL APPEND PROPERTY shaderc_patch_command bash "-c" "sed -i -e \'17a include(${CMAKE_BINARY_DIR}/shaderc_patch.cmake)\' CMakeLists.txt && sed -i \'137,141d\' CMakeLists.txt && sed -i \'56d\' glslc/CMakeLists.txt")
  # set_property(GLOBAL APPEND PROPERTY shaderc_cmake_extra -DSHADERC_GLSLANG_DIR=${CMAKE_CURRENT_LIST_DIR}/glslang -DSHADERC_SPIRV_TOOLS_DIR=${CMAKE_CURRENT_LIST_DIR}/spirv-tools)

  ls_path(".")
  ls_path("..")
  ls_path("...")


endif()

function(setup_component_dependency key value parentName)
  setup_component(${key} ${parentName})
  set_property(GLOBAL APPEND PROPERTY ${parentName}_cmake_extra -D${value}:FILEPATH=${VULKAN_SDK})
  set_property(GLOBAL APPEND PROPERTY ${parentName}_deps ${key})
endfunction()

function(setup_component name parentName)
    if (TARGET ${name})
      # message(STATUS "skipping second ExternalProject_Add ${name}")
      return()
    endif()
    # message(">>>>>>>>>>>>>>>>>>>>>> ${name}_component_defined==${${name}_component_defined}")
    json_get_subprops("${configJson}" "repos" "${name}" PROPERTIES url dependencies)
    _assert(url "could not read URL for name=${name} url=${url}")
    json_coalesce_subprops("${configJson}" ref "repos" "${name}" PROPERTIES commit tag branch)

    # process config.json dependencies first
    json_foreach("${dependencies}" "" setup_component_dependency ${name})
    # then any override deps_extra's
    get_component_props(${name} deps_extra)
    foreach(kv ${deps_extra})
      setup_component_dependency(${kv} ${name})
    endforeach()

    get_component_props(${name} deps cmake_extra patch_command install_command)
    # convert spaces to list (otherwise CMAKE_ARGS seems to force quotes if there are spaces in singular values)
    string(REPLACE " " ";" cmake_extra "${cmake_extra}")
    set(cmake_args
        -DCMAKE_INSTALL_MESSAGE=NEVER
        -DCMAKE_BUILD_TYPE=$<CONFIG>
        -DCMAKE_INSTALL_PREFIX=${VULKAN_SDK}
        # -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
        # -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
        # -DCMAKE_BUILD_WITH_INSTALL_RPATH:BOOL=ON
    )

    list(APPEND cmake_args ${cmake_extra})
    if(NOT ("${name}" STREQUAL "Vulkan-Loader"))
      list(APPEND cmake_args -DCMAKE_DEBUG_POSTFIX=d)
    endif()
    message(STATUS "ExternalProject_Add ${name} ${ref} deps=[${deps}] cmake_extra=[${cmake_extra}]")
    ExternalProject_Add("${name}"
      GIT_REPOSITORY "${url}"
      GIT_TAG "${ref}"
      GIT_PROGRESS OFF
      CMAKE_CACHE_ARGS ${cmake_extra}
      CMAKE_ARGS ${cmake_args}
      DEPENDS ${deps}
      PATCH_COMMAND ${patch_command}
      INSTALL_COMMAND ${install_command}
    )

    set_property(GLOBAL APPEND PROPERTY VULKAN_COMPONENTS_PROCESSED ${name})
endfunction()

##############################################################################
file(READ ${VULKAN_SDK_CONFIG} configJson)

list(JOIN VULKAN_SDK_COMPONENTS " " REQUESTED_COMPONENTS)
json_get_subprops("${configJson}" PROPERTIES version release release_date)
message("---------------------------------------------------------------------")
message("sdk components:  ${REQUESTED_COMPONENTS}")
message("    build path:  ${CMAKE_BINARY_DIR}")
message("  install path:  ${VULKAN_SDK}")
message(" configuration:  ${VULKAN_SDK_CONFIG}")
message("      .version:  ${version}")
message(" .release_date:  ${release_date}")
message("---------------------------------------------------------------------")

string(REPLACE " " ";" AVAILABLE_COMPONENTS_LIST ${AVAILABLE_COMPONENTS})
foreach(name ${VULKAN_SDK_COMPONENTS})
  list(FIND AVAILABLE_COMPONENTS_LIST ${name} index)
  if (${index} EQUAL -1)
    message(FATAL_ERROR "unknown component: ${name}\navailable: ${AVAILABLE_COMPONENTS}")
  endif()
  setup_component(${name} "${name}")
endforeach()



message("===================================================================")
message("VULKAN_SDK_COMPONENTS: ${VULKAN_SDK_COMPONENTS}")
get_property(VULKAN_COMPONENTS_PROCESSED GLOBAL PROPERTY VULKAN_COMPONENTS_PROCESSED)
message("            PROCESSED: ${VULKAN_COMPONENTS_PROCESSED}")
message("===================================================================")

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