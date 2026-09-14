# Thread: Repo Restructuring Execution Guide

This is the record of what the restructuring actually did, with the real
commands. It supersedes the earlier aspirational guide which assumed a CMake
layout that does not exist in this repository.

Key reality checks before you judge any step:

- `CMakeLists.txt` is a single monolithic file (~990 lines). There is no
  `add_subdirectory(cloud_gpu)` or `add_subdirectory(metal)`; GPU and Metal
  targets are defined inline. The restructuring therefore keeps the monolithic
  file and rewrites paths in place, rather than inventing subproject CMake
  files.
- `scripts/` is retained as a real directory. It is not only python: it holds
  `setup.sh`, `run.sh`, `commit.sh`, `install_cuda.sh`,
  `validate-circleci.sh` (hooked from `.pre-commit-config.yaml`),
  `transfer_tiles.sh`, `batch_upscale.sh`, `check_cuda_build.sh`, and CI
  helpers. Removing it breaks pre-commit and CI.
- `docs/` is retained because `mkdocs.yml`, `.github/workflows/pages.yml`, and
  `.github/workflows/release-validation.yml` all consume it. Collapsing docs
  into README is a separate content decision.
- Runtime verification (cmake, ctest, pytest) could NOT be run on the machine
  that performed the move: no cmake, no cv2/flask/numpy, no pytest. Every step
  below was statically verified (py_compile, bash -n, grep for stale paths).
  The runtime commands are the acceptance test for a tooled builder.

## Phase 1. GPU to `src/gpu/`

```bash
git checkout -b refactor/tight-structure
mkdir -p src/gpu                 # git mv cannot create the destination parent

git mv cloud_gpu src/gpu/cuda     # 12 CUDA kernels
git mv src/metal src/gpu/metal    # shim + upscaler + shader

# Include fix: cloud_gpu/upscale.cu had a RELATIVE include
#   "#include "../include/cuda_utils.hpp""
# which now points at src/gpu/ (nowhere). Resolve it via the include dir instead:
#   "#include "cuda_utils.hpp""
```

Path updates (the only mechanical ones):

- `CMakeLists.txt`: `cloud_gpu/` -> `src/gpu/cuda/`, `src/metal/` ->
  `src/gpu/metal/`. This covers the CUDA GLOB (line >185),
  `METAL_SHADER_FILES` x2, `METAL_SOURCES`, `METAL_SHIM_SOURCES`, and the 12
  `add_executable(...)` CUDA targets.
- `scripts/transfer_tiles.sh` and `scripts/batch_upscale.sh`: the `nvcc
  cloud_gpu/upscale.cu` command inside the ssh/echo strings.
- `scripts/check_cuda_build.sh` (`cd cloud_gpu` -> `cd src/gpu/cuda`).
- `.github/labeler.yml`, `.github/codeql/codeql-config.yml`,
  `.github/CODEOWNERS` path patterns. `codeql-config.yml` scan paths now point
  at `src/` only (there is no `tests/unit` or `tests/performance` anymore).

`Dockerfile.cuda` needs no edit: it builds through cmake, and the target path
now lives only in `CMakeLists.txt`.

Check: `grep -rn "cloud_gpu\|src/metal/" --include=CMakeLists.txt --include=*.yml --include=*.sh CMakeLists.txt scripts .github` is empty.

## Phase 2. Core and headers to `src/core/`

```bash
mkdir -p src/core
git mv src/preprocess.c src/preprocess.cpp src/upscaler.cpp src/core/
git mv include src/core/include
```

Include fixes:

- `src/core/upscaler.cpp` had `#include "metal/MetalUpscaler.hpp"` (resolved
  relative to `src/`). Now `#include "../gpu/metal/MetalUpscaler.hpp"`.
