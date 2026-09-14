#!/bin/bash

# Check CUDA build script for upscale.cu

if command -v nvcc &>/dev/null; then
	echo "CUDA found. Attempting to build upscale.cu..."
	cd src/gpu/cuda || exit
	if nvcc upscale.cu -o upscaler -lopencv_core -lopencv_imgcodecs -lopencv_imgproc -lopencv_highgui -std=c++17; then
		echo "CUDA build successful"
		rm -f upscaler # Clean up binary
	else
		echo "CUDA build failed"
		exit 1
	fi
else
	echo "CUDA not available; skipping build check"
fi
