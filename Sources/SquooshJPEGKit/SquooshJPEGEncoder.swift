// SquooshJPEGEncoder.swift — Swift encoder wrapping the C shim
// Created by okooo5km(十里)

import Foundation
import CMozJPEG

/// JPEG encoder that produces output identical to Google Squoosh's MozJPEG encoder.
public struct SquooshJPEGEncoder: Sendable {

    public init() {}

    /// Encode an RGBA image to JPEG using Squoosh-aligned MozJPEG settings.
    /// - Parameters:
    ///   - image: The input RGBA8 image.
    ///   - options: Encoding options (defaults to Squoosh defaults).
    /// - Returns: An `EncodedJPEG` containing the JPEG data and diagnostics.
    /// - Throws: `SquooshJPEGError.encodingFailed` if encoding fails.
    public func encode(_ image: RGBAImage, options: SquooshMozJPEGOptions = .squooshDefault) throws -> EncodedJPEG {
        let cOpts = options.toCOptions()

        let result: SquooshJPEGResult = image.data.withUnsafeBytes { rawBuffer in
            let ptr = rawBuffer.baseAddress!.assumingMemoryBound(to: UInt8.self)
            return squoosh_jpeg_encode(ptr, Int32(image.width), Int32(image.height), cOpts)
        }

        guard result.error == 0, let dataPtr = result.data else {
            let msg = withUnsafePointer(to: result.error_msg) { msgPtr in
                msgPtr.withMemoryRebound(to: CChar.self, capacity: 256) { cStr in
                    String(cString: cStr)
                }
            }
            throw SquooshJPEGError.encodingFailed(msg)
        }

        let jpegData = Data(bytes: dataPtr, count: Int(result.size))
        squoosh_jpeg_free(dataPtr)

        return EncodedJPEG(data: jpegData)
    }
}

extension SquooshMozJPEGOptions {
    func toCOptions() -> SquooshMozJPEGEncOptions {
        var opts = SquooshMozJPEGEncOptions()
        opts.quality = Int32(quality)
        opts.baseline = baseline
        opts.arithmetic = arithmetic
        opts.progressive = progressive
        opts.optimize_coding = optimizeCoding
        opts.smoothing = Int32(smoothing)
        opts.color_space = Int32(colorSpace.rawValue)
        opts.quant_table = Int32(quantTable)
        opts.trellis_multipass = trellisMultipass
        opts.trellis_opt_zero = trellisOptZero
        opts.trellis_opt_table = trellisOptTable
        opts.trellis_loops = Int32(trellisLoops)
        opts.auto_subsample = autoSubsample
        opts.chroma_subsample = Int32(chromaSubsample)
        opts.separate_chroma_quality = separateChromaQuality
        opts.chroma_quality = Int32(chromaQuality)
        return opts
    }
}
