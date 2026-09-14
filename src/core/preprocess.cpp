#include "utils.hpp" // Helper functions
#include <exception>
#include <filesystem>
#include <system_error>
#include <iostream>
#include <opencv2/opencv.hpp>
#include <string>
#include <vector>

namespace fs = std::filesystem;

int main(int argc, char **argv) {
  if (argc < 3 || argc > 4) {
    std::cerr
        << "Usage: ./preprocess <input_folder> <output_folder> [tile_size]\n";
    return -1;
  }

  std::string input_folder = argv[1];
  std::string output_folder = argv[2];
  int tile_size = 64;
  if (argc == 4) {
    try {
      tile_size = std::stoi(argv[3]);
    } catch (const std::exception &) {
      std::cerr << "Error: Invalid tile_size value provided: " << argv[3]
                << std::endl;
      return -1;
    }
  }
  if (tile_size <= 0) {
    std::cerr << "Error: tile_size must be positive\n";
    return -1;
  }

   // Create output folder if it does not exist
   std::error_code ec;
   fs::create_directories(output_folder, ec);
   if (ec) {
     std::cerr << "Error creating output directory: " << ec.message() << "\n";
     return -1;
   }

   try {
     for (const auto &entry : fs::directory_iterator(input_folder)) {
    if (entry.is_regular_file()) {
      cv::Mat image = cv::imread(entry.path().string());
      if (image.empty()) {
        std::cerr << "Error loading image: " << entry.path() << "\n";
        continue;
      }
      std::vector<cv::Mat> tiles = splitImageIntoTiles(image, tile_size);

      // Save tiles to output folder
      for (size_t i = 0; i < tiles.size(); ++i) {
        const std::string filename = entry.path().stem().string() + "_tile_" + std::to_string(i) + ".jpg";
        const fs::path output_path = fs::path(output_folder) / filename;
        if (!cv::imwrite(output_path.string(), tiles[i])) {
          std::cerr << "Error saving tile " << i << " to " << output_path.string() << "\n";
          continue;
        }
      }

      std::cout << "Processed " << entry.path() << " and saved " << tiles.size()
                << " tiles!\n";
    }
   }
   } catch (const std::exception &e) {
     std::cerr << "Error accessing input directory: " << e.what() << "\n";
     return -1;
   }

   return 0;
}
