#include "cuda_shim.h"
#include <benchmark/benchmark.h>
#include <random>
#include <vector>

class MetalShimBenchmark : public benchmark::Fixture {
protected:
  void SetUp(const ::benchmark::State &state) override {
    cudaShimInit();
    size = state.range(0);

    // Allocate host memory
    h_data = std::vector<float>(size);

    // Initialize with random data
    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_real_distribution<float> dist(0.0f, 1.0f);

    for (auto &val : h_data) {
      val = dist(gen);
    }

    // Allocate device memory
    cudaMalloc((void **)&d_data, size * sizeof(float));
  }

  void TearDown(const ::benchmark::State &) override {
    cudaFree(d_data);
    cudaShimShutdown();
  }

  size_t size;
  std::vector<float> h_data;
  float *d_data;
};

BENCHMARK_DEFINE_F(MetalShimBenchmark, MemcpyH2D)(benchmark::State &state) {
  for (auto _ : state) {
    cudaMemcpy(d_data, h_data.data(), size * sizeof(float),
               cudaMemcpyHostToDevice);
  }
  state.SetBytesProcessed(int64_t(state.iterations()) *
                          int64_t(size * sizeof(float)));
}

BENCHMARK_DEFINE_F(MetalShimBenchmark, MemcpyD2H)(benchmark::State &state) {
  for (auto _ : state) {
    cudaMemcpy(h_data.data(), d_data, size * sizeof(float),
               cudaMemcpyDeviceToHost);
  }
  state.SetBytesProcessed(int64_t(state.iterations()) *
                          int64_t(size * sizeof(float)));
}

// Register benchmarks with different sizes
BENCHMARK_REGISTER_F(MetalShimBenchmark, MemcpyH2D)
    ->RangeMultiplier(4)
    ->Range(1 << 10, 1 << 20) // Test from 1KB to 1MB
    ->Unit(benchmark::kMicrosecond);

BENCHMARK_REGISTER_F(MetalShimBenchmark, MemcpyD2H)
    ->RangeMultiplier(4)
    ->Range(1 << 10, 1 << 20) // Test from 1KB to 1MB
    ->Unit(benchmark::kMicrosecond);

BENCHMARK_MAIN();
