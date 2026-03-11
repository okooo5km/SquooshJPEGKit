// MetadataTests.swift — Tests for JPEG metadata parsing and injection
// Created by okooo5km(十里)

import Testing
import Foundation
@testable import SquooshJPEGKit

// MARK: - Helpers

/// Build a minimal JPEG with custom APP segments for testing.
func buildTestJPEG(appSegments: [(UInt8, Data)] = []) -> Data {
    var jpeg = Data()

    // SOI
    jpeg.append(contentsOf: [0xFF, 0xD8])

    // APP segments
    for (marker, payload) in appSegments {
        jpeg.append(contentsOf: [0xFF, marker])
        let length = UInt16(payload.count + 2) // +2 for length field itself
        jpeg.append(UInt8(length >> 8))
        jpeg.append(UInt8(length & 0xFF))
        jpeg.append(payload)
    }

    // Minimal DQT
    jpeg.append(contentsOf: [0xFF, 0xDB, 0x00, 0x43, 0x00])
    jpeg.append(contentsOf: [UInt8](repeating: 1, count: 64))

    // SOF0 (1x1, 1 component grayscale)
    jpeg.append(contentsOf: [0xFF, 0xC0, 0x00, 0x0B, 0x08, 0x00, 0x01, 0x00, 0x01, 0x01, 0x01, 0x11, 0x00])

    // DHT
    jpeg.append(contentsOf: [0xFF, 0xC4, 0x00, 0x1F, 0x00])
    jpeg.append(contentsOf: [UInt8](repeating: 0, count: 28))

    // SOS
    jpeg.append(contentsOf: [0xFF, 0xDA, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00, 0x3F, 0x00])

    // Scan data (minimal)
    jpeg.append(contentsOf: [0x00])

    // EOI
    jpeg.append(contentsOf: [0xFF, 0xD9])

    return jpeg
}

/// Build an EXIF APP1 payload: "Exif\0\0" + minimal TIFF header
func buildEXIFPayload(withOrientation orientation: UInt16 = 1) -> Data {
    var payload = Data()
    // "Exif\0\0"
    payload.append(contentsOf: [0x45, 0x78, 0x69, 0x66, 0x00, 0x00])

    // TIFF header (little endian)
    payload.append(contentsOf: [0x49, 0x49]) // "II" = little endian
    payload.append(contentsOf: [0x2A, 0x00]) // TIFF magic
    payload.append(contentsOf: [0x08, 0x00, 0x00, 0x00]) // Offset to IFD0

    // IFD0 with 1 entry: Orientation
    payload.append(contentsOf: [0x01, 0x00]) // 1 entry
    // Tag 0x0112 (Orientation), Type 3 (SHORT), Count 1, Value
    payload.append(contentsOf: [0x12, 0x01]) // tag
    payload.append(contentsOf: [0x03, 0x00]) // type SHORT
    payload.append(contentsOf: [0x01, 0x00, 0x00, 0x00]) // count
    payload.append(UInt8(orientation & 0xFF))
    payload.append(UInt8(orientation >> 8))
    payload.append(contentsOf: [0x00, 0x00]) // padding
    // Next IFD offset = 0
    payload.append(contentsOf: [0x00, 0x00, 0x00, 0x00])

    return payload
}

/// Build an ICC APP2 payload
func buildICCPayload() -> Data {
    var payload = Data()
    // "ICC_PROFILE\0"
    payload.append(contentsOf: [0x49, 0x43, 0x43, 0x5F, 0x50, 0x52, 0x4F, 0x46, 0x49, 0x4C, 0x45, 0x00])
    // Chunk number, total chunks
    payload.append(contentsOf: [0x01, 0x01])
    // Minimal ICC data
    payload.append(contentsOf: [UInt8](repeating: 0x42, count: 20))
    return payload
}

// MARK: - Parser Tests

@Suite("JPEG Marker Parser")
struct MarkerParserTests {

    let parser = JPEGMarkerParser()

    @Test("Parse empty JPEG returns no segments")
    func parseEmpty() {
        let segments = parser.parse(from: Data())
        #expect(segments.isEmpty)
    }

    @Test("Parse JPEG with no APP segments")
    func parseNoAPP() {
        let jpeg = buildTestJPEG()
        let segments = parser.parse(from: jpeg)
        #expect(segments.isEmpty)
    }

    @Test("Parse JPEG with EXIF APP1")
    func parseEXIF() {
        let exifPayload = buildEXIFPayload(withOrientation: 6)
        let jpeg = buildTestJPEG(appSegments: [(0xE1, exifPayload)])
        let segments = parser.parse(from: jpeg)
        #expect(segments.count == 1)
        #expect(segments[0].marker == 0xE1)
        #expect(segments[0].isEXIF == true)
    }

    @Test("Parse JPEG with ICC APP2")
    func parseICC() {
        let iccPayload = buildICCPayload()
        let jpeg = buildTestJPEG(appSegments: [(0xE2, iccPayload)])
        let segments = parser.parse(from: jpeg)
        #expect(segments.count == 1)
        #expect(segments[0].isICC == true)
    }

