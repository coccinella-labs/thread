# Thread: Migration Troubleshooting

Real failures and traps encountered while restructuring `refactor/tight-structure`
against this specific repository. Every issue below either happened during the
migration or was found by auditing the repo rather than assuming.

## 1. `git mv` cannot create the destination parent directory

Symptom:

```
fatal: renaming 'cloud_gpu' failed: No such file or directory
```

Cause: `git mv cloud_gpu src/gpu/cuda` when `src/gpu/` does not exist yet.

Fix: `mkdir -p src/gpu` first, then `git mv`. This caught us on the very first
move and is not documented in git help.

## 2. Relative `#include` paths break silently on directory moves

`cloud_gpu/upscale.cu:20` had:

```c
#include "../include/cuda_utils.hpp"
```

After `cloud_gpu/ -> src/gpu/cuda/` and `include/ -> src/core/include/` that
resolves to nothing. It compiles only on a CUDA host, so a CPU-only machine
would never notice.

Fix: `#include "cuda_utils.hpp"`, resolved through
`target_include_directories(... ${CMAKE_SOURCE_DIR}/src/core/include)`.

`src/core/upscaler.cpp:17` had `#include "metal/MetalUpscaler.hpp>"`, which
resolved relative to `src/`. After the move: `#include "../gpu/metal/MetalUpscaler.hpp"`.

Rule: after any move, `grep -rn '#include "\.\.' src cloud_gpu` and decide each
hit by hand. Do not assume the include dir covers it; it only covers bare names.

## 3. Dynamic imports break when a directory becomes a package

The tests did not do `from api import server`. They did:

```python
sys.modules.pop("api.server", None)
server = importlib.import_module("api.server")
```

and `test_stitch.py` did `importlib.import_module("scripts.stitch")`.

Both need `src/__init__.py` to exist before `import src.api.server` can work,
plus the module string change (`api.server` -> `src.api.server`,
`scripts.stitch` -> `src.cli.stitch`). Without `src/__init__.py` you get
`ModuleNotFoundError: No module named 'src'`.

pytest prepend-import mode inserts the first ancestor of a test file that has
no `__init__.py` into `sys.path`. Once `src/` has `__init__.py`, tests under
`src/api/` resolve from the repo root, which is why this works without a root
`conftest.py` or a `pythonpath` setting. There is no root conftest in this
repo, and none was added.

## 4. Subprocess calls that assumed CWD == repo root

`scripts/e2e.py` ran helpers by bare relative name:

```python
subprocess.run([sys.executable, "create_test_image.py"], check=True)
...
subprocess.run([sys.executable, "scripts/stitch.py", ...], check=True)
```

Both break the moment the script lives somewhere else. Fix with
`str(Path(__file__).parent / "create_test_image.py")`. Same pattern in
`test_create_test_image.py`.

Note `e2e.py` also invokes `./build/bin/preprocess_c` and expects `build/` in
the CWD. That invariant is real (CI and run.sh always `cd` to repo root first)
and was left untouched.

## 5. Watch for path strings you already rewrote

A chained `sed` that mapped `api/server.py -> src/api/server.py` and then had a
second rule for `api/server` produced `src/src/api/server.py` in `README.md`.
Do path rewrites in one pass with word boundaries, or two passes with a
`grep -rn "src/src"` sweep afterwards. We caught the artifact with exactly that
sweep. The same class of bug would produce `src/gpu/cuda/..` noise if `g/` was
used sloppily on the `.cu` GLOB line.

## 6. `sed` is a terrible code editor

While fixing the stitch subprocess line, a `sed` produced:

```python
"str(Path(__file__).parent / "stitch.py")"
```

which is a syntax error and even worse, confusion between the expected string
and the inner quote. It is visible only if you recompile. Use a proper editor
for expressions with nested quotes, then always run
`python3 -m py_compile <file>` before committing.

## 7. The API port is 5001, not 5000

