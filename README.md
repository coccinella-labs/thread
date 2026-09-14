<p align="center">
  <img src="https://raw.githubusercontent.com/coccinella-labs/thread/main/.github/assets/thumbnail.png" alt="thread" width="100%">
</p>

<p align="center">
  <img src="https://raw.githubusercontent.com/coccinella-labs/thread/main/.github/thread-flow.png" alt="Thread: image flow, stitched with care" style="width:100%; max-width:100%; height:auto; display:block;">
</p>

<p align="center">
  <em>📍 thread, Kolkata, 2026</em><br>
  <sub>an image pipeline, stitched with care</sub><br>
  <sub>0.1.0 &nbsp;·&nbsp; BSD 3-Clause</sub>
</p>

<br>

> *This is not a dump.*
>
> *It is a single sheet, laid on the table,*
> *typed slowly, with space to breathe.*
> *Every command here has been held and checked.*
> *If something breaks, it will tell you gently.*

<p align="center"><sub>* * *</sub></p>

### A note, before you run anything

Thread takes one image. It makes careful tiles. It can upscale those tiles, on the CPU by default, with Metal or CUDA if you ask for it, and it stitches them back into one image. A small, local API holds it all together.

It is quiet software. It does not shout. It prefers the default path.

*Built for macOS 11+, Ubuntu 22.04+, Windows 10+ · Python 3.10+ · C++20 · CMake 3.10+*

<br>

## Contents

```
  i.    The Work: what it does
  ii.   The Atelier: where things live
  iii.  What Works Now: an honest ledger
  iv.   To Run It, Gently: setup and build
  v.    Correspondence: the local API (v1)
  vi.   On Metal and CUDA: only if needed
  vii.  Care and Checks: tests, lint, CI
  viii. Paper Stock: compatibility
  ix.   Colophon
```

<p align="center"><sub>* * *</sub></p>

## i. The Work

Thread is a tiled image pipeline. Not a framework. Not a platform. Just a small, well-lit room where four things happen:

1.  **Upload**: one image comes in.
2.  **Tile**: the image is cut, cleanly, into squares (`tile_size`, default `512`).
3.  **Upscale**: each tile is enlarged (`scale` 2×–8×, bicubic on CPU; Metal / CUDA when available).
4.  **Stitch**: tiles are joined again, row by row, with care for edges.

