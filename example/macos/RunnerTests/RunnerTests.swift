import Foundation
import Testing

@testable import file_picker_darwin

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

/// A picked item that loads `content` as `fileName` after `delay`, or fails
/// when `content` is `nil`. Like iOS, it deletes the loaded file as soon as
/// the completion handler returns.
final class MockMediaItem: PickedMediaItem {
    let assetIdentifier: String?
    let suggestedName: String?
    let registeredTypeIdentifiers: [String]
    let fileName: String
    let content: String?
    let delay: TimeInterval
    private(set) var requestedTypes: [String] = []

    init(
        fileName: String,
        content: String?,
        delay: TimeInterval = 0,
        assetIdentifier: String? = nil,
        suggestedName: String? = nil,
        registeredTypeIdentifiers: [String] = ["public.jpeg"]
    ) {
        self.fileName = fileName
        self.content = content
        self.delay = delay
        self.assetIdentifier = assetIdentifier
        self.suggestedName = suggestedName
        self.registeredTypeIdentifiers = registeredTypeIdentifiers
    }

    func loadFile(
        forTypeIdentifier typeIdentifier: String,
        completion: @escaping (URL?) -> Void
    ) {
        requestedTypes.append(typeIdentifier)
        let fileName = fileName
        let content = content
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
            guard let content else {
                completion(nil)
                return
            }
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            let url = directory.appendingPathComponent(fileName)
            try? FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true)
            try? content.write(to: url, atomically: true, encoding: .utf8)
            completion(url)
            try? FileManager.default.removeItem(at: directory)
        }
    }
}

@Suite("PickLoader")
struct PickLoaderTests {
    let loader = PickLoader(
        temporaryDirectory: FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true))

    func loadMedia(
        _ items: [MockMediaItem],
        preferringCompatible: Bool = false
    ) async -> [[String: Any]] {
        await withCheckedContinuation { continuation in
            loader.loadMedia(
                items,
                preferringCompatible: preferringCompatible,
                queue: .global()
            ) { loaded in
                continuation.resume(returning: loaded)
            }
        }
    }

    func names(_ loaded: [[String: Any]]) -> [String] {
        loaded.compactMap { $0["name"] as? String }
    }

    func content(_ info: [String: Any]) -> String? {
        (info["path"] as? String).flatMap {
            try? String(contentsOfFile: $0, encoding: .utf8)
        }
    }

    // Items load concurrently and finish in any order (#2217).
    @Test("Media keeps the picked order when items finish out of order")
    func pickedOrder() async {
        let loaded = await loadMedia([
            MockMediaItem(fileName: "a.jpeg", content: "a", delay: 0.2),
            MockMediaItem(fileName: "b.jpeg", content: "b"),
            MockMediaItem(fileName: "c.jpeg", content: "c", delay: 0.1),
        ])
        #expect(names(loaded) == ["a.jpeg", "b.jpeg", "c.jpeg"])
    }

    @Test("Media that fails to load is dropped, the rest is kept")
    func partialFailure() async {
        let loaded = await loadMedia([
            MockMediaItem(fileName: "a.jpeg", content: "a"),
            MockMediaItem(fileName: "b.jpeg", content: nil),
            MockMediaItem(fileName: "c.jpeg", content: "c"),
        ])
        #expect(names(loaded) == ["a.jpeg", "c.jpeg"])
        guard case .loaded(let items) = PickOutcome.resolve(pickedCount: 3, loaded: loaded)
        else {
            Issue.record("Expected the loaded items to be returned")
            return
        }
        #expect(items.count == 2)
    }

    // Failing to load every item must not look like a cancellation (#2248).
    @Test("Media where nothing loads is a load failure")
    func nothingLoaded() async {
        let loaded = await loadMedia([
            MockMediaItem(fileName: "a.jpeg", content: nil),
            MockMediaItem(fileName: "b.jpeg", content: nil),
        ])
        #expect(loaded.isEmpty)
        guard case .loadFailed = PickOutcome.resolve(pickedCount: 2, loaded: loaded) else {
            Issue.record("Expected loadFailed")
            return
        }
    }

    // Photos edited in the Photos app share a file name, and their copies
    // used to delete each other.
    @Test("Media with the same file name keeps both copies")
    func sameFileName() async {
        let loaded = await loadMedia([
            MockMediaItem(fileName: "FullSizeRender.jpeg", content: "first"),
            MockMediaItem(fileName: "FullSizeRender.jpeg", content: "second"),
        ])
        #expect(loaded.count == 2)
        #expect(loaded.map(content) == ["first", "second"])
        #expect(Set(loaded.compactMap { $0["path"] as? String }).count == 2)
    }

    // iOS deletes the loaded file when the handler returns.
    @Test("Media is copied before the system deletes it")
    func copiedBeforeDeletion() async throws {
        let loaded = await loadMedia([
            MockMediaItem(fileName: "a.jpeg", content: "kept", assetIdentifier: "ID/L0/001"),
        ])
        let info = try #require(loaded.first)
        #expect(content(info) == "kept")
        #expect(info["size"] as? Int == 4)
        #expect(info["assetIdentifier"] as? String == "ID/L0/001")
    }

    @Test("A Live Photo is loaded as its original still image")
    func livePhotoRequest() async {
        let item = MockMediaItem(
            fileName: "IMG_1.heic",
            content: "photo",
            registeredTypeIdentifiers: MediaRepresentationTests.livePhotoTypes)
        _ = await loadMedia([item])
        #expect(item.requestedTypes == ["public.heic"])
    }

    // The document picker opens with asCopy, so moving avoids a second copy
    // (#2261).
    @Test("Documents are moved, and missing ones are dropped")
    func documentsMoved() throws {
        let source = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        let report = source.appendingPathComponent("report.pdf")
        try "pdf".write(to: report, atomically: true, encoding: .utf8)
        let missing = source.appendingPathComponent("missing.pdf")

        let loaded = loader.loadDocuments([report, missing])

        #expect(names(loaded) == ["report.pdf"])
        #expect(!FileManager.default.fileExists(atPath: report.path))
        #expect(content(try #require(loaded.first)) == "pdf")
    }

    // A Live Photo may suggest its bundle's ".pvt" name (#2245).
    @Test("An asset reference gets the extension of its original image")
    func assetInfoName() throws {
        let item = MockMediaItem(
            fileName: "",
            content: nil,
            assetIdentifier: "ID/L0/001",
            suggestedName: "IMG_1.pvt",
            registeredTypeIdentifiers: MediaRepresentationTests.livePhotoTypes)

        let info = try #require(loader.assetInfo(for: item, preferringCompatible: false))
        #expect(info["name"] as? String == "IMG_1.heic")
        #expect(info["uri"] as? String == "ph:///ID/L0/001")

        let compatible = try #require(loader.assetInfo(for: item, preferringCompatible: true))
        #expect(compatible["name"] as? String == "IMG_1.jpeg")
    }

    @Test("An item without an asset identifier has no asset reference")
    func assetInfoWithoutIdentifier() {
        let item = MockMediaItem(fileName: "a.jpeg", content: nil, suggestedName: "a.jpeg")
        #expect(loader.assetInfo(for: item, preferringCompatible: false) == nil)
    }
}
