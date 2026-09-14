#pragma once
#include <cuda_runtime.h>
#include <stdexcept>
#include <string>

// Macro for CUDA error checking that throws std::runtime_error
#define CUDA_CHECK(call)                                                       \
  do {                                                                         \
    cudaError_t err = call;                                                    \
    if (err != cudaSuccess) {                                                  \
      throw std::runtime_error(std::string("CUDA error in ") + __FILE__ +     \
                               " at line " + std::to_string(__LINE__) + ": " + \
                               cudaGetErrorString(err));                       \
    }                                                                          \
  } while (0)
