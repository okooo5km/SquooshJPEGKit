// Errors.swift — Error types for SquooshJPEGKit
// Created by okooo5km(十里)

import Foundation

/// Errors that can occur during JPEG encoding.
public enum SquooshJPEGError: Error, LocalizedError, Sendable {
    /// Image dimensions are invalid (must be > 0).
    case invalidDimensions(width: Int, height: Int)
    /// Pixel data size doesn't match expected size.
    case invalidDataSize(expected: Int, actual: Int)
    /// MozJPEG encoding failed with a message.
    case encodingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidDimensions(let w, let h):
            return "Invalid image dimensions: \(w)x\(h)"
        case .invalidDataSize(let expected, let actual):
            return "Invalid data size: expected \(expected) bytes, got \(actual)"
        case .encodingFailed(let msg):
            return "JPEG encoding failed: \(msg)"
        }
    }
}
