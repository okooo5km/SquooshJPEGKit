// SquooshColorSpace.swift — Color space enum aligned with Squoosh
// Created by okooo5km(十里)

import Foundation

/// JPEG color spaces matching MozJPEG's J_COLOR_SPACE values used by Squoosh.
public enum SquooshColorSpace: Int, Sendable, CaseIterable {
    /// Grayscale (JCS_GRAYSCALE = 1)
    case grayscale = 1
    /// RGB (JCS_RGB = 2)
    case rgb = 2
    /// YCbCr (JCS_YCbCr = 3) — Squoosh default
    case ycbcr = 3
}