The API speaks [HAL+JSON](https://stateless.co/hal_specification.html). Every response carries `_links` to where you might go next, and `_embedded` where there is more to see. Errors are small, legible objects: `{ code, title, details }`.

No cloud. Runs on `http://localhost:5001`. Your images stay on your paper.

```
  [ image.jpg ] ──► [ tiles ] ──► [ upscaled tiles ] ──► [ stitched.jpg ]
       │                 │                  │                    │
     POST              POST               POST                 POST
   /v1/images    /v1/images/:id/tiles  /v1/tiles/:id/upscale  /v1/stitch
```

<br>

## ii. The Atelier

Every tool has its drawer. Nothing hidden.

| Path | Use: what lives there |
| :--- | :--- |
| `src/api/server.py` | Flask API: uploads, tiles, upscale, stitch, HAL responses |
| `src/preprocess.c` | `stb_image` tiler: no OpenCV needed, always builds |
| `src/preprocess.cpp` | OpenCV path: when you want it |
| `src/upscaler.cpp` | Upscaler factory: chooses Metal to CUDA to error, with grace |
| `src/gpu/metal/` | Metal on macOS: `MetalShim.mm`, `MetalUpscaler.cpp`, `Upscale.metal` |
| `src/gpu/cuda/` | CUDA on Linux/Windows: `upscale.cu`, `filters.cu`, `resize.cu` + 9 more |
| `src/core/include/` | Headers: `upscaler.hpp`, `cuda_shim.h`, `stb_image.h` |
| `scripts/` | Shell hands: `setup.sh`, `run.sh`, `commit.sh`, CI helpers |
| `src/cli/` | Python hands: `e2e.py`, `stitch.py`, `create_test_image.py` |
| `src/core/` | C and C++ sources with their tests: `preprocess.c`, `test_preprocess.c` |
| `src/api/` | Flask API with its test: `server.py`, `test_api_server.py` |
| `docs/` | Notes and site: Onboarding, Compatibility, CI, Troubleshooting |
| `CMakeLists.txt` | Build: Metal OFF by default, CUDA OFF by default, as it should be |

The drawing on the wall: `thread-flow.png`: one image, four steps, stitched in the centre.

<br>

## iii. What Works Now: an honest ledger

We list what is true today. No embellishment.

| Part | State | Note |
| :--- | :--- | :--- |
| Python API | **Active** | Flask, HAL, paginated |
| Upload image | **Active** | `png` `jpg` `jpeg` `bmp` `tiff` |
| Make tiles | **Active** | `stb_image` always; OpenCV if present |
| CPU upscale fallback | **Active** | `cv2.INTER_CUBIC`, deterministic |
| Stitch output | **Active** | `hconcat` + `vconcat`, normalises edges |
| C preprocessor (`preprocess_c`) | **Active** | `build/bin/preprocess_c` |
| CUDA | *Optional* | Off by default. `USE_CUDA=ON` + Toolkit 12+ |
| Metal | *Optional* | Off by default. `WITH_METAL=ON` + Xcode 14+ |

> The default path is CPU.
> It is enough to see the whole work.
> CUDA and Metal are not needed for the local flow, they are for when you know you need them.

<br>

## iv. To Run It, Gently

We have kept this to four gestures. No rush.

### 1: Lay the table

```bash
bash scripts/setup.sh
```

*What it does, quietly:*

| Area | Default (no flags) |
| :--- | :--- |
| macOS | Homebrew: CMake, Ninja, Xcode command line tools |
| Linux | `apt`: CMake, Ninja, Python, Git, build-essential |
| Windows | Chocolatey: CMake, Ninja, Python, Git |
| Python | `venv`, `requirements.txt`, pytest, ruff, black, mypy, pre-commit |

*If you need more:*

| Need | Command: typed exactly |
| :--- | :--- |
| Native OpenCV (`libopencv-dev` / `brew install opencv`) | `INSTALL_NATIVE_OPENCV=true bash scripts/setup.sh` |
| Apple Metal toolchain | `WITH_METAL=ON bash scripts/setup.sh` |
| CUDA toolkit on Linux (12.6) | `INSTALL_CUDA=true bash scripts/setup.sh` |

Then, to work inside:

```bash
source venv/bin/activate        # Unix / macOS
# or
.\venv\Scripts\activate         # Windows
```

### 2: Build (CPU, the quiet way)

This is the recommended build. It keeps both shims off, so nothing foreign is asked for.

```bash
cmake -S . -B build -DUSE_CUDA=OFF -DWITH_OPENCV=OFF -DWITH_METAL=OFF -DENABLE_BENCHMARK=OFF
cmake --build build --parallel
ctest --test-dir build --output-on-failure
```

You should see `test_preprocess` pass. That is the C tiler, cut from `stb_image`, no dependencies.

### 3: Python checks

```bash
python -m pytest -v
```

Covers `test_api_server.py`, `test_stitch.py`, `test_create_test_image.py` colocated with their modules under `src/`.

### 4: See the whole flow, end to end

```bash
python src/cli/e2e.py
```

It will: create a test image → run `build/bin/preprocess_c` (16 tiles) → upscale each tile to `128×128` (using `build/bin/upscale` if built, else `cv2` fallback) → stitch to `test_images/final_output.jpg` (`512×512`) → verify and print *“E2E test passed”*.

### 5: Start the API

```bash
python src/api/server.py
# → http://localhost:5001
#   health:  http://localhost:5001/v1/health  (and /health)
```

Environment, if you like to set it:

```
API_VERSION=v1
UPLOAD_FOLDER=/tmp/thread/uploads
OUTPUT_FOLDER=/tmp/thread/output
PORT=5001
FLASK_DEBUG=0
```

<br>

## v. Correspondence: the local API

*Version: `v1`. Base: `http://localhost:5001`. All bodies are JSON unless you are sending a file.*

Every reply is HAL, a small courtesy:

```json
{
  "_links": { "self": { "href": "/v1/images/..." } },
  "_embedded": { "tiles": [ ... ] },
  "id": "...",
  "created_at": "2026-..."
}
```

Errors are always:

```json
{ "errors": [{ "code": "not_found", "title": "Not Found", "details": "..." }] }
```

---

**Upload an image**

```bash
curl -X POST http://localhost:5001/v1/images \
  -F "file=@image.jpg"
# 201 → { id, filename, format, size, created_at,
#         _links: { self, tiles, upscale } }
```

Allowed: `png` `jpg` `jpeg` `bmp` `tiff`. Stored as `<uuid>_<filename>` under `UPLOAD_FOLDER`.

**List images**: paginated, with care:

```bash
curl "http://localhost:5001/v1/images?offset=0&limit=25"
# → { count, total, _embedded: { images: [...] },
#     _links: { self, next, prev } }
```

**Get one image / download the file**

```bash
curl http://localhost:5001/v1/images/<image_id>
curl http://localhost:5001/v1/images/<image_id>/file --output original.jpg
```

**Create tiles**

```bash
curl -X POST http://localhost:5001/v1/images/<image_id>/tiles \
  -H "Content-Type: application/json" \
  -d '{"tile_size": 512}'
# 202 → { image_id, tile_count, tile_size,
#         _embedded: { tiles: [{ id, filename, href }] } }
```

Tiles live at `OUTPUT_FOLDER/tiles_<image_id>/<image_id>_tile_<n>.jpg`.

```bash
# list all tiles
curl "http://localhost:5001/v1/tiles?offset=0&limit=25"

# get one tile
curl http://localhost:5001/v1/tiles/<tile_id>
```

**Upscale: whole image**

```bash
curl -X POST http://localhost:5001/v1/images/<image_id>/upscale \
  -H "Content-Type: application/json" \
  -d '{"scale": 2}'
# scale: 1–8, default 2
# 202 → { id, scale, output_file, _links: { download: "/v1/outputs/..." } }
```

**Upscale: single tile**

```bash
curl -X POST http://localhost:5001/v1/tiles/<tile_id>/upscale \
  -H "Content-Type: application/json" \
  -d '{"scale": 2}'

# download the upscaled tile
curl http://localhost:5001/v1/tiles/<tile_id>/upscaled --output upscaled.png
# or
curl http://localhost:5001/v1/outputs/upscaled_<tile_id>.png --output upscaled.png
```

*Underneath: `cv2.resize(..., INTER_CUBIC)` on CPU; Metal / CUDA if your build provides it.*

**Stitch tiles**

```bash
curl -X POST http://localhost:5001/v1/stitch \
  -H "Content-Type: application/json" \
  -d '{
    "tile_ids": ["tile_0", "tile_1", "tile_2", "tile_3"],
    "rows": 2,
    "cols": 2,
    "output": "stitched.png"
  }'
# rows/cols optional, if omitted, tile_count must be a perfect square
# prefers upscaled tiles if found, else originals
# 202 → { id: <job_id>, status: "completed", result: "/v1/outputs/...",
#         tile_count, rows, cols,
#         _links: { self: "/v1/stitch/<job_id>", status: "/v1/jobs/<job_id>", download } }
```

```bash
# check the job
curl http://localhost:5001/v1/jobs/<job_id>

# download the stitched image
curl http://localhost:5001/v1/outputs/<filename> --output stitched.png
```

**Health and root**

```bash
curl http://localhost:5001/v1/health
# → { status: "healthy", version: "v1" }

curl http://localhost:5001/
# → { message: "Thread API v1", endpoints: { health, images, tiles, stitch } }
```

IDs are `SQUUID`-shaped (`uuid4`, lower-case, `[A-Za-z0-9_-]` only), safe for paths and URLs. `tile_ids` and `output` names are validated with `secure_filename`.

<br>

## vi. On Metal and CUDA: only if needed

> *A note on gloss: we keep these off until you ask. The work is complete without them.*

**Metal (macOS 12+, Xcode 14+, macOS deployment 11.0)**

```bash
WITH_METAL=ON bash scripts/setup.sh
cmake -S . -B build -DWITH_METAL=ON -DUSE_CUDA=OFF
cmake --build build --parallel
# shaders: build/shaders/default.metallib  →  share/thread/shaders/
# library: build/lib/libcudart.* (Metal shim, cudart_shim)
```

The shim provides a `cudart`-shaped surface over Metal: `Upscale.metal` compiled via `xcrun metal` to `metallib`, wrapped by `MetalUpscaler.cpp` / `MetalShim.mm`, chosen at runtime by `Upscaler::create()` (`isMetalAvailable()` checks `MTLCreateSystemDefaultDevice()`).

**CUDA (Ubuntu 22.04+, Toolkit 12.0+)**

```bash
INSTALL_CUDA=true bash scripts/setup.sh
cmake -S . -B build -DUSE_CUDA=ON -DWITH_METAL=OFF -DCUDA_ARCH="70;75;80;86"
cmake --build build --parallel
# executables: upscale, filters, rotation, resize, colorspace,
#              histogram, morphology, median, sharpen, threshold, canny, blend
```

CUDA executables live in `build/bin/`. The factory prefers Metal when present; otherwise CUDA if `isCudaAvailable()` (`cudaGetDeviceCount > 0`); otherwise it raises gently, and the CPU fallback in `src/api/server.py` continues.

*Do not set both to `ON` on the same machine unless you know why. The default keeps both `OFF`.*

<br>

## vii. Care and Checks

We treat checks as part of the work, not an afterthought.

| Check | State | How to run it |
| :--- | :--- | :--- |
| C tests (`ctest`) | **Active** | `ctest --test-dir build --output-on-failure` |
| Python tests (`pytest`) | **Active** | `python -m pytest` / `python -m pytest --cov` |
| E2E flow | **Active** | `python src/cli/e2e.py` |
| Pre-commit (black, isort, ruff, yamllint) | **Active** | `pre-commit run --all-files` |
| Build (macOS / Linux / Windows) | **Active** | GitHub Actions + CircleCI |
| Release check | **Active** | `scripts/validate_release_config.sh` |
| Docs deploy | **Active** | `mkdocs` → `docs/` |
| Extra workflows | Manual / slash command | `.github/workflows/` |

Formatting is `black` (127), `isort` (black), `ruff` (E,F,W,C90,I,N,UP…), `clang-format` for C++. Commits are conventional: `feat(api): …` / `fix(ci): …` / `docs(readme): …`.

```bash
# before you push, slowly, then once
pre-commit run --all-files
python -m pytest
ctest --test-dir build --output-on-failure
```

CI lives in `.github/workflows/` and `.circleci/`: CodeQL, Trivy, benchmark gates, and platform matrices.

<br>

## viii. Paper Stock: compatibility

*A small card, kept in the drawer:*

| Stock | Detail |
| :--- | :--- |
| Python | 3.10+ (tested 3.10–3.14) |
| C++ | 20 · Objective-C++ 17 (Metal) |
| CMake | 3.10+ (3.21+ recommended for CUDA/Metal) |
| OpenCV | 4.0+ (4.5+ recommended), optional: `stb_image` is the fallback |
| CUDA | 12.0+ optional (tested 12.6.1, 13.0–13.1) |
| Metal | 3.0+ on macOS 12+ |
| OpenMP | optional, for CUDA targets |
| OS | macOS 11+ (arm64/x86_64), Ubuntu 22.04+, Windows 10+ |

Full matrix: [`docs/COMPATIBILITY.md`](docs/COMPATIBILITY.md) · Onboarding: [`docs/ONBOARDING.md`](docs/ONBOARDING.md) · Testing: [`docs/TESTING.md`](docs/TESTING.md)

<br>

## ix. Colophon

```
Thread
: a tiled image pipeline

📍 Kolkata
Printed with care on quiet paper.
No tracking. No cloud. Just tiles and stitch.

Version 0.1.0: see VERSION
License BSD 3-Clause: see LICENSE
© 2026 bniladridas

Contributing: see CONTRIBUTING.md
Development: see DEVELOPMENT.md
Security: see SECURITY.md
Changelog: see CHANGELOG.md
Docs site: mkdocs.yml  (theme: readthedocs)
```

*If you use this work, a citation or a note is kindly received, but never required. If something is unclear, open an issue and we will answer plainly.*

<p align="center"><sub>* * *</sub></p>

<p align="center">
  <em>“Make it simple, but not simpler. Make it sensitive, not loud.”</em><br>
  <sub>- atelier note, pinned above the press</sub>
</p>

<p align="center">
  <sub>📍 Kolkata &nbsp;·&nbsp; 100% sensitive &nbsp;·&nbsp; not a dump</sub>
</p>
