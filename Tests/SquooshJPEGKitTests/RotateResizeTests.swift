// RotateResizeTests.swift — Tests for rotate and resize operations
// Created by okooo5km(十里)

import Testing
import Foundation
@testable import SquooshJPEGKit

// MARK: - Rotate Tests

@Suite("Rotation")
struct RotationTests {

    let processor = SquooshImageProcessor()

    /// Create a 4x2 image with known pixel pattern for rotation verification.
    /// Pattern (RGBA as uint32):
    ///   Row 0: [R, G, B, W]
    ///   Row 1: [C, M, Y, K]
    func patternImage() throws -> RGBAImage {
        let pixels: [(UInt8, UInt8, UInt8, UInt8)] = [
            // Row 0
            (255, 0, 0, 255),   // R
            (0, 255, 0, 255),   // G
            (0, 0, 255, 255),   // B
            (255, 255, 255, 255), // W
            // Row 1
            (0, 255, 255, 255),   // C
            (255, 0, 255, 255),   // M
            (255, 255, 0, 255),   // Y
            (0, 0, 0, 255),       // K
        ]
        var data = Data(count: 4 * 2 * 4)
        for (i, p) in pixels.enumerated() {
            data[i * 4 + 0] = p.0
            data[i * 4 + 1] = p.1
            data[i * 4 + 2] = p.2
            data[i * 4 + 3] = p.3
        }
        return try RGBAImage(width: 4, height: 2, data: data)
    }

    func pixel(at index: Int, in image: RGBAImage) -> (UInt8, UInt8, UInt8, UInt8) {
        let d = image.data
        let o = index * 4
        return (d[o], d[o+1], d[o+2], d[o+3])
    }

    @Test("Rotate 0 is identity")
    func rotate0() throws {
        let img = try patternImage()
        let result = try processor.rotate(img, by: .none)
        #expect(result.width == 4)
        #expect(result.height == 2)
        #expect(result.data == img.data)
    }

    @Test("Rotate 90 dimensions swap")
    func rotate90Dimensions() throws {
        let img = try patternImage()
        let result = try processor.rotate(img, by: .clockwise90)
        #expect(result.width == 2)
        #expect(result.height == 4)
    }

    @Test("Rotate 90 pixel correctness")
    func rotate90Pixels() throws {
        let img = try patternImage()
        let result = try processor.rotate(img, by: .clockwise90)
        // Original 4x2:     After 90° CW rotation (2x4):
        // R G B W            C R
        // C M Y K            M G
        //                    Y B
        //                    K W
        let p00 = pixel(at: 0, in: result) // (0,0) should be C
        #expect(p00 == (0, 255, 255, 255))
        let p10 = pixel(at: 1, in: result) // (1,0) should be R
        #expect(p10 == (255, 0, 0, 255))
    }

    @Test("Rotate 180 pixel correctness")
    func rotate180Pixels() throws {
        let img = try patternImage()
        let result = try processor.rotate(img, by: .clockwise180)
        #expect(result.width == 4)
        #expect(result.height == 2)
        // 180° reversal:
        // K Y M C
        // W B G R
        let p0 = pixel(at: 0, in: result) // K
        #expect(p0 == (0, 0, 0, 255))
        let p7 = pixel(at: 7, in: result) // R
        #expect(p7 == (255, 0, 0, 255))
    }

    @Test("Rotate 270 dimensions swap")
    func rotate270Dimensions() throws {
        let img = try patternImage()
        let result = try processor.rotate(img, by: .clockwise270)
        #expect(result.width == 2)
        #expect(result.height == 4)
    }

    @Test("Rotate 270 pixel correctness")
    func rotate270Pixels() throws {
        let img = try patternImage()
        let result = try processor.rotate(img, by: .clockwise270)
        // After 270° CW rotation (2x4):
        // W K
        // B Y
        // G M
        // R C
        let p00 = pixel(at: 0, in: result) // (0,0) should be W
        #expect(p00 == (255, 255, 255, 255))
        let p10 = pixel(at: 1, in: result) // (1,0) should be K
        #expect(p10 == (0, 0, 0, 255))
    }

    @Test("Rotate 90 then 270 is identity")
    func rotate90Then270() throws {
        let img = try patternImage()
        let r90 = try processor.rotate(img, by: .clockwise90)
        let r270 = try processor.rotate(r90, by: .clockwise270)
        #expect(r270.width == img.width)
        #expect(r270.height == img.height)
        #expect(r270.data == img.data)
    }

    @Test("Rotate 180 twice is identity")
    func rotate180Twice() throws {
        let img = try patternImage()
        let r1 = try processor.rotate(img, by: .clockwise180)
        let r2 = try processor.rotate(r1, by: .clockwise180)
        #expect(r2.data == img.data)
    }

    @Test("Rotate large image")
    func rotateLargeImage() throws {
        let img = try gradientImage(width: 100, height: 60)
        let result = try processor.rotate(img, by: .clockwise90)
        #expect(result.width == 60)
        #expect(result.height == 100)
    }
}

// MARK: - Resize Tests

@Suite("Resize")
struct ResizeTests {

    let processor = SquooshImageProcessor()

    @Test("Resize same dimensions is identity")
    func resizeSameDimensions() throws {
        let img = try solidColorImage(width: 16, height: 16, r: 128, g: 128, b: 128)
        let opts = SquooshResizeOptions(width: 16, height: 16)
        let result = try processor.resize(img, options: opts)
        #expect(result.width == 16)
        #expect(result.height == 16)
        #expect(result.data == img.data)
    }

