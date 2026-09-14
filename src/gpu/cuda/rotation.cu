/**
 * CUDA Image Rotation
 * Rotates images by a given angle using bilinear interpolation.
 */

#include <cmath>
#include <cuda_runtime.h>
#include <iostream>
#include <opencv2/opencv.hpp>

// CUDA kernel for rotation
__global__ void rotateKernel(uchar *input, uchar *output, int in_w, int in_h,
                             int out_w, int out_h, float angle) {
  int x = blockIdx.x * blockDim.x + threadIdx.x;
  int y = blockIdx.y * blockDim.y + threadIdx.y;

  if (x >= out_w || y >= out_h)
    return;

  // Center of output
  float cx = out_w / 2.0f;
  float cy = out_h / 2.0f;

  // Rotate point back to input space
  float cos_a = cosf(angle);
  float sin_a = sinf(angle);
  float rx = (x - cx) * cos_a + (y - cy) * sin_a + in_w / 2.0f;
  float ry = -(x - cx) * sin_a + (y - cy) * cos_a + in_h / 2.0f;

  if (rx >= 0 && rx < in_w - 1 && ry >= 0 && ry < in_h - 1) {
    int x1 = (int)rx;
    int y1 = (int)ry;
    int x2 = x1 + 1;
    int y2 = y1 + 1;

    float fx = rx - x1;
    float fy = ry - y1;

    for (int c = 0; c < 3; c++) {
      float val = (1 - fx) * (1 - fy) * input[(y1 * in_w + x1) * 3 + c] +
                  fx * (1 - fy) * input[(y1 * in_w + x2) * 3 + c] +
                  (1 - fx) * fy * input[(y2 * in_w + x1) * 3 + c] +
                  fx * fy * input[(y2 * in_w + x2) * 3 + c];
      output[(y * out_w + x) * 3 + c] = (uchar)val;
    }
  } else {
    for (int c = 0; c < 3; c++) {
      output[(y * out_w + x) * 3 + c] = 0;
    }
  }
}

// Host function
int applyRotation(const cv::Mat &input, cv::Mat &output, float angle) {
  int in_w = input.cols;
  int in_h = input.rows;
  int out_w = in_w;
  int out_h = in_h;

  output = cv::Mat(out_h, out_w, input.type());

  size_t in_size = in_w * in_h * 3 * sizeof(uchar);
  size_t out_size = out_w * out_h * 3 * sizeof(uchar);

  uchar *d_input, *d_output;
  cudaMalloc(&d_input, in_size);
  cudaMalloc(&d_output, out_size);
  cudaMemcpy(d_input, input.data, in_size, cudaMemcpyHostToDevice);

  dim3 block(16, 16);
  dim3 grid((out_w + block.x - 1) / block.x, (out_h + block.y - 1) / block.y);
  rotateKernel<<<grid, block>>>(d_input, d_output, in_w, in_h, out_w, out_h,
                                angle);

  cudaMemcpy(output.data, d_output, out_size, cudaMemcpyDeviceToHost);
  cudaFree(d_input);
  cudaFree(d_output);

  return 0;
}

// Main for testing
int main(int argc, char **argv) {
  if (argc < 4) {
    std::cerr << "Usage: ./rotation <input_file> <output_file> <angle_deg>\n";
    return -1;
  }

  cv::Mat input = cv::imread(argv[1]);
  if (input.empty())
    return -1;

  cv::Mat output;
  float angle = atof(argv[3]) * M_PI / 180.0f;
  applyRotation(input, output, angle);
  cv::imwrite(argv[2], output);

  std::cout << "Rotation applied." << std::endl;
  return 0;
}
