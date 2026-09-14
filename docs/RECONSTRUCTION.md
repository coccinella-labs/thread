# Thread: Repository Reconstruction

*A durable technical record of what this repository is, what it was, and how it got from there to here. Written for anyone who must understand the codebase from scratch: a replacement for a long lost conversation.*

> Scope note: this is a **post-hoc forensic reconstruction** from git history and `HEAD @ 9a09a1f`, not an official project document. It is deliberately honest about what does and does not work. Where a claim is inference rather than evidence, it is flagged as such.

---

## 1. Origin and evolution: `hybrid-compute` → `thread`

The repository was imported as **`hybrid-compute`** on **2025-10-04** (`cd81c9d` *"update hybrid-compute: upscaling, gpu, tests"*) and spent six months as a GPU-acceleration project before being reframed as **`thread`**, a CPU-first image pipeline, on **2026-05-28** (`f375435`, the MVP cut).

The project name described its ambition: *hybrid* compute, the same CUDA-style source running on NVIDIA GPUs (Linux/Windows) *and* Apple Silicon via a Metal back-end. The pre-cut `docs/PROJECT_README.md` states it explicitly:

> *"Hybrid-compute is a cross-platform GPU-accelerated image processing framework with a CUDA-to-Metal compatibility shim. It enables CUDA-based operations on macOS (Apple Silicon) via Metal."*

The intended usage workflow at that point was **Split → Transfer + Upscale in the cloud → Stitch**. The GPU work was always conceived as a *separate* (cloud) component, never an in-process part of a local web app.

By `HEAD`, that original identity survives mostly as residue: `CMakeLists.txt` still describes the project as **"Thread - CUDA to Metal Shim"**, and the entire Metal/CUDA layer remains in the tree, gated off and optional.

## 2. Original API execution model

The REST API was born on **2026-02-19** (`66c2c67` *"feat: rest api server with livingsocial design guide (#74)"*) as `api/server.py` (365 lines). It was a thin HTTP shell over **compiled native binaries invoked via `subprocess`** rather than a self-contained server:

