#pragma once

#include <cstdint>

// Forward declarations for Metal types
#ifdef __OBJC__
@import Metal;
@import Foundation;
#else
// Forward declarations for C++
#ifdef __cplusplus
extern "C" {
#endif
// Forward declarations for Objective-C types
typedef struct objc_object *id;
typedef struct objc_selector *SEL;

// Forward declarations for Metal types
typedef id MTLDevice;
typedef id MTLCommandQueue;

// Objective-C runtime functions
void *objc_msgSend(void *self, const char *op, ...);
void *objc_getClass(const char *name);
SEL sel_registerName(const char *str);

// Metal framework functions
void *MTLCreateSystemDefaultDevice();

#ifdef __cplusplus
}
#endif
#endif

class MetalUpscaler {
public:
  MetalUpscaler();
  ~MetalUpscaler();

  // Simple bilinear upscale for now
  void upscale(const uint8_t *input, uint32_t inWidth, uint32_t inHeight,
               uint8_t *output, uint32_t outWidth, uint32_t outHeight);

private:
  void *m_device;       // MTLDevice*
  void *m_commandQueue; // MTLCommandQueue*

  // Prevent copying
  MetalUpscaler(const MetalUpscaler &) = delete;
  MetalUpscaler &operator=(const MetalUpscaler &) = delete;
};
