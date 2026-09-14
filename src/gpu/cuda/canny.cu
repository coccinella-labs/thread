/**
 * CUDA Canny Edge Detection
 */

#include <cuda_runtime.h>
#include <opencv2/opencv.hpp>

// Simplified Canny: Sobel edge detection on grayscale
__global__ void sobelKernel(uchar *input, uchar *output, int width,
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
      float gray = input[py * width + px];
      gx += gray * Gx[ky + 1][kx + 1];
      gy += gray * Gy[ky + 1][kx + 1];
    }
  }
  float magnitude = sqrtf(gx * gx + gy * gy);
  output[y * width + x] = (uchar)min(magnitude, 255.0f);
}

int applyCanny(const cv::Mat &input, cv::Mat &output) {
  cv::Mat gray;
  cv::cvtColor(input, gray, cv::COLOR_BGR2GRAY);

  int width = gray.cols;
  int height = gray.rows;
  size_t size = width * height * sizeof(uchar);

  output = cv::Mat(height, width, CV_8UC1);

  uchar *d_input, *d_output;
  cudaMalloc(&d_input, size);
  cudaMalloc(&d_output, size);
  cudaMemcpy(d_input, gray.data, size, cudaMemcpyHostToDevice);

  dim3 block(16, 16);
  dim3 grid((width + block.x - 1) / block.x, (height + block.y - 1) / block.y);
  sobelKernel<<<grid, block>>>(d_input, d_output, width, height);

  cudaMemcpy(output.data, d_output, size, cudaMemcpyDeviceToHost);
  cudaFree(d_input);
  cudaFree(d_output);

  return 0;
}

int main(int argc, char **argv) {
  cv::Mat input = cv::imread(argv[1]);
  cv::Mat output;
  applyCanny(input, output);
  cv::imwrite(argv[2], output);
  std::cout << "Canny applied." << std::endl;
  return 0;
}
