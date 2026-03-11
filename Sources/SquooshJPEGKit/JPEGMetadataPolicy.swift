// JPEGMetadataPolicy.swift — Metadata preservation policies
// Created by okooo5km(十里)

import Foundation

/// Policy for preserving metadata when re-encoding JPEG images.
public enum JPEGMetadataPolicy: Sendable, Equatable {
    /// Drop all metadata (Squoosh default behavior).
    case dropAll

    /// Preserve only ICC color profile (APP2 ICC_PROFILE segments).
    case preserveICCOnly

    /// Preserve ICC + safe EXIF subset (strip GPS, MakerNote; set orientation to 1).
    case preserveSafe

    /// Preserve all recognized APP and COM marker segments.
    case preserveAllRecognized
}

/// Applies metadata policy to filter and transform marker segments.
public struct JPEGMetadataProcessor: Sendable {

    public init() {}

    /// Filter marker segments according to the given policy.
    /// - Parameters:
    ///   - segments: Parsed marker segments from the source JPEG.
    ///   - policy: The metadata preservation policy to apply.
    /// - Returns: Filtered (and possibly modified) marker segments to inject.
    public func apply(policy: JPEGMetadataPolicy, to segments: [JPEGMarkerSegment]) -> [JPEGMarkerSegment] {
        switch policy {
        case .dropAll:
            return []

        case .preserveICCOnly:
            return segments.filter { $0.isICC }

        case .preserveSafe:
            var result: [JPEGMarkerSegment] = []
            for segment in segments {
                if segment.isICC {
                    result.append(segment)
                } else if segment.isEXIF {
                    if let sanitized = sanitizeEXIF(segment) {
                        result.append(sanitized)
                    }
                }
                // Drop XMP, IPTC, COM, and other APP segments
            }
            return result

        case .preserveAllRecognized:
            return segments
        }
    }

    /// Inject marker segments into encoded JPEG data.
    /// Inserts segments after SOI and before the first non-APP marker.
    /// - Parameters:
    ///   - segments: Marker segments to inject.
    ///   - jpegData: The encoded JPEG data.
    /// - Returns: JPEG data with marker segments injected.
    public func inject(segments: [JPEGMarkerSegment], into jpegData: Data) -> Data {
        guard !segments.isEmpty else { return jpegData }
        guard jpegData.count >= 2 else { return jpegData }

        // Find insertion point: after SOI (FF D8), before first non-APP/non-COM marker
        var insertionPoint = 2 // After SOI

        let bytes = Array(jpegData)
        var i = 2
        while i < bytes.count - 1 {
            guard bytes[i] == 0xFF else { i += 1; continue }
            let marker = bytes[i + 1]
            if marker == 0xFF { i += 1; continue }

            // Skip past existing APP and COM markers in the encoded output
            if (marker >= 0xE0 && marker <= 0xEF) || marker == 0xFE {
                if i + 3 < bytes.count {
                    let length = (Int(bytes[i + 2]) << 8) | Int(bytes[i + 3])
                    i += 2 + length
                    insertionPoint = i
                } else {
                    break
                }
            } else {
                break
            }
        }

        // Build output
        var output = Data()
        output.append(jpegData[0..<insertionPoint])

        for segment in segments {
            output.append(contentsOf: [0xFF, segment.marker])
            output.append(segment.data)
        }

        output.append(jpegData[insertionPoint...])
        return output
    }

    // MARK: - EXIF Sanitization

    /// Sanitize EXIF data: strip GPS, MakerNote, set Orientation to 1.
    /// This is a simplified implementation that preserves the EXIF structure
    /// but zeros out sensitive IFD entries.
    private func sanitizeEXIF(_ segment: JPEGMarkerSegment) -> JPEGMarkerSegment? {
        guard segment.isEXIF, segment.data.count > 14 else { return nil }

        var data = segment.data
        // EXIF structure: [length(2)]["Exif\0\0"(6)][TIFF header + IFDs]
        // We'll do a simple pass to find and modify specific tags

        // Find orientation tag (0x0112) in IFD0 and set to 1
        let tiffStart = 8 // After length(2) + "Exif\0\0"(6)
        guard data.count > tiffStart + 8 else { return segment }

        let isLittleEndian = data[tiffStart] == 0x49 && data[tiffStart + 1] == 0x49

        // Walk IFD0 to find and modify Orientation tag
        modifyEXIFTag(in: &data, tiffStart: tiffStart, isLittleEndian: isLittleEndian,
                      targetTag: 0x0112, newShortValue: 1) // Orientation = 1

        // Try to null out GPS IFD pointer (tag 0x8825) and MakerNote (tag 0x927C)
        nullifyEXIFTag(in: &data, tiffStart: tiffStart, isLittleEndian: isLittleEndian,
                       targetTag: 0x8825) // GPS IFD pointer
        nullifyEXIFSubIFDTag(in: &data, tiffStart: tiffStart, isLittleEndian: isLittleEndian,
                             targetTag: 0x927C) // MakerNote

        return JPEGMarkerSegment(marker: segment.marker, data: data)
    }

