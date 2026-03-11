// squoosh_resize.h — Public C API for Squoosh-aligned image resizing
// Created by okooo5km(十里)

#ifndef SQUOOSH_RESIZE_H
#define SQUOOSH_RESIZE_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Resize filter types matching Squoosh's resize crate 0.5.5
typedef enum {
    SQUOOSH_FILTER_TRIANGLE = 0,   // Bilinear, radius 1.0
    SQUOOSH_FILTER_CATROM   = 1,   // Catmull-Rom, radius 2.0
    SQUOOSH_FILTER_MITCHELL = 2,   // Mitchell-Netravali, radius 2.0
    SQUOOSH_FILTER_LANCZOS3 = 3    // Lanczos3, radius 3.0
} SquooshResizeFilter;

/// Result of resize operation
typedef struct {
    uint8_t *data;          // RGBA8 output, caller must free with squoosh_resize_free()
    int output_width;
    int output_height;
    int error;              // 0 = success
} SquooshResizeResult;

/// Resize RGBA8 image data.
/// Mirrors Squoosh's codecs/resize/src/lib.rs resize() function.
/// Uses separable convolution (horizontal then vertical).
///
/// @param rgba_data                Pointer to RGBA8 pixel data
/// @param input_width              Input image width
/// @param input_height             Input image height
/// @param output_width             Desired output width
/// @param output_height            Desired output height
/// @param filter                   Resize filter type
/// @param premultiply              Premultiply alpha before resize
/// @param color_space_conversion   Convert sRGB↔Linear during resize
/// @return                         Result containing resized pixel data
SquooshResizeResult squoosh_resize(
    const uint8_t *rgba_data,
    int input_width,
    int input_height,
    int output_width,
    int output_height,
    SquooshResizeFilter filter,
    bool premultiply,
    bool color_space_conversion
);

/// Free resized data returned by squoosh_resize()
void squoosh_resize_free(uint8_t *data);

#ifdef __cplusplus
}
#endif

#endif // SQUOOSH_RESIZE_H
