// SquooshPipeline.swift — Pipeline orchestration: rotate → resize → encode
// Created by okooo5km(十里)

import Foundation

/// Pipeline options combining rotate, resize, and encode.
public struct SquooshPipelineOptions: Sendable {
    /// Rotation to apply (before resize). Default: .none
    public var rotation: SquooshRotation
    /// Resize options. If nil, no resize is performed.
    public var resize: SquooshResizeOptions?
    /// JPEG encoding options. Default: Squoosh defaults.
    public var encode: SquooshMozJPEGOptions

    public init(
        rotation: SquooshRotation = .none,
        resize: SquooshResizeOptions? = nil,
        encode: SquooshMozJPEGOptions = .squooshDefault
    ) {
        self.rotation = rotation
        self.resize = resize
        self.encode = encode
    }
}

/// Pipeline that orchestrates rotate → resize → encode, matching Squoosh's processing order.
public struct SquooshPipeline: Sendable {

    private let processor = SquooshImageProcessor()
    private let encoder = SquooshJPEGEncoder()

    public init() {}

    /// Process an RGBA image through the full pipeline: rotate → resize → encode.
    /// - Parameters:
    ///   - image: The input RGBA8 image.
    ///   - options: Pipeline options controlling each stage.
    /// - Returns: An `EncodedJPEG` containing the final JPEG data.
    public func process(_ image: RGBAImage, options: SquooshPipelineOptions) throws -> EncodedJPEG {
        // Step 1: Rotate
        var current = try processor.rotate(image, by: options.rotation)

        // Step 2: Resize
        if let resizeOpts = options.resize {
            current = try processor.resize(current, options: resizeOpts)
        }

        // Step 3: Encode
        return try encoder.encode(current, options: options.encode)
    }
}
