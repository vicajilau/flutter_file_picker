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
