#include <vulkan/vulkan.h>
#include <stdio.h>
#include <stdint.h>

int main(int argc, char** argv) {
  fprintf(stderr, "[test_vulkan.c] main....\n");fflush(stderr);
  uint32_t version = 0;
  PFN_vkEnumerateInstanceVersion vkEnumerateInstanceVersion = (PFN_vkEnumerateInstanceVersion)vkGetInstanceProcAddr(NULL, "vkEnumerateInstanceVersion");
  if(vkEnumerateInstanceVersion) {
      vkEnumerateInstanceVersion(&version);
  } else {
      fprintf(stderr, "[test_vulkan.c] vkGetInstanceProcAddr (%p) lookup of vkEnumerateInstanceVersion failed...\n", vkEnumerateInstanceVersion);
      return 1;
  }

  printf("[test_vulkan.c] Vulkan Version: (%u) %d.%d.%d\n", version,
    VK_VERSION_MAJOR(version),
    VK_VERSION_MINOR(version),
    VK_VERSION_PATCH(version)
  );
  return 0;
}