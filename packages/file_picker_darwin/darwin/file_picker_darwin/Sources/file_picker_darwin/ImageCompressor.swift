import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Recompresses picked images when the app asks for a `compressionQuality`.
///
/// Kept free of UIKit, AppKit and Flutter so it can be unit tested on its own.
@available(iOS 14.0, macOS 11.0, *)
enum ImageCompressor {
    /// The formats that take a lossy quality. Anything else, such as PNG or
    /// GIF, is left as it is.
    static let lossyTypes: [UTType] = [.jpeg, .heic, .heif]

    /// Rewrites the image at `url` in place with `quality`, from 1 to 100,
    /// keeping its format, its name and its metadata, such as the
    /// orientation and the EXIF data.
    ///
    /// Returns whether the file was rewritten. It is left untouched, and this
    /// returns `false`, when:
    ///
    /// * `quality` is 0, the default, or out of range.
    /// * The file is not a single JPEG or HEIC image, so videos, PNG files,
    ///   animated images and documents are never changed.
    /// * It cannot be encoded, as HEIC on devices without an HEVC encoder.
    /// * The result is not smaller, as with an image that already uses a
    ///   lower quality.
    ///
    /// A failure here is never worth failing the pick over: the app still
    /// gets the image the user chose.
    @discardableResult
    static func compress(_ url: URL, quality: Int) -> Bool {
        guard (1...100).contains(quality),
            let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            CGImageSourceGetCount(source) == 1,
            let typeIdentifier = CGImageSourceGetType(source),
            let type = UTType(typeIdentifier as String),
            lossyTypes.contains(type)
        else {
            return false
        }

        let fileManager = FileManager.default
        // Written next to the original, so replacing it stays on one volume.
        let temporaryURL = url.deletingLastPathComponent()
            .appendingPathComponent(UUID().uuidString)
        defer { try? fileManager.removeItem(at: temporaryURL) }

        guard
            let destination = CGImageDestinationCreateWithURL(
                temporaryURL as CFURL, typeIdentifier, 1, nil)
        else {
            return false
        }
        // Adding the image from its source, instead of from a decoded image,
        // carries its metadata over.
        let options =
            [kCGImageDestinationLossyCompressionQuality: Double(quality) / 100] as CFDictionary
        CGImageDestinationAddImageFromSource(destination, source, 0, options)
        guard CGImageDestinationFinalize(destination) else {
            return false
        }

        guard let originalSize = fileSize(of: url),
            let compressedSize = fileSize(of: temporaryURL),
            compressedSize < originalSize
        else {
            return false
        }

        do {
            _ = try fileManager.replaceItemAt(url, withItemAt: temporaryURL)
            return true
        } catch {
            return false
        }
    }

    private static func fileSize(of url: URL) -> Int? {
        (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
    }
}
