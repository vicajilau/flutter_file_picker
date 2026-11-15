import Foundation
import Testing

@testable import file_picker_darwin

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
