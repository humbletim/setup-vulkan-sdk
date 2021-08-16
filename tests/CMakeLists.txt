cmake_minimum_required(VERSION 3.18)
project(test_vulkan)

message(STATUS "")
message(STATUS "|| VULKAN_SDK '$ENV{VULKAN_SDK}' PREFLIGHT TEST ||")
find_package(Vulkan)
get_cmake_property(Vars VARIABLES)
# debug -- dump all variables starting with "vulkan""
foreach (Var ${Vars})
  string( TOLOWER "${Var}" var )
  if (var MATCHES "^vulkan")
    message(STATUS "${Var}=${${Var}}")
  endif()
endforeach()

message(STATUS "")
message(STATUS "|| VULKAN_SDK TEST APPLICATION ||")
find_package(Vulkan REQUIRED FATAL_ERROR)
add_executable(test_vulkan test_vulkan.c)
target_link_libraries(test_vulkan PRIVATE Vulkan::Vulkan)

## alternative approach
#target_include_directories(test_vulkan PRIVATE ${Vulkan_INCLUDE_DIR})
#target_link_libraries(test_vulkan PRIVATE ${Vulkan_LIBRARY})
