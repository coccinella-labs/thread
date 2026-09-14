# Compatibility

## What Works

- Python 3.10, 3.11, 3.12, 3.13, 3.14
- C++20
- CMake 3.10+ (3.21+ recommended for CUDA and Metal support)
- OpenCV 4.0+ (optional; `stb_image` is the fallback)
- CUDA Toolkit 12.0+ (optional, Linux/Windows only, OFF by default)
- Metal 3.0+ (optional, macOS only, OFF by default)

Tested on:

- macOS 11+ (arm64, x86_64)
- Ubuntu 22.04+
- Windows 10+

## What Does Not Work

The project once planned GPU acceleration as a core feature. Those plans were
abandoned. The following were never part of the working product:

- Eigen: not used
- pybind11: not used
- TensorRT: not used
- ONNX: not used
- TensorFlow: not used
- PyTorch: not used

GPU code in the API is not functional. See `RECONSTRUCTION.md` for the design
history and why each GPU layer was left incomplete.