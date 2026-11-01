/// Decides whether a pending pick can be given up when a new one arrives.
///
/// Kept free of UIKit, AppKit and Flutter so it can be unit tested on its own.
enum PendingRequest {
    /// Whether the pending request is stale: its picker was shown and is gone,
    /// and nothing is still loading for it.
    ///
    /// UIKit can dismiss a picker without calling any of its delegate
    /// methods, for example when it is swiped away while still appearing
    /// (#2291). Its request would then stay pending forever and reject every
    /// later one with `multiple_request`.
    ///
    /// A request whose picker has not been shown yet (`wasPresented` is
    /// false), such as `saveFile()` while it writes its temporary file, or
    /// whose picked items are still loading, is not stale.
    static func isStale(
        wasPresented: Bool,
        isStillPresented: Bool,
        isLoadingPickedItems: Bool
    ) -> Bool {
        wasPresented && !isStillPresented && !isLoadingPickedItems
    }
}
