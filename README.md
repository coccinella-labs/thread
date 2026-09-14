<p align="center">
  <img src="https://raw.githubusercontent.com/Coccinella-Labs/thread/main/.github/assets/thumbnail.png" alt="thread" width="100%">
</p>

# Thread

Thread is an image tiling and upscaling pipeline. You upload one image, we split it into tiles, upscale each one on the CPU (or GPU if you have it), and stitch them back together. It runs as an HTTP API on your machine at localhost:5001. Nothing goes to the cloud. Your images stay local.

This is version 0.1.0. It works. GPU support exists in the code but does not work in the API yet, so we keep it off by default.

## What You Need

Python 3.10 or later. CMake 3.10 or later. A machine running macOS 11 or later, Ubuntu 22.04 or later, or Windows 10 or later. That is all.

## How to Start

Run the setup script first. This installs CMake, Ninja, Python dependencies, and sets up a virtual environment.

```bash
bash scripts/setup.sh
source venv/bin/activate
```

On Windows, use `.\venv\Scripts\activate` instead.

Now build the project. Use the CPU-only build. GPU code is there but does not work in the API, so we keep it off.

```bash
cmake -S . -B build -DUSE_CUDA=OFF -DWITH_METAL=OFF
cmake --build build --parallel
ctest --test-dir build --output-on-failure
```

You should see tests pass. The test_preprocess test runs the C tiler. That is your proof the core works.

Run the Python tests.

```bash
python -m pytest
```

This tests the Flask API, the stitch logic, and the helpers. If it passes, the API will start cleanly.

Start the API.

```bash
python src/api/server.py
```

It listens on port 5001. Check the health endpoint.

```bash
curl http://localhost:5001/v1/health
# → { status: "healthy", version: "v1" }
```

The API root lists the available endpoints.

```bash
curl http://localhost:5001/
# → { message: "Thread API v1", endpoints: { health, images, tiles, stitch } }
```

## What the API Does

The API has six main endpoints. Upload images, create tiles from those images, upscale the tiles or the whole image, stitch tiles back together, and check job status.

Upload an image. You send a JPG, PNG, BMP, or TIFF file. The API gives back an image ID and metadata.

```bash
curl -X POST http://localhost:5001/v1/images \
  -F "file=@image.jpg"
# 201 → { id, filename, format, size, created_at,
#         _links: { self, tiles, upscale } }
```

List all images you have uploaded.

```bash
curl http://localhost:5001/v1/images?offset=0&limit=25
# → { count, total, _embedded: { images: [...] },
#     _links: { self, next, prev } }
```

Create tiles from an image. This splits the image into squares. The default tile size is 512 by 512 pixels.

```bash
curl -X POST http://localhost:5001/v1/images/<image_id>/tiles \
  -H "Content-Type: application/json" \
  -d '{"tile_size": 512}'
# 202 → { image_id, tile_count, tile_size,
#         _links: { self, image },
#         _embedded: { tiles: [{ id, filename, size, href }] } }
```

The tiles live in `OUTPUT_FOLDER/tiles_<image_id>/`.

List all tiles.

```bash
curl http://localhost:5001/v1/tiles?offset=0&limit=25
# → { count, total, _embedded: { tiles: [...] },
#     _links: { self, next, prev } }
```

Upscale an entire image. You specify the scale factor from 1 to 8. Default is 2.

```bash
curl -X POST http://localhost:5001/v1/images/<image_id>/upscale \
  -H "Content-Type: application/json" \
  -d '{"scale": 2}'
# 202 → { id, scale, output_file, _links: { self, image, download } }
```

Upscale a single tile. Same scale options.

```bash
curl -X POST http://localhost:5001/v1/tiles/<tile_id>/upscale \
  -H "Content-Type: application/json" \
  -d '{"scale": 2}'
# 202 → { id, scale, output_file, _links: { self, tile, download } }
```

Stitch tiles back into one image. You pass a list of tile IDs, the number of rows, the number of columns, and a name for the output file.

```bash
curl -X POST http://localhost:5001/v1/stitch \
  -H "Content-Type: application/json" \
  -d '{
    "tile_ids": ["tile_0", "tile_1", "tile_2", "tile_3"],
    "rows": 2,
    "cols": 2,
    "output": "stitched.png"
  }'
# 202 → { id: <job_id>, status: "completed", result: "/v1/outputs/...",
#         tile_count, rows, cols,
#         _links: { self, status, download } }
```

