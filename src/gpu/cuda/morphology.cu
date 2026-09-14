/**
 * CUDA Morphological Operations
 */

#include <cuda_runtime.h>
#include <iostream>
#include <opencv2/opencv.hpp>

// Dilation kernel
__global__ void morphologyKernel(unsigned char *input, unsigned char *output,
                                 int width, int height) {
  int x = blockIdx.x * blockDim.x + threadIdx.x;
  int y = blockIdx.y * blockDim.y + threadIdx.y;

  if (x >= width || y >= height)
    return;

  for (int c = 0; c < 3; c++) {
    unsigned char max_val = 0;
    for (int ky = -1; ky <= 1; ky++) {
      for (int kx = -1; kx <= 1; kx++) {
        int px = min(max(x + kx, 0), width - 1);
        int py = min(max(y + ky, 0), height - 1);
        max_val = max(max_val, input[(py * width + px) * 3 + c]);
      }
    }
    output[(y * width + x) * 3 + c] = max_val;
  }
}

int applyMorphology(const cv::Mat &input, cv::Mat &output) {
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
  morphologyKernel<<<grid, block>>>(d_input, d_output, width, height);

  cudaMemcpy(output.data, d_output, size, cudaMemcpyDeviceToHost);
  cudaFree(d_input);
  cudaFree(d_output);

  return 0;
}

int main(int argc, char **argv) {
  cv::Mat input = cv::imread(argv[1]);
  cv::Mat output;
  applyMorphology(input, output);
  cv::imwrite(argv[2], output);
  std::cout << "Morphology applied." << std::endl;
  return 0;
}
