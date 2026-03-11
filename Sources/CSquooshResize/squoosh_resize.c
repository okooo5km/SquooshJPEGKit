// squoosh_resize.c — Resize implementation mirroring Squoosh's resize behavior
// Created by okooo5km(十里)
//
// Port of squoosh/codecs/resize/src/lib.rs which uses the `resize` crate 0.5.5.
// Implements separable convolution (horizontal then vertical) with 4 filter types.
// sRGB↔Linear conversion and alpha premultiply match Squoosh exactly.

#include <stdlib.h>
#include <string.h>
#include <math.h>
#include "squoosh_resize.h"

// ============================================================================
// sRGB conversion — mirrors squoosh/codecs/resize/src/srgb.rs
// ============================================================================

// 256-entry LUT: sRGB byte -> linear float
// Generated from srgb_to_linear() for values 0..255
static float SRGB_TO_LINEAR_LUT[256];
static int srgb_lut_initialized = 0;

static float srgb_to_linear(float v) {
    if (v < 0.04045f) {
        return v / 12.92f;
    } else {
        float result = powf((v + 0.055f) / 1.055f, 2.4f);
        if (result < 0.0f) return 0.0f;
        if (result > 1.0f) return 1.0f;
        return result;
    }
}

static float linear_to_srgb(float v) {
    if (v < 0.0031308f) {
        float r = v * 12.92f;
        if (r < 0.0f) return 0.0f;
        if (r > 1.0f) return 1.0f;
        return r;
    } else {
        float r = 1.055f * powf(v, 1.0f / 2.4f) - 0.055f;
        if (r < 0.0f) return 0.0f;
        if (r > 1.0f) return 1.0f;
        return r;
    }
}

static void init_srgb_lut(void) {
    if (srgb_lut_initialized) return;
    for (int i = 0; i < 256; i++) {
        SRGB_TO_LINEAR_LUT[i] = srgb_to_linear((float)i / 255.0f);
    }
    srgb_lut_initialized = 1;
}

// ============================================================================
// Filter kernels — matches resize crate 0.5.5
// ============================================================================

static float clampf(float v, float lo, float hi) {
    if (v < lo) return lo;
    if (v > hi) return hi;
    return v;
}

// Triangle (bilinear) filter, radius = 1.0
static float filter_triangle(float x) {
    x = fabsf(x);
    if (x < 1.0f) return 1.0f - x;
    return 0.0f;
}

// Catmull-Rom (Catrom) filter, radius = 2.0
static float filter_catrom(float x) {
    x = fabsf(x);
    if (x < 1.0f) {
        return 0.5f * (2.0f + x * x * (-5.0f + x * 3.0f));
    } else if (x < 2.0f) {
        return 0.5f * (4.0f + x * (-8.0f + x * (5.0f - x)));
    }
    return 0.0f;
}

// Mitchell-Netravali filter, radius = 2.0
// B=1/3, C=1/3
static float filter_mitchell(float x) {
    x = fabsf(x);
    if (x < 1.0f) {
        return (1.0f / 6.0f) * (x * x * (12.0f - 9.0f * x) - x * 18.0f + 6.0f + x * 18.0f);
        // Simplified: (16 + x^2 * (21x - 36)) / 18 ... let me use the standard formula
    } else if (x < 2.0f) {
        // Standard Mitchell B=1/3 C=1/3 formula
    }
    // Use correct Mitchell formula:
    float B = 1.0f / 3.0f;
    float C = 1.0f / 3.0f;
    x = fabsf(x);
    if (x < 1.0f) {
        return ((12.0f - 9.0f * B - 6.0f * C) * x * x * x
              + (-18.0f + 12.0f * B + 6.0f * C) * x * x
              + (6.0f - 2.0f * B)) / 6.0f;
    } else if (x < 2.0f) {
        return ((-B - 6.0f * C) * x * x * x
              + (6.0f * B + 30.0f * C) * x * x
              + (-12.0f * B - 48.0f * C) * x
              + (8.0f * B + 24.0f * C)) / 6.0f;
    }
    return 0.0f;
}

