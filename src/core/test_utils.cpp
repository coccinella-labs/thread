#include "utils.hpp"
#include <cassert>
#include <iostream>
#include <opencv2/opencv.hpp>
#include <vector>

int main() {
  // Test splitImageIntoTiles
  cv::Mat image(128, 128, CV_8UC3, cv::Scalar(255, 0, 0)); // 128x128 image
  int tile_size = 64;
  std::vector<cv::Mat> tiles = splitImageIntoTiles(image, tile_size);

  // Should have 4 tiles (2x2)
  assert(tiles.size() == 4);
  for (const auto &tile : tiles) {
    assert(tile.rows == tile_size);
    assert(tile.cols == tile_size);
    assert(tile.channels() == 3);
  }

  // Test with non-square image
  cv::Mat image2(100, 200, CV_8UC3, cv::Scalar(0, 255, 0));
  std::vector<cv::Mat> tiles2 = splitImageIntoTiles(image2, 50);
  // 2 rows (100/50=2), 4 cols (200/50=4), total 8 tiles
  assert(tiles2.size() == 8);

  std::cout << "All tests passed!" << std::endl;
  return 0;
}
