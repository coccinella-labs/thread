#include "cuda_shim.h"
#include <cassert>
#include <chrono>
#include <iostream>
#include <vector>

// Simple vector addition kernel
__global__ void vectorAdd(const float *A, const float *B, float *C,
                          int numElements) {
  int i = blockDim.x * blockIdx.x + threadIdx.x;
  if (i < numElements) {
    C[i] = A[i] + B[i];
  }
}

void verifyResults(const float *A, const float *B, const float *C,
                   int numElements) {
  for (int i = 0; i < numElements; i++) {
    float expected = A[i] + B[i];
    if (fabs(C[i] - expected) > 1e-5) {
      printf("Mismatch at element %d: expected %f, got %f\n", i, expected,
             C[i]);
      assert(false);
    }
  }
}

int main() {
  // Initialize data size
  const int numElements = 1 << 20; // 1M elements
  size_t size = numElements * sizeof(float);

  // Allocate host memory
  std::vector<float> h_A(numElements);
  std::vector<float> h_B(numElements);
  std::vector<float> h_C(numElements);

  // Initialize host arrays
  for (int i = 0; i < numElements; i++) {
    h_A[i] = static_cast<float>(rand()) / RAND_MAX;
    h_B[i] = static_cast<float>(rand()) / RAND_MAX;
  }

  // Allocate device memory
  float *d_A, *d_B, *d_C;
  cudaMalloc((void **)&d_A, size);
  cudaMalloc((void **)&d_B, size);
  cudaMalloc((void **)&d_C, size);

  // Create streams
  cudaStream_t stream1, stream2;
  cudaStreamCreate(&stream1);
  cudaStreamCreateWithFlags(&stream2, cudaStreamNonBlocking);

  // Create events for timing
  cudaEvent_t start, stop;
  cudaEventCreate(&start);
  cudaEventCreate(&stop);

  // Copy data to device asynchronously
  cudaMemcpyAsync(d_A, h_A.data(), size, cudaMemcpyHostToDevice, stream1);
  cudaMemcpyAsync(d_B, h_B.data(), size, cudaMemcpyHostToDevice, stream1);

  // Launch kernel on stream1
  int threadsPerBlock = 256;
  int blocksPerGrid = (numElements + threadsPerBlock - 1) / threadsPerBlock;

  cudaEventRecord(start, stream1);
  vectorAdd<<<blocksPerGrid, threadsPerBlock, 0, stream1>>>(d_A, d_B, d_C,
                                                            numElements);
  cudaEventRecord(stop, stream1);

  // Copy result back to host asynchronously
  cudaMemcpyAsync(h_C.data(), d_C, size, cudaMemcpyDeviceToHost, stream1);

  // Wait for stream1 to complete
  cudaStreamSynchronize(stream1);

  // Verify results
  verifyResults(h_A.data(), h_B.data(), h_C.data(), numElements);

  // Print timing information
  float milliseconds = 0;
  cudaEventElapsedTime(&milliseconds, start, stop);
  printf("Kernel execution time: %f ms\n", milliseconds);

  // Test stream concurrency
  printf("Testing stream concurrency...\n");

  // Split work between two streams
  int halfSize = numElements / 2;
  size_t halfSizeBytes = halfSize * sizeof(float);

  // First half on stream1
  cudaMemcpyAsync(d_A, h_A.data(), halfSizeBytes, cudaMemcpyHostToDevice,
                  stream1);
  cudaMemcpyAsync(d_B, h_B.data(), halfSizeBytes, cudaMemcpyHostToDevice,
                  stream1);
  vectorAdd<<<(halfSize + threadsPerBlock - 1) / threadsPerBlock,
              threadsPerBlock, 0, stream1>>>(d_A, d_B, d_C, halfSize);
  cudaMemcpyAsync(h_C.data(), d_C, halfSizeBytes, cudaMemcpyDeviceToHost,
                  stream1);

  // Second half on stream2
  cudaMemcpyAsync(d_A + halfSize, h_A.data() + halfSize, halfSizeBytes,
                  cudaMemcpyHostToDevice, stream2);
  cudaMemcpyAsync(d_B + halfSize, h_B.data() + halfSize, halfSizeBytes,
                  cudaMemcpyHostToDevice, stream2);
  vectorAdd<<<(halfSize + threadsPerBlock - 1) / threadsPerBlock,
              threadsPerBlock, 0, stream2>>>(d_A + halfSize, d_B + halfSize,
                                             d_C + halfSize, halfSize);
  cudaMemcpyAsync(h_C.data() + halfSize, d_C + halfSize, halfSizeBytes,
                  cudaMemcpyDeviceToHost, stream2);

  // Wait for both streams to complete
  cudaStreamSynchronize(stream1);
  cudaStreamSynchronize(stream2);

  // Verify results
  verifyResults(h_A.data(), h_B.data(), h_C.data(), numElements);
  printf("Stream concurrency test passed!\n");

  // Test events
  printf("Testing events...\n");
  cudaEvent_t event1, event2;
  cudaEventCreate(&event1);
  cudaEventCreate(&event2);

  // Record events on stream1 and stream2
  cudaEventRecord(event1, stream1);
  cudaEventRecord(event2, stream2);

  // Wait for both events
  cudaEventSynchronize(event1);
  cudaEventSynchronize(event2);

  // Check if events are complete
  cudaError_t status = cudaEventQuery(event1);
  assert(status == cudaSuccess);
  status = cudaEventQuery(event2);
  assert(status == cudaSuccess);

  // Cleanup
  cudaFree(d_A);
  cudaFree(d_B);
  cudaFree(d_C);
  cudaStreamDestroy(stream1);
  cudaStreamDestroy(stream2);
  cudaEventDestroy(start);
  cudaEventDestroy(stop);
  cudaEventDestroy(event1);
  cudaEventDestroy(event2);

  printf("All tests passed!\n");
  return 0;
}
