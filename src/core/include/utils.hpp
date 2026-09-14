#pragma once
#include <opencv2/opencv.hpp>
#include <vector>

std::vector<cv::Mat> splitImageIntoTiles(const cv::Mat &image, int tile_size) {
  std::vector<cv::Mat> tiles;
  for (int y = 0; y < image.rows; y += tile_size) {
    for (int x = 0; x < image.cols; x += tile_size) {
      cv::Rect roi(x, y, tile_size, tile_size);
      tiles.push_back(image(roi).clone());
    }
  }
  return tiles;
}
