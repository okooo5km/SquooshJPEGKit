// squoosh_jpeg_shim.c — C shim mirroring Squoosh's mozjpeg_enc.cpp encode()
// Created by okooo5km(十里)
//
// This file strictly mirrors the encoding flow from:
//   squoosh/codecs/mozjpeg/enc/mozjpeg_enc.cpp lines 60-216
// Every step is annotated with the corresponding Squoosh line reference.

#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <setjmp.h>
#include "jpeglib.h"

// cdjpeg.h provides set_quality_ratings()
#include "cdjpeg.h"

#include "squoosh_jpeg_shim.h"

// Custom error handler that uses setjmp/longjmp instead of exit()
typedef struct {
    struct jpeg_error_mgr pub;
    jmp_buf setjmp_buffer;
    char message[256];
} squoosh_error_mgr;

static void squoosh_error_exit(j_common_ptr cinfo) {
    squoosh_error_mgr *err = (squoosh_error_mgr *)cinfo->err;
    (*cinfo->err->format_message)(cinfo, err->message);
    longjmp(err->setjmp_buffer, 1);
}

SquooshMozJPEGEncOptions squoosh_jpeg_default_options(void) {
    SquooshMozJPEGEncOptions opts;
    opts.quality = 75;
    opts.baseline = false;
    opts.arithmetic = false;
    opts.progressive = true;
    opts.optimize_coding = true;
    opts.smoothing = 0;
    opts.color_space = 3;       // JCS_YCbCr
    opts.quant_table = 3;
    opts.trellis_multipass = false;
    opts.trellis_opt_zero = false;
    opts.trellis_opt_table = false;
    opts.trellis_loops = 1;
    opts.auto_subsample = true;
    opts.chroma_subsample = 2;
    opts.separate_chroma_quality = false;
    opts.chroma_quality = 75;
    return opts;
}

SquooshJPEGResult squoosh_jpeg_encode(
    const uint8_t *rgba_data,
    int width,
    int height,
    SquooshMozJPEGEncOptions opts
) {
    SquooshJPEGResult result;
    memset(&result, 0, sizeof(result));

    // === Squoosh line 75-92: allocate and initialize JPEG compression object ===
    struct jpeg_compress_struct cinfo;
    squoosh_error_mgr jerr;

    cinfo.err = jpeg_std_error(&jerr.pub);
    jerr.pub.error_exit = squoosh_error_exit;
    memset(jerr.message, 0, sizeof(jerr.message));

    if (setjmp(jerr.setjmp_buffer)) {
        // Error occurred during compression
        strncpy(result.error_msg, jerr.message, sizeof(result.error_msg) - 1);
        result.error = 1;
        jpeg_destroy_compress(&cinfo);
        return result;
    }

    jpeg_create_compress(&cinfo);

    // === Squoosh line 106-108: specify memory destination ===
    uint8_t *output = NULL;
    unsigned long size = 0;
    jpeg_mem_dest(&cinfo, &output, &size);

    // === Squoosh line 115-123: set input image parameters ===
    cinfo.image_width = width;
    cinfo.image_height = height;
    cinfo.input_components = 4;           // Squoosh line 117
    cinfo.in_color_space = JCS_EXT_RGBA;  // Squoosh line 118

    // jpeg_set_defaults triggers JCP_MAX_COMPRESSION hidden defaults
    jpeg_set_defaults(&cinfo);            // Squoosh line 123

    // === Squoosh line 125: set colorspace ===
    jpeg_set_colorspace(&cinfo, (J_COLOR_SPACE)opts.color_space);

    // === Squoosh line 127-129: quant table ===
    if (opts.quant_table != -1) {
        jpeg_c_set_int_param(&cinfo, JINT_BASE_QUANT_TBL_IDX, opts.quant_table);
    }

    // === Squoosh line 131: optimize coding ===
    cinfo.optimize_coding = opts.optimize_coding;

    // === Squoosh line 133-136: arithmetic coding ===
    if (opts.arithmetic) {
        cinfo.arith_code = TRUE;
        cinfo.optimize_coding = FALSE;
    }

    // === Squoosh line 138: smoothing ===
    cinfo.smoothing_factor = opts.smoothing;

    // === Squoosh line 140-144: trellis and DC scan opt mode ===
    jpeg_c_set_bool_param(&cinfo, JBOOLEAN_USE_SCANS_IN_TRELLIS, opts.trellis_multipass);
    jpeg_c_set_bool_param(&cinfo, JBOOLEAN_TRELLIS_EOB_OPT, opts.trellis_opt_zero);
    jpeg_c_set_bool_param(&cinfo, JBOOLEAN_TRELLIS_Q_OPT, opts.trellis_opt_table);
    jpeg_c_set_int_param(&cinfo, JINT_TRELLIS_NUM_LOOPS, opts.trellis_loops);

    // === Squoosh line 144: CRITICAL — dc_scan_opt_mode = 0 ===
    jpeg_c_set_int_param(&cinfo, JINT_DC_SCAN_OPT_MODE, 0);

    // === Squoosh line 148-156: quality ratings using string ===
    // Build quality string like "75" or "75,90"
    char quality_str[64];
    if (opts.separate_chroma_quality && opts.color_space == 3 /* JCS_YCbCr */) {
        snprintf(quality_str, sizeof(quality_str), "%d,%d", opts.quality, opts.chroma_quality);
    } else {
        snprintf(quality_str, sizeof(quality_str), "%d", opts.quality);
    }

    set_quality_ratings(&cinfo, quality_str, (boolean)opts.baseline);

    // === Squoosh line 158-166: manual chroma subsampling ===
    if (!opts.auto_subsample && opts.color_space == 3 /* JCS_YCbCr */) {
        cinfo.comp_info[0].h_samp_factor = opts.chroma_subsample;
        cinfo.comp_info[0].v_samp_factor = opts.chroma_subsample;

        if (opts.chroma_subsample > 2) {
            // Squoosh line 164: fallback to avoid encoding failure
            jpeg_c_set_int_param(&cinfo, JINT_DC_SCAN_OPT_MODE, 1);
        }
    }

    // === Squoosh line 168-173: progressive or baseline ===
    if (!opts.baseline && opts.progressive) {
        jpeg_simple_progression(&cinfo);
    } else {
        cinfo.num_scans = 0;
        cinfo.scan_info = NULL;
    }

    // === Squoosh line 179: start compressor ===
    jpeg_start_compress(&cinfo, TRUE);

    // === Squoosh line 189-200: write scanlines ===
    int row_stride = width * 4;  // RGBA = 4 bytes per pixel

    while (cinfo.next_scanline < cinfo.image_height) {
        JSAMPROW row_pointer = (JSAMPROW)&rgba_data[cinfo.next_scanline * row_stride];
        jpeg_write_scanlines(&cinfo, &row_pointer, 1);
    }

    // === Squoosh line 204: finish compression ===
    jpeg_finish_compress(&cinfo);

    // === Squoosh line 211: destroy and return ===
    jpeg_destroy_compress(&cinfo);

    result.data = output;
    result.size = size;
    result.error = 0;

    return result;
}

void squoosh_jpeg_free(uint8_t *data) {
    if (data) {
        free(data);
    }
}
