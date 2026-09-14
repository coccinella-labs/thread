# SPDX-License-Identifier: BSD-3-Clause

import os
import subprocess
import sys
from pathlib import Path

import cv2


def test_create_test_image(tmp_path: Path) -> None:
    """Test that create_test_image.py creates a test image."""
    # Create test_images dir in tmp_path
    test_images_dir = tmp_path / "test_images"
    test_images_dir.mkdir()

    # Change to tmp_path to avoid cluttering the repo
    original_cwd = Path.cwd()
    try:
        os.chdir(tmp_path)
        # Run the script
        result = subprocess.run([sys.executable, str(Path(__file__).parent / "create_test_image.py")], check=True)
        assert result.returncode == 0

        # Check if test_images/test.jpg was created
        test_image_path = Path("test_images/test.jpg")
        assert test_image_path.exists()

        # Optionally, check image properties
        img = cv2.imread(str(test_image_path))
        assert img is not None
        assert img.shape == (256, 256, 3)
        assert img.dtype == "uint8"
    finally:
        os.chdir(original_cwd)