- The 20 `target_include_directories(... ${CMAKE_SOURCE_DIR}/include)` refs in
  `CMakeLists.txt` and 2 in `tests/CMakeLists.txt` become
  `${CMAKE_SOURCE_DIR}/src/core/include`. The `${CMAKE_CURRENT_SOURCE_DIR}/include`
  MSVC-arm path becomes `${CMAKE_CURRENT_SOURCE_DIR}/src/core/include`.
- `add_executable(preprocess_c ...)` and `add_library(preprocess ...)` sources
  move to `src/core/`. The `DESTINATION include)` install lines are untouched
  (they were never resolver paths).

No other code has relative includes into `include/`; the C/C++/ObjC/Metal
files all include headers by bare name and resolve them through the CMake
include dirs that were just updated. Note `tests/CMakeLists.txt` paths were
fixed here so the tree stays consistent between phases; the file itself is
absorbed into root in Phase 4.

## Phase 3. `api/` and python CLI to `src/`

```bash
git mv api src/api                      # server.py, __init__.py, TEST_RESULTS.md
mkdir -p src/cli
git mv scripts/e2e.py src/cli/e2e.py
git mv scripts/stitch.py src/cli/stitch.py
git mv create_test_image.py src/cli/create_test_image.py
git mv tests/test_create_test_image.py src/cli/test_create_test_image.py
git mv tests/test_stitch.py src/cli/test_stitch.py
git mv tests/test_api_server.py src/api/test_api_server.py
touch src/__init__.py src/cli/__init__.py
```

Python changes:

- `test_api_server.py` and `test_stitch.py` import modules dynamically:
  `api.server` -> `src.api.server`, `scripts.stitch` -> `src.cli.stitch`.
  `src/__init__.py` makes `src` a package so `import src.api.server` works
  from the repo root (pytest prepend-import mode inserts the root, since
  `src/` and `src/api/` now both carry `__init__.py`).
- `e2e.py` invoked helpers by bare name assuming CWD = repo root:
  `create_test_image.py` and `scripts/stitch.py`. Both are now resolved as
  `str(Path(__file__).parent / "...")` so the script works from anywhere.
- `test_create_test_image.py` runs the child script via
  `Path(__file__).parent / "create_test_image.py"`.

Callers updated:

- `Dockerfile` CMD: `python3 src/cli/e2e.py`.
- `.github/workflows/ci.yml` lines ~191/192/336/637 and `.circleci/config.yml`
  lines ~482/483/530: `create_test_image.py`, `scripts/stitch.py`,
  `scripts/e2e.py` commands point at `src/cli/...`.
- `pyproject.toml` coverage `omit`: `src/cli/e2e.py`, `src/cli/create_test_image.py`.
- `scripts/run.sh`, `test_changes.sh`: `scripts/stitch.py` -> `src/cli/stitch.py`.
- `README.md` / docs: `api/server.py` -> `src/api/server.py`, run commands, and
  the structure table.

Run `python3 -m py_compile` on every moved `.py`. All passed.

## Phase 4. Tests co-located; `tests/` deleted

| Moved from | Moved to |
| :--- | :--- |
| `tests/test_preprocess.c` | `src/core/test_preprocess.c` |
| `tests/test_utils.cpp` | `src/core/test_utils.cpp` |
| `tests/test_upscaler.cpp` | `src/core/test_upscaler.cpp` |
| `tests/test_metal_shim.cu` | `src/gpu/cuda/test_shim.cu` |
| `tests/unit/test_metal_shim.cpp` | `src/gpu/metal/test_shim.cpp` |
| `tests/performance/benchmark_metal_shim.cpp` | `src/gpu/metal/benchmark.cpp` |

`tests/CMakeLists.txt` was not deleted, it was absorbed. Its contents
(googletest FetchContent v1.14.0, benchmark FetchContent v1.8.3, the
`test_metal_shim` and `benchmark_metal_shim` targets with their
`cudart_shim`/gtest/`${METAL_FRAMEWORKS}` links) moved into the root
`CMakeLists.txt` inside the `BUILD_TESTING` block, with source paths updated
and `TEST_DATA_DIR` pointed at `CMAKE_CURRENT_BINARY_DIR` instead of the now
nonexistent `tests/test_data`. The `include(FetchContent)` call moved with it.

