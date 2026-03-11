// SquooshPipeline.swift — Pipeline orchestration: rotate → resize → encode
// Created by okooo5km(十里)

import Foundation

/// Pipeline options combining rotate, resize, encode, and metadata policy.
public struct SquooshPipelineOptions: Sendable {
    /// Rotation to apply (before resize). Default: .none
    public var rotation: SquooshRotation
    /// Resize options. If nil, no resize is performed.
    public var resize: SquooshResizeOptions?
    /// JPEG encoding options. Default: Squoosh defaults.
    public var encode: SquooshMozJPEGOptions
    /// Metadata preservation policy. Default: .dropAll (Squoosh behavior).
    public var metadataPolicy: JPEGMetadataPolicy
    /// Source JPEG data for extracting metadata (required if metadataPolicy != .dropAll).
    public var sourceJPEGData: Data?

    public init(
        rotation: SquooshRotation = .none,
        resize: SquooshResizeOptions? = nil,
        encode: SquooshMozJPEGOptions = .squooshDefault,
        metadataPolicy: JPEGMetadataPolicy = .dropAll,
        sourceJPEGData: Data? = nil
    ) {
        self.rotation = rotation
        self.resize = resize
        self.encode = encode
        self.metadataPolicy = metadataPolicy
        self.sourceJPEGData = sourceJPEGData
    }
}

/// Pipeline that orchestrates rotate → resize → encode → metadata, matching Squoosh's processing order.
public struct SquooshPipeline: Sendable {

    private let processor = SquooshImageProcessor()
    private let encoder = SquooshJPEGEncoder()
    private let markerParser = JPEGMarkerParser()
    private let metadataProcessor = JPEGMetadataProcessor()

    public init() {}

    /// Process an RGBA image through the full pipeline: rotate → resize → encode → metadata.
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
        var encoded = try encoder.encode(current, options: options.encode)

        // Step 4: Metadata injection
        if options.metadataPolicy != .dropAll, let sourceData = options.sourceJPEGData {
            let sourceSegments = markerParser.parse(from: sourceData)
            let filtered = metadataProcessor.apply(policy: options.metadataPolicy, to: sourceSegments)
            if !filtered.isEmpty {
                let injectedData = metadataProcessor.inject(segments: filtered, into: encoded.data)
                encoded = EncodedJPEG(data: injectedData)
            }
        }

        return encoded
    }
}
