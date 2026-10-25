import Foundation

/// Why one picked item could not be loaded, sent in the `details` of the
/// `load_failed` error.
///
/// One description covers causes an app would handle differently. A photo
/// library item that fails with "Cannot load representation of type
/// public.movie" may be on a device with no space left for the copy, or be
/// stored only in iCloud while the device is offline. The error's domain and
/// code, and those of the errors underneath it, are what can tell them apart.
///
/// Kept free of UIKit, AppKit and Flutter so it can be unit tested on its own.
struct LoadFailure {
    /// The position of the item among the picked items.
    let index: Int
    let error: Error

    /// How many underlying errors `details` follows, so a cyclic or very deep
    /// chain cannot grow it without bound.
    static let maxUnderlyingDepth = 4

    /// The failure as a map the method channel can carry: `index`, and the
    /// error's `domain`, `code` and `message`. When the error wraps another one,
    /// `underlying` lists the chain of `NSUnderlyingErrorKey` errors, outermost
    /// first, each with its own `domain`, `code` and `message`.
    var details: [String: Any] {
        var details = Self.describe(error as NSError)
        details["index"] = index

        var underlying: [[String: Any]] = []
        var next = (error as NSError).userInfo[NSUnderlyingErrorKey] as? NSError
        while let current = next, underlying.count < Self.maxUnderlyingDepth {
            underlying.append(Self.describe(current))
            next = current.userInfo[NSUnderlyingErrorKey] as? NSError
        }
        if !underlying.isEmpty {
            details["underlying"] = underlying
        }
        return details
    }

    private static func describe(_ error: NSError) -> [String: Any] {
        [
            "domain": error.domain,
            "code": error.code,
            "message": error.localizedDescription,
        ]
    }
}
