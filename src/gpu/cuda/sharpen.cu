/**
 * CUDA Image Sharpening
 */

#include <cuda_runtime.h>
#include <opencv2/opencv.hpp>

__global__ void sharpenKernel(uchar *input, uchar *output, int width,
                              int height) {
  int x = blockIdx.x * blockDim.x + threadIdx.x;
  int y = blockIdx.y * blockDim.y + threadIdx.y;

  if (x >= width || y >= height)
    return;

  for (int c = 0; c < 3; c++) {
    float sum = 0.0f;
    for (int ky = -1; ky <= 1; ky++) {
      for (int kx = -1; kx <= 1; kx++) {
        int px = min(max(x + kx, 0), width - 1);
        int py = min(max(y + ky, 0), height - 1);
        float kernel_val = (kx == 0 && ky == 0) ? 5.0f : -1.0f;
        sum += input[(py * width + px) * 3 + c] * kernel_val;
      }
    }
    output[(y * width + x) * 3 + c] = (uchar)min(max(sum, 0.0f), 255.0f);
  }
}

int applySharpening(const cv::Mat &input, cv::Mat &output) {
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
  sharpenKernel<<<grid, block>>>(d_input, d_output, width, height);

  cudaMemcpy(output.data, d_output, size, cudaMemcpyDeviceToHost);
  cudaFree(d_input);
  cudaFree(d_output);

  return 0;
}

int main(int argc, char **argv) {
  cv::Mat input = cv::imread(argv[1]);
  cv::Mat output;
  applySharpening(input, output);
  cv::imwrite(argv[2], output);
  std::cout << "Sharpening applied." << std::endl;
  return 0;
}
