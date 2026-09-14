/**
 * CUDA Image Blending
 */

#include <cuda_runtime.h>
#include <opencv2/opencv.hpp>

__global__ void blendKernel(uchar *input1, uchar *input2, uchar *output,
                            int width, int height, float alpha) {
  int x = blockIdx.x * blockDim.x + threadIdx.x;
  int y = blockIdx.y * blockDim.y + threadIdx.y;

  if (x >= width || y >= height)
    return;

  int idx = (y * width + x) * 3;
  for (int c = 0; c < 3; c++) {
    float val = alpha * input1[idx + c] + (1.0f - alpha) * input2[idx + c];
    output[idx + c] = (uchar)min(max(val, 0.0f), 255.0f);
  }
}

int applyBlending(const cv::Mat &input1, const cv::Mat &input2, cv::Mat &output,
                  float alpha) {
  int width = input1.cols;
  int height = input1.rows;
  size_t size = width * height * 3 * sizeof(uchar);

  output = cv::Mat(height, width, input1.type());

  uchar *d_input1, *d_input2, *d_output;
  cudaMalloc(&d_input1, size);
  cudaMalloc(&d_input2, size);
  cudaMalloc(&d_output, size);
  cudaMemcpy(d_input1, input1.data, size, cudaMemcpyHostToDevice);
  cudaMemcpy(d_input2, input2.data, size, cudaMemcpyHostToDevice);

  dim3 block(16, 16);
  dim3 grid((width + block.x - 1) / block.x, (height + block.y - 1) / block.y);
  blendKernel<<<grid, block>>>(d_input1, d_input2, d_output, width, height,
                               alpha);

  cudaMemcpy(output.data, d_output, size, cudaMemcpyDeviceToHost);
  cudaFree(d_input1);
  cudaFree(d_input2);
  cudaFree(d_output);

  return 0;
}

int main(int argc, char **argv) {
  cv::Mat input1 = cv::imread(argv[1]);
  cv::Mat input2 = cv::imread(argv[2]);
  cv::Mat output;
  float alpha = atof(argv[4]);
  applyBlending(input1, input2, output, alpha);
  cv::imwrite(argv[3], output);
  std::cout << "Blending applied." << std::endl;
  return 0;
}
