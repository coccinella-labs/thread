#pragma once

#include <cstdint>
#include <memory>
#include <stdexcept>

class Upscaler {
public:
  virtual ~Upscaler() = default;

  // Upscale an image
  // Input and output should be RGBA8 format (4 bytes per pixel)
  // The caller is responsible for allocating the output buffer
  virtual void upscale(const uint8_t *input, uint32_t inWidth,
                       uint32_t inHeight, uint8_t *output, uint32_t outWidth,
                       uint32_t outHeight) = 0;

  // Factory method to create the appropriate upscaler for the current platform
  static std::unique_ptr<Upscaler> create();

  // Check if Metal is available (macOS only)
  static bool isMetalAvailable();

  // Check if CUDA is available
  static bool isCudaAvailable();
};