`api/server.py` (now `src/api/server.py`):

```python
port = int(os.getenv("PORT", "5001"))
```

Any guide, health-check, or curl example that says `:5000` will silently hit a
wrong port.

## 8. There are no console_scripts to install

The packaging section of the old guide said to add:

```toml
[project.scripts]
thread-cli = "src.cli.e2e:main"
thread-api = "src.api.server:main"
```

Neither file has a `main()` (the API runs through its `if __name__ ==
"__main__":` block), so those entry points cannot exist today. Running the API
is `python src/api/server.py`. Do not document `thread-api` until a `main()`
exists.

## 9. `tests/CMakeLists.txt` was absorbed, not deleted

The googletest/benchmark FetchContent and the `test_metal_shim` /
`benchmark_metal_shim` targets lived only in `tests/CMakeLists.txt`, reached by
`add_subdirectory(tests)`. Deleting the directory without moving that logic
would silently drop the Metal test and benchmark targets. The block now lives
in the root `CMakeLists.txt` under `option(BUILD_TESTING ...)`, and
`include(FetchContent)` moved with it. Two include-dir refs inside it had to be
repointed at `src/core/include`.

Related: after `git mv` of every file out of `tests/`, git leaves empty
`tests/`, `tests/unit/`, `tests/performance/` dirs on disk (git tracks files,
not dirs). Remove them with `rmdir`. They are invisible to `git status` and are
whitespace only; `codeql-config.yml` previously used those paths, hence its
`paths:` now points at `src/` only.

## 10. `transfer_tiles.sh:17` fails `bash -n` and that is pre-existing

```
if [[ "$input" =~ [[:space:];\|\&\$\`\(\)\"\'\<\>\{\}\[\]] ]]; then
```
syntax error in conditional expression: unexpected token `;`

Verified at `HEAD~4` (before this migration) and at current HEAD: the error is
not caused by the restructuring. Whether it parses depends on the bash build
(3.2 on macOS is strict). Out of scope here; flag it separately.

## 11. Micro-artifacts: `src/preprocess`, `logs/*`, `__pycache__`

A stray compiled binary `src/preprocess` (76 KB) from an earlier local build
sits in the tree; it is git-ignored so `git mv` and commits ignore it. Same
family: `__pycache__/` dirs created by `py_compile`, and any `logs/`. Clean the
workspace with `git clean -ndx` before judging what is and is not part of the
repo.

## 12. Files the old guide told you to delete but must survive

| File | Why it must stay |
| :--- | :--- |
| `WindowsConfig.cmake` | `include()`d on WIN32 in root CMakeLists |
| `CTestConfig.cmake` | ctest picks this up from the source dir (parallel level 4) |
| `vcpkg.json` | setup-vcpkg action, setup.sh, validate_release_config.sh |
| `VERSION` | `pyproject.toml` dynamic version |
| `mkdocs.yml` + `docs/` | pages.yml and release-validation.yml consume them |
| `cmake/` + `cmake_uninstall.cmake.in` | `configure_file`/install rules |
| `Dockerfile.cuda`, `signed.json`, `test_changes.sh` | release/CI tooling |

The old guide's final state (5 root files, 2 root dirs) is not achievable
without breaking one of the above; the honest final state is 4 visible dirs
(`cmake/ docs/ scripts/ src/`) plus `.github/` `.circleci/`, with the source
code and tests reorganized. That is the point of the restructuring; the file
count is not.

## 13. Toolchain absence limits what can be proven

Static validation on the migration machine:

- every `.py` under `src/` passes `python3 -m py_compile`
- every tracked `.sh` passes `bash -n` (except the pre-existing item 10)
- `grep` for old paths across code/config is clean

Runtime validation (cmake/ctest/pytest/cv2/flask) requires a tooled machine and
is listed in the last section of `QUICK_START_MIGRATION.md`. Do not claim
"build passes" until a builder has run it.