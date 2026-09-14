#pragma once

#include <stddef.h> // For size_t
#include <stdint.h> // For standard integer types

#ifdef __cplusplus
extern "C" {
#endif

// Match CUDA error codes
typedef enum {
  cudaSuccess = 0,
  cudaErrorMemoryAllocation = 2,
  cudaErrorInitializationError = 3,
  cudaErrorInvalidValue = 11,
  cudaErrorNotReady = 600, // For stream/event queries
  cudaErrorNotSupported = 801,
  cudaErrorUnknown = 999
} cudaError_t;

// Match CUDA stream and event flags
typedef enum {
  cudaStreamDefault = 0x00,
  cudaStreamNonBlocking = 0x01,
  cudaEventDefault = 0x00,
  cudaEventBlockingSync = 0x01,
  cudaEventDisableTiming = 0x02,
  cudaEventInterprocess = 0x04
} cudaStreamFlags_t;

// Match CUDA event status
typedef enum {
  cudaEventStatusComplete = 0,
  cudaEventStatusNotReady = 1,
  cudaEventStatusError = 2
} cudaEventStatus_t;

// Match CUDA types
typedef void *cudaStream_t;
typedef void *cudaEvent_t;
typedef int cudaStreamCaptureStatus;
typedef int cudaStreamCaptureMode;

// CUDA stream callback function type
typedef void (*cudaStreamCallback_t)(cudaStream_t stream, cudaError_t status,
                                     void *userData);

typedef enum cudaMemcpyKind {
  cudaMemcpyHostToHost = 0,
  cudaMemcpyHostToDevice = 1,
  cudaMemcpyDeviceToHost = 2,
  cudaMemcpyDeviceToDevice = 3,
  cudaMemcpyDefault = 4
} cudaMemcpyKind;

// Function pointer types for interception
typedef cudaError_t (*cudaMalloc_t)(void **devPtr, size_t size);
typedef cudaError_t (*cudaFree_t)(void *devPtr);
typedef cudaError_t (*cudaMemcpy_t)(void *dst, const void *src, size_t count,
                                    cudaMemcpyKind kind);
typedef cudaError_t (*cudaMemcpyAsync_t)(void *dst, const void *src,
                                         size_t count, cudaMemcpyKind kind,
                                         cudaStream_t stream);
typedef cudaError_t (*cudaMemset_t)(void *devPtr, int value, size_t count);
typedef cudaError_t (*cudaMemsetAsync_t)(void *devPtr, int value, size_t count,
                                         cudaStream_t stream);
typedef cudaError_t (*cudaLaunchKernel_t)(
    const void *func, unsigned int gridDimX, unsigned int gridDimY,
    unsigned int gridDimZ, unsigned int blockDimX, unsigned int blockDimY,
    unsigned int blockDimZ, unsigned int sharedMem, cudaStream_t stream,
    void **args, void **extra);
typedef cudaError_t (*cudaDeviceSynchronize_t)();

typedef cudaError_t (*cudaStreamCreate_t)(cudaStream_t *pStream);
typedef cudaError_t (*cudaStreamCreateWithFlags_t)(cudaStream_t *pStream,
                                                   unsigned int flags);
typedef cudaError_t (*cudaStreamDestroy_t)(cudaStream_t stream);
typedef cudaError_t (*cudaStreamSynchronize_t)(cudaStream_t stream);
typedef cudaError_t (*cudaStreamQuery_t)(cudaStream_t stream);
typedef cudaError_t (*cudaStreamAddCallback_t)(cudaStream_t stream,
                                               cudaStreamCallback_t callback,
                                               void *userData,
                                               unsigned int flags);

typedef cudaError_t (*cudaEventCreate_t)(cudaEvent_t *event);
typedef cudaError_t (*cudaEventCreateWithFlags_t)(cudaEvent_t *event,
                                                  unsigned int flags);
typedef cudaError_t (*cudaEventDestroy_t)(cudaEvent_t event);
typedef cudaError_t (*cudaEventRecord_t)(cudaEvent_t event,
                                         cudaStream_t stream);
typedef cudaError_t (*cudaEventSynchronize_t)(cudaEvent_t event);
typedef cudaError_t (*cudaEventElapsedTime_t)(float *ms, cudaEvent_t start,
                                              cudaEvent_t end);
typedef cudaError_t (*cudaEventQuery_t)(cudaEvent_t event);

// Function declarations
cudaError_t cudaShimInit();
void cudaShimShutdown();

// Function pointers that will be set to either CUDA or Metal implementations
extern cudaMalloc_t cudaMallocPtr;
extern cudaFree_t cudaFreePtr;
extern cudaMemcpy_t cudaMemcpyPtr;
extern cudaMemcpyAsync_t cudaMemcpyAsyncPtr;
extern cudaMemset_t cudaMemsetPtr;
extern cudaMemsetAsync_t cudaMemsetAsyncPtr;
extern cudaLaunchKernel_t cudaLaunchKernelPtr;
extern cudaDeviceSynchronize_t cudaDeviceSynchronizePtr;

// Stream management
extern cudaStreamCreate_t cudaStreamCreatePtr;
extern cudaStreamCreateWithFlags_t cudaStreamCreateWithFlagsPtr;
extern cudaStreamDestroy_t cudaStreamDestroyPtr;
extern cudaStreamSynchronize_t cudaStreamSynchronizePtr;
extern cudaStreamQuery_t cudaStreamQueryPtr;
extern cudaStreamAddCallback_t cudaStreamAddCallbackPtr;

// Event management
extern cudaEventCreate_t cudaEventCreatePtr;
extern cudaEventCreateWithFlags_t cudaEventCreateWithFlagsPtr;
extern cudaEventDestroy_t cudaEventDestroyPtr;
extern cudaEventRecord_t cudaEventRecordPtr;
extern cudaEventSynchronize_t cudaEventSynchronizePtr;
extern cudaEventElapsedTime_t cudaEventElapsedTimePtr;
extern cudaEventQuery_t cudaEventQueryPtr;

// Macros to redirect CUDA calls to our shim
#define cudaMalloc(ptr, size) cudaMallocPtr(ptr, size)
#define cudaFree(ptr) cudaFreePtr(ptr)
#define cudaMemcpy(dst, src, count, kind) cudaMemcpyPtr(dst, src, count, kind)
#define cudaMemcpyAsync(dst, src, count, kind, stream)                         \
  cudaMemcpyAsyncPtr(dst, src, count, kind, stream)
#define cudaMemset(devPtr, value, count) cudaMemsetPtr(devPtr, value, count)
#define cudaMemsetAsync(devPtr, value, count, stream)                          \
  cudaMemsetAsyncPtr(devPtr, value, count, stream)
#define cudaLaunchKernel(...) cudaLaunchKernelPtr(__VA_ARGS__)
#define cudaDeviceSynchronize() cudaDeviceSynchronizePtr()

// Stream management macros
#define cudaStreamCreate(pStream) cudaStreamCreatePtr(pStream)
#define cudaStreamCreateWithFlags(pStream, flags)                              \
  cudaStreamCreateWithFlagsPtr(pStream, flags)
#define cudaStreamDestroy(stream) cudaStreamDestroyPtr(stream)
#define cudaStreamSynchronize(stream) cudaStreamSynchronizePtr(stream)
#define cudaStreamQuery(stream) cudaQueryPtr(stream)
#define cudaStreamAddCallback(stream, callback, userData, flags)               \
  cudaStreamAddCallbackPtr(stream, callback, userData, flags)

// Event management macros
#define cudaEventCreate(event) cudaEventCreatePtr(event)
#define cudaEventCreateWithFlags(event, flags)                                 \
  cudaEventCreateWithFlagsPtr(event, flags)
#define cudaEventDestroy(event) cudaEventDestroyPtr(event)
#define cudaEventRecord(event, stream) cudaEventRecordPtr(event, stream)
#define cudaEventSynchronize(event) cudaEventSynchronizePtr(event)
#define cudaEventElapsedTime(ms, start, end)                                   \
  cudaEventElapsedTimePtr(ms, start, end)
#define cudaEventQuery(event) cudaEventQueryPtr(event)

#ifdef __cplusplus
} // extern "C"
#endif
