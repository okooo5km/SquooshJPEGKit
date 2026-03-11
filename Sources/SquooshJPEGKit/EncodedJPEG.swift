// EncodedJPEG.swift — Encoded JPEG result container
// Created by okooo5km(十里)

import Foundation

/// Result of JPEG encoding, containing the data and diagnostic info.
public struct EncodedJPEG: Sendable {
    /// The encoded JPEG file data.
    public let data: Data
    /// Diagnostic information parsed from the JPEG data.
    public let diagnostics: JPEGDiagnostics

    public init(data: Data) {
        self.data = data
        self.diagnostics = JPEGDiagnostics.parse(from: data)
    }
}
