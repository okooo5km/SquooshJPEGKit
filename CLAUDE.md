# SquooshJPEGKit

## Project Overview

Swift Package providing JPEG encoding aligned with Google Squoosh's MozJPEG behavior.

## Build & Test

```bash
swift build        # Build the package
swift test         # Run all tests
swift build -c release  # Release build
```

## Project Structure

- `Sources/CMozJPEG/` — Vendored MozJPEG 3.3.1 C sources + C shim
  - `include/` — Public headers, jconfig.h, module.modulemap
  - `squoosh_jpeg_shim.c` — C shim mirroring Squoosh's mozjpeg_enc.cpp
  - `jsimd_none.c` — SIMD stubs for --without-simd builds
- `Sources/SquooshJPEGKit/` — Swift public API
- `Tests/SquooshJPEGKitTests/` — Swift Testing framework tests
- `Vendor/mozjpeg-3.3.1/` — Full MozJPEG source (reference only)
- `Scripts/` — Tooling scripts

## Key Design Decisions

- **MozJPEG 3.3.1** matches Squoosh's exact version
- **C shim** mirrors `squoosh/codecs/mozjpeg/enc/mozjpeg_enc.cpp` line-by-line
- **`JINT_DC_SCAN_OPT_MODE = 0`** is the most critical alignment point
- **`--without-simd`** matches Squoosh's WASM build (no SIMD)
- **`--without-arith-enc --without-arith-dec`** matches Squoosh config
- Config headers (`jconfig.h`, `jconfigint.h`) are pre-generated and committed

## Conventions

- Author: okooo5km(十里)
- Code & comments in English, communication in Chinese
- Minimum deployment: macOS 13
- License: MIT

## Squoosh Reference

The reference Squoosh source is at `/Users/5km/Dev/Web/squoosh`.
Key file: `codecs/mozjpeg/enc/mozjpeg_enc.cpp` (encode function, lines 60-216).
