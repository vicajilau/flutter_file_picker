import Foundation
import Testing

@testable import file_picker_darwin

@Suite("PickLoader")
struct PickLoaderTests {
    let loader = PickLoader(
        temporaryDirectory: FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true))

    func loadMediaWithFailures(
        _ items: [MockMediaItem],
        preferringCompatible: Bool = false
    ) async -> ([[String: Any]], [LoadFailure]) {
        await withCheckedContinuation { continuation in
            loader.loadMedia(
                items,
                preferringCompatible: preferringCompatible,
                queue: .global()
            ) { loaded, failures in
                continuation.resume(returning: (loaded, failures))
            }
        }
    }

    func loadMedia(
        _ items: [MockMediaItem],
        preferringCompatible: Bool = false
    ) async -> [[String: Any]] {
        await loadMediaWithFailures(items, preferringCompatible: preferringCompatible).0
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

    // The errors reach Dart in the load_failed details (#2274).
    @Test("Media that fails to load reports why, with its index")
    func mediaFailures() async {
        let (loaded, failures) = await loadMediaWithFailures([
            MockMediaItem(fileName: "a.jpeg", content: "a"),
            MockMediaItem(fileName: "b.jpeg", content: nil),
            MockMediaItem(fileName: "c.jpeg", content: nil, delay: 0.1),
        ])
        #expect(loaded.count == 1)
        #expect(failures.map(\.index).sorted() == [1, 2])
        #expect(failures.allSatisfy { ($0.error as NSError) == MockMediaItem.loadError })
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

        let (loaded, failures) = loader.moveDocuments([report, missing])

        #expect(names(loaded) == ["report.pdf"])
        #expect(failures.map(\.index) == [1])
        #expect((failures.first?.error as? CocoaError)?.code == .fileNoSuchFile)
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
        #expect(compatible["uri"] as? String == "ph:///ID/L0/001")
    }

    @Test("An item without an asset identifier has no asset reference")
    func assetInfoWithoutIdentifier() {
        let item = MockMediaItem(fileName: "a.jpeg", content: nil, suggestedName: "a.jpeg")
        #expect(loader.assetInfo(for: item, preferringCompatible: false) == nil)
    }
}