    @Test("Resize downscale")
    func resizeDownscale() throws {
        let img = try gradientImage(width: 64, height: 64)
        let opts = SquooshResizeOptions(width: 32, height: 32, filter: .lanczos3)
        let result = try processor.resize(img, options: opts)
        #expect(result.width == 32)
        #expect(result.height == 32)
        #expect(result.data.count == 32 * 32 * 4)
    }

    @Test("Resize upscale")
    func resizeUpscale() throws {
        let img = try solidColorImage(width: 8, height: 8, r: 200, g: 100, b: 50)
        let opts = SquooshResizeOptions(width: 32, height: 32, filter: .lanczos3)
        let result = try processor.resize(img, options: opts)
        #expect(result.width == 32)
        #expect(result.height == 32)
        // Solid color should remain approximately the same after upscale
        let centerPixel = 16 * 32 + 16
        let r = result.data[centerPixel * 4]
        let g = result.data[centerPixel * 4 + 1]
        let b = result.data[centerPixel * 4 + 2]
        // Allow some tolerance from filter ringing
        #expect(abs(Int(r) - 200) <= 5)
        #expect(abs(Int(g) - 100) <= 5)
        #expect(abs(Int(b) - 50) <= 5)
    }

    @Test("All filter types produce valid output")
    func allFilterTypes() throws {
        let img = try gradientImage(width: 32, height: 32)
        for filter in SquooshResizeFilter.allCases {
            let opts = SquooshResizeOptions(width: 16, height: 16, filter: filter)
            let result = try processor.resize(img, options: opts)
            #expect(result.width == 16, "Filter \(filter) width")
            #expect(result.height == 16, "Filter \(filter) height")
            #expect(result.data.count == 16 * 16 * 4, "Filter \(filter) data size")
        }
    }

    @Test("Resize with premultiply")
    func resizeWithPremultiply() throws {
        let img = try solidColorImage(width: 16, height: 16, r: 200, g: 100, b: 50, a: 128)
        let opts = SquooshResizeOptions(width: 8, height: 8, premultiply: true)
        let result = try processor.resize(img, options: opts)
        #expect(result.data.count == 8 * 8 * 4)
    }

    @Test("Resize with color space conversion")
    func resizeWithColorSpaceConversion() throws {
        let img = try gradientImage(width: 32, height: 32)
        let opts = SquooshResizeOptions(width: 16, height: 16, colorSpaceConversion: true)
        let result = try processor.resize(img, options: opts)
        #expect(result.data.count == 16 * 16 * 4)
    }

    @Test("Resize with both premultiply and color space conversion")
    func resizeWithBothOptions() throws {
        let img = try gradientImage(width: 32, height: 32)
        let opts = SquooshResizeOptions(width: 16, height: 16, premultiply: true, colorSpaceConversion: true)
        let result = try processor.resize(img, options: opts)
        #expect(result.data.count == 16 * 16 * 4)
    }

    @Test("Resize non-square")
    func resizeNonSquare() throws {
        let img = try gradientImage(width: 64, height: 32)
        let opts = SquooshResizeOptions(width: 16, height: 8)
        let result = try processor.resize(img, options: opts)
        #expect(result.width == 16)
        #expect(result.height == 8)
    }

    @Test("Invalid resize dimensions throw")
    func invalidResizeDimensions() throws {
        let img = try solidColorImage(width: 16, height: 16, r: 128, g: 128, b: 128)
        let opts = SquooshResizeOptions(width: 0, height: 16)
        #expect(throws: SquooshJPEGError.self) {
            _ = try processor.resize(img, options: opts)
        }
    }
}

// MARK: - Pipeline Tests

@Suite("Pipeline")
struct PipelineTests {

    let pipeline = SquooshPipeline()

    @Test("Pipeline encode only")
    func pipelineEncodeOnly() throws {
        let img = try gradientImage(width: 32, height: 32)
        let opts = SquooshPipelineOptions()
        let result = try pipeline.process(img, options: opts)
        #expect(result.data.count > 0)
    }

    @Test("Pipeline rotate then encode")
    func pipelineRotateEncode() throws {
        let img = try gradientImage(width: 32, height: 16)
        let opts = SquooshPipelineOptions(rotation: .clockwise90)
        let result = try pipeline.process(img, options: opts)
        #expect(result.data.count > 0)
    }

    @Test("Pipeline resize then encode")
    func pipelineResizeEncode() throws {
        let img = try gradientImage(width: 64, height: 64)
        let resize = SquooshResizeOptions(width: 32, height: 32, filter: .lanczos3)
        let opts = SquooshPipelineOptions(resize: resize)
        let result = try pipeline.process(img, options: opts)
        #expect(result.data.count > 0)
    }

    @Test("Pipeline full: rotate → resize → encode")
    func pipelineFullChain() throws {
        let img = try gradientImage(width: 64, height: 32)
        let resize = SquooshResizeOptions(width: 16, height: 16, filter: .catrom,
                                          premultiply: true, colorSpaceConversion: true)
        let opts = SquooshPipelineOptions(
            rotation: .clockwise90,
            resize: resize,
            encode: .squooshDefault
        )
        let result = try pipeline.process(img, options: opts)
        #expect(result.data.count > 0)
        #expect(result.diagnostics.isProgressive == true)
    }
}
