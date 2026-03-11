// jsimd_none.c — SIMD stubs for --without-simd builds
// All jsimd_can_* functions return 0 (SIMD not available)

#define JPEG_INTERNALS
#include "jinclude.h"
#include "jpeglib.h"
#include "jpegcomp.h"
#include "jdct.h"
#include "jsimd.h"

GLOBAL(int) jsimd_can_rgb_ycc(void) { return 0; }
GLOBAL(int) jsimd_can_rgb_gray(void) { return 0; }
GLOBAL(int) jsimd_can_ycc_rgb(void) { return 0; }
GLOBAL(int) jsimd_can_ycc_rgb565(void) { return 0; }
GLOBAL(int) jsimd_c_can_null_convert(void) { return 0; }
GLOBAL(int) jsimd_can_h2v2_downsample(void) { return 0; }
GLOBAL(int) jsimd_can_h2v1_downsample(void) { return 0; }
GLOBAL(int) jsimd_can_h2v2_smooth_downsample(void) { return 0; }
GLOBAL(int) jsimd_can_h2v2_upsample(void) { return 0; }
GLOBAL(int) jsimd_can_h2v1_upsample(void) { return 0; }
GLOBAL(int) jsimd_can_int_upsample(void) { return 0; }
GLOBAL(int) jsimd_can_h2v2_fancy_upsample(void) { return 0; }
GLOBAL(int) jsimd_can_h2v1_fancy_upsample(void) { return 0; }
GLOBAL(int) jsimd_can_h2v2_merged_upsample(void) { return 0; }
GLOBAL(int) jsimd_can_h2v1_merged_upsample(void) { return 0; }
GLOBAL(int) jsimd_can_huff_encode_one_block(void) { return 0; }
GLOBAL(int) jsimd_can_convsamp(void) { return 0; }
GLOBAL(int) jsimd_can_convsamp_float(void) { return 0; }
GLOBAL(int) jsimd_can_fdct_islow(void) { return 0; }
GLOBAL(int) jsimd_can_fdct_ifast(void) { return 0; }
GLOBAL(int) jsimd_can_fdct_float(void) { return 0; }
GLOBAL(int) jsimd_can_quantize(void) { return 0; }
GLOBAL(int) jsimd_can_quantize_float(void) { return 0; }

// Stub implementations — should never be called since can_* returns 0

GLOBAL(void) jsimd_rgb_ycc_convert(j_compress_ptr cinfo, JSAMPARRAY input_buf,
    JSAMPIMAGE output_buf, JDIMENSION output_row, int num_rows) { (void)cinfo; (void)input_buf; (void)output_buf; (void)output_row; (void)num_rows; }
GLOBAL(void) jsimd_rgb_gray_convert(j_compress_ptr cinfo, JSAMPARRAY input_buf,
    JSAMPIMAGE output_buf, JDIMENSION output_row, int num_rows) { (void)cinfo; (void)input_buf; (void)output_buf; (void)output_row; (void)num_rows; }
GLOBAL(void) jsimd_ycc_rgb_convert(j_decompress_ptr cinfo, JSAMPIMAGE input_buf,
    JDIMENSION input_row, JSAMPARRAY output_buf, int num_rows) { (void)cinfo; (void)input_buf; (void)input_row; (void)output_buf; (void)num_rows; }
GLOBAL(void) jsimd_ycc_rgb565_convert(j_decompress_ptr cinfo, JSAMPIMAGE input_buf,
    JDIMENSION input_row, JSAMPARRAY output_buf, int num_rows) { (void)cinfo; (void)input_buf; (void)input_row; (void)output_buf; (void)num_rows; }
GLOBAL(void) jsimd_c_null_convert(j_compress_ptr cinfo, JSAMPARRAY input_buf,
    JSAMPIMAGE output_buf, JDIMENSION output_row, int num_rows) { (void)cinfo; (void)input_buf; (void)output_buf; (void)output_row; (void)num_rows; }

GLOBAL(void) jsimd_h2v2_downsample(j_compress_ptr cinfo, jpeg_component_info *compptr,
    JSAMPARRAY input_data, JSAMPARRAY output_data) { (void)cinfo; (void)compptr; (void)input_data; (void)output_data; }
GLOBAL(void) jsimd_h2v1_downsample(j_compress_ptr cinfo, jpeg_component_info *compptr,
    JSAMPARRAY input_data, JSAMPARRAY output_data) { (void)cinfo; (void)compptr; (void)input_data; (void)output_data; }
GLOBAL(void) jsimd_h2v2_smooth_downsample(j_compress_ptr cinfo, jpeg_component_info *compptr,
    JSAMPARRAY input_data, JSAMPARRAY output_data) { (void)cinfo; (void)compptr; (void)input_data; (void)output_data; }

GLOBAL(void) jsimd_h2v2_upsample(j_decompress_ptr cinfo, jpeg_component_info *compptr,
    JSAMPARRAY input_data, JSAMPARRAY *output_data_ptr) { (void)cinfo; (void)compptr; (void)input_data; (void)output_data_ptr; }
GLOBAL(void) jsimd_h2v1_upsample(j_decompress_ptr cinfo, jpeg_component_info *compptr,
    JSAMPARRAY input_data, JSAMPARRAY *output_data_ptr) { (void)cinfo; (void)compptr; (void)input_data; (void)output_data_ptr; }
GLOBAL(void) jsimd_int_upsample(j_decompress_ptr cinfo, jpeg_component_info *compptr,
    JSAMPARRAY input_data, JSAMPARRAY *output_data_ptr) { (void)cinfo; (void)compptr; (void)input_data; (void)output_data_ptr; }

GLOBAL(void) jsimd_h2v2_fancy_upsample(j_decompress_ptr cinfo, jpeg_component_info *compptr,
    JSAMPARRAY input_data, JSAMPARRAY *output_data_ptr) { (void)cinfo; (void)compptr; (void)input_data; (void)output_data_ptr; }
GLOBAL(void) jsimd_h2v1_fancy_upsample(j_decompress_ptr cinfo, jpeg_component_info *compptr,
    JSAMPARRAY input_data, JSAMPARRAY *output_data_ptr) { (void)cinfo; (void)compptr; (void)input_data; (void)output_data_ptr; }

GLOBAL(void) jsimd_h2v2_merged_upsample(j_decompress_ptr cinfo, JSAMPIMAGE input_buf,
    JDIMENSION in_row_group_ctr, JSAMPARRAY output_buf) { (void)cinfo; (void)input_buf; (void)in_row_group_ctr; (void)output_buf; }
GLOBAL(void) jsimd_h2v1_merged_upsample(j_decompress_ptr cinfo, JSAMPIMAGE input_buf,
    JDIMENSION in_row_group_ctr, JSAMPARRAY output_buf) { (void)cinfo; (void)input_buf; (void)in_row_group_ctr; (void)output_buf; }

GLOBAL(JOCTET*) jsimd_huff_encode_one_block(void *state, JOCTET *buffer, JCOEFPTR block,
    int last_dc_val, c_derived_tbl *dctbl, c_derived_tbl *actbl) {
    (void)state; (void)buffer; (void)block; (void)last_dc_val; (void)dctbl; (void)actbl;
    return buffer;
}

GLOBAL(void) jsimd_convsamp(JSAMPARRAY sample_data, JDIMENSION start_col, DCTELEM *workspace) {
    (void)sample_data; (void)start_col; (void)workspace;
}
GLOBAL(void) jsimd_convsamp_float(JSAMPARRAY sample_data, JDIMENSION start_col, FAST_FLOAT *workspace) {
    (void)sample_data; (void)start_col; (void)workspace;
}
GLOBAL(void) jsimd_fdct_islow(DCTELEM *data) { (void)data; }
GLOBAL(void) jsimd_fdct_ifast(DCTELEM *data) { (void)data; }
GLOBAL(void) jsimd_fdct_float(FAST_FLOAT *data) { (void)data; }
GLOBAL(void) jsimd_quantize(JCOEFPTR coef_block, DCTELEM *divisors, DCTELEM *workspace) {
    (void)coef_block; (void)divisors; (void)workspace;
}
GLOBAL(void) jsimd_quantize_float(JCOEFPTR coef_block, FAST_FLOAT *divisors, FAST_FLOAT *workspace) {
    (void)coef_block; (void)divisors; (void)workspace;
}
