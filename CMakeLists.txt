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

if(VULKAN_SDK_COMPONENTS MATCHES "shaderc")
  file(WRITE ${CMAKE_BINARY_DIR}/shaderc_patch.cmake  [====[

    function(ls_path path)
      if(WIN32)
        execute_process(COMMAND powershell "-c" "ls ${path}")
      else()
        execute_process(COMMAND bash "-c" "ls ${path}")
      endif()
    endfunction(ls_path path)

    message(STATUS "======================== SHADER PATCH ========================")

    find_path(glslang_SOURCE_DIR glslang/Public/ShaderLang.h HINTS "${CMAKE_INSTALL_PREFIX}/include")
    set(glslang_SOURCE_DIR "${glslang_SOURCE_DIR}/glslang" "${glslang_SOURCE_DIR}" CACHE STRING "" FORCE)

    set(spirv-tools_SOURCE_DIR "${CMAKE_INSTALL_PREFIX}/include" CACHE FILEPATH "" FORCE)
    set(SPIRV-Headers_SOURCE_DIR "${CMAKE_INSTALL_PREFIX}/include" CACHE FILEPATH "" FORCE)
    # set(glslang_SOURCE_DIR "${CMAKE_INSTALL_PREFIX}/include")

    # -DSHADERC_GLSLANG_DIR=${CMAKE_CURRENT_LIST_DIR}/glslang -DSHADERC_SPIRV_TOOLS_DIR=${CMAKE_CURRENT_LIST_DIR}/spirv-tools
    # set(SHADERC_GLSLANG_DIR "${CMAKE_CURRENT_LIST_DIR}/glslang" CACHE STRING "" FORCE)
    # set(SHADERC_SPIRV_TOOLS_DIR "${CMAKE_CURRENT_LIST_DIR}/spirv-tools" CACHE STRING "" FORCE)

    message(STATUS "spirv-tools_SOURCE_DIR")
    ls_path(${spirv-tools_SOURCE_DIR})

    include(FindPackageHandleStandardArgs)
    include(SelectLibraryConfigurations)

    set(CMAKE_DEBUG_POSTFIX "" CACHE STRING "" FORCE)

    find_library(SPIRV_TOOLS_LIBRARY_DEBUG NAMES SPIRV-Toolsd HINTS ${CMAKE_INSTALL_PREFIX} PATH_SUFFIXES DEBUG/lib)
    find_library(SPIRV_TOOLS_LIBRARY_RELEASE NAMES SPIRV-Tools HINTS ${CMAKE_INSTALL_PREFIX} PATH_SUFFIXES lib)
    find_path(SPIRV_TOOLS_INCLUDE_DIR NAMES spirv-tools/libspirv.h HINTS ${CMAKE_INSTALL_PREFIX} ${CMAKE_INSTALL_PREFIX}/include/spirv-tools PATH_SUFFIXES include)
    find_library(SPIRV_TOOLS_OPT_LIBRARY_DEBUG NAMES SPIRV-Tools-optd HINTS ${CMAKE_INSTALL_PREFIX} PATH_SUFFIXES DEBUG/lib)
    find_library(SPIRV_TOOLS_OPT_LIBRARY_RELEASE NAMES SPIRV-Tools-opt HINTS ${CMAKE_INSTALL_PREFIX} PATH_SUFFIXES lib)

    message(STATUS "SPIRV_TOOLS_INCLUDE_DIR")
    ls_path(${SPIRV_TOOLS_INCLUDE_DIR})

    message(STATUS "CMAKE_INSTALL_PREFIX/include/")
    ls_path(${CMAKE_INSTALL_PREFIX}/include/)

    message(STATUS "CMAKE_INSTALL_PREFIX/include/spirv-tools")
    ls_path(${CMAKE_INSTALL_PREFIX}/include/spirv-tools)
    
    select_library_configurations(SPIRV_TOOLS)
    select_library_configurations(SPIRV_TOOLS_OPT)

    find_package_handle_standard_args(
      SPIRV-Tools
      DEFAULT_MSG
      SPIRV_TOOLS_LIBRARY
      SPIRV_TOOLS_OPT_LIBRARY
      SPIRV_TOOLS_INCLUDE_DIR
    )

    add_library(SPIRV-Tools UNKNOWN IMPORTED)
    set_property(TARGET SPIRV-Tools APPEND PROPERTY IMPORTED_CONFIGURATIONS "$<$<CONFIG:DEBUG>:Debug>$<$<CONFIG:RELEASE>:Debug>")
    set_target_properties(
      SPIRV-Tools
        PROPERTIES
          IMPORTED_LOCATION ${SPIRV_TOOLS_LIBRARY}
          INCLUDE_DIRECTORIES ${SPIRV_TOOLS_INCLUDE_DIR} 
    )

    set_target_properties(SPIRV-Tools PROPERTIES INTERFACE_INCLUDE_DIRECTORIES ${SPIRV_TOOLS_INCLUDE_DIR} )

    add_library(SPIRV-Tools-opt UNKNOWN IMPORTED)
    set_property(TARGET SPIRV-Tools-opt APPEND PROPERTY IMPORTED_CONFIGURATIONS "$<$<CONFIG:DEBUG>:Debug>$<$<CONFIG:RELEASE>:Release>")
    set_target_properties(
      SPIRV-Tools-opt
        PROPERTIES
          IMPORTED_LOCATION ${SPIRV_TOOLS_OPT_LIBRARY}
          INCLUDE_DIRECTORIES ${SPIRV_TOOLS_INCLUDE_DIR}
    )

    set_property(TARGET SPIRV-Tools-opt APPEND PROPERTY INTERFACE_LINK_LIBRARIES SPIRV-Tools)

    find_library(GLSLANG_LIBRARY_RELEASE NAMES glslang HINTS ${CMAKE_INSTALL_PREFIX} PATH_SUFFIXES lib)
    find_library(OGLCOMPILER_LIBRARY_RELEASE NAMES OGLCompiler HINTS ${CMAKE_INSTALL_PREFIX} PATH_SUFFIXES lib)
    find_library(OSDEPENDENT_LIBRARY_RELEASE NAMES OSDependent HINTS ${CMAKE_INSTALL_PREFIX} PATH_SUFFIXES lib)
    find_library(GENERICCODEGEN_LIBRARY_RELEASE NAMES GenericCodeGen HINTS ${CMAKE_INSTALL_PREFIX} PATH_SUFFIXES lib)
    find_library(MACHINEINDEPENDENT_LIBRARY_RELEASE NAMES MachineIndependent HINTS ${CMAKE_INSTALL_PREFIX} PATH_SUFFIXES lib)
    find_library(HLSL_LIBRARY_RELEASE NAMES HLSL HINTS ${CMAKE_INSTALL_PREFIX} PATH_SUFFIXES  lib)
    find_library(SPIRV_LIBRARY_RELEASE NAMES SPIRV HINTS ${CMAKE_INSTALL_PREFIX} PATH_SUFFIXES lib)
    find_library(SPVREMAPPER_LIBRARY_RELEASE NAMES SPVRemapper HINTS ${CMAKE_INSTALL_PREFIX} PATH_SUFFIXES lib)
    find_library(GLSLANG_LIBRARY_DEBUG NAMES glslangd HINTS ${CMAKE_INSTALL_PREFIX} PATH_SUFFIXES DEBUG/lib)
    find_library(OGLCOMPILER_LIBRARY_DEBUG NAMES OGLCompilerd HINTS ${CMAKE_INSTALL_PREFIX} PATH_SUFFIXES DEBUG/lib)
    find_library(OSDEPENDENT_LIBRARY_DEBUG NAMES OSDependentd HINTS ${CMAKE_INSTALL_PREFIX} PATH_SUFFIXES DEBUG/lib)
    find_library(SPIRV_LIBRARY_DEBUG NAMES SPIRVd PATH_SUFFIXES HINTS ${CMAKE_INSTALL_PREFIX} DEBUG/lib)
    find_library(GENERICCODEGEN_LIBRARY_DEBUG NAMES GenericCodeGend HINTS ${CMAKE_INSTALL_PREFIX} PATH_SUFFIXES DEBUG/lib)
    find_library(MACHINEINDEPENDENT_LIBRARY_DEBUG NAMES MachineIndependentd HINTS ${CMAKE_INSTALL_PREFIX} PATH_SUFFIXES DEBUG/lib)
    find_library(HLSL_LIBRARY_DEBUG NAMES HLSLd PATH_SUFFIXES HINTS ${CMAKE_INSTALL_PREFIX} DEBUG/lib)
    find_library(SPVREMAPPER_LIBRARY_DEBUG NAMES SPVRemapperd HINTS ${CMAKE_INSTALL_PREFIX} PATH_SUFFIXES DEBUG/lib)
    find_path(GLSLANG_INCLUDE_DIR NAMES glslang/Public/ShaderLang.h HINTS ${CMAKE_INSTALL_PREFIX} PATH_SUFFIXES include)
    find_path(SPIRV_INCLUDE_DIR NAMES SPIRV/spirv.hpp HINTS ${CMAKE_INSTALL_PREFIX} ${CMAKE_INSTALL_PREFIX}/include/glslang PATH_SUFFIXES include)
    find_program(GLSLANG_VALIDATOR_EXE NAMES glslangValidator HINTS ${CMAKE_INSTALL_PREFIX} PATH_SUFFIXES bin)
    
    message(STATUS "CMAKE_INSTALL_PREFIX")
    ls_path(${CMAKE_INSTALL_PREFIX})
    
    message(STATUS "SPIRV_INCLUDE_DIR")
    ls_path(${SPIRV_INCLUDE_DIR})
    
    select_library_configurations(GLSLANG)
    select_library_configurations(OGLCOMPILER)
    select_library_configurations(OSDEPENDENT)
    select_library_configurations(SPIRV)
    select_library_configurations(HLSL)
    select_library_configurations(GENERICCODEGEN)
    select_library_configurations(MACHINEINDEPENDENT)
    select_library_configurations(SPVREMAPPER)

    find_package_handle_standard_args(
      glslang
      DEFAULT_MSG
      GLSLANG_LIBRARY
      OGLCOMPILER_LIBRARY
      OSDEPENDENT_LIBRARY
      SPIRV_TOOLS_OPT_LIBRARY
      SPIRV_LIBRARY
      HLSL_LIBRARY
      SPVREMAPPER_LIBRARY
      GLSLANG_INCLUDE_DIR
      SPIRV_INCLUDE_DIR
    )

    find_package(Threads)

    add_library(OGLCompiler STATIC IMPORTED)
    set_property(TARGET OGLCompiler APPEND PROPERTY IMPORTED_CONFIGURATIONS "$<$<CONFIG:DEBUG>:Debug>$<$<CONFIG:RELEASE>:Release>")
    set_target_properties(
      OGLCompiler   
        PROPERTIES
          IMPORTED_LOCATION ${OGLCOMPILER_LIBRARY}
    )

    target_link_libraries(OGLCompiler INTERFACE Threads::Threads)

    add_library(OSDependent STATIC IMPORTED)
    set_property(TARGET OSDependent APPEND PROPERTY IMPORTED_CONFIGURATIONS "$<$<CONFIG:DEBUG>:Debug>$<$<CONFIG:RELEASE>:Release>")
    set_target_properties(
      OSDependent
        PROPERTIES
          IMPORTED_LOCATION ${OSDEPENDENT_LIBRARY}
    )

    target_link_libraries(OSDependent INTERFACE Threads::Threads)

    add_library(HLSL STATIC IMPORTED)
    set_property(TARGET HLSL APPEND PROPERTY IMPORTED_CONFIGURATIONS "$<$<CONFIG:DEBUG>:Debug>$<$<CONFIG:RELEASE>:Release>")
    set_target_properties(
      HLSL
        PROPERTIES
          IMPORTED_LOCATION ${HLSL_LIBRARY}
          INCLUDE_DIRECTORIES ${CMAKE_INSTALL_PREFIX}/include/glslang
    )

    add_library(GenericCodeGen STATIC IMPORTED)
    set_property(TARGET GenericCodeGen APPEND PROPERTY IMPORTED_CONFIGURATIONS "$<$<CONFIG:DEBUG>:Debug>$<$<CONFIG:RELEASE>:Release>")
    set_target_properties(
      GenericCodeGen
        PROPERTIES
          IMPORTED_LOCATION ${GENERICCODEGEN_LIBRARY}
          INCLUDE_DIRECTORIES ${CMAKE_INSTALL_PREFIX}/include/glslang
    )

    add_library(MachineIndependent STATIC IMPORTED)
    set_property(TARGET MachineIndependent APPEND PROPERTY IMPORTED_CONFIGURATIONS "$<$<CONFIG:DEBUG>:Debug>$<$<CONFIG:RELEASE>:Release>")
    set_target_properties(
      MachineIndependent
        PROPERTIES
          IMPORTED_LOCATION ${MACHINEINDEPENDENT_LIBRARY}
          INCLUDE_DIRECTORIES ${CMAKE_INSTALL_PREFIX}/include/glslang
    )
    
    target_link_libraries(MachineIndependent INTERFACE OGLCompiler OSDependent GenericCodeGen)

    add_library(SPVRemapper STATIC IMPORTED)
    set_property(TARGET SPVRemapper APPEND PROPERTY IMPORTED_CONFIGURATIONS "$<$<CONFIG:DEBUG>:Debug>$<$<CONFIG:RELEASE>:Release>")
    set_target_properties(
      SPVRemapper
        PROPERTIES
          IMPORTED_LOCATION ${SPVREMAPPER_LIBRARY}
    )

    add_library(glslang STATIC IMPORTED)
    set_property(TARGET glslang APPEND PROPERTY IMPORTED_CONFIGURATIONS "$<$<CONFIG:DEBUG>:Debug>$<$<CONFIG:RELEASE>:Release>")
    set_target_properties(
      glslang
        PROPERTIES
          IMPORTED_LOCATION ${GLSLANG_LIBRARY}
          INTERFACE_INCLUDE_DIRECTORIES "${CMAKE_INSTALL_PREFIX}/include;${CMAKE_INSTALL_PREFIX}/include/glslang;${GLSLANG_INCLUDE_DIR}"
    )

    target_link_directories(glslang 
      INTERFACE ${CMAKE_INSTALL_PREFIX}/include
      INTERFACE ${CMAKE_INSTALL_PREFIX}/include/glslang
      INTERFACE ${GLSLANG_INCLUDE_DIR})
    target_link_libraries(glslang INTERFACE HLSL OSDependent OGLCompiler GenericCodeGen MachineIndependent SPIRV-Tools SPIRV-Tools-opt)
    
    add_library(SPIRV STATIC IMPORTED)
    set_property(TARGET SPIRV APPEND PROPERTY IMPORTED_CONFIGURATIONS "$<$<CONFIG:DEBUG>:Debug>$<$<CONFIG:RELEASE>:Release>")
    set_target_properties(
      SPIRV
        PROPERTIES
          IMPORTED_LOCATION ${SPIRV_LIBRARY}
          INTERFACE_INCLUDE_DIRECTORIES "${CMAKE_INSTALL_PREFIX}/include;${CMAKE_INSTALL_PREFIX}/include/glslang;${SPIRV_INCLUDE_DIR}"
    )

    target_link_directories(SPIRV 
      INTERFACE ${CMAKE_INSTALL_PREFIX}/include
      INTERFACE ${CMAKE_INSTALL_PREFIX}/include/glslang
      INTERFACE ${SPIRV_INCLUDE_DIR})

    target_link_libraries(SPIRV INTERFACE MachineIndependent SPIRV-Tools-opt)

    find_package_handle_standard_args(glslangValidator
        "Cannot find glslangValidator, Shader won't be compiled offline"
        GLSLANG_VALIDATOR_EXE
    )
    
    add_executable(glslangValidator IMPORTED)
    set_target_properties(glslangValidator PROPERTIES IMPORTED_LOCATION ${GLSLANG_VALIDATOR_EXE})

    file(COPY "CHANGES" DESTINATION ${CMAKE_INSTALL_PREFIX}/include)

    if(MSVC)
      set(SHADERC_ENABLE_SHARED_CRT ON CACHE BOOL "" FORCE)
    endif()

    message(STATUS "glslang/Include")
    ls_path(${CMAKE_INSTALL_PREFIX}/include/glslang/Include)

    if(CMAKE_BUILD_TYPE STREQUAL "Debug")
      message(STATUS "config debug strqual")
      # set(CMAKE_DEBUG_POSTFIX d)
      set(CMAKE_STATIC_LIBRARY_SUFFIX "d${CMAKE_STATIC_LIBRARY_SUFFIX}")
      set(CMAKE_SHARED_LIBRARY_SUFFIX "d${CMAKE_SHARED_LIBRARY_SUFFIX}")
    endif()

    # SPIRV-Tools-static
    # MachineIndependent
    # SPIRV
    # SPIRV-Tools-opt
    # GenericCodeGen
    # OSDependent
    # OGLCompiler

  ]====])

  file(WRITE ${CMAKE_BINARY_DIR}/shaderc_util_patch.cmake  [====[
    if(SHADERC_ENABLE_INSTALL AND NOT BUILD_SHARED_LIBS)
      install(TARGETS shaderc_util
        LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
        RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
        ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR})
    endif()

  ]====])

  set_property(GLOBAL APPEND PROPERTY shaderc_patch_command bash "-c" "sed -i -e \'17a include(${CMAKE_BINARY_DIR}/shaderc_patch.cmake)\' CMakeLists.txt && sed -i -e \'52a include(${CMAKE_BINARY_DIR}/shaderc_util_patch.cmake)\' libshaderc_util/CMakeLists.txt && sed -i \'142,146d\' CMakeLists.txt && sed -i \'56d\' glslc/CMakeLists.txt")

  # set_property(GLOBAL APPEND PROPERTY shaderc_cmake_extra)

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