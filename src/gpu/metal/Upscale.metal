#include <metal_stdlib>
using namespace metal;

// Metal shader for image upscaling
// Uses a simple bilinear interpolation for upscaling

kernel void upscaleBilinear(
    texture2d<float, access::read> input [[texture(0)]],
    texture2d<float, access::write> output [[texture(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    // Get output dimensions
    uint outWidth = output.get_width();
    uint outHeight = output.get_height();

    // Get input dimensions
    uint inWidth = input.get_width();
    uint inHeight = input.get_height();

    // Calculate scale factors
    float scaleX = float(inWidth) / float(outWidth);
    float scaleY = float(inHeight) / float(outHeight);

    // Calculate corresponding position in input texture
    float srcX = (gid.x + 0.5f) * scaleX - 0.5f;
    float srcY = (gid.y + 0.5f) * scaleY - 0.5f;

    // Get integer and fractional parts
    int x0 = int(floor(srcX));
    int y0 = int(floor(srcY));
    float x_frac = srcX - x0;
    float y_frac = srcY - y0;

    // Clamp to input texture bounds
    x0 = clamp(x0, 0, int(inWidth) - 1);
    y0 = clamp(y0, 0, int(inHeight) - 1);
    int x1 = min(x0 + 1, int(inWidth) - 1);
    int y1 = min(y0 + 1, int(inHeight) - 1);

    // Sample the four surrounding pixels
    float4 p00 = input.read(uint2(x0, y0));
    float4 p10 = input.read(uint2(x1, y0));
    float4 p01 = input.read(uint2(x0, y1));
    float4 p11 = input.read(uint2(x1, y1));

    // Bilinear interpolation
    float4 top = mix(p00, p10, x_frac);
    float4 bottom = mix(p01, p11, x_frac);
    float4 result = mix(top, bottom, y_frac);

    // Write the result to output
    output.write(result, gid);
}
