/**
 * CUDA Median Filter
 */

#include <cuda_runtime.h>
#include <opencv2/opencv.hpp>

__global__ void medianKernel(uchar *input, uchar *output, int width,
                             int height) {
  int x = blockIdx.x * blockDim.x + threadIdx.x;
  int y = blockIdx.y * blockDim.y + threadIdx.y;

  if (x >= width || y >= height)
    return;

  for (int c = 0; c < 3; c++) {
    uchar window[9];
    int idx = 0;
    for (int ky = -1; ky <= 1; ky++) {
      for (int kx = -1; kx <= 1; kx++) {
        int px = min(max(x + kx, 0), width - 1);
        int py = min(max(y + ky, 0), height - 1);
        window[idx++] = input[(py * width + px) * 3 + c];
      }
    }
    // Simple bubble sort
    for (int i = 0; i < 9; i++) {
      for (int j = i + 1; j < 9; j++) {
        if (window[i] > window[j]) {
          uchar temp = window[i];
          window[i] = window[j];
          window[j] = temp;
        }
      }
    }
    output[(y * width + x) * 3 + c] = window[4];
  }
}

int applyMedianFilter(const cv::Mat &input, cv::Mat &output) {
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
  medianKernel<<<grid, block>>>(d_input, d_output, width, height);

  cudaMemcpy(output.data, d_output, size, cudaMemcpyDeviceToHost);
  cudaFree(d_input);
  cudaFree(d_output);

  return 0;
}

int main(int argc, char **argv) {
  cv::Mat input = cv::imread(argv[1]);
  cv::Mat output;
  applyMedianFilter(input, output);
  cv::imwrite(argv[2], output);
  std::cout << "Median filter applied." << std::endl;
  return 0;
}
