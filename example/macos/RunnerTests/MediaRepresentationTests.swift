import Foundation
import Testing

@testable import file_picker_darwin

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
