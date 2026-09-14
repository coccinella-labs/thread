/**
 * CUDA Color Space Conversion
 * Converts RGB to HSV.
 */

#include <algorithm>
#include <cuda_runtime.h>
#include <iostream>
#include <opencv2/opencv.hpp>

// CUDA kernel for RGB to HSV
__global__ void rgbToHsvKernel(uchar *input, float *output, int width,
                               int height) {
  int x = blockIdx.x * blockDim.x + threadIdx.x;
  int y = blockIdx.y * blockDim.y + threadIdx.y;

  if (x >= width || y >= height)
    return;

  int idx = (y * width + x) * 3;
  float r = input[idx] / 255.0f;
  float g = input[idx + 1] / 255.0f;
  float b = input[idx + 2] / 255.0f;

  float max_val = fmaxf(fmaxf(r, g), b);
  float min_val = fminf(fminf(r, g), b);
  float delta = max_val - min_val;

  float h, s, v = max_val;

  if (delta == 0) {
    h = 0;
  } else if (max_val == r) {
    h = 60 * ((g - b) / delta);
  } else if (max_val == g) {
    h = 60 * ((b - r) / delta + 2);
  } else {
    h = 60 * ((r - g) / delta + 4);
  }
  if (h < 0)
    h += 360;

  s = (max_val == 0) ? 0 : (delta / max_val);

  output[idx] = h / 360.0f; // H normalized to 0-1
  output[idx + 1] = s;      // S 0-1
  output[idx + 2] = v;      // V 0-1
}

// Host function
int applyRgbToHsv(const cv::Mat &input, cv::Mat &output) {
  int width = input.cols;
  int height = input.rows;

  output = cv::Mat(height, width, CV_32FC3);

  size_t in_size = width * height * 3 * sizeof(uchar);
  size_t out_size = width * height * 3 * sizeof(float);

  uchar *d_input;
  float *d_output;
  cudaMalloc(&d_input, in_size);
  cudaMalloc(&d_output, out_size);
  cudaMemcpy(d_input, input.data, in_size, cudaMemcpyHostToDevice);

  dim3 block(16, 16);
  dim3 grid((width + block.x - 1) / block.x, (height + block.y - 1) / block.y);
  rgbToHsvKernel<<<grid, block>>>(d_input, d_output, width, height);

  cudaMemcpy(output.data, d_output, out_size, cudaMemcpyDeviceToHost);
  cudaFree(d_input);
  cudaFree(d_output);

  return 0;
}

// Main
int main(int argc, char **argv) {
  if (argc < 3) {
    std::cerr << "Usage: ./colorspace <input_file> <output_file>\n";
    return -1;
  }

  cv::Mat input = cv::imread(argv[1]);
  if (input.empty())
    return -1;

  cv::Mat output;
  applyRgbToHsv(input, output);
  // Note: Output is float, save as is or convert back
  cv::imwrite(argv[2], output * 255); // Approximate for visualization

  std::cout << "RGB to HSV applied." << std::endl;
  return 0;
}
