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

@Suite("PickerTemporaryFiles")
struct PickerTemporaryFilesTests {
    @Test("Repeated exports have separate destinations and preserve the extension")
    func separateExports() {
        let first = PickerTemporaryFiles.uniqueExportURL(fileName: "report.pdf")
        let second = PickerTemporaryFiles.uniqueExportURL(fileName: "report.pdf")
        #expect(first != second)
        #expect(first.lastPathComponent == "report.pdf")
        #expect(first.deletingLastPathComponent().deletingLastPathComponent()
            == PickerTemporaryFiles.root())
    }

    @Test("Export names cannot escape the plugin directory")
    func confinedNames() {
        for name in ["../../report.pdf", "/tmp/report.pdf", "", ".", ".."] {
            let file = PickerTemporaryFiles.uniqueExportURL(fileName: name)
            #expect(file.deletingLastPathComponent().deletingLastPathComponent()
                == PickerTemporaryFiles.root())
            #expect(!file.lastPathComponent.isEmpty)
            #expect(file.lastPathComponent != ".")
            #expect(file.lastPathComponent != "..")
        }
    }

    @Test("Clearing picker files preserves unrelated host temporary files")
    func preservesHostFiles() throws {
        let manager = FileManager.default
        let temporary = manager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try manager.createDirectory(at: temporary, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: temporary) }
        let hostFile = temporary.appendingPathComponent("host.txt")
        try Data([1]).write(to: hostFile)
        let export = PickerTemporaryFiles.uniqueExportURL(fileName: "report.pdf", in: temporary)
        try manager.createDirectory(at: export.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data([2]).write(to: export)

        try PickerTemporaryFiles.clear(in: temporary)
        #expect(manager.fileExists(atPath: hostFile.path))
        #expect(!manager.fileExists(atPath: export.path))
        try PickerTemporaryFiles.clear(in: temporary)
    }
}

/// Unit tests for the parts of the native implementation that do not depend
/// on a system picker, which tests cannot drive.
@Suite("PickOutcome")
struct PickOutcomeTests {
    @Test("Nothing picked is a cancellation")
    func nothingPicked() {
        let outcome = PickOutcome<String>.resolve(pickedCount: 0, loaded: [])
        guard case .cancelled = outcome else {
            Issue.record("Expected cancelled, got \(outcome)")
            return
        }
    }

    @Test("Every picked item loaded")
    func everythingLoaded() {
        let outcome = PickOutcome.resolve(pickedCount: 2, loaded: ["a", "b"])
        guard case .loaded(let items) = outcome else {
            Issue.record("Expected loaded, got \(outcome)")
            return
        }
        #expect(items == ["a", "b"])
    }

    // Picking items that cannot be loaded, such as iCloud only photos while
    // offline, must not look like a cancellation (#2248).
    @Test("Nothing loaded is a failure, not a cancellation")
    func nothingLoaded() {
        let outcome = PickOutcome<String>.resolve(pickedCount: 2, loaded: [])
        guard case .loadFailed = outcome else {
            Issue.record("Expected loadFailed, got \(outcome)")
            return
        }
    }

    @Test("Partial failures keep the loaded items")
    func partialFailure() {
        let outcome = PickOutcome.resolve(pickedCount: 3, loaded: ["a"])
        guard case .loaded(let items) = outcome else {
            Issue.record("Expected loaded, got \(outcome)")
            return
        }
        #expect(items == ["a"])
    }
}

@Suite("PendingRequest")
struct PendingRequestTests {
    // A picker swiped away while still appearing can leave without any
    // delegate callback (#2291).
    @Test("A shown picker that is gone without a callback is stale")
    func pickerGone() {
        #expect(PendingRequest.isStale(
            wasPresented: true, isStillPresented: false, isLoadingPickedItems: false))
    }

    @Test("A picker still on screen is not stale")
    func pickerStillShown() {
        #expect(!PendingRequest.isStale(
            wasPresented: true, isStillPresented: true, isLoadingPickedItems: false))
    }

    @Test("A request whose picker is not shown yet is not stale")
    func pickerNotShownYet() {
        #expect(!PendingRequest.isStale(
            wasPresented: false, isStillPresented: false, isLoadingPickedItems: false))
    }

    @Test("A request still loading its picked items is not stale")
    func stillLoading() {
        #expect(!PendingRequest.isStale(
            wasPresented: true, isStillPresented: false, isLoadingPickedItems: true))
    }
}

