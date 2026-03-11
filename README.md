# SquooshJPEGKit

A Swift Package that provides JPEG encoding strictly aligned with [Google Squoosh](https://squoosh.app)'s MozJPEG behavior.

## Overview

SquooshJPEGKit wraps MozJPEG 3.3.1 with a C shim that mirrors Squoosh's `mozjpeg_enc.cpp` encode flow step-by-step, ensuring identical output for the same input and options.

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

```swift
import SquooshJPEGKit

// Create an RGBA image
let image = try RGBAImage(width: 100, height: 100, data: rgbaData)

// Encode with Squoosh defaults
let encoder = SquooshJPEGEncoder()
let result = try encoder.encode(image)

// Access the JPEG data
let jpegData = result.data

// Check diagnostics
print("Progressive: \(result.diagnostics.isProgressive)")
print("Scan count: \(result.diagnostics.scanCount)")

// Custom options
var options = SquooshMozJPEGOptions.squooshDefault
options.quality = 85
options.quantTable = 2
let customResult = try encoder.encode(image, options: options)
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

- **CMozJPEG**: C target containing vendored MozJPEG 3.3.1 encoder sources and a C shim (`squoosh_jpeg_shim.c`) that mirrors Squoosh's encoding flow
- **SquooshJPEGKit**: Swift target providing the public API

## License

MIT License. See [LICENSE](LICENSE) for details.

MozJPEG is licensed under a modified BSD license. See `Vendor/mozjpeg-3.3.1/LICENSE.md` for details.
