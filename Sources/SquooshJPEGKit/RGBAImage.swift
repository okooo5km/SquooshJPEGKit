// RGBAImage.swift — RGBA8 image container
// Created by okooo5km(十里)

import Foundation

/// An RGBA8 image with unpremultiplied alpha.
public struct RGBAImage: Sendable {
    /// Image width in pixels.
    public let width: Int
    /// Image height in pixels.
    public let height: Int
    /// Raw RGBA8 pixel data (width * height * 4 bytes).
    public let data: Data

    /// Creates an RGBAImage from raw pixel data.
    /// - Parameters:
    ///   - width: Image width in pixels (must be > 0).
    ///   - height: Image height in pixels (must be > 0).
    ///   - data: RGBA8 pixel data, must be exactly `width * height * 4` bytes.
    /// - Throws: `SquooshJPEGError.invalidDimensions` or `.invalidDataSize`
    public init(width: Int, height: Int, data: Data) throws {
        guard width > 0, height > 0 else {
            throw SquooshJPEGError.invalidDimensions(width: width, height: height)
        }
        let expectedSize = width * height * 4
        guard data.count == expectedSize else {
            throw SquooshJPEGError.invalidDataSize(expected: expectedSize, actual: data.count)
        }
        self.width = width
        self.height = height
        self.data = data
    }
}
