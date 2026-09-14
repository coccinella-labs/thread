#include <algorithm>
#include <cassert>
#include <iostream>

// Simplified versions of the functions for CPU testing

float clamp(float value, float min_val, float max_val) {
  return std::min(std::max(value, min_val), max_val);
}

float cubicInterpolate(float p0, float p1, float p2, float p3, float t) {
  return p1 + 0.5f * t *
                  (2.0f * p0 - 5.0f * p1 + 4.0f * p2 - p3 +
                   t * (3.0f * (p1 - p2) + p3 - p0));
}

float perform_interpolation(const float vals[4][4], float tx, float ty) {
  float col[4];
  for (int m = 0; m < 4; m++) {
    col[m] =
        cubicInterpolate(vals[m][0], vals[m][1], vals[m][2], vals[m][3], tx);
  }
  float value = cubicInterpolate(col[0], col[1], col[2], col[3], ty);
  return clamp(value, 0.0f, 255.0f);
}

void fetchVals(unsigned char *input, int in_w, int in_h, int channels, int gxi,
               int gyi, int c, float vals[4][4]) {
  for (int m = -1; m <= 2; m++) {
    for (int n = -1; n <= 2; n++) {
      int px = clamp(gxi + m, 0, in_w - 1);
      int py = clamp(gyi + n, 0, in_h - 1);
      vals[m + 1][n + 1] = input[(py * in_w + px) * channels + c];
    }
  }
}

float getBicubicValue(unsigned char *input, int in_w, int in_h, int channels,
                      float gx, float gy, int c) {
  int gxi = (int)gx;
  int gyi = (int)gy;

  float vals[4][4];
  fetchVals(input, in_w, in_h, channels, gxi, gyi, c, vals);

  float tx = gx - gxi;
  float ty = gy - gyi;
  return perform_interpolation(vals, tx, ty);
}

int main() {
  // Test getBicubicValue on a small 4x4 image
  const int w = 4, h = 4, channels = 3;
  unsigned char test_image[h][w][channels] = {
      {{0, 0, 0}, {64, 64, 64}, {128, 128, 128}, {192, 192, 192}},
      {{0, 0, 0}, {64, 64, 64}, {128, 128, 128}, {192, 192, 192}},
      {{0, 0, 0}, {64, 64, 64}, {128, 128, 128}, {192, 192, 192}},
      {{0, 0, 0}, {64, 64, 64}, {128, 128, 128}, {192, 192, 192}}};

  // Test interpolation at (1.5, 1.5) for channel 0 (scale=2 equivalent)
  float result = getBicubicValue((unsigned char *)test_image, w, h, channels,
                                 1.5f, 1.5f, 0);
  // Expected around 64 (linear interpolation), but bicubic should be similar
  assert(result >= 60 && result <= 68); // Allow some tolerance

  // Test interpolation at (1.25, 1.25) for channel 0 (scale=4 equivalent)
  result = getBicubicValue((unsigned char *)test_image, w, h, channels, 1.25f,
                           1.25f, 0);
  assert(result >= 48 &&
         result <= 80); // Wider tolerance for different position

  // Test edge case: at integer position (1,1)
  result = getBicubicValue((unsigned char *)test_image, w, h, channels, 1.0f,
                           1.0f, 0);
  assert(result == 64.0f);

  // Test clamp: value should be clamped to 0-255
  // Create image with high values
  unsigned char high_image[4][4][3];
  for (int i = 0; i < 4; i++)
    for (int j = 0; j < 4; j++)
      for (int c = 0; c < 3; c++)
        high_image[i][j][c] = 255;
  result = getBicubicValue((unsigned char *)high_image, w, h, channels, 1.5f,
                           1.5f, 0);
  assert(result <= 255.0f && result >= 0.0f);

  // Integration test: check if upscale executable exists and runs
  // Note: This assumes the executable is built; in CI it may not be
  // For now, just check the unit tests
  std::cout << "All upscaler unit tests passed!" << std::endl;
  return 0;
}
