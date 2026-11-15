import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers

@testable import file_picker_darwin

@Suite("ImageCompressor")
struct ImageCompressorTests {
    /// A directory of its own for each test, removed by the caller.
    private func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// Writes a noisy image, which compresses badly, so the quality makes a
    /// clear difference in size.
    private func writeImage(
        to url: URL,
        type: UTType,
        quality: Double = 1,
        orientation: Int? = nil
    ) throws {
        let side = 256
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        var generator = SystemRandomNumberGenerator()
        for index in pixels.indices {
            pixels[index] = index % 4 == 3 ? 255 : UInt8.random(in: 0...255, using: &generator)
        }
        let context = try #require(
            CGContext(
                data: &pixels, width: side, height: side, bitsPerComponent: 8,
                bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        let image = try #require(context.makeImage())
        let destination = try #require(
            CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil))
        var properties: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: quality]
        if let orientation {
            properties[kCGImagePropertyOrientation] = orientation
        }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))
    }

    private func size(of url: URL) throws -> Int {
        try #require(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize)
    }

    @Test("A JPEG gets smaller and keeps its name, format and orientation")
    func compressesJPEG() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("photo.jpg")
        try writeImage(to: url, type: .jpeg, orientation: 6)
        let originalSize = try size(of: url)

        #expect(ImageCompressor.compress(url, quality: 30))

        #expect(try size(of: url) < originalSize)
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        #expect(CGImageSourceGetType(source) as String? == UTType.jpeg.identifier)
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        #expect(properties?[kCGImagePropertyOrientation] as? Int == 6)
        // Nothing else is left behind next to it.
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path) == ["photo.jpg"])
    }

    @Test("The default quality of 0 and out of range values change nothing")
    func ignoresNoQuality() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("photo.jpg")
        try writeImage(to: url, type: .jpeg)
        let original = try Data(contentsOf: url)

        for quality in [0, -1, 101] {
            #expect(!ImageCompressor.compress(url, quality: quality))
        }
        #expect(try Data(contentsOf: url) == original)
    }

    @Test("A PNG, which has no lossy quality, is left as it is")
    func leavesPNG() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("drawing.png")
        try writeImage(to: url, type: .png)
        let original = try Data(contentsOf: url)

        #expect(!ImageCompressor.compress(url, quality: 30))
        #expect(try Data(contentsOf: url) == original)
    }

    @Test("A file that is not an image is left as it is")
    func leavesDocuments() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("notes.txt")
        try Data("hello".utf8).write(to: url)

        #expect(!ImageCompressor.compress(url, quality: 30))
        #expect(try Data(contentsOf: url) == Data("hello".utf8))
    }

    @Test("An image that would not get smaller is left as it is")
    func neverGrows() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("photo.jpg")
        try writeImage(to: url, type: .jpeg, quality: 0.1)
        let original = try Data(contentsOf: url)

        #expect(!ImageCompressor.compress(url, quality: 100))
        #expect(try Data(contentsOf: url) == original)
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path) == ["photo.jpg"])
    }

    @Test("Documents moved by the loader are compressed with the quality")
    func loaderCompressesDocuments() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let picked = directory.appendingPathComponent("picked.jpg")
        try writeImage(to: picked, type: .jpeg)
        let untouched = directory.appendingPathComponent("untouched.jpg")
        try FileManager.default.copyItem(at: picked, to: untouched)
        let originalSize = try size(of: picked)
        var loader = PickLoader()
        loader.temporaryDirectory = directory.appendingPathComponent("stored", isDirectory: true)

        let compressed = loader.moveDocuments([picked], compressionQuality: 30)
        let plain = loader.moveDocuments([untouched])

        #expect(compressed.failures.isEmpty && plain.failures.isEmpty)
        #expect(try #require(compressed.loaded.first?["size"] as? Int) < originalSize)
        #expect(plain.loaded.first?["size"] as? Int == originalSize)
    }
}
