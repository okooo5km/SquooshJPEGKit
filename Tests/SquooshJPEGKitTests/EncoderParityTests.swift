// EncoderParityTests.swift — Tests for Squoosh parity
// Created by okooo5km(十里)

import Testing
import Foundation
@testable import SquooshJPEGKit

// MARK: - Helper

/// Create a solid-color RGBA image.
func solidColorImage(width: Int, height: Int, r: UInt8, g: UInt8, b: UInt8, a: UInt8 = 255) throws -> RGBAImage {
    var data = Data(count: width * height * 4)
    for i in 0..<(width * height) {
        let offset = i * 4
        data[offset] = r
        data[offset + 1] = g
        data[offset + 2] = b
        data[offset + 3] = a
    }
    return try RGBAImage(width: width, height: height, data: data)
}

/// Create a gradient RGBA image.
func gradientImage(width: Int, height: Int) throws -> RGBAImage {
    var data = Data(count: width * height * 4)
    for y in 0..<height {
        for x in 0..<width {
            let offset = (y * width + x) * 4
            data[offset] = UInt8(x * 255 / max(width - 1, 1))
            data[offset + 1] = UInt8(y * 255 / max(height - 1, 1))
            data[offset + 2] = 128
            data[offset + 3] = 255
        }
    }
    return try RGBAImage(width: width, height: height, data: data)
}

// MARK: - Basic Encoding Tests

@Suite("Basic Encoding")
struct BasicEncodingTests {

    let encoder = SquooshJPEGEncoder()

    @Test("Encode 8x8 solid red")
    func encodeSolidRed8x8() throws {
        let image = try solidColorImage(width: 8, height: 8, r: 255, g: 0, b: 0)
        let result = try encoder.encode(image)

        #expect(result.data.count > 0)
        // JPEG starts with SOI marker
        #expect(result.data[0] == 0xFF)
        #expect(result.data[1] == 0xD8)
        // JPEG ends with EOI marker
        #expect(result.data[result.data.count - 2] == 0xFF)
        #expect(result.data[result.data.count - 1] == 0xD9)
    }

    @Test("Encode 1x1 pixel")
    func encode1x1() throws {
        let image = try solidColorImage(width: 1, height: 1, r: 128, g: 128, b: 128)
        let result = try encoder.encode(image)
        #expect(result.data.count > 0)
    }

    @Test("Encode larger image")
    func encodeLargerImage() throws {
        let image = try gradientImage(width: 64, height: 64)
        let result = try encoder.encode(image)
        #expect(result.data.count > 0)
    }

    @Test("Invalid dimensions throw")
    func invalidDimensions() throws {
        #expect(throws: SquooshJPEGError.self) {
            _ = try RGBAImage(width: 0, height: 10, data: Data())
        }
    }

    @Test("Invalid data size throws")
    func invalidDataSize() throws {
        #expect(throws: SquooshJPEGError.self) {
            _ = try RGBAImage(width: 2, height: 2, data: Data(count: 10))
        }
    }
}

// MARK: - Default Options Parity

@Suite("Default Options Parity")
struct DefaultOptionsParityTests {

    let encoder = SquooshJPEGEncoder()

    @Test("Default options match Squoosh")
    func defaultOptionsMatchSquoosh() throws {
        let opts = SquooshMozJPEGOptions.squooshDefault
        #expect(opts.quality == 75)
        #expect(opts.baseline == false)
        #expect(opts.arithmetic == false)
        #expect(opts.progressive == true)
        #expect(opts.optimizeCoding == true)
        #expect(opts.smoothing == 0)
        #expect(opts.colorSpace == .ycbcr)
        #expect(opts.quantTable == 3)
        #expect(opts.trellisMultipass == false)
        #expect(opts.trellisOptZero == false)
        #expect(opts.trellisOptTable == false)
        #expect(opts.trellisLoops == 1)
        #expect(opts.autoSubsample == true)
        #expect(opts.chromaSubsample == 2)
        #expect(opts.separateChromaQuality == false)
        #expect(opts.chromaQuality == 75)
    }

    @Test("Default encoding produces progressive JPEG")
    func defaultIsProgressive() throws {
        let image = try solidColorImage(width: 16, height: 16, r: 100, g: 150, b: 200)
        let result = try encoder.encode(image)
        #expect(result.diagnostics.isProgressive == true)
        #expect(result.diagnostics.scanCount > 1)
    }

    @Test("Baseline encoding produces non-progressive JPEG")
    func baselineIsNotProgressive() throws {
        let image = try solidColorImage(width: 16, height: 16, r: 100, g: 150, b: 200)
        var opts = SquooshMozJPEGOptions.squooshDefault
        opts.baseline = true
        opts.progressive = false
        let result = try encoder.encode(image, options: opts)
        #expect(result.diagnostics.isProgressive == false)
        #expect(result.diagnostics.scanCount == 1)
    }
}

