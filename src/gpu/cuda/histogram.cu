/**
 * CUDA Histogram Equalization
 */

#include <climits>
#include <cuda_runtime.h>
#include <iostream>
#include <opencv2/opencv.hpp>

__global__ void histKernel(uchar *input, int *hist, int width, int height) {
  int x = blockIdx.x * blockDim.x + threadIdx.x;
  int y = blockIdx.y * blockDim.y + threadIdx.y;

  if (x >= width || y >= height)
    return;

  int idx = y * width + x;
  atomicAdd(&hist[input[idx]], 1);
}

__global__ void equalizeKernel(uchar *input, uchar *output, int *cdf,
                               int min_cdf, int total_pixels, int width,
                               int height) {
  int x = blockIdx.x * blockDim.x + threadIdx.x;
  int y = blockIdx.y * blockDim.y + threadIdx.y;

  if (x >= width || y >= height)
    return;

  int idx = y * width + x;
  float val =
      (float)(cdf[input[idx]] - min_cdf) / (total_pixels - min_cdf) * 255.0f;
  output[idx] = (uchar)roundf(val);
}

// Host function
int applyHistogramEqualization(const cv::Mat &input, cv::Mat &output) {
  cv::Mat gray;
  cv::cvtColor(input, gray, cv::COLOR_BGR2GRAY);

  int width = gray.cols;
  int height = gray.rows;
  size_t size = width * height * sizeof(uchar);
  int total_pixels = width * height;

  int *d_hist;
  cudaMalloc(&d_hist, 256 * sizeof(int));
  cudaMemset(d_hist, 0, 256 * sizeof(int));

  dim3 block(16, 16);
  dim3 grid((width + block.x - 1) / block.x, (height + block.y - 1) / block.y);
  histKernel<<<grid, block>>>(gray.data, d_hist, width, height);

  int hist[256];
  cudaMemcpy(hist, d_hist, 256 * sizeof(int), cudaMemcpyDeviceToHost);

  int cdf[256];
  cdf[0] = hist[0];
  for (int i = 1; i < 256; i++) {
    cdf[i] = cdf[i - 1] + hist[i];
  }

  int min_cdf = INT_MAX;
  for (int i = 0; i < 256; i++) {
    if (hist[i] > 0) {
      min_cdf = cdf[i];
      break;
    }
  }

  int *d_cdf;
  cudaMalloc(&d_cdf, 256 * sizeof(int));
  cudaMemcpy(d_cdf, cdf, 256 * sizeof(int), cudaMemcpyHostToDevice);

  uchar *d_input, *d_output;
  cudaMalloc(&d_input, size);
  cudaMalloc(&d_output, size);
  cudaMemcpy(d_input, gray.data, size, cudaMemcpyHostToDevice);

  equalizeKernel<<<grid, block>>>(d_input, d_output, d_cdf, min_cdf,
                                  total_pixels, width, height);

  output = cv::Mat(height, width, CV_8UC1);
  cudaMemcpy(output.data, d_output, size, cudaMemcpyDeviceToHost);

  cudaFree(d_hist);
  cudaFree(d_cdf);
  cudaFree(d_input);
  cudaFree(d_output);

  return 0;
}

// Main
int main(int argc, char **argv) {
  cv::Mat input = cv::imread(argv[1]);
  cv::Mat output;
  applyHistogramEqualization(input, output);
  cv::imwrite(argv[2], output);
  std::cout << "Histogram equalization applied." << std::endl;
  return 0;
}
