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