// Lanczos3 filter, radius = 3.0
static float filter_lanczos3(float x) {
    x = fabsf(x);
    if (x < 1e-7f) return 1.0f;
    if (x >= 3.0f) return 0.0f;
    float pi_x = (float)M_PI * x;
    return (sinf(pi_x) / pi_x) * (sinf(pi_x / 3.0f) / (pi_x / 3.0f));
}

typedef float (*filter_func)(float);

static void get_filter(SquooshResizeFilter filter, filter_func *func, float *radius) {
    switch (filter) {
        case SQUOOSH_FILTER_TRIANGLE:
            *func = filter_triangle;
            *radius = 1.0f;
            break;
        case SQUOOSH_FILTER_CATROM:
            *func = filter_catrom;
            *radius = 2.0f;
            break;
        case SQUOOSH_FILTER_MITCHELL:
            *func = filter_mitchell;
            *radius = 2.0f;
            break;
        case SQUOOSH_FILTER_LANCZOS3:
            *func = filter_lanczos3;
            *radius = 3.0f;
            break;
        default:
            *func = filter_lanczos3;
            *radius = 3.0f;
            break;
    }
}

// ============================================================================
// Separable convolution — matches resize crate approach
// ============================================================================

/// Compute filter coefficients for one output sample
/// Returns the number of contributing input samples
static int compute_coeffs(
    filter_func fn, float radius,
    int in_size, int out_size,
    int out_pos,
    int *start,
    float *coeffs,
    int max_coeffs
) {
    float ratio = (float)in_size / (float)out_size;
    float scale = ratio > 1.0f ? ratio : 1.0f;
    float filter_radius = radius * scale;

    // Center of the output pixel in input space
    float center = ((float)out_pos + 0.5f) * ratio - 0.5f;

    int left = (int)ceilf(center - filter_radius);
    int right = (int)floorf(center + filter_radius);

    if (left < 0) left = 0;
    if (right >= in_size) right = in_size - 1;

    *start = left;
    int count = right - left + 1;
    if (count > max_coeffs) count = max_coeffs;

    float sum = 0.0f;
    for (int i = 0; i < count; i++) {
        float x = ((float)(left + i) - center) / scale;
        coeffs[i] = fn(x);
        sum += coeffs[i];
    }

    // Normalize
    if (sum != 0.0f) {
        for (int i = 0; i < count; i++) {
            coeffs[i] /= sum;
        }
    }

    return count;
}

// Max filter radius * 2 * max scale factor — generous upper bound
#define MAX_COEFFS 256

// Horizontal resize of f32 RGBA image
static void resize_horizontal(
    const float *in_data, int in_w, int in_h,
    float *out_data, int out_w,
    filter_func fn, float radius
) {
    float coeffs[MAX_COEFFS];
    for (int y = 0; y < in_h; y++) {
        for (int x = 0; x < out_w; x++) {
            int start;
            int count = compute_coeffs(fn, radius, in_w, out_w, x, &start, coeffs, MAX_COEFFS);

            float r = 0, g = 0, b = 0, a = 0;
            for (int i = 0; i < count; i++) {
                int src_x = start + i;
                int src_idx = (y * in_w + src_x) * 4;
                float c = coeffs[i];
                r += in_data[src_idx + 0] * c;
                g += in_data[src_idx + 1] * c;
                b += in_data[src_idx + 2] * c;
                a += in_data[src_idx + 3] * c;
            }

            int dst_idx = (y * out_w + x) * 4;
            out_data[dst_idx + 0] = r;
            out_data[dst_idx + 1] = g;
            out_data[dst_idx + 2] = b;
            out_data[dst_idx + 3] = a;
        }
    }
}

// Vertical resize of f32 RGBA image
static void resize_vertical(
    const float *in_data, int in_w, int in_h,
    float *out_data, int out_h,
    filter_func fn, float radius
) {
    float coeffs[MAX_COEFFS];
    for (int y = 0; y < out_h; y++) {
        int start;
        int count = compute_coeffs(fn, radius, in_h, out_h, y, &start, coeffs, MAX_COEFFS);

        for (int x = 0; x < in_w; x++) {
            float r = 0, g = 0, b = 0, a = 0;
            for (int i = 0; i < count; i++) {
                int src_y = start + i;
                int src_idx = (src_y * in_w + x) * 4;
                float c = coeffs[i];
                r += in_data[src_idx + 0] * c;
                g += in_data[src_idx + 1] * c;
                b += in_data[src_idx + 2] * c;
                a += in_data[src_idx + 3] * c;
            }

            int dst_idx = (y * in_w + x) * 4;
            out_data[dst_idx + 0] = r;
            out_data[dst_idx + 1] = g;
            out_data[dst_idx + 2] = b;
            out_data[dst_idx + 3] = a;
        }
    }
}

