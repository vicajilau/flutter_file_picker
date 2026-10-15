import Foundation
import UniformTypeIdentifiers

/// A photo library item picked by the user, as `PickLoader` needs it.
///
/// `PHPickerResult` provides it on iOS, and tests provide a mock that loads,
/// fails or takes a while for specific items.
protocol PickedMediaItem {
    /// The photo library identifier, when the picker has library access.
    var assetIdentifier: String? { get }
    /// The file name the item suggests, which may lack an extension.
    var suggestedName: String? { get }
    /// The representations the item can be loaded as, in the order it
    /// registered them.
    var registeredTypeIdentifiers: [String] { get }
    /// Loads the item as a file of the given type, calling `completion` with
    /// its URL, or `nil` if it could not be loaded. The file may be deleted
    /// as soon as `completion` returns, and `completion` may be called on any
    /// queue.
    func loadFile(
        forTypeIdentifier typeIdentifier: String,
        completion: @escaping (URL?) -> Void)
}

/// Turns picked items into the file descriptions sent back to Dart.
///
/// Kept free of UIKit, AppKit and Flutter so it can be unit tested on its own.
@available(iOS 14.0, macOS 11.0, *)
struct PickLoader {
    /// Where picked files are stored, each one in its own subdirectory.
    var temporaryDirectory = URL(fileURLWithPath: NSTemporaryDirectory())

    /// Loads and copies each of `items`, then calls `completion` on `queue`
    /// with the ones that loaded, in the order of `items`.
    ///
    /// The items load concurrently and may finish in any order, so the
    /// results are collected by index rather than appended as they arrive.
    func loadMedia(
        _ items: [PickedMediaItem],
        preferringCompatible: Bool,
        queue: DispatchQueue = .main,
        completion: @escaping ([[String: Any]]) -> Void
    ) {
        let group = DispatchGroup()
        var resolved = [[String: Any]?](repeating: nil, count: items.count)
        let resolvedLock = NSLock()

        for (index, item) in items.enumerated() {
            group.enter()
            // Loading the image or video itself, instead of any
            // representation, keeps a Live Photo from bringing its whole
            // bundle, paired video included (#2260).
            let typeIdentifier = MediaRepresentation.typeIdentifier(
                for: item.registeredTypeIdentifiers,
                preferringCompatible: preferringCompatible)
            item.loadFile(forTypeIdentifier: typeIdentifier) { url in
                defer { group.leave() }
                // The file may be deleted when this returns, so it has to be
                // copied.
                guard let url,
                      let copiedURL = store(url, copying: true),
                      var info = fileInfo(for: copiedURL)
                else {
                    return
                }
                if let assetIdentifier = item.assetIdentifier {
                    info["assetIdentifier"] = assetIdentifier
                }
                resolvedLock.lock()
                resolved[index] = info
                resolvedLock.unlock()
            }
        }

        group.notify(queue: queue) {
            completion(resolved.compactMap { $0 })
        }
    }

    /// Moves each of the document picker's `urls` into its own temporary
    /// subdirectory and describes the ones that could be moved.
    ///
    /// The picker opens with `asCopy`, so each file is already a copy the app
    /// owns, and moving it avoids storing it twice (#2261).
    func loadDocuments(_ urls: [URL]) -> [[String: Any]] {
        urls.compactMap { url in
            store(url, copying: false).flatMap(fileInfo(for:))
        }
    }

    /// Describes a picked photo library asset without copying it, by its
    /// `assetIdentifier` and a `ph:///` URI. Returns `nil` for items that do
    /// not come from the photo library and so have no identifier.
    func assetInfo(
        for item: PickedMediaItem,
        preferringCompatible: Bool
    ) -> [String: Any]? {
        guard let assetIdentifier = item.assetIdentifier else {
            return nil
        }

        var name = item.suggestedName ?? assetIdentifier
        // Use the extension of the image or video representation. A Live
        // Photo registers its bundle type first, and its suggested name may
        // already end in that bundle's ".pvt" extension, so replace any
        // extension that is not an image or video one.
        let mediaType = MediaRepresentation.mediaType(
            in: item.registeredTypeIdentifiers,
            preferringCompatible: preferringCompatible)
        let currentExtension = (name as NSString).pathExtension
        let hasMediaExtension = UTType(filenameExtension: currentExtension)
            .map(MediaRepresentation.isMedia) ?? false
        if !hasMediaExtension, let ext = mediaType?.preferredFilenameExtension {
            if !currentExtension.isEmpty {
                name = (name as NSString).deletingPathExtension
            }
            name += ".\(ext)"
        }

        return [
            // Three slashes keep the identifier out of the URI host, which
            // would be lowercased and stop matching the identifier.
            "uri": "ph:///\(assetIdentifier)",
            "name": name,
            "assetIdentifier": assetIdentifier,
        ]
    }

    /// Moves a picked item into its own freshly created subdirectory of
    /// `temporaryDirectory`, or copies it when `copying` is set, for sources
    /// the app does not own.
    ///
    /// The destination used to be `NSTemporaryDirectory()` plus the source's
    /// `lastPathComponent`, which is not unique: two picked assets can share a
    /// file name. Photos edited in the Photos app are exported under a fixed
    /// name, and Live Photos arrive as `.pvt` packages. These copies also run
    /// concurrently, because `loadFileRepresentation` calls its completion
    /// handler on an arbitrary queue, once per selected item. Colliding names
    /// therefore raced:
    ///
    ///     A: fileExists? no  -> starts copying to /tmp/NAME
    ///     B: fileExists? yes -> removes /tmp/NAME, deleting A's in-flight copy
    ///     A: copyItem throws -> returns nil
    ///     B: copyItem throws -> returns nil
    ///
    /// Both items are then dropped by the `compactMap` over `resolved`, and
    /// when every item loses the race the picker calls back with `nil`, which
    /// reaches Dart as an empty list. That is indistinguishable from the user
    /// cancelling, so the failure is silent.
    ///
    /// Giving each item its own directory removes the shared destination, so
    /// the copies can no longer observe or delete each other. The existence
    /// check is gone with it, the directory is new every time.
    func store(_ sourceURL: URL, copying: Bool) -> URL? {
        let directoryURL = temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let destinationURL = directoryURL
            .appendingPathComponent(sourceURL.lastPathComponent)

        do {
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )
            if copying {
                try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            } else {
                try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
            }
            return destinationURL
        } catch {
            return nil
        }
    }

    /// Describes a stored file for Dart.
    func fileInfo(for fileURL: URL) -> [String: Any]? {
        do {
            let values = try fileURL.resourceValues(forKeys: [.fileSizeKey])
            let size = values.fileSize ?? 0

            return [
                "path": fileURL.path,
                "identifier": fileURL.absoluteString,
                "name": fileURL.lastPathComponent,
                "size": size,
            ]
        } catch {
            return nil
        }
    }
}
