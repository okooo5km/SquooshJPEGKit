# SquooshJPEGKit

A Swift Package that provides JPEG encoding, image rotation, resizing, and metadata handling — all strictly aligned with [Google Squoosh](https://squoosh.app)'s behavior.

## Overview

SquooshJPEGKit wraps MozJPEG 3.3.1 with a C shim that mirrors Squoosh's `mozjpeg_enc.cpp` encode flow step-by-step. It also ports Squoosh's rotate (from `rotate.rs`) and resize (from the `resize` crate 0.5.5) implementations to C, ensuring identical output for the same input and options.

## Requirements

- macOS 13 (Ventura) or later
- Swift 5.9+

## Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/okooo5km/SquooshJPEGKit.git", from: "0.1.0"),
]
```

## Usage

### Basic Encoding

```swift
import SquooshJPEGKit

let image = try RGBAImage(width: 100, height: 100, data: rgbaData)
let encoder = SquooshJPEGEncoder()
let result = try encoder.encode(image)
let jpegData = result.data
```

### Rotate and Resize

```swift
let processor = SquooshImageProcessor()

// Rotate 90°
let rotated = try processor.rotate(image, by: .clockwise90)

// Resize with Lanczos3
let resized = try processor.resize(image, options: SquooshResizeOptions(
    width: 400, height: 300,
    filter: .lanczos3,
    premultiply: true,
    colorSpaceConversion: true
))
```

### Full Pipeline (rotate → resize → encode)

```swift
let pipeline = SquooshPipeline()
let options = SquooshPipelineOptions(
    rotation: .clockwise90,
    resize: SquooshResizeOptions(width: 800, height: 600, filter: .lanczos3),
    encode: .squooshDefault,
    metadataPolicy: .preserveICCOnly,
    sourceJPEGData: originalJPEGData
)
let result = try pipeline.process(image, options: options)
```

### Metadata Policies

```swift
// Drop all metadata (Squoosh default)
.dropAll

// Preserve ICC color profile only
.preserveICCOnly

// Preserve ICC + safe EXIF (strip GPS, set orientation to 1)
.preserveSafe

// Preserve all APP and COM markers
.preserveAllRecognized
```

## Squoosh Default Options

| Option | Default |
|--------|---------|
| quality | 75 |
| baseline | false |
| arithmetic | false |
| progressive | true |
| optimize_coding | true |
| smoothing | 0 |
| color_space | YCbCr (3) |
| quant_table | 3 |
| trellis_multipass | false |
| trellis_opt_zero | false |
| trellis_opt_table | false |
| trellis_loops | 1 |
| auto_subsample | true |
| chroma_subsample | 2 |
| separate_chroma_quality | false |
| chroma_quality | 75 |

## Architecture

- **CMozJPEG**: Vendored MozJPEG 3.3.1 encoder + C shim mirroring Squoosh's encode flow
- **CSquooshRotate**: 0/90/180/270° rotation with 16x16 tile algorithm (ported from `rotate.rs`)
- **CSquooshResize**: Separable convolution resize with Triangle/Catrom/Mitchell/Lanczos3 filters, sRGB↔Linear conversion, alpha premultiply (ported from `resize` crate 0.5.5)
- **SquooshJPEGKit**: Swift API — encoder, processor, pipeline, metadata, diagnostics

## License

MIT License. See [LICENSE](LICENSE) for details.

MozJPEG is licensed under a modified BSD license. See `Vendor/mozjpeg-3.3.1/LICENSE.md` for details.