    private func readUInt16(_ data: Data, at offset: Int, littleEndian: Bool) -> UInt16? {
        guard offset + 1 < data.count else { return nil }
        if littleEndian {
            return UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
        } else {
            return (UInt16(data[offset]) << 8) | UInt16(data[offset + 1])
        }
    }

    private func readUInt32(_ data: Data, at offset: Int, littleEndian: Bool) -> UInt32? {
        guard offset + 3 < data.count else { return nil }
        if littleEndian {
            return UInt32(data[offset]) | (UInt32(data[offset + 1]) << 8)
                | (UInt32(data[offset + 2]) << 16) | (UInt32(data[offset + 3]) << 24)
        } else {
            return (UInt32(data[offset]) << 24) | (UInt32(data[offset + 1]) << 16)
                | (UInt32(data[offset + 2]) << 8) | UInt32(data[offset + 3])
        }
    }

    private func writeUInt16(_ data: inout Data, at offset: Int, value: UInt16, littleEndian: Bool) {
        guard offset + 1 < data.count else { return }
        if littleEndian {
            data[offset] = UInt8(value & 0xFF)
            data[offset + 1] = UInt8(value >> 8)
        } else {
            data[offset] = UInt8(value >> 8)
            data[offset + 1] = UInt8(value & 0xFF)
        }
    }

    private func modifyEXIFTag(in data: inout Data, tiffStart: Int, isLittleEndian: Bool,
                                targetTag: UInt16, newShortValue: UInt16) {
        let ifdOffset = tiffStart + 4 // Skip byte order + magic
        guard let ifd0Offset = readUInt32(data, at: ifdOffset, littleEndian: isLittleEndian) else { return }

        let ifd0Start = tiffStart + Int(ifd0Offset)
        guard let entryCount = readUInt16(data, at: ifd0Start, littleEndian: isLittleEndian) else { return }

        for i in 0..<Int(entryCount) {
            let entryOffset = ifd0Start + 2 + i * 12
            guard let tag = readUInt16(data, at: entryOffset, littleEndian: isLittleEndian) else { continue }
            if tag == targetTag {
                // Write new value at offset+8 (value field in IFD entry)
                writeUInt16(&data, at: entryOffset + 8, value: newShortValue, littleEndian: isLittleEndian)
                return
            }
        }
    }

    private func nullifyEXIFTag(in data: inout Data, tiffStart: Int, isLittleEndian: Bool,
                                 targetTag: UInt16) {
        let ifdOffset = tiffStart + 4
        guard let ifd0Offset = readUInt32(data, at: ifdOffset, littleEndian: isLittleEndian) else { return }

        let ifd0Start = tiffStart + Int(ifd0Offset)
        guard let entryCount = readUInt16(data, at: ifd0Start, littleEndian: isLittleEndian) else { return }

        for i in 0..<Int(entryCount) {
            let entryOffset = ifd0Start + 2 + i * 12
            guard let tag = readUInt16(data, at: entryOffset, littleEndian: isLittleEndian) else { continue }
            if tag == targetTag {
                // Zero out the value/offset field
                for j in 0..<4 {
                    if entryOffset + 8 + j < data.count {
                        data[entryOffset + 8 + j] = 0
                    }
                }
                return
            }
        }
    }

    private func nullifyEXIFSubIFDTag(in data: inout Data, tiffStart: Int, isLittleEndian: Bool,
                                       targetTag: UInt16) {
        // Find EXIF SubIFD (tag 0x8769) in IFD0
        let ifdOffset = tiffStart + 4
        guard let ifd0Offset = readUInt32(data, at: ifdOffset, littleEndian: isLittleEndian) else { return }

        let ifd0Start = tiffStart + Int(ifd0Offset)
        guard let entryCount = readUInt16(data, at: ifd0Start, littleEndian: isLittleEndian) else { return }

        var exifSubIFDOffset: UInt32?
        for i in 0..<Int(entryCount) {
            let entryOffset = ifd0Start + 2 + i * 12
            guard let tag = readUInt16(data, at: entryOffset, littleEndian: isLittleEndian) else { continue }
            if tag == 0x8769 { // ExifIFDPointer
                exifSubIFDOffset = readUInt32(data, at: entryOffset + 8, littleEndian: isLittleEndian)
                break
            }
        }

        guard let subIFDOff = exifSubIFDOffset else { return }
        let subIFDStart = tiffStart + Int(subIFDOff)
        guard let subEntryCount = readUInt16(data, at: subIFDStart, littleEndian: isLittleEndian) else { return }

        for i in 0..<Int(subEntryCount) {
            let entryOffset = subIFDStart + 2 + i * 12
            guard let tag = readUInt16(data, at: entryOffset, littleEndian: isLittleEndian) else { continue }
            if tag == targetTag {
                for j in 0..<4 {
                    if entryOffset + 8 + j < data.count {
                        data[entryOffset + 8 + j] = 0
                    }
                }
                return
            }
        }
    }
}
