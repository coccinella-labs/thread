/**
 * CUDA Thresholding
 */

#include <cuda_runtime.h>
#include <opencv2/opencv.hpp>

__global__ void thresholdKernel(uchar *input, uchar *output, int width,
                                int height, int thresh) {
  int x = blockIdx.x * blockDim.x + threadIdx.x;
  int y = blockIdx.y * blockDim.y + threadIdx.y;

  if (x >= width || y >= height)
    return;

  int idx = (y * width + x) * 3;
  for (int c = 0; c < 3; c++) {
    output[idx + c] = (input[idx + c] > thresh) ? 255 : 0;
  }
}

int applyThresholding(const cv::Mat &input, cv::Mat &output, int thresh) {
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
  thresholdKernel<<<grid, block>>>(d_input, d_output, width, height, thresh);

  cudaMemcpy(output.data, d_output, size, cudaMemcpyDeviceToHost);
  cudaFree(d_input);
  cudaFree(d_output);

  return 0;
}

int main(int argc, char **argv) {
  cv::Mat input = cv::imread(argv[1]);
  cv::Mat output;
  int thresh = atoi(argv[3]);
  applyThresholding(input, output, thresh);
  cv::imwrite(argv[2], output);
  std::cout << "Thresholding applied." << std::endl;
  return 0;
}