Check the status of any stitch job.

```bash
curl http://localhost:5001/v1/jobs/<job_id>
# → { id, status, result, tile_count, rows, cols,
#     _links: { self } }
```

Download the final output.

```bash
curl http://localhost:5001/v1/outputs/stitched.png --output stitched.png
```

Every response from the API is JSON in HAL format. It includes links to related resources and, where useful, embedded data:

```json
{
  "_links": { "self": { "href": "/v1/images/<image_id>" } },
  "_embedded": { "tiles": [ ... ] },
  "id": "<image_id>",
  "created_at": "2026-..."
}
```

Errors come back in a fixed shape:

```json
{ "errors": [{ "code": "not_found", "title": "Not Found", "details": "..." }] }
```

## How It Works Inside

The Flask server lives in src/api/server.py. It handles all the HTTP routes and validates input. Everything else runs in-process with OpenCV, on the CPU, with no subprocess calls and no GPU.

The Flask API does all tiling itself. It uses OpenCV to split the image into tiles (cv2 code at line 210) and to upscale each tile with bicubic interpolation (line 205). It is all Python, in-process, no subprocess calls.

There is a separate C tiler in src/core/preprocess.c that uses stb_image instead. It has no dependencies and is always built and tested. But the API does not call it. Only the CLI (src/cli/e2e.py) and the dev flow (scripts/run.sh) invoke the C tiler. So it exists for reference and for the CLI, not for the API.

There is also a C++ tiler in src/core/preprocess.cpp that uses OpenCV instead. If you pass WITH_OPENCV=ON to CMake, it will build that version too. But it has a bug in the edge handling, so the C version is what we use by default.

The src/cli/e2e.py file is a standalone CLI. It creates a test image, tiles it with the C binary (build/bin/preprocess_c), upscales each tile (using the CUDA binary if you built it with USE_CUDA=ON, otherwise falling back to cv2), and stitches everything back. It does not use the Flask API. It is a separate tool to test the full pipeline end to end. This is why we always build preprocess_c even though the API does not use it.

## What Actually Works

The Flask API works. You can upload images, create tiles, upscale them on the CPU, and stitch them back. All of that is tested and it works.

The C tiler works. The Python tests work. The E2E CLI works. CPU upscaling via cv2 works. Stitching works.

GPU code exists in the repository but it does not work in the API. Here is the state of GPU support.

Metal on macOS: The code compiles. But when you try to launch a GPU kernel, it returns an error saying the operation is not supported. The Metal shader exists but is never actually dispatched to the GPU. The Metal shim is a wrapper that makes the API look like CUDA, but underneath it calls CPU functions. So it works, but it does not use the GPU. We keep Metal off by default because it adds no value right now.

CUDA on Linux and Windows: The CUDA kernels compile. The standalone e2e.py script can use them if you build with USE_CUDA=ON. But the Flask API does not call the GPU upscaler. The API always uses the CPU fallback. The GPU factory code exists but is never reached from the API. So CUDA works in the CLI, not in the HTTP API. We keep it off by default.

If you want to know why GPU support is incomplete, read docs/RECONSTRUCTION.md. That file explains the design history and why things are the way they are.

The GPU factory abstraction from the original design still exists in src/core/upscaler.cpp, src/core/test_upscaler.cpp, and src/core/include/upscaler.hpp. None of it is compiled or called. It is preserved as a reference point for anyone who wants to understand the intended GPU integration or try to finish it.

## Building with Optional Features

You can turn on OpenCV if you want to use the C++ tiler.

```bash
cmake -S . -B build -DWITH_OPENCV=ON -DUSE_CUDA=OFF -DWITH_METAL=OFF
cmake --build build --parallel
```

You can turn on Metal if you are on macOS and you have Xcode installed. But remember, Metal does not actually use the GPU in the API yet.

```bash
cmake -S . -B build -DWITH_METAL=ON -DUSE_CUDA=OFF
cmake --build build --parallel
```

You can turn on CUDA if you are on Linux or Windows and you have the CUDA Toolkit 12.0 or later installed. CUDA works in the e2e.py CLI but not in the API.

```bash
INSTALL_CUDA=true bash scripts/setup.sh
cmake -S . -B build -DUSE_CUDA=ON -DWITH_METAL=OFF
cmake --build build --parallel
```

