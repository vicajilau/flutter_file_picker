import Foundation

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
    /// its URL, or with `nil` and the error if it could not be loaded. The
    /// file may be deleted as soon as `completion` returns, and `completion`
    /// may be called on any queue.
    func loadFile(
        forTypeIdentifier typeIdentifier: String,
        completion: @escaping (URL?, Error?) -> Void)
}
