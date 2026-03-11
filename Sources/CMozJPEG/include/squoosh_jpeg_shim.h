// squoosh_jpeg_shim.h — Public C API for Squoosh-aligned JPEG encoding
// Created by okooo5km(十里)

#ifndef SQUOOSH_JPEG_SHIM_H
#define SQUOOSH_JPEG_SHIM_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Options mirroring Squoosh's MozJpegOptions (16 fields)
typedef struct {
    int quality;
    bool baseline;
    bool arithmetic;
    bool progressive;
    bool optimize_coding;
    int smoothing;
    int color_space;
    int quant_table;
    bool trellis_multipass;
    bool trellis_opt_zero;
    bool trellis_opt_table;
    int trellis_loops;
    bool auto_subsample;
    int chroma_subsample;
    bool separate_chroma_quality;
    int chroma_quality;
} SquooshMozJPEGEncOptions;

/// Result of JPEG encoding
typedef struct {
    uint8_t *data;       // Caller must free with squoosh_jpeg_free()
    unsigned long size;
    int error;           // 0 = success
    char error_msg[256];
} SquooshJPEGResult;

/// Encode RGBA pixel data to JPEG, mirroring Squoosh's mozjpeg_enc.cpp encode() exactly.
/// @param rgba_data  Pointer to RGBA8 pixel data (width * height * 4 bytes)
/// @param width      Image width in pixels
/// @param height     Image height in pixels
/// @param opts       Encoding options matching Squoosh defaults
/// @return           Result containing JPEG data or error info
SquooshJPEGResult squoosh_jpeg_encode(
    const uint8_t *rgba_data,
    int width,
    int height,
    SquooshMozJPEGEncOptions opts
);

/// Free JPEG data returned by squoosh_jpeg_encode()
void squoosh_jpeg_free(uint8_t *data);

/// Returns Squoosh-aligned default options
SquooshMozJPEGEncOptions squoosh_jpeg_default_options(void);

#ifdef __cplusplus
}
#endif

#endif // SQUOOSH_JPEG_SHIM_H
