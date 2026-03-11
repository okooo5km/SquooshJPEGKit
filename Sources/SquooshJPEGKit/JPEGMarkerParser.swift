// JPEGMarkerParser.swift — JPEG marker segment parser
// Created by okooo5km(十里)

import Foundation

/// A parsed JPEG marker segment.
public struct JPEGMarkerSegment: Sendable, Equatable {
    /// Marker byte (e.g., 0xE0 for APP0, 0xE1 for APP1/EXIF).
    public let marker: UInt8
    /// Full segment data including length bytes but excluding the FF marker prefix.
    public let data: Data

    /// Marker type classification.
    public var type: JPEGMarkerType {
        switch marker {
        case 0xE0: return .app0
        case 0xE1: return .app1
        case 0xE2: return .app2
        case 0xED: return .app13
        case 0xFE: return .comment
        default:
            if marker >= 0xE0 && marker <= 0xEF {
                return .appOther(marker)
            }
            return .other(marker)
        }
    }

    /// Whether this segment is an EXIF APP1 segment.
    public var isEXIF: Bool {
        marker == 0xE1 && data.count >= 6
            && data[2] == 0x45 && data[3] == 0x78
            && data[4] == 0x69 && data[5] == 0x66 // "Exif"
    }

    /// Whether this segment is an XMP APP1 segment.
    public var isXMP: Bool {
        marker == 0xE1 && data.count >= 31
            && String(data: data[2..<min(31, data.count)], encoding: .ascii)?
                .hasPrefix("http://ns.adobe.com/xap/1.0/") == true
    }

    /// Whether this segment is an ICC profile APP2 segment.
    public var isICC: Bool {
        marker == 0xE2 && data.count >= 16
            && data[2] == 0x49 && data[3] == 0x43
            && data[4] == 0x43 && data[5] == 0x5F
            && data[6] == 0x50 && data[7] == 0x52
            && data[8] == 0x4F && data[9] == 0x46
            && data[10] == 0x49 && data[11] == 0x4C
            && data[12] == 0x45 // "ICC_PROFILE"
    }

    /// Whether this segment is an IPTC APP13 segment.
    public var isIPTC: Bool {
        marker == 0xED
    }
}

/// Classification of JPEG marker types.
public enum JPEGMarkerType: Sendable, Equatable {
    case app0
    case app1       // EXIF, XMP
    case app2       // ICC
    case app13      // IPTC
    case comment    // COM
    case appOther(UInt8)
    case other(UInt8)
}

/// Parser that extracts marker segments from JPEG data.
public struct JPEGMarkerParser: Sendable {

    public init() {}

    /// Parse all marker segments from JPEG data.
    /// Extracts APP, COM, and other marker segments between SOI and the first SOS/SOF.
    public func parse(from data: Data) -> [JPEGMarkerSegment] {
        var segments: [JPEGMarkerSegment] = []
        let bytes = Array(data)
        let count = bytes.count
        var i = 0

        // Skip SOI
        guard count >= 2, bytes[0] == 0xFF, bytes[1] == 0xD8 else {
            return segments
        }
        i = 2

        while i < count - 1 {
            guard bytes[i] == 0xFF else { i += 1; continue }

            let marker = bytes[i + 1]

            // Skip padding FF bytes
            if marker == 0xFF { i += 1; continue }
            // Skip standalone markers (RST, TEM)
            if marker == 0x00 || (marker >= 0xD0 && marker <= 0xD7) || marker == 0x01 {
                i += 2
                continue
            }

            // Stop at SOS or EOI
            if marker == 0xDA || marker == 0xD9 { break }

            // Markers with length field
            if i + 3 < count {
                let length = (Int(bytes[i + 2]) << 8) | Int(bytes[i + 3])
                if i + 2 + length <= count {
                    let segmentData = Data(bytes[(i + 2)..<(i + 2 + length)])
                    let segment = JPEGMarkerSegment(marker: marker, data: segmentData)

                    // Only collect APP, COM markers
                    if (marker >= 0xE0 && marker <= 0xEF) || marker == 0xFE {
                        segments.append(segment)
                    }
                }
                i += 2 + length
            } else {
                break
            }
        }

        return segments
    }
}