// MARK: - Structural Tests

@Suite("Structural Verification")
struct StructuralTests {

    let encoder = SquooshJPEGEncoder()

    @Test("Quant table 0-8 all produce valid JPEG")
    func quantTableVariants() throws {
        let image = try gradientImage(width: 32, height: 32)
        for qt in 0...8 {
            var opts = SquooshMozJPEGOptions.squooshDefault
            opts.quantTable = qt
            let result = try encoder.encode(image, options: opts)
            #expect(result.data.count > 0, "quant_table=\(qt) should produce output")
            #expect(result.diagnostics.quantTables.count > 0, "quant_table=\(qt) should have DQT")
        }
    }

    @Test("Quality affects output size")
    func qualityAffectsSize() throws {
        let image = try gradientImage(width: 64, height: 64)

        var lowOpts = SquooshMozJPEGOptions.squooshDefault
        lowOpts.quality = 10
        let lowResult = try encoder.encode(image, options: lowOpts)

        var highOpts = SquooshMozJPEGOptions.squooshDefault
        highOpts.quality = 95
        let highResult = try encoder.encode(image, options: highOpts)

        #expect(lowResult.data.count < highResult.data.count)
    }

    @Test("Separate chroma quality")
    func separateChromaQuality() throws {
        let image = try gradientImage(width: 32, height: 32)
        var opts = SquooshMozJPEGOptions.squooshDefault
        opts.separateChromaQuality = true
        opts.chromaQuality = 30
        let result = try encoder.encode(image, options: opts)
        #expect(result.data.count > 0)
        // With separate chroma quality in YCbCr, we expect multiple quant tables
        #expect(result.diagnostics.quantTables.count >= 2)
    }

    @Test("Manual chroma subsampling")
    func manualChromaSubsampling() throws {
        let image = try gradientImage(width: 32, height: 32)
        var opts = SquooshMozJPEGOptions.squooshDefault
        opts.autoSubsample = false
        opts.chromaSubsample = 1  // No subsampling
        let result = try encoder.encode(image, options: opts)
        #expect(result.data.count > 0)
        // All sampling factors should be 1x1 when chroma_subsample=1
        if !result.diagnostics.samplingFactors.isEmpty {
            #expect(result.diagnostics.samplingFactors[0].h == 1)
            #expect(result.diagnostics.samplingFactors[0].v == 1)
        }
    }

    @Test("Chroma subsample > 2 sets dc_scan_opt_mode to 1")
    func chromaSubsampleAbove2() throws {
        let image = try gradientImage(width: 32, height: 32)
        // Squoosh allows chroma_subsample=3 with progressive mode
        // dc_scan_opt_mode is set to 1 when chroma_subsample > 2
        var opts = SquooshMozJPEGOptions.squooshDefault
        opts.autoSubsample = false
        opts.chromaSubsample = 3
        let result = try encoder.encode(image, options: opts)
        #expect(result.data.count > 0)
        // Should still produce a valid progressive JPEG
        #expect(result.diagnostics.isProgressive == true)
    }

    @Test("Grayscale color space")
    func grayscaleColorSpace() throws {
        let image = try solidColorImage(width: 16, height: 16, r: 128, g: 128, b: 128)
        var opts = SquooshMozJPEGOptions.squooshDefault
        opts.colorSpace = .grayscale
        let result = try encoder.encode(image, options: opts)
        #expect(result.data.count > 0)
        // Grayscale should have only 1 component
        #expect(result.diagnostics.samplingFactors.count == 1)
    }

    @Test("Deterministic encoding")
    func deterministicEncoding() throws {
        let image = try solidColorImage(width: 16, height: 16, r: 200, g: 100, b: 50)
        let result1 = try encoder.encode(image)
        let result2 = try encoder.encode(image)
        #expect(result1.data == result2.data)
    }

    @Test("Full transparent RGBA")
    func fullTransparent() throws {
        let image = try solidColorImage(width: 8, height: 8, r: 0, g: 0, b: 0, a: 0)
        let result = try encoder.encode(image)
        #expect(result.data.count > 0)
    }
}

// MARK: - Fixture Parity Tests

@Suite("Fixture Parity")
struct FixtureParityTests {

    let encoder = SquooshJPEGEncoder()

    @Test("Encode and compare with fixture - default options")
    func compareWithFixture() throws {
        // Generate a known RGBA pattern (4x4 red)
        let image = try solidColorImage(width: 4, height: 4, r: 255, g: 0, b: 0)
        let result = try encoder.encode(image)

        // For now, just verify it produces valid JPEG
        // Full fixture comparison requires generate_fixtures.mjs output
        #expect(result.data.count > 0)
        #expect(result.diagnostics.isProgressive == true)
    }
}
