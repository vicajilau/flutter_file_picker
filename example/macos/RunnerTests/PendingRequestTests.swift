import Foundation
import Testing

@testable import file_picker_darwin

@Suite("PendingRequest")
struct PendingRequestTests {
    // A picker swiped away while still appearing can leave without any
    // delegate callback (#2291).
    @Test("A shown picker that is gone without a callback is stale")
    func pickerGone() {
        #expect(PendingRequest.isStale(
            wasPresented: true, isStillPresented: false, isLoadingPickedItems: false))
    }

    @Test("A picker still on screen is not stale")
    func pickerStillShown() {
        #expect(!PendingRequest.isStale(
            wasPresented: true, isStillPresented: true, isLoadingPickedItems: false))
    }

    @Test("A request whose picker is not shown yet is not stale")
    func pickerNotShownYet() {
        #expect(!PendingRequest.isStale(
            wasPresented: false, isStillPresented: false, isLoadingPickedItems: false))
    }

    @Test("A request still loading its picked items is not stale")
    func stillLoading() {
        #expect(!PendingRequest.isStale(
            wasPresented: true, isStillPresented: false, isLoadingPickedItems: true))
    }
}
