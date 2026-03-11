// squoosh_rotate.h — Public C API for Squoosh-aligned image rotation
// Created by okooo5km(十里)

#ifndef SQUOOSH_ROTATE_H
#define SQUOOSH_ROTATE_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Rotation angles supported by Squoosh
typedef enum {
    SQUOOSH_ROTATE_0   = 0,
    SQUOOSH_ROTATE_90  = 90,
    SQUOOSH_ROTATE_180 = 180,
    SQUOOSH_ROTATE_270 = 270
} SquooshRotation;

/// Result of rotation
typedef struct {
    uint32_t *data;         // Caller must free with squoosh_rotate_free()
    int output_width;
    int output_height;
    int error;              // 0 = success
} SquooshRotateResult;

/// Rotate RGBA image data.
/// Mirrors Squoosh's codecs/rotate/rotate.rs with 16x16 tile algorithm.
/// @param rgba_data  Pointer to RGBA8 pixel data as uint32_t (width * height pixels)
/// @param width      Image width in pixels
/// @param height     Image height in pixels
/// @param rotation   Rotation angle (0, 90, 180, 270)
/// @return           Result containing rotated pixel data
SquooshRotateResult squoosh_rotate(
    const uint32_t *rgba_data,
    int width,
    int height,
    SquooshRotation rotation
);

/// Free rotated data returned by squoosh_rotate()
void squoosh_rotate_free(uint32_t *data);

#ifdef __cplusplus
}
#endif

#endif // SQUOOSH_ROTATE_H
