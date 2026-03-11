// JPEGDiagnostics.swift — Diagnostic info extracted from encoded JPEG
// Created by okooo5km(十里)

import Foundation

/// Diagnostic information about an encoded JPEG file.
public struct JPEGDiagnostics: Sendable, Equatable {
    /// Number of SOS (Start of Scan) markers found (indicates scan count).
    public let scanCount: Int
    /// Whether the JPEG is progressive (has multiple scans).
    public let isProgressive: Bool
    /// Quantization table values extracted from DQT markers.
    public let quantTables: [[UInt16]]
    /// Component sampling factors as (h, v) pairs.
    public let samplingFactors: [(h: Int, v: Int)]

    /// Parse diagnostics from raw JPEG data.
    public static func parse(from data: Data) -> JPEGDiagnostics {
        var scanCount = 0
        var isProgressive = false
        var quantTables: [[UInt16]] = []
        var samplingFactors: [(h: Int, v: Int)] = []

        var i = 0
        let bytes = Array(data)
        let count = bytes.count

        while i < count - 1 {
            guard bytes[i] == 0xFF else { i += 1; continue }

            let marker = bytes[i + 1]

            switch marker {
            case 0xC2: // SOF2 — Progressive DCT
                isProgressive = true
                if i + 9 < count {
                    let numComponents = Int(bytes[i + 9])
                    for c in 0..<numComponents {
                        let offset = i + 10 + c * 3
                        if offset + 1 < count {
                            let sampByte = bytes[offset + 1]
                            samplingFactors.append((h: Int(sampByte >> 4), v: Int(sampByte & 0x0F)))
                        }
                    }
                }
                i += 2

            case 0xC0: // SOF0 — Baseline DCT
                if i + 9 < count {
                    let numComponents = Int(bytes[i + 9])
                    for c in 0..<numComponents {
                        let offset = i + 10 + c * 3
                        if offset + 1 < count {
                            let sampByte = bytes[offset + 1]
                            samplingFactors.append((h: Int(sampByte >> 4), v: Int(sampByte & 0x0F)))
                        }
                    }
                }
                i += 2

            case 0xDA: // SOS
                scanCount += 1
                i += 2

            case 0xDB: // DQT
                if i + 3 < count {
                    let length = (Int(bytes[i + 2]) << 8) | Int(bytes[i + 3])
                    var offset = i + 4
                    let end = i + 2 + length
                    while offset < end && offset < count {
                        let precision = Int(bytes[offset] >> 4) // 0 = 8-bit, 1 = 16-bit
                        offset += 1
                        var table: [UInt16] = []
                        for _ in 0..<64 {
                            if offset >= count { break }
                            if precision == 0 {
                                table.append(UInt16(bytes[offset]))
                                offset += 1
                            } else {
                                if offset + 1 >= count { break }
                                table.append(UInt16(bytes[offset]) << 8 | UInt16(bytes[offset + 1]))
                                offset += 2
                            }
                        }
                        quantTables.append(table)
                    }
                }
                i += 2

            default:
                i += 2
            }
        }

        return JPEGDiagnostics(
            scanCount: scanCount,
            isProgressive: isProgressive,
            quantTables: quantTables,
            samplingFactors: samplingFactors
        )
    }
}

extension JPEGDiagnostics {
    public static func == (lhs: JPEGDiagnostics, rhs: JPEGDiagnostics) -> Bool {
        lhs.scanCount == rhs.scanCount
            && lhs.isProgressive == rhs.isProgressive
            && lhs.quantTables == rhs.quantTables
            && lhs.samplingFactors.count == rhs.samplingFactors.count
            && zip(lhs.samplingFactors, rhs.samplingFactors).allSatisfy { $0.h == $1.h && $0.v == $1.v }
    }
}
