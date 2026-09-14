import importlib
import os
import sys
from pathlib import Path

import cv2
import numpy as np
import pytest

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

# Import stitch module dynamically
stitch_module = importlib.import_module("src.cli.stitch")
stitch_tiles = stitch_module.stitch_tiles


def create_dummy_tiles(input_dir: str, tile_count: int, tile_size: tuple[int, int] = (10, 10)) -> None:
    os.makedirs(input_dir, exist_ok=True)
    for i in range(tile_count):
        img = np.random.randint(0, 256, (tile_size[1], tile_size[0], 3), dtype=np.uint8)
        cv2.imwrite(os.path.join(input_dir, f"tile_{i}.jpg"), img)


def test_stitch_tiles_success(tmp_path: Path) -> None:
    input_dir = tmp_path / "input"
    output_path = tmp_path / "output.jpg"
    tile_count = 16
    tile_size = (10, 10)
    create_dummy_tiles(str(input_dir), tile_count, tile_size)

    stitch_tiles(str(input_dir), str(output_path))

    assert output_path.exists()
    stitched = cv2.imread(str(output_path))
    assert stitched is not None
    expected_shape = (tile_size[0] * 4, tile_size[1] * 4, 3)  # 4x4 grid
    assert stitched.shape == expected_shape


def test_stitch_tiles_missing_tile(tmp_path: Path) -> None:
    input_dir = tmp_path / "input"
    output_path = tmp_path / "output.jpg"
    tile_count = 16
    create_dummy_tiles(str(input_dir), tile_count - 1)  # Missing last tile

    with pytest.raises(ValueError, match="not a perfect square"):
        stitch_tiles(str(input_dir), str(output_path))


def test_stitch_tiles_no_tiles(tmp_path: Path) -> None:
    input_dir = tmp_path / "input"
    output_path = tmp_path / "output.jpg"
    os.makedirs(input_dir, exist_ok=True)  # Create empty dir

    with pytest.raises(ValueError, match="No tile files found"):
        stitch_tiles(str(input_dir), str(output_path))