- **Upload / list / download / tile route:** `subprocess.run(["./preprocess", source_dir+"/", tiles_dir+"/"], capture_output=True, text=True, timeout=60), the C++/OpenCV tiler.
- **Upscale route:** `subprocess.run(["./cloud_gpu/upscaler", source_file, output_file, str(scale)], timeout=120), the CUDA binary.
- **Stitch route:** **was never implemented.** `stitch_tiles()` returned `{"job_id": …, "status": "processing"}` and did nothing. `get_job_status()` *hardcoded* `{"status": "completed", "result": "/v1/outputs/<job_id>/result.png"}, a fabricated URL pointing at a file that could never exist.
- Server defaults: `UPLOAD_FOLDER=/tmp/hybrid-compute/uploads`, `OUTPUT_FOLDER=/tmp/hybrid-compute/output`, `app.run(host="0.0.0.0", port=5000, debug=True)`.

Error handling was honest about the dependency: missing binaries surfaced as **`501 Not Available`** ("Please build the CUDA upscaler") and timeouts as **`504`**.

The whole API was framed as a *design guide* exercise: the pre-cut README was titled **"Hybrid Compute API Design Guide, Version 1.0.0, Published 2026 Feb 19"** (869 lines of LivingSocial-Api-Documentation content: SQUUIDs, HAL, versioning, pagination). The API is best read as an aspirational reference implementation of that guide, not as production software.

## 3. CUDA and Metal architecture

Two parallel GPU stacks were built, neither of which ever reached a working image-producing path by default:

**CUDA (`cloud_gpu/`, 12 kernels).** `cloud_gpu/upscale.cu` is a standalone OpenCV-linked binary (`upscale`) with a bicubic kernel, a Catmull-Rom variant, and a CPU OpenMP fallback. Sibling files (`filters.cu`, `rotation.cu`, `blend.cu`, …) form a library of image operations with no HTTP API exposure. Everything in `cloud_gpu/` is compiled only under `USE_CUDA=ON` (default **OFF**, `cuda.cmake:2`, target archs `75;80;86`).

**Metal (`src/metal/`).** `MetalUpscaler` is selected by `Upscaler::create()` (`src/upscaler.cpp:34-52`: Metal → CUDA → `throw std::runtime_error("No suitable upscaler available")`). Critically, `MetalUpscaler::upscale()` (`src/metal/MetalUpscaler.cpp:166`) **always calls the CPU `bilinearUpscale()`** (`:177`). Its own Metal shader `Upscale.metal` (kernel `upscaleBilinear`, `:7`) is compiled into `shaders/default.metallib` but **never dispatched**: there is no `computePipelineState`. The Metal path is GPU-*capable* only in the sense that it links Metal; it never accelerates anything.

The shared factory abstraction (`include/upscaler.hpp`) is used **nowhere in the API**: `api/server.py` performs upscaling directly with `cv2.resize(..., INTER_CUBIC)`. The GPU abstraction is a zombie: fully built, never load-bearing.

## 4. The CUDA-to-Metal shim and its actual implementation boundary

The shim (`include/cuda_shim.h` + `src/metal/MetalShim.mm`) is the **most substantial artifact in the repository** and was the heart of the original "hybrid compute" concept.

**Intent:** provide the CUDA Runtime API surface (`cudaError_t`, `cudaMemcpyKind`, `cudaMalloc`, `cudaMemcpy`, `cudaStream*`, `cudaEvent*`) backed by Metal, so that CUDA-style source compiles and runs unmodified on Apple Silicon. Evidence of intent:

- `cuda_shim.h` mirrors CUDA error enums (`:10-19`), declares function pointers, and `#define`s redirect `cudaMalloc → cudaMallocPtr` (`:128`).
- `CMakeLists.txt:391` builds `cudart_shim` as a SHARED library with `OUTPUT_NAME "cudart"`, so `-lcudart` binds to the Metal back-end on macOS.
- `tests/test_metal_shim.cu` contains a **real CUDA kernel** (`vectorAdd<<<blocks,threads,0,stream>>>` with async copies, streams, events), a demonstration that a CUDA program would run through the shim.

**Actual implementation boundary (what is real vs not)**

| Layer | Status | Evidence |
| :--- | :--- | :--- |
| Memory model | **Real** | `MTLBuffer` (shared storage) alloc/free; pointer registry (`MetalShim.mm:89`), malloc via `MTLResourceStorageModeShared` (`:218`) |
| Host↔device copies | **Real** | H2D / D2H / D2D `memcpy` (`MetalShim.mm:298-316`) |
| Memset | Real | Padded/partial-coverage logic |
| Streams | **Real** | Per-stream `MTLCommandQueue`; launch queue per stream |
| Events / sync | **Real** | `MTLSharedEvent`-based `cudaStreamSynchronize`, `cudaEventRecord/ElapsedTime` (`:326-371`) |
| Kernel dispatch | **NOT implemented** | `launchKernel()` returns `cudaErrorNotSupported` (`MetalShim.mm:536-542`) |
| Full CUDA coverage | **NOT implemented** | Only the subset a hand-written runtime would need |

The shim is, in short, a **complete runtime-API skeleton with a correct memory/sync model, whose kernel-dispatch layer was never built.** Correctness fixes were layered in while the project was active (`1c13d45`, a retain/double-free fix seconds after `64c42e6`, and `27c9cb2`, an async race and bounds check), and it is covered by unit tests (`tests/unit/test_metal_shim.cpp`, alloc/copy round-trips) and even a benchmark (`tests/performance/benchmark_metal_shim.cpp`). The kernel-translation problem (the hard 80%: turning CUDA kernels into Metal compute pipelines) stopped being worked on once the project pivoted, and the layer-out writers moved on.

## 5. Remote GPU execution model

The repository documents a **cloud-worker** deploy path in parallel with local usage. The `cloud_gpu` binaries were never meant to be in-process with the API; they were built to run on an NVIDIA GPU box (or container) over the network:

- `scripts/transfer_tiles.sh`: scp local tiles to a cloud host, ssh in, `nvcc cloud_gpu/upscale.cu -o upscaler` (against a full OpenCV toolchain), run, scp results back. Pre-cut defaults pointed at `/home/ubuntu/HybridCompute`; the script includes input-validation hardening (injection/option-injection checks) added around `438fa6b` (2026-01-27).
- `scripts/batch_upscale.sh`: `UPSCALER=./upscaler` over a tile directory; error-checks the binary and input pattern.
- `Dockerfile.cuda`: GPU container; CI (`ci.yml`) publishes image variants (`thread-gpu`) and CI includes CUDA/WSL jobs.

The API's `202 + job_id` async shape was modeling exactly this: upload → tile locally → ship tiles to the GPU box → poll job → collect. It was a remote-workflow UI that never got a real remote end-point wired to it (the "job" was fabricated, §2).

## 6. The `f375435` MVP cut

Commit **`f375435`** (2026-05-28, *"chore: prepare thread mvp (#148)"*) is the single most consequential commit. Its own message is the thesis: *"This repo needed the active image flow to match the current Thread direction. Made setup CPU-first. CUDA, Metal, and native OpenCV are now optional."*

What it changed:

- **Removed** `import subprocess` from `api/server.py`; replaced both native-binary invocations with in-process Python `cv2`. Tiling became `split_image()` (clamped edge tiles via `min()`), upscaling became `cv2.resize(..., INTER_CUBIC)`.
- **Implemented what the old API only staged**: real `stitch_image()` + `determine_grid()` (hconcat/vconcat with row normalization), real job records under in-memory `JOBS`, replacing the fabricated "completed" stub. **The MVP cut added the one real feature the Feb API had faked.**
- **Hardened validation**: `parse_positive_int`, `MAX_PAGE_LIMIT=100`, `is_safe_id` on every resource, `secure_filename` on outputs (later `033e6b1`/`784b044` closed the `image_id` path-traversal hole).
- **Renamed the project** `hybrid-compute` → `thread` at every level: `project()` in CMake, `com.hybridcompute.metalshim` → `com.thread.metalshim` dispatch-queue label in `src/metal/MetalShim.mm` (the *only* core-source change in the entire cut), folder defaults `/tmp/hybrid-compute/*` → `/tmp/thread/*` in the server.
- **Downgraded the version** from `1.0.0` to `0.1.0` (`VERSION` file): an honest "this is once again an MVP" signal. The CMake project *description* string stayed "…CUDA to Metal Shim" (residue).
- **Quieted the documentation**: the 869-line "Hybrid Compute API Design Guide" README and marketing `docs/web/*.html` were replaced with the terse "a small, well-lit room" README and the "What Works Now" honesty ledger. `docs/PROJECT_README.md` was rewritten from "cross-platform GPU-accelerated framework" to "Thread is a small image processing project. … The CPU path is the default path."
- **Only two files were *added* in the whole commit**: `.github/thread-flow.png` (the stitch identity) and `tests/test_api_server.py` (the regression suite for the new server).

**Nothing GPU-related was deleted.** `cloud_gpu/`, `src/metal/`, `cuda_shim.h`, `cudart_shim`, and `Upscale.metal` all survived the cut. The cut *decoupled* the API from the GPU layer; it did not remove the layer.

## 7. CPU-first architecture after the cut

At `HEAD`, the functional product is entirely CPU/Python:

```
Upload (Flask, HAL)  →  split_image()      →  resize_image()/cv2   →  stitch_image()  →  outputs/
                      (tiles, clamped)          (INTER_CUBIC)          (h/vconcat)     /v1/outputs/
```

- `api/server.py`: Flask, HAL every response, pagination capped at `MAX_PAGE_LIMIT`, in-memory `JOBS`. Routes: upload/list/get/download image → create/list tiles → per-tile upscale and download → stitch/batch/join → final output download under `/v1/outputs/`.
- Native CPU tools retained: `src/preprocess_c.c` (stb_image tiler, always built, `CMakeLists.txt:810`) is the correct partial-edge tiler used by `scripts/e2e.py` and CLI; `build/bin/preprocess` (OpenCV C++, `WITH_OPENCV`) remains.
- CLI path: `scripts/e2e.py`: preprocess with `preprocess_c`, then try `build/bin/upscale` (GPU build) and fall back to `cv2.INTER_CUBIC` (`:52-64`).
- `scripts/stitch.py`: stand-alone stitcher with a CLAHE enhancement path (grayscale) that **diverges** from the API's color `cv2.hconcat/vconcat`.

## 8. The macOS `501/504` nuance

In the original design there was a gap between **intended architecture** and **what could actually run on the author's machine** (a macOS Apple Silicon laptop per `DEVELOPMENT.md`/`setup.sh` conventions):

- The API's upscale route pointed at `./cloud_gpu/upscaler`, but that binary only builds under real CUDA (`USE_CUDA=ON`, nvcc + Toolkit), which is **OFF by default** (`cuda.cmake:2`) and does not exist on Apple Silicon.
- The tiler `./preprocess` (OpenCV C++ version) similarly only appears under `WITH_OPENCV`.
- Therefore, out of the box on macOS, the original API's tile and upscale routes would raise `FileNotFoundError` → **`501 Not Available`** (or a `504` timeout if a stale binary hung), no matter what the workflow said.

The post-cut CPU-first server removes this gap entirely: `python api/server.py` works with nothing but `pip` dependencies. This is the single clearest example of the cut's goal: **the API was made runnable exactly where the author actually worked.**

## 9. Current runtime truth (`HEAD`)

What actually works, end to end, with default settings:

- **CPU pipeline**: `python api/server.py` → upload → tile (cv2) → upscale (cv2, INTER_CUBIC) → stitch (cv2) → download. Fully functional; tested (`tests/test_api_server.py`).
- **Native CPU tiler**: `preprocess_c` (stb_image) builds and tiles correctly, including partial edges.
- **GPU**: does **not** accelerate anything today. `MetalUpscaler::upscale()` is CPU bilinear; `Upscale.metal` is compiled but never dispatched; `launchKernel` returns `NotSupported`; the CUDA path requires an NVIDIA toolchain not present on the author's platform. GPU artifacts build as *optional* libraries/binaries but produce no GPU-computed pixels.

The README's "What Works Now" table is an accurate honesty ledger of this state (**CUDA/Metal = *Optional***). The default path is CPU, and the CPU path is enough to see the whole product.

## 10. Current architectural seams and unfinished pieces

- **`WITH_METAL` default mismatch**: `CMakeLists.txt:39` defaults `WITH_METAL=ON`, while the README and `scripts/run.sh:46` treat it as OFF. On a default macOS build, Metal is compiled for no functional gain.
- **Three divergent tilers**: Python `split_image()` (clamped), `preprocess_c.c` (correct), C++ `include/utils.hpp` `Rect(x,y,tile_size,tile_size)` with an **un-clamped out-of-bounds bug** (`utils.hpp:5-13`). The Python one is what the API uses; the C one is what e2e uses; the C++ one is latent.
- **`Mystitht` divergence**: `scripts/stitch.py` runs a CLAHE (grayscale) enhancement path that the API stitcher does not; results differ by path.
- **Zombie GPU abstraction**: `Upscaler::create()` (Metal→CUDA→throw) is never called from the API; the 12 `cloud_gpu` kernels have no API exposure; the Metal shim can't dispatch kernels.
- **CMake duplication** (reachitecture artifacts): Metal `find_library` at `:55` and `:108`, `xcrun metal` at `:259` and `:372`, OpenCV discovery at `:504` and `:669`; duplicate `cudaStreamSynchronizePtr` in `MetalShim.mm:874`/`:880`.
- **`docs/COMPATIBILITY.md` dead-end**: documents Eigen, pybind11, TensorRT, ONNX, PyTorch as required/optional dependencies that were never added.
- **Job model**: in-memory dict; operations execute synchronously yet return `202`; no persistence, no auth.
- **CHANGELOG.md**: reduced to a pointer to GitHub Releases.
- **Name residue**: CMake description *"Thread - CUDA to Metal Shim"*; release/CI artifacts and image tags still carry `hybrid-compute`/`thread-gpu` naming.

