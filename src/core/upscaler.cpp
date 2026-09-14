// SPDX-License-Identifier: BSD-3-Clause

#include "upscaler.hpp"

// Forward declarations
#ifdef HAVE_CUDA
class CudaUpscaler : public Upscaler {
public:
  void upscale(const uint8_t *input, uint32_t inWidth, uint32_t inHeight,
               uint8_t *output, uint32_t outWidth,
               uint32_t outHeight) override {
    // This would be implemented by the CUDA upscaler
    throw std::runtime_error("CUDA upscaler not implemented");
  }
};
#endif

#ifdef HAVE_METAL
#include "../gpu/metal/MetalUpscaler.hpp"
class MetalUpscalerWrapper : public Upscaler {
  std::unique_ptr<MetalUpscaler> m_metalUpscaler;

public:
  MetalUpscalerWrapper() : m_metalUpscaler(std::make_unique<MetalUpscaler>()) {}

  void upscale(const uint8_t *input, uint32_t inWidth, uint32_t inHeight,
               uint8_t *output, uint32_t outWidth,
               uint32_t outHeight) override {
    m_metalUpscaler->upscale(input, inWidth, inHeight, output, outWidth,
                             outHeight);
  }
};
#endif

// Factory implementation
std::unique_ptr<Upscaler> Upscaler::create() {
#ifdef HAVE_METAL
  if (isMetalAvailable()) {
    try {
      return std::make_unique<MetalUpscalerWrapper>();
    } catch (const std::exception &e) {
      // Fall through to CUDA if Metal fails
    }
  }
#endif

#ifdef HAVE_CUDA
  if (isCudaAvailable()) {
    return std::make_unique<CudaUpscaler>();
  }
#endif

  throw std::runtime_error("No suitable upscaler available");
}

bool Upscaler::isMetalAvailable() {
#ifdef __APPLE__
  // Check if we can create a Metal device
  @autoreleasepool {
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    return device != nil;
  }
#else
  return false;
#endif
}

bool Upscaler::isCudaAvailable() {
#ifdef HAVE_CUDA
  // Simple check if CUDA is available
  int deviceCount = 0;
  cudaError_t error_id = cudaGetDeviceCount(&deviceCount);
  return (error_id == cudaSuccess) && (deviceCount > 0);
#else
  return false;
#endif
}
