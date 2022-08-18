include(FindPackageHandleStandardArgs)
include(SelectLibraryConfigurations)

# RELEASE
find_library(GLSLANG_LIBRARY_RELEASE NAMES glslang HINTS ${CMAKE_INSTALL_PREFIX} PATH_SUFFIXES lib)
find_library(OGLCOMPILER_LIBRARY_RELEASE NAMES OGLCompiler HINTS ${CMAKE_INSTALL_PREFIX} PATH_SUFFIXES lib)
find_library(OSDEPENDENT_LIBRARY_RELEASE NAMES OSDependent HINTS ${CMAKE_INSTALL_PREFIX} PATH_SUFFIXES lib)
find_library(GENERICCODEGEN_LIBRARY_RELEASE NAMES GenericCodeGen HINTS ${CMAKE_INSTALL_PREFIX} PATH_SUFFIXES lib)
find_library(MACHINEINDEPENDENT_LIBRARY_RELEASE NAMES MachineIndependent HINTS ${CMAKE_INSTALL_PREFIX} PATH_SUFFIXES lib)
find_library(HLSL_LIBRARY_RELEASE NAMES HLSL HINTS ${CMAKE_INSTALL_PREFIX} PATH_SUFFIXES  lib)
find_library(SPIRV_LIBRARY_RELEASE NAMES SPIRV HINTS ${CMAKE_INSTALL_PREFIX} PATH_SUFFIXES lib)
find_library(SPVREMAPPER_LIBRARY_RELEASE NAMES SPVRemapper HINTS ${CMAKE_INSTALL_PREFIX} PATH_SUFFIXES lib)
# DEBUG
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
      GLSLANG_INCLUDE_DIR
      SPIRV_INCLUDE_DIR
    )

find_package(Threads)

add_library(OGLCompiler STATIC IMPORTED GLOBAL)
set_property(TARGET OGLCompiler APPEND PROPERTY IMPORTED_CONFIGURATIONS "$<$<CONFIG:DEBUG>:Debug>$<$<CONFIG:RELEASE>:Release>")
set_target_properties(
    OGLCompiler   
    PROPERTIES
        IMPORTED_LOCATION ${OGLCOMPILER_LIBRARY}
)

target_link_libraries(OGLCompiler INTERFACE Threads::Threads)

add_library(OSDependent STATIC IMPORTED GLOBAL)
set_property(TARGET OSDependent APPEND PROPERTY IMPORTED_CONFIGURATIONS "$<$<CONFIG:DEBUG>:Debug>$<$<CONFIG:RELEASE>:Release>")
set_target_properties(
    OSDependent
    PROPERTIES
        IMPORTED_LOCATION ${OSDEPENDENT_LIBRARY}
)

target_link_libraries(OSDependent INTERFACE Threads::Threads)

add_library(HLSL STATIC IMPORTED GLOBAL)
set_property(TARGET HLSL APPEND PROPERTY IMPORTED_CONFIGURATIONS "$<$<CONFIG:DEBUG>:Debug>$<$<CONFIG:RELEASE>:Release>")
set_target_properties(
    HLSL
    PROPERTIES
        IMPORTED_LOCATION ${HLSL_LIBRARY}
        INCLUDE_DIRECTORIES ${CMAKE_INSTALL_PREFIX}/include/glslang
)

add_library(GenericCodeGen STATIC IMPORTED GLOBAL)
set_property(TARGET GenericCodeGen APPEND PROPERTY IMPORTED_CONFIGURATIONS "$<$<CONFIG:DEBUG>:Debug>$<$<CONFIG:RELEASE>:Release>")
set_target_properties(
    GenericCodeGen
    PROPERTIES
        IMPORTED_LOCATION ${GENERICCODEGEN_LIBRARY}
        INCLUDE_DIRECTORIES ${CMAKE_INSTALL_PREFIX}/include/glslang
)

add_library(MachineIndependent STATIC IMPORTED GLOBAL)
set_property(TARGET MachineIndependent APPEND PROPERTY IMPORTED_CONFIGURATIONS "$<$<CONFIG:DEBUG>:Debug>$<$<CONFIG:RELEASE>:Release>")
set_target_properties(
    MachineIndependent
    PROPERTIES
        IMPORTED_LOCATION ${MACHINEINDEPENDENT_LIBRARY}
        INCLUDE_DIRECTORIES ${CMAKE_INSTALL_PREFIX}/include/glslang
)

target_link_libraries(MachineIndependent INTERFACE OGLCompiler OSDependent GenericCodeGen)

add_library(glslang STATIC IMPORTED GLOBAL)
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

target_link_libraries(SPIRV INTERFACE MachineIndependent SPIRV-Tools SPIRV-Tools-opt)

add_executable(glslangValidator IMPORTED GLOBAL)
set_target_properties(glslangValidator PROPERTIES IMPORTED_LOCATION ${GLSLANG_VALIDATOR_EXE})


    # include(CMakeFindDependencyMacro)

    # find_dependency(Threads)

    # foreach(targets OGLCompiler OSDependent glslang glslang-default-resource-limits glslangValidator HLSL SPIRV)
    #   include("${CMAKE_CURRENT_LIST_DIR}/${targets}Targets.cmake" OPTIONAL)
    # endforeach()