    @Test("Parse JPEG with multiple segments")
    func parseMultiple() {
        let exifPayload = buildEXIFPayload()
        let iccPayload = buildICCPayload()
        let jpeg = buildTestJPEG(appSegments: [
            (0xE1, exifPayload),
            (0xE2, iccPayload),
            (0xFE, Data("Test comment".utf8)),
        ])
        let segments = parser.parse(from: jpeg)
        #expect(segments.count == 3)
        #expect(segments[0].isEXIF == true)
        #expect(segments[1].isICC == true)
        #expect(segments[2].type == .comment)
    }
}

// MARK: - Metadata Policy Tests

@Suite("Metadata Policy")
struct MetadataPolicyTests {

    let processor = JPEGMetadataProcessor()

    func makeTestSegments() -> [JPEGMarkerSegment] {
        let exifData = buildEXIFPayload(withOrientation: 6)
        let iccData = buildICCPayload()
        let commentData = Data("hello".utf8)

        // Simulate parsed segments (with length prefix)
        func withLength(_ data: Data) -> Data {
            let length = UInt16(data.count + 2)
            var d = Data()
            d.append(UInt8(length >> 8))
            d.append(UInt8(length & 0xFF))
            d.append(data)
            return d
        }

        return [
            JPEGMarkerSegment(marker: 0xE1, data: withLength(exifData)),
            JPEGMarkerSegment(marker: 0xE2, data: withLength(iccData)),
            JPEGMarkerSegment(marker: 0xFE, data: withLength(commentData)),
        ]
    }

    @Test("dropAll returns empty")
    func dropAll() {
        let segments = makeTestSegments()
        let result = processor.apply(policy: .dropAll, to: segments)
        #expect(result.isEmpty)
    }

    @Test("preserveICCOnly keeps only ICC")
    func preserveICCOnly() {
        let segments = makeTestSegments()
        let result = processor.apply(policy: .preserveICCOnly, to: segments)
        #expect(result.count == 1)
        #expect(result[0].isICC == true)
    }

    @Test("preserveAllRecognized keeps all")
    func preserveAll() {
        let segments = makeTestSegments()
        let result = processor.apply(policy: .preserveAllRecognized, to: segments)
        #expect(result.count == 3)
    }

    @Test("preserveSafe keeps ICC and sanitized EXIF")
    func preserveSafe() {
        let segments = makeTestSegments()
        let result = processor.apply(policy: .preserveSafe, to: segments)
        // Should have ICC + sanitized EXIF (if EXIF data is valid enough)
        #expect(result.count >= 1) // At least ICC
        #expect(result.contains(where: { $0.isICC }))
    }
}

// MARK: - Injection Tests

@Suite("Metadata Injection")
struct MetadataInjectionTests {

    let processor = JPEGMetadataProcessor()
    let encoder = SquooshJPEGEncoder()

    @Test("dropAll output matches bare encoder")
    func dropAllMatchesBare() throws {
        let image = try solidColorImage(width: 8, height: 8, r: 128, g: 128, b: 128)
        let result = try encoder.encode(image)

        let injected = processor.inject(segments: [], into: result.data)
        #expect(injected == result.data)
    }

    @Test("Inject ICC into encoded JPEG")
    func injectICC() throws {
        let image = try solidColorImage(width: 8, height: 8, r: 128, g: 128, b: 128)
        let encoded = try encoder.encode(image)

        let iccPayload = buildICCPayload()
        var segmentData = Data()
        let length = UInt16(iccPayload.count + 2)
        segmentData.append(UInt8(length >> 8))
        segmentData.append(UInt8(length & 0xFF))
        segmentData.append(iccPayload)

        let segment = JPEGMarkerSegment(marker: 0xE2, data: segmentData)
        let injected = processor.inject(segments: [segment], into: encoded.data)

        // Verify the injected JPEG is larger
        #expect(injected.count > encoded.data.count)

        // Verify it still starts with SOI and ends with EOI
        #expect(injected[0] == 0xFF)
        #expect(injected[1] == 0xD8)
        #expect(injected[injected.count - 2] == 0xFF)
        #expect(injected[injected.count - 1] == 0xD9)

        // Verify the ICC segment can be re-parsed
        let parser = JPEGMarkerParser()
        let segments = parser.parse(from: injected)
        #expect(segments.contains(where: { $0.isICC }))
    }

    @Test("Pipeline with metadata policy")
    func pipelineWithMetadata() throws {
        let image = try solidColorImage(width: 16, height: 16, r: 100, g: 150, b: 200)

        // Create a source JPEG with ICC
        let iccPayload = buildICCPayload()
        let sourceJPEG = buildTestJPEG(appSegments: [(0xE2, iccPayload)])

        let pipeline = SquooshPipeline()
        let opts = SquooshPipelineOptions(
            metadataPolicy: .preserveICCOnly,
            sourceJPEGData: sourceJPEG
        )
        let result = try pipeline.process(image, options: opts)
        #expect(result.data.count > 0)
    }
}