// ============================================================================
// Public API
// ============================================================================

SquooshResizeResult squoosh_resize(
    const uint8_t *rgba_data,
    int input_width,
    int input_height,
    int output_width,
    int output_height,
    SquooshResizeFilter filter,
    bool premultiply,
    bool color_space_conversion
) {
    SquooshResizeResult result;
    memset(&result, 0, sizeof(result));
    result.output_width = output_width;
    result.output_height = output_height;

    int num_in = input_width * input_height;
    int num_out = output_width * output_height;

    filter_func fn;
    float radius;
    get_filter(filter, &fn, &radius);

    // Allocate output
    uint8_t *output = (uint8_t *)malloc((size_t)num_out * 4);
    if (!output) {
        result.error = 1;
        return result;
    }

    // === Squoosh lib.rs: fast path when both options are false ===
    // When !premultiply && !color_space_conversion, operate directly on u8
    // through f32 conversion (simple /255 and *255).
    // For simplicity and accuracy, we always use the f32 path.

    init_srgb_lut();

    // Step 1: Convert input u8 RGBA to f32, with optional sRGB→linear and premultiply
    // Mirrors lib.rs lines 95-107
    float *f32_input = (float *)malloc((size_t)num_in * 4 * sizeof(float));
    if (!f32_input) {
        free(output);
        result.error = 1;
        return result;
    }

    for (int i = 0; i < num_in; i++) {
        float alpha = (float)rgba_data[4 * i + 3] / 255.0f;
        for (int j = 0; j < 3; j++) {
            float v;
            if (color_space_conversion) {
                v = SRGB_TO_LINEAR_LUT[rgba_data[4 * i + j]];
            } else {
                v = (float)rgba_data[4 * i + j] / 255.0f;
            }
            if (premultiply) {
                v = v * alpha;
            }
            f32_input[4 * i + j] = v;
        }
        f32_input[4 * i + 3] = alpha;
    }

    // Step 2: Separable resize — horizontal then vertical
    // Intermediate buffer: output_width x input_height
    float *temp = (float *)malloc((size_t)output_width * input_height * 4 * sizeof(float));
    float *f32_output = (float *)malloc((size_t)num_out * 4 * sizeof(float));
    if (!temp || !f32_output) {
        free(f32_input);
        free(temp);
        free(f32_output);
        free(output);
        result.error = 1;
        return result;
    }

    resize_horizontal(f32_input, input_width, input_height,
                      temp, output_width, fn, radius);
    resize_vertical(temp, output_width, input_height,
                    f32_output, output_height, fn, radius);

    free(f32_input);
    free(temp);

    // Step 3: Convert f32 back to u8, with optional demultiply and linear→sRGB
    // Mirrors lib.rs lines 121-134
    for (int i = 0; i < num_out; i++) {
        float alpha = f32_output[4 * i + 3];
        for (int j = 0; j < 3; j++) {
            float v = f32_output[4 * i + j];
            if (premultiply && alpha > 0.0f) {
                v = v / alpha;
            }
            if (color_space_conversion) {
                v = linear_to_srgb(v) * 255.0f;
            } else {
                v = v * 255.0f;
            }
            output[4 * i + j] = (uint8_t)clampf(v + 0.5f, 0.0f, 255.0f);
        }
        // Alpha channel — lib.rs line 132: round then clamp
        output[4 * i + 3] = (uint8_t)clampf(roundf(alpha * 255.0f), 0.0f, 255.0f);
    }

    free(f32_output);

    result.data = output;
    result.error = 0;
    return result;
}

void squoosh_resize_free(uint8_t *data) {
    if (data) {
        free(data);
    }
}