## 11. Git-history timeline

| Date | Commit | Significance |
| :--- | :--- | :--- |
| 2025-10-04 | `cd81c9d` | Import as `hybrid-compute`; CUDA upscaler, GPU tests, BSD-3 license from day one |
| 2025-10-24 | `64c42e6` | **Design commit**: Metal/CUDA back-ends (`cuda_shim.h`, `MetalShim.mm` (725 lines), `Upscale.metal`, `test_metal_shim.cu`, factory, benchmark, docs; 2,475 insertions) |
| 2025-10-24 | `1c13d45` | Immediate shim memory-management fix (retain/double-release) |
| 2025-10-24 | `dd77899` | `preprocess_c` moved outside `WITH_OPENCV` (CPU tiler always builds) |
| 2025-10-24 | `6853c4f` | `cuda.cmake` extracted |
| 2025-10-28 | `27c9cb2` | Shim async-race fix + bounds checks |
| 2026-01-27 | `438fa6b` | Batch upscaling + flexible stitching; `transfer_tiles.sh` hardening |
| 2026-02-19 | `66c2c67` | REST API with subprocess–GPU execution model + 869-line LivingSocial API Design Guide |
| 2026-05-28 | `f375435` | **MVP cut**: CPU-first `thread` 0.1.0, API→pure `cv2`, real stitch, docs quieted |
| post-cut | `4507f76` | Port + route fixes (#113) |
| post-cut | `033e6b1`/`784b044` | `image_id` path-traversal validation |
| post-cut | `c4eee8c` | Flask debug-mode hard-coding fix |
| `HEAD` | `9a09a1f` | Documentation header-image pointer (#162) |

Two adjacent-commit fingerprints (`64c42e6`+`1c13d45` in the same session; later fix-up pairs) suggest an AI-assisted authoring style: large coherent pieces emitted at once, followed by immediate targeted bug-fix commits. *(Inference, marked.)*

## 12. Evidence vs inference

**Evidence** (verified directly from git and files): all commit messages, dates, and file contents above; the exact `subprocess` command lines and `501/504` handlers in `66c2c67:api/server.py`; the fabricated stitch/job stubs; `MetalUpscaler::upscale()` → CPU; `launchKernel → NotSupported`; `cudart_shim OUTPUT_NAME "cudart"`; the pre/post-cut READMEs and `docs/PROJECT_README.md`; the three tiler behaviors; `WITH_METAL` defaults; `VERSION` downgrade.

**Inference** (flagged in text): that the original API's GPU route was *unrunnable on the author's Mac* (§8), supported by build gating (`USE_CUDA=OFF` default, no CUDA on Apple Silicon) but not by direct observation of a failed run; that the 202/job API was modeled on the remote cloud workflow (§5); that the shim's kernel layer was abandoned rather than deferred by plan (§4); AI-assisted author style (§11).

## 13. Final one-paragraph engineering story

This repository is the product of one builder iterating on a single idea in three acts: it began as **`hybrid-compute`**, an ambitious cross-platform GPU framework whose centerpiece was a CUDA-to-Metal compatibility shim: a real, tested runtime-API skeleton (memory, copies, streams, events) that stopped exactly where the hard part lives (kernel dispatch) and quietly shipped a GPU upscaler in `MetalUpscaler` that always runs on the CPU instead; it then wrapped that framework in a **LivingSocial API-design-guide showcase**, an aspirational 365-line Flask server that shelled out to GPU binaries over `subprocess`, fabricated its `202`-accepted stitches and its "completed" jobs, and could not actually run its own GPU routes on the laptop it was written on; and finally **`f375435` cut it down to what really worked**, renaming it `thread`, downgrading it to 0.1.0, moving the entire pipeline in-process onto pure Python/OpenCV, implementing the stitch the old API had only staged, quieting the 869-line handbook into an honest ledger, and demoting the entire GPU layer (shim, kernels, Metal upscaler, and all) to an optional, unconnected, still-shipped side path that survives to this day as "Thread - CUDA to Metal Shim" in the very CMake file that no longer needs it.
