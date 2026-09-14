#include "MetalUpscaler.hpp"
#include <iostream>

// Include Metal headers
#ifdef __OBJC__
@import Metal;
@import Foundation;
#else
// Forward declarations for C++
#ifdef __cplusplus
extern "C" {
#endif
// Metal framework functions
void *MTLCreateSystemDefaultDevice();

// Objective-C runtime functions
void *objc_msgSend(void *self, const char *op, ...);
void *objc_getClass(const char *name);
void *sel_registerName(const char *str);

// Define OBJC_MSGSEND macro for C++
#ifndef OBJC_MSGSEND
#define OBJC_MSGSEND(receiver, selector)                                       \
  ((void *(*)(void *, void *))objc_msgSend)(receiver, selector)
#define OBJC_MSGSEND_RETURN(type, receiver, selector)                          \
  ((type (*)(void *, void *))objc_msgSend)(receiver, selector)
#endif

// Declare NSObject methods
void *objc_msgSend_release(void *self, void *_cmd);

#ifdef __cplusplus
}
#endif
#endif

// Simple bilinear upscaling implementation (CPU fallback)
static void bilinearUpscale(const uint8_t *input, uint32_t inWidth,
                            uint32_t inHeight, uint8_t *output,
                            uint32_t outWidth, uint32_t outHeight) {

  if (!input || !output || inWidth == 0 || inHeight == 0 || outWidth == 0 ||
      outHeight == 0) {
    throw std::invalid_argument("Invalid input or output parameters");
  }

  float x_ratio =
      (inWidth > 1) ? static_cast<float>(inWidth - 1) / outWidth : 0.0f;
  float y_ratio =
      (inHeight > 1) ? static_cast<float>(inHeight - 1) / outHeight : 0.0f;

  for (uint32_t y = 0; y < outHeight; ++y) {
    for (uint32_t x = 0; x < outWidth; ++x) {
      float gx = x * x_ratio;
      float gy = y * y_ratio;

      int gxi = static_cast<int>(gx);
      int gyi = static_cast<int>(gy);

      // Clamp to image boundaries
      gxi = (gxi < 0)                                ? 0
            : (gxi >= static_cast<int>(inWidth) - 1) ? inWidth - 2
                                                     : gxi;
      gyi = (gyi < 0)                                 ? 0
            : (gyi >= static_cast<int>(inHeight) - 1) ? inHeight - 2
                                                      : gyi;

      float dx = gx - gxi;
      float dy = gy - gyi;

      for (int c = 0; c < 4; ++c) {
        // Get the four nearest pixels
        uint8_t a = input[(gyi * inWidth + gxi) * 4 + c];
        uint8_t b = input[(gyi * inWidth + (gxi + 1)) * 4 + c];
        uint8_t c_val = input[((gyi + 1) * inWidth + gxi) * 4 + c];
        uint8_t d = input[((gyi + 1) * inWidth + (gxi + 1)) * 4 + c];

        // Bilinear interpolation
        float val = a * (1 - dx) * (1 - dy) + b * dx * (1 - dy) +
                    c_val * (1 - dx) * dy + d * dx * dy;

        // Clamp and store
        output[(y * outWidth + x) * 4 + c] = static_cast<uint8_t>(val);
      }
    }
  }
}

MetalUpscaler::MetalUpscaler() : m_device(nullptr), m_commandQueue(nullptr) {
  @autoreleasepool {
    // Get the default Metal device
#ifdef __OBJC__
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    if (device) {
      m_device = (__bridge_retained void *)device;
      // Create a command queue
      id<MTLCommandQueue> commandQueue = [device newCommandQueue];
      if (commandQueue) {
        m_commandQueue = (__bridge_retained void *)commandQueue;
      } else {
        std::cerr << "Warning: Failed to create Metal command queue. Falling "
                     "back to CPU upscaling."
                  << std::endl;
        CFRelease(m_device);
        m_device = nullptr;
      }
    } else {
      std::cerr << "Warning: Metal is not supported on this device. Falling "
                   "back to CPU upscaling."
                << std::endl;
    }
#else
    // Manual Objective-C message sending for C++
    void *nsDevice = MTLCreateSystemDefaultDevice();
    if (nsDevice) {
      m_device = nsDevice;

      // Create a command queue
      void *selNewCommandQueue = sel_registerName("newCommandQueue");
      void *commandQueue =
          OBJC_MSGSEND_RETURN(void *, m_device, selNewCommandQueue);

      if (commandQueue) {
        m_commandQueue = commandQueue;
      } else {
        std::cerr << "Warning: Failed to create Metal command queue. Falling "
                     "back to CPU upscaling."
                  << std::endl;
        void *selRelease = sel_registerName("release");
        OBJC_MSGSEND(m_device, selRelease);
        m_device = nullptr;
      }
    } else {
      std::cerr << "Warning: Metal is not supported on this device. Falling "
                   "back to CPU upscaling."
                << std::endl;
    }
#endif
  }
}

MetalUpscaler::~MetalUpscaler() {
  @autoreleasepool {
    if (m_commandQueue) {
#ifdef __OBJC__
      CFRelease(m_commandQueue);
#else
      void *selRelease = sel_registerName("release");
      OBJC_MSGSEND(m_commandQueue, selRelease);
#endif
      m_commandQueue = nullptr;
    }

    if (m_device) {
#ifdef __OBJC__
      CFRelease(m_device);
#else
      void *selRelease = sel_registerName("release");
      OBJC_MSGSEND(m_device, selRelease);
#endif
      m_device = nullptr;
    }
  }
}

void MetalUpscaler::upscale(const uint8_t *input, uint32_t inWidth,
                            uint32_t inHeight, uint8_t *output,
                            uint32_t outWidth, uint32_t outHeight) {

  if (!input || !output || inWidth == 0 || inHeight == 0 || outWidth == 0 ||
      outHeight == 0) {
    throw std::invalid_argument("Invalid input or output parameters");
  }

  // For now, always use the CPU-based upscaling
  // In a real implementation, we would check if Metal is available and use it
  bilinearUpscale(input, inWidth, inHeight, output, outWidth, outHeight);
}