Do not turn both Metal and CUDA on at the same time unless you know what you are doing. And do not turn GPU support on for the API unless you have fixed the integration bugs first. Right now, GPU is experimental and incomplete.

## Tests and Quality Checks

Run the C and C++ tests with ctest.

```bash
ctest --test-dir build --output-on-failure
```

Run the Python tests with pytest.

```bash
python -m pytest
```

Run the full end to end test with the CLI.

```bash
python src/cli/e2e.py
```

This creates a test image, tiles it, upscales, and stitches it back. It should output test_images/final_output.jpg and print "E2E test passed".

Before you push code, run the pre-commit checks. These format your code, check for imports, and lint YAML.

```bash
pre-commit run --all-files
```

## Where Everything Lives

src/api/server.py is the Flask API. That is the main thing you interact with.

src/cli/e2e.py is the standalone CLI pipeline. scripts/setup.sh sets up your environment.

src/core/preprocess.c is the C tiler. src/core/preprocess.cpp is the optional C++ tiler. src/core/upscaler.cpp is the GPU factory, but the API does not use it. The tests for the core code sit next to it in the same directory.

src/gpu/metal/ is the Metal code for macOS. src/gpu/metal/Upscale.metal is the shader. src/gpu/metal/MetalShim.mm is the wrapper. src/gpu/metal/MetalUpscaler.cpp handles the API.

src/gpu/cuda/ is where the CUDA kernels live. upscale.cu is the main one. There are also filters, rotation, blend, canny, colorspace, histogram, median, morphology, resize, sharpen, and threshold. These are all optional.

src/core/include/ is headers. stb_image.h is the image loader. upscaler.hpp is the GPU factory interface. cuda_shim.h makes Metal look like CUDA.

The Python tests live next to their modules. src/api/test_api_server.py tests the API. src/cli/test_stitch.py tests the stitching. src/cli/test_create_test_image.py tests the test-image helper. The C tests live beside the core code in src/core/. Running pytest from the repo root finds all Python tests because pytest.ini sets testpaths to src.

CMakeLists.txt controls the build. It is big and handles all the platform detection and GPU gating.

docs/ has documentation. ONBOARDING.md explains how the code is organized. COMPATIBILITY.md lists what platforms and versions we support. TESTING.md explains the test setup. RECONSTRUCTION.md tells the design history.

Dockerfile builds a CPU-only container. Dockerfile.cuda builds a GPU container with CUDA 13.1.

## Environment Variables

You can set these if you want to customize where things go or what port the API uses.

```bash
export API_VERSION=v1
export UPLOAD_FOLDER=/tmp/thread/uploads
export OUTPUT_FOLDER=/tmp/thread/output
export PORT=5001
export FLASK_DEBUG=0
```

The defaults are fine for local development. PORT is always 5001. UPLOAD_FOLDER and OUTPUT_FOLDER go in /tmp/thread by default on Unix and your temp directory on Windows.

## What Systems Support What

Python 3.10, 3.11, 3.12, 3.13, and 3.14 all work.

C++20 is required. CMake 3.10 and later works, but 3.21 or later is better if you want Metal or CUDA.

OpenCV 4.0 or later is optional. If you do not install it, we use stb_image instead.

CUDA Toolkit 12.0 or later is optional. It only works on Linux and Windows. Only tested on Ubuntu 22.04 with CUDA 12.6.1 and 13.0.

Metal 3.0 or later is optional. Only on macOS 11 or later. Requires Xcode 14 or later.

macOS 11 or later, arm64 or x86_64. Ubuntu 22.04 or later. Windows 10 or later with MSVC or MinGW. Full details in docs/COMPATIBILITY.md.

## Known Issues

GPU code in the API does not work. The Metal shim has no actual GPU dispatch. The CUDA kernels are not called by the API. If you want to use GPU upscaling in the API, you will need to wire it up and test it yourself first.

The C++ tiler in src/core/preprocess.cpp has a bug in the bounds checking for edge tiles. Use the C tiler instead, which is the default.

Read docs/RECONSTRUCTION.md to understand why the GPU code is incomplete and what the original design goal was.

## Contributing

See CONTRIBUTING.md for code style and commit conventions. See DEVELOPMENT.md for how to set up a dev environment. See SECURITY.md for security contact info.

## License

BSD 3-Clause. See LICENSE.

## Version

Version 0.1.0. See VERSION and CHANGELOG.md for release history.
