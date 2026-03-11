// SquooshRotation.swift — Rotation type aligned with Squoosh
// Created by okooo5km(十里)

import Foundation

/// Rotation angles supported by Squoosh's rotate codec.
public enum SquooshRotation: Int, Sendable, CaseIterable {
    case none = 0
    case clockwise90 = 90
    case clockwise180 = 180
    case clockwise270 = 270
}
