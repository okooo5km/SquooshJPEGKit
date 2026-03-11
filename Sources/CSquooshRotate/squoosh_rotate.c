// squoosh_rotate.c — Rotation implementation mirroring Squoosh's rotate.rs
// Created by okooo5km(十里)
//
// Port of squoosh/codecs/rotate/rotate.rs
// Uses 16x16 tile algorithm for cache-friendly access patterns.
// Operates on uint32_t pixels (RGBA as a single 32-bit value).

#include <stdlib.h>
#include <string.h>
#include "squoosh_rotate.h"

#define TILE_SIZE 16

#ifndef MIN
#define MIN(a, b) ((a) < (b) ? (a) : (b))
#endif

// rotate.rs line 39-44: rotate_0 — simple copy
static void rotate_0(const uint32_t *in_b, uint32_t *out_b, int width, int height) {
    memcpy(out_b, in_b, (size_t)width * height * sizeof(uint32_t));
}

// rotate.rs line 47-68: rotate_90 — 16x16 tiled
static void rotate_90(const uint32_t *in_b, uint32_t *out_b, int width, int height) {
    int new_width = height;
    for (int y_start = 0; y_start < height; y_start += TILE_SIZE) {
        for (int x_start = 0; x_start < width; x_start += TILE_SIZE) {
            int y_end = MIN(y_start + TILE_SIZE, height);
            for (int y = y_start; y < y_end; y++) {
                int x_end = MIN(x_start + TILE_SIZE, width);
                for (int x = x_start; x < x_end; x++) {
                    int new_x = (new_width - 1) - y;
                    int new_y = x;
                    out_b[new_y * new_width + new_x] = in_b[y * width + x];
                }
            }
        }
    }
}

// rotate.rs line 72-77: rotate_180 — reverse copy
static void rotate_180(const uint32_t *in_b, uint32_t *out_b, int width, int height) {
    int num_pixels = width * height;
    for (int i = 0; i < num_pixels; i++) {
        out_b[num_pixels - 1 - i] = in_b[i];
    }
}

// rotate.rs line 80-101: rotate_270 — 16x16 tiled
static void rotate_270(const uint32_t *in_b, uint32_t *out_b, int width, int height) {
    int new_width = height;
    int new_height = width;
    for (int y_start = 0; y_start < height; y_start += TILE_SIZE) {
        for (int x_start = 0; x_start < width; x_start += TILE_SIZE) {
            int y_end = MIN(y_start + TILE_SIZE, height);
            for (int y = y_start; y < y_end; y++) {
                int x_end = MIN(x_start + TILE_SIZE, width);
                for (int x = x_start; x < x_end; x++) {
                    int new_x = y;
                    int new_y = new_height - 1 - x;
                    out_b[new_y * new_width + new_x] = in_b[y * width + x];
                }
            }
        }
    }
}

SquooshRotateResult squoosh_rotate(
    const uint32_t *rgba_data,
    int width,
    int height,
    SquooshRotation rotation
) {
    SquooshRotateResult result;
    memset(&result, 0, sizeof(result));

    int out_w, out_h;
    if (rotation == SQUOOSH_ROTATE_90 || rotation == SQUOOSH_ROTATE_270) {
        out_w = height;
        out_h = width;
    } else {
        out_w = width;
        out_h = height;
    }

    result.output_width = out_w;
    result.output_height = out_h;

    uint32_t *out = (uint32_t *)malloc((size_t)out_w * out_h * sizeof(uint32_t));
    if (!out) {
        result.error = 1;
        return result;
    }

    switch (rotation) {
        case SQUOOSH_ROTATE_0:
            rotate_0(rgba_data, out, width, height);
            break;
        case SQUOOSH_ROTATE_90:
            rotate_90(rgba_data, out, width, height);
            break;
        case SQUOOSH_ROTATE_180:
            rotate_180(rgba_data, out, width, height);
            break;
        case SQUOOSH_ROTATE_270:
            rotate_270(rgba_data, out, width, height);
            break;
        default:
            free(out);
            result.error = 2;
            return result;
    }

    result.data = out;
    result.error = 0;
    return result;
}

void squoosh_rotate_free(uint32_t *data) {
    if (data) {
        free(data);
    }
}
