/**
 * Additional CUDA Image Filters
 *
 * This file provides GPU-accelerated image filters: Gaussian blur and edge
 * detection (Sobel). Can be extended with more filters.
 */

#include <cuda_runtime.h>
#include <iostream>
#include <opencv2/opencv.hpp>

// CUDA kernel for Gaussian blur (simple 3x3 kernel)
__global__ void gaussianBlurKernel(uchar *input, uchar *output, int width,
                                   int height) {
  int x = blockIdx.x * blockDim.x + threadIdx.x;
  int y = blockIdx.y * blockDim.y + threadIdx.y;

  if (x >= width || y >= height)
    return;

  float kernel[3][3] = {{1 / 16.0f, 2 / 16.0f, 1 / 16.0f},
                        {2 / 16.0f, 4 / 16.0f, 2 / 16.0f},
                        {1 / 16.0f, 2 / 16.0f, 1 / 16.0f}};

  for (int c = 0; c < 3; c++) {
    float sum = 0.0f;
    for (int ky = -1; ky <= 1; ky++) {
      for (int kx = -1; kx <= 1; kx++) {
        int px = min(max(x + kx, 0), width - 1);
        int py = min(max(y + ky, 0), height - 1);
        sum += input[(py * width + px) * 3 + c] * kernel[ky + 1][kx + 1];
      }
    }
    output[(y * width + x) * 3 + c] = (uchar)sum;
  }
}

// CUDA kernel for Sobel edge detection
__global__ void sobelEdgeKernel(uchar *input, uchar *output, int width,
                                int height) {
  int x = blockIdx.x * blockDim.x + threadIdx.x;
  int y = blockIdx.y * blockDim.y + threadIdx.y;

  if (x >= width || y >= height)
    return;

  int Gx[3][3] = {{-1, 0, 1}, {-2, 0, 2}, {-1, 0, 1}};
  int Gy[3][3] = {{-1, -2, -1}, {0, 0, 0}, {1, 2, 1}};

  float gx = 0.0f, gy = 0.0f;
  for (int ky = -1; ky <= 1; ky++) {
    for (int kx = -1; kx <= 1; kx++) {
      int px = min(max(x + kx, 0), width - 1);
      int py = min(max(y + ky, 0), height - 1);
      float gray = 0.299f * input[(py * width + px) * 3] +
                   0.587f * input[(py * width + px) * 3 + 1] +
                   0.114f * input[(py * width + px) * 3 + 2];
      gx += gray * Gx[ky + 1][kx + 1];
      gy += gray * Gy[ky + 1][kx + 1];
    }
  }
  float magnitude = sqrtf(gx * gx + gy * gy);
  output[(y * width + x) * 3] = output[(y * width + x) * 3 + 1] =
      output[(y * width + x) * 3 + 2] = (uchar)min(magnitude, 255.0f);
}

// Host function to apply Gaussian blur
int applyGaussianBlur(const cv::Mat &input, cv::Mat &output) {
  int width = input.cols;
  int height = input.rows;
  size_t size = width * height * 3 * sizeof(uchar);

  output = cv::Mat(height, width, input.type());

  uchar *d_input, *d_output;
  cudaMalloc(&d_input, size);
  cudaMalloc(&d_output, size);
  cudaMemcpy(d_input, input.data, size, cudaMemcpyHostToDevice);

  dim3 block(16, 16);
  dim3 grid((width + block.x - 1) / block.x, (height + block.y - 1) / block.y);
  gaussianBlurKernel<<<grid, block>>>(d_input, d_output, width, height);

  cudaMemcpy(output.data, d_output, size, cudaMemcpyDeviceToHost);
  cudaFree(d_input);
  cudaFree(d_output);

  return 0;
}

// Host function to apply Sobel edge detection
int applySobelEdge(const cv::Mat &input, cv::Mat &output) {
  int width = input.cols;
  int height = input.rows;
  size_t size = width * height * 3 * sizeof(uchar);

  output = cv::Mat(height, width, input.type());

  uchar *d_input, *d_output;
  cudaMalloc(&d_input, size);
  cudaMalloc(&d_output, size);
  cudaMemcpy(d_input, input.data, size, cudaMemcpyHostToDevice);

  dim3 block(16, 16);
  dim3 grid((width + block.x - 1) / block.x, (height + block.y - 1) / block.y);
  sobelEdgeKernel<<<grid, block>>>(d_input, d_output, width, height);

  cudaMemcpy(output.data, d_output, size, cudaMemcpyDeviceToHost);
  cudaFree(d_input);
  cudaFree(d_output);

  return 0;
}

// Main function for testing filters
int main(int argc, char **argv) {
  if (argc < 4) {
    std::cerr << "Usage: ./filters <input_file> <output_file> <filter_type>\n";
    std::cerr << "Filter types: blur, sobel\n";
    return -1;
  }

  std::string input_file = argv[1];
  std::string output_file = argv[2];
  std::string filter_type = argv[3];

  cv::Mat input = cv::imread(input_file);
  if (input.empty()) {
    std::cerr << "Error: Could not load image " << input_file << std::endl;
    return -1;
  }

  cv::Mat output;
  int result = -1;

  if (filter_type == "blur") {
    result = applyGaussianBlur(input, output);
  } else if (filter_type == "sobel") {
    result = applySobelEdge(input, output);
  } else {
    std::cerr << "Error: Unknown filter type " << filter_type << std::endl;
    return -1;
  }

  if (result == 0) {
    cv::imwrite(output_file, output);
    std::cout << "Filter applied successfully. Output saved to " << output_file
              << std::endl;
  } else {
    std::cerr << "Error applying filter" << std::endl;
    return -1;
  }

  return 0;
}
