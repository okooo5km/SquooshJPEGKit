// SquooshImageProcessor.swift — Rotate and Resize operations
// Created by okooo5km(十里)

import Foundation
import CSquooshRotate
import CSquooshResize

/// Image processor providing Squoosh-aligned rotate and resize operations.
public struct SquooshImageProcessor: Sendable {

    public init() {}

    /// Rotate an RGBA image.
    /// Mirrors Squoosh's codecs/rotate/rotate.rs with 16x16 tile algorithm.
    /// - Parameters:
    ///   - image: The input RGBA8 image.
    ///   - rotation: The rotation angle.
    /// - Returns: A new `RGBAImage` with the rotation applied.
    public func rotate(_ image: RGBAImage, by rotation: SquooshRotation) throws -> RGBAImage {
        if rotation == .none {
            return image
        }

        let result: SquooshRotateResult = image.data.withUnsafeBytes { rawBuffer in
            let ptr = rawBuffer.baseAddress!.assumingMemoryBound(to: UInt32.self)
            return squoosh_rotate(ptr, Int32(image.width), Int32(image.height),
                                 CSquooshRotate.SquooshRotation(UInt32(rotation.rawValue)))
        }

        guard result.error == 0, let dataPtr = result.data else {
            throw SquooshJPEGError.encodingFailed("Rotation failed with error \(result.error)")
        }

        let outW = Int(result.output_width)
        let outH = Int(result.output_height)
        let outData = Data(bytes: dataPtr, count: outW * outH * 4)
        squoosh_rotate_free(dataPtr)

        return try RGBAImage(width: outW, height: outH, data: outData)
    }

    /// Resize an RGBA image.
    /// Mirrors Squoosh's codecs/resize/src/lib.rs resize() function.
    /// Uses separable convolution with configurable filter, premultiply, and color space conversion.
    /// - Parameters:
    ///   - image: The input RGBA8 image.
    ///   - options: Resize options including target dimensions and filter.
    /// - Returns: A new `RGBAImage` with the resize applied.
    public func resize(_ image: RGBAImage, options: SquooshResizeOptions) throws -> RGBAImage {
        if options.width == image.width && options.height == image.height {
            return image
        }

        guard options.width > 0, options.height > 0 else {
            throw SquooshJPEGError.invalidDimensions(width: options.width, height: options.height)
        }

        let result: SquooshResizeResult = image.data.withUnsafeBytes { rawBuffer in
            let ptr = rawBuffer.baseAddress!.assumingMemoryBound(to: UInt8.self)
            return squoosh_resize(
                ptr,
                Int32(image.width), Int32(image.height),
                Int32(options.width), Int32(options.height),
                CSquooshResize.SquooshResizeFilter(UInt32(options.filter.rawValue)),
                options.premultiply,
                options.colorSpaceConversion
            )
        }

        guard result.error == 0, let dataPtr = result.data else {
            throw SquooshJPEGError.encodingFailed("Resize failed with error \(result.error)")
        }

        let outW = Int(result.output_width)
        let outH = Int(result.output_height)
        let outData = Data(bytes: dataPtr, count: outW * outH * 4)
        squoosh_resize_free(dataPtr)

        return try RGBAImage(width: outW, height: outH, data: outData)
    }
}