@Suite("LoadFailure")
struct LoadFailureTests {
    // An error shaped like the photo picker's: a generic description, with
    // the specific cause in the errors underneath it.
    static let outOfSpace = NSError(
        domain: NSItemProvider.errorDomain,
        code: -1000,
        userInfo: [
            NSLocalizedDescriptionKey: "Cannot load representation of type public.movie",
            NSUnderlyingErrorKey: NSError(
                domain: NSCocoaErrorDomain,
                code: NSFileWriteOutOfSpaceError,
                userInfo: [
                    NSUnderlyingErrorKey: NSError(domain: NSPOSIXErrorDomain, code: 28)
                ]),
        ])

    @Test("Details carry the index, domain, code and message")
    func topLevel() {
        let details = LoadFailure(index: 2, error: Self.outOfSpace).details
        #expect(details["index"] as? Int == 2)
        #expect(details["domain"] as? String == NSItemProvider.errorDomain)
        #expect(details["code"] as? Int == -1000)
        #expect(details["message"] as? String == "Cannot load representation of type public.movie")
    }

    @Test("Details list the underlying errors, outermost first")
    func underlyingChain() {
        let details = LoadFailure(index: 0, error: Self.outOfSpace).details
        let underlying = details["underlying"] as? [[String: Any]] ?? []
        #expect(underlying.count == 2)
        #expect(underlying.first?["domain"] as? String == NSCocoaErrorDomain)
        #expect(underlying.first?["code"] as? Int == NSFileWriteOutOfSpaceError)
        #expect(underlying.last?["domain"] as? String == NSPOSIXErrorDomain)
        #expect(underlying.last?["code"] as? Int == 28)
    }

    @Test("An error with nothing underneath has no underlying list")
    func noUnderlying() {
        let error = CocoaError(.fileReadNoSuchFile)
        let details = LoadFailure(index: 0, error: error).details
        #expect(details["domain"] as? String == NSCocoaErrorDomain)
        #expect(details["code"] as? Int == CocoaError.fileReadNoSuchFile.rawValue)
        #expect(details["underlying"] == nil)
    }

    @Test("A deep chain stops at the depth limit")
    func depthLimit() {
        var error = NSError(domain: "test", code: 0)
        for code in 1...10 {
            error = NSError(domain: "test", code: code, userInfo: [NSUnderlyingErrorKey: error])
        }
        let details = LoadFailure(index: 0, error: error).details
        let underlying = details["underlying"] as? [[String: Any]] ?? []
        #expect(underlying.count == LoadFailure.maxUnderlyingDepth)
    }
}

@Suite("MediaRepresentation")
struct MediaRepresentationTests {
    // A Live Photo registers its bundle first. Loading that would bring the
    // paired video along with the still image (#2260).
    // As registered by a HEIC Live Photo, JPEG first.
    static let livePhotoTypes = [
        "com.apple.live-photo-bundle",
        "public.jpeg",
        "public.heic",
        "com.apple.private.photos.thumbnail.standard",
    ]

    @Test("A Live Photo loads its original still image, not its bundle")
    func livePhoto() {
        let identifier = MediaRepresentation.typeIdentifier(
            for: Self.livePhotoTypes)
        #expect(identifier == "public.heic")
    }

    @Test("The compatible mode loads the JPEG the picker transcodes to")
    func compatible() {
        let identifier = MediaRepresentation.typeIdentifier(
            for: Self.livePhotoTypes, preferringCompatible: true)
        #expect(identifier == "public.jpeg")
    }

    @Test("A JPEG photo loads as JPEG")
    func jpegOnly() {
        let identifier = MediaRepresentation.typeIdentifier(for: ["public.jpeg"])
        #expect(identifier == "public.jpeg")
    }

    @Test("A video loads as a video")
    func video() {
        let identifier = MediaRepresentation.typeIdentifier(
            for: ["com.apple.quicktime-movie"])
        #expect(identifier == "com.apple.quicktime-movie")
    }

    @Test("An item with no image or video falls back to any representation")
    func noMedia() {
        let identifier = MediaRepresentation.typeIdentifier(
            for: ["com.apple.live-photo-bundle", "com.example.unknown"])
        #expect(identifier == "public.item")
    }
}