`BUILD_TESTING` was previously gated on `EXISTS tests/`; now it is just the
`option(BUILD_TESTING ...)` + `enable_testing()`.

`pytest.ini`: `testpaths = src`.

`git rm -r tests/`, then `rmdir tests tests/unit tests/performance` for the
empty leftover dirs.

## Phase 5. Config: what to delete, and what must stay

Deleted:

- `cuda.cmake`, `benchmark.cmake` (pure `option()` files); their four options
  are now inline in `CMakeLists.txt` where they used to be `include()`d.

Kept, with reasons:

- `WindowsConfig.cmake` - conditionally included on WIN32.
- `cmake/thread-config.cmake.in` + `cmake_uninstall.cmake.in` - wired to
  `configure_file`/install rules in `CMakeLists.txt`.
- `CTestConfig.cmake` - sets `CTEST_PARALLEL_LEVEL 4`; ctest discovers it from
  the source dir automatically.
- `vcpkg.json` - used by `.github/actions/setup-vcpkg`, `scripts/setup.sh`
  (Windows path) and `scripts/validate_release_config.sh`. Deleting it breaks
  Windows CI and release validation.
- `VERSION` - `pyproject.toml` reads it via `setuptools.dynamic`.
- `signed.json`, `Dockerfile.cuda`, `test_changes.sh`, `mkdocs.yml` - each is
  referenced by real tooling.

There is no `config.py`/`config-3.py` in the tree; they remain in the coverage
`omit` list only because removing them changes the coverage report. Low value,
left alone.

## Phase 6. Docs and README

- `README.md` structure table now shows `src/api/`, `src/cli/`, `src/core/`,
  `src/gpu/`, `scripts/` and their purposes; run commands use new paths.
- `docs/ONBOARDING.md`, `docs/CI.md`,
  `docs/TESTING.md`, `docs/TROUBLESHOOTING.md`, `docs/web/*.html` updated.
- `docs/TESTING.md` and `docs/web/testing.html` no longer describe
  `tests/unit/` / `tests/performance/`; tests are co-located beside code.
- `DEVELOPMENT.md` benchmark-run path -> `./build/bin/benchmark_metal_shim`.
- `CONTRIBUTING.md` unit-test command -> `python -m pytest src`.
- `docs/RECONSTRUCTION.md` is historical (pre-cut forensic record). It is not
  rewritten; it documents state at commit `f375435`.

## Phase 7. Acceptance for a tooled machine

```bash
python3 -m venv .venv && . .venv/bin/activate && pip install -r requirements.txt
cmake -B build -DCMAKE_BUILD_TYPE=Release -DUSE_CUDA=OFF -DWITH_OPENCV=ON
cmake --build build
ctest --test-dir build --output-on-failure        # test_preprocess, test_utils, test_metal_shim, benchmark_metal_shim
pytest src                                        # api + cli + create_test_image tests
python src/cli/e2e.py                             # CPU pipeline e2e
python src/api/server.py &                        # API on :5001 (PORT env)
curl http://localhost:5001/v1/health
```

## What was deliberately NOT done

- No `src/CMakeLists.txt`, `src/api/CMakeLists.txt` etc. invented. The target
  graph is one file; that is the actual structure of this repo.
- No console_scripts entry points (`thread-api`, `thread-cli`). The python
  files have no `main()` to install; the API runs via its `__main__` block on
  `python src/api/server.py`.
- No docs/ merge, no docs/web deletion, no vcpkg/WindowsConfig/CTestConfig
  removal. Each was checked and kept for the reasons in phase 5.
- No CMake runtime test performed locally (no toolchain). Everything that could
  be checked without a compiler was checked.