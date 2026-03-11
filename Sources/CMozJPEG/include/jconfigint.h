/* jconfigint.h
 * Generated for MozJPEG 3.3.1 matching Squoosh build configuration.
 * Configure flags: --disable-shared --without-turbojpeg --without-simd
 *                  --without-arith-enc --without-arith-dec
 *
 * Created by okooo5km(十里)
 */

/* libjpeg-turbo build number */
#define BUILD "20260311"

/* Compiler's inline keyword */
/* #undef inline */

/* How to obtain function inlining. */
#define INLINE __inline__ __attribute__((always_inline))

/* Define to the full name of this package. */
#define PACKAGE_NAME "mozjpeg"

/* Version number of package */
#define VERSION "3.3.1"

/* The size of `size_t', as computed by sizeof. */
#ifdef __LP64__
#define SIZEOF_SIZE_T 8
#else
#define SIZEOF_SIZE_T 4
#endif
