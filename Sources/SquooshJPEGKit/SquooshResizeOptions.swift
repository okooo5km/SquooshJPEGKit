// SquooshResizeOptions.swift — Resize options aligned with Squoosh
// Created by okooo5km(十里)

import Foundation

/// Resize filter types matching Squoosh's resize implementation.
/// Uses the `resize` crate 0.5.5 filter definitions.
public enum SquooshResizeFilter: Int, Sendable, CaseIterable {
    /// Bilinear / Triangle filter, radius 1.0
    case triangle = 0
    /// Catmull-Rom filter, radius 2.0
    case catrom = 1
    /// Mitchell-Netravali filter (B=1/3, C=1/3), radius 2.0
    case mitchell = 2
    /// Lanczos3 filter, radius 3.0
    case lanczos3 = 3
}

/// Options for Squoosh-aligned image resizing.
public struct SquooshResizeOptions: Sendable, Equatable {
    /// Output width in pixels.
    public var width: Int
    /// Output height in pixels.
    public var height: Int
    /// Resize filter method.
    public var filter: SquooshResizeFilter
    /// Premultiply alpha before resize, demultiply after.
    public var premultiply: Bool
    /// Convert sRGB↔Linear during resize for better quality.
    public var colorSpaceConversion: Bool

    public init(
        width: Int,
        height: Int,
        filter: SquooshResizeFilter = .lanczos3,
        premultiply: Bool = false,
        colorSpaceConversion: Bool = false
    ) {
        self.width = width
        self.height = height
        self.filter = filter
        self.premultiply = premultiply
        self.colorSpaceConversion = colorSpaceConversion
    }
}
