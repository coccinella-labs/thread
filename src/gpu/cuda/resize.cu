/**
 * CUDA Image Resizing (Downscaling)
 * Downscales images using bilinear interpolation.
 */

#include <cuda_runtime.h>
#include <iostream>
#include <opencv2/opencv.hpp>

// CUDA kernel for resizing
__global__ void resizeKernel(uchar *input, uchar *output, int in_w, int in_h,
                             int out_w, int out_h) {
  int x = blockIdx.x * blockDim.x + threadIdx.x;
  int y = blockIdx.y * blockDim.y + threadIdx.y;

  if (x >= out_w || y >= out_h)
    return;

  float scale_x = (float)in_w / out_w;
  float scale_y = (float)in_h / out_h;

  float rx = x * scale_x;
  float ry = y * scale_y;

  int x1 = (int)rx;
  int y1 = (int)ry;
  int x2 = min(x1 + 1, in_w - 1);
  int y2 = min(y1 + 1, in_h - 1);

  float fx = rx - x1;
  float fy = ry - y1;

  for (int c = 0; c < 3; c++) {
    float val = (1 - fx) * (1 - fy) * input[(y1 * in_w + x1) * 3 + c] +
                fx * (1 - fy) * input[(y1 * in_w + x2) * 3 + c] +
                (1 - fx) * fy * input[(y2 * in_w + x1) * 3 + c] +
                fx * fy * input[(y2 * in_w + x2) * 3 + c];
    output[(y * out_w + x) * 3 + c] = (uchar)val;
  }
}

// Host function
int applyResize(const cv::Mat &input, cv::Mat &output, int new_w, int new_h) {
  int in_w = input.cols;
  int in_h = input.rows;

  output = cv::Mat(new_h, new_w, input.type());

  size_t in_size = in_w * in_h * 3 * sizeof(uchar);
  size_t out_size = new_w * new_h * 3 * sizeof(uchar);

  uchar *d_input, *d_output;
  cudaMalloc(&d_input, in_size);
  cudaMalloc(&d_output, out_size);
  cudaMemcpy(d_input, input.data, in_size, cudaMemcpyHostToDevice);

  dim3 block(16, 16);
  dim3 grid((new_w + block.x - 1) / block.x, (new_h + block.y - 1) / block.y);
  resizeKernel<<<grid, block>>>(d_input, d_output, in_w, in_h, new_w, new_h);

  cudaMemcpy(output.data, d_output, out_size, cudaMemcpyDeviceToHost);
  cudaFree(d_input);
  cudaFree(d_output);

  return 0;
}

// Main
int main(int argc, char **argv) {
  if (argc < 5) {
    std::cerr << "Usage: ./resize <input_file> <output_file> <new_width> "
                 "<new_height>\n";
    return -1;
  }

  cv::Mat input = cv::imread(argv[1]);
  if (input.empty())
    return -1;

  cv::Mat output;
  int nw = atoi(argv[3]);
  int nh = atoi(argv[4]);
  applyResize(input, output, nw, nh);
  cv::imwrite(argv[2], output);

  std::cout << "Resize applied." << std::endl;
  return 0;
}
