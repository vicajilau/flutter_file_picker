import Foundation

@testable import file_picker_darwin

/// A picked item that loads `content` as `fileName` after `delay`, or fails
/// with `MockMediaItem.loadError` when `content` is `nil`. Like iOS, it
/// deletes the loaded file as soon as the completion handler returns.
final class MockMediaItem: PickedMediaItem {
    let assetIdentifier: String?
    let suggestedName: String?
    let registeredTypeIdentifiers: [String]
    let fileName: String
    let content: String?
    let delay: TimeInterval
    private(set) var requestedTypes: [String] = []

    static let loadError = NSError(domain: NSItemProvider.errorDomain, code: -1000)

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
        completion: @escaping (URL?, Error?) -> Void
    ) {
        requestedTypes.append(typeIdentifier)
        let fileName = fileName
        let content = content
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
            guard let content else {
                completion(nil, Self.loadError)
                return
            }
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            let url = directory.appendingPathComponent(fileName)
            try? FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true)
            try? content.write(to: url, atomically: true, encoding: .utf8)
            completion(url, nil)
            try? FileManager.default.removeItem(at: directory)
        }
    }
}
