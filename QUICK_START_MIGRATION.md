# Thread: Restructuring Quick Start

This guide points you at the finished work, not a wish list. Everything below
was actually executed on branch `refactor/tight-structure` and verified with
static checks. Runtime checks (cmake/ctest/pytest) still need a tooled machine;
the exact commands are listed at the end.

## What changed

| Before | After |
| :--- | :--- |
| `cloud_gpu/` (12 `.cu` kernels) | `src/gpu/cuda/` (kernels + `test_shim.cu`) |
| `src/metal/` (shim, shader) | `src/gpu/metal/` (+ `test_shim.cpp`, `benchmark.cpp`) |
| `include/` at repo root | `src/core/include/` |
| `src/preprocess.c`, `.cpp`, `src/upscaler.cpp` | `src/core/` |
| `api/` | `src/api/` (co-located `test_api_server.py`) |
| `scripts/e2e.py`, `scripts/stitch.py`, root `create_test_image.py` | `src/cli/` (co-located tests) |
| `tests/` tree | gone; tests co-located beside code |
| `cuda.cmake`, `benchmark.cmake` | inlined as `option()` in root `CMakeLists.txt` |
| root dirs: `api cloud_gpu include src src/metal tests` | root dirs: `src docs scripts cmake` (+ `.github` `.circleci`) |

Root "file" count barely moves: the real win is the layout, not the count.
`VERSION`, `pytest.ini`, `vcpkg.json`, `CTestConfig.cmake`, `WindowsConfig.cmake`,
`mkdocs.yml`, `signed.json`, `Dockerfile`, `Dockerfile.cuda`, `test_changes.sh`
all still exist because something real depends on each of them. See
`MIGRATION_TROUBLESHOOTING.md` for why each one had to stay.

## The work, as committed

7 commits on `refactor/tight-structure`, 69 files changed (+420 / -262).

```
838fdee  refactor: move GPU code to src/gpu/
9fc1959  refactor: move core sources and headers to src/core/
0c8d7d9  refactor: move api and python CLI into src/
176e260  refactor: co-locate tests with code, absorb tests/CMakeLists into root
7bd8bf0  refactor: inline cuda.cmake and benchmark.cmake options into root CMakeLists
5911fc8  docs: update README + docs to the src/gpu|core|api|cli layout
a6e1418  docs: point unit/benchmark test conventions and run paths at new layout
```

## Super quick validation

```bash
# On the branch
git checkout refactor/tight-structure

# Static sanity (no compiler needed)
find src -name "*.py" -not -path "*__pycache__*" -exec python3 -m py_compile {} \;
for f in $(git ls-files '*.sh'); do bash -n "$f"; done
grep -rn "cloud_gpu\|src/metal/\|scripts/e2e\|scripts/stitch" . --exclude-dir=.git --exclude-dir=build | grep -v RECONSTRUCTION
# The grep above should only hit docs (incl. this file) and RECONSTRUCTION.md
```

## Runtime validation (needs cmake + python deps, not available on this machine)

```bash
python3 -m venv .venv && . .venv/bin/activate
pip install -r requirements.txt

cmake -B build -DCMAKE_BUILD_TYPE=Release -DUSE_CUDA=OFF -DWITH_OPENCV=ON
cmake --build build
ctest --test-dir build --output-on-failure

pytest src                                            # testpaths = src
python src/cli/e2e.py                                 # full pipeline (runs ~1 min)
python src/api/server.py &                            # API on :5001 (PORT env)
sleep 2 && curl http://localhost:5001/v1/health
```

The API port is **5001**, not 5000. There is no installed `thread-api` /
`thread-cli` command; the console_scripts entry points were never added and are
out of scope for a repo-layout migration.

## Rollback

Rollback is per-commit since every move was a `git mv`:

```bash
git checkout refactor/tight-structure
git revert 7bd8bf0^..main   # or: git reset --hard main after saving your work
```

Or simply `git checkout main`; `main` is untouched.

## Next steps

- Run the runtime validation on a tooled machine and fix anything it surfaces.
- Decide whether the remaining "thin" split of `docs/` into per-topic files is
  worth merging into README (it is a docs-content job, not a path job).
- Fix the pre-existing `scripts/transfer_tiles.sh:17` bash syntax error
  (it was broken before this restructuring).