// SquooshMozJPEGOptions.swift — Encoder options mirroring Squoosh's MozJpegOptions
// Created by okooo5km(十里)

import Foundation

/// Encoding options that exactly mirror Squoosh's 16-field MozJpegOptions struct.
///
/// Default values match Squoosh's `defaultOptions` from
/// `src/features/encoders/mozJPEG/shared/meta.ts`.
public struct SquooshMozJPEGOptions: Sendable, Equatable {
    /// JPEG quality (1-100). Default: 75
    public var quality: Int
    /// Force baseline compatibility. Default: false
    public var baseline: Bool
    /// Use arithmetic coding. Default: false
    public var arithmetic: Bool
    /// Enable progressive JPEG. Default: true
    public var progressive: Bool
    /// Optimize Huffman coding tables. Default: true
    public var optimizeCoding: Bool
    /// Smoothing factor (0-100). Default: 0
    public var smoothing: Int
    /// Output color space. Default: .ycbcr
    public var colorSpace: SquooshColorSpace
    /// Quantization table preset (0-8, or -1 for default). Default: 3
    public var quantTable: Int
    /// Use scans in trellis optimization. Default: false
    public var trellisMultipass: Bool
    /// Trellis EOB optimization. Default: false
    public var trellisOptZero: Bool
    /// Trellis quantization table optimization. Default: false
    public var trellisOptTable: Bool
    /// Number of trellis optimization loops. Default: 1
    public var trellisLoops: Int
    /// Auto-determine chroma subsampling. Default: true
    public var autoSubsample: Bool
    /// Chroma subsampling factor (1-4). Default: 2
    public var chromaSubsample: Int
    /// Use separate quality for chroma. Default: false
    public var separateChromaQuality: Bool
    /// Chroma quality when separateChromaQuality is true. Default: 75
    public var chromaQuality: Int

    /// Squoosh's exact default options.
    public static let squooshDefault = SquooshMozJPEGOptions(
        quality: 75,
        baseline: false,
        arithmetic: false,
        progressive: true,
        optimizeCoding: true,
        smoothing: 0,
        colorSpace: .ycbcr,
        quantTable: 3,
        trellisMultipass: false,
        trellisOptZero: false,
        trellisOptTable: false,
        trellisLoops: 1,
        autoSubsample: true,
        chromaSubsample: 2,
        separateChromaQuality: false,
        chromaQuality: 75
    )

    public init(
        quality: Int = 75,
        baseline: Bool = false,
        arithmetic: Bool = false,
        progressive: Bool = true,
        optimizeCoding: Bool = true,
        smoothing: Int = 0,
        colorSpace: SquooshColorSpace = .ycbcr,
        quantTable: Int = 3,
        trellisMultipass: Bool = false,
        trellisOptZero: Bool = false,
        trellisOptTable: Bool = false,
        trellisLoops: Int = 1,
        autoSubsample: Bool = true,
        chromaSubsample: Int = 2,
        separateChromaQuality: Bool = false,
        chromaQuality: Int = 75
    ) {
        self.quality = quality
        self.baseline = baseline
        self.arithmetic = arithmetic
        self.progressive = progressive
        self.optimizeCoding = optimizeCoding
        self.smoothing = smoothing
        self.colorSpace = colorSpace
        self.quantTable = quantTable
        self.trellisMultipass = trellisMultipass
        self.trellisOptZero = trellisOptZero
        self.trellisOptTable = trellisOptTable
        self.trellisLoops = trellisLoops
        self.autoSubsample = autoSubsample
        self.chromaSubsample = chromaSubsample
        self.separateChromaQuality = separateChromaQuality
        self.chromaQuality = chromaQuality
    }
}
