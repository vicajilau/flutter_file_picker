import Foundation
import Testing

@testable import file_picker_darwin

@Suite("PickerTemporaryFiles")
struct PickerTemporaryFilesTests {
    @Test("Repeated exports have separate destinations and preserve the extension")
    func separateExports() {
        let first = PickerTemporaryFiles.uniqueExportURL(fileName: "report.pdf")
        let second = PickerTemporaryFiles.uniqueExportURL(fileName: "report.pdf")
        #expect(first != second)
        #expect(first.lastPathComponent == "report.pdf")
        #expect(first.deletingLastPathComponent().deletingLastPathComponent()
            == PickerTemporaryFiles.root())
    }

    @Test("Export names cannot escape the plugin directory")
    func confinedNames() {
        for name in ["../../report.pdf", "/tmp/report.pdf", "", ".", ".."] {
            let file = PickerTemporaryFiles.uniqueExportURL(fileName: name)
            #expect(file.deletingLastPathComponent().deletingLastPathComponent()
                == PickerTemporaryFiles.root())
            #expect(!file.lastPathComponent.isEmpty)
            #expect(file.lastPathComponent != ".")
            #expect(file.lastPathComponent != "..")
        }
    }

    @Test("Clearing picker files preserves unrelated host temporary files")
    func preservesHostFiles() throws {
        let manager = FileManager.default
        let temporary = manager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try manager.createDirectory(at: temporary, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: temporary) }
        let hostFile = temporary.appendingPathComponent("host.txt")
        try Data([1]).write(to: hostFile)
        let export = PickerTemporaryFiles.uniqueExportURL(fileName: "report.pdf", in: temporary)
        try manager.createDirectory(at: export.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data([2]).write(to: export)

        try PickerTemporaryFiles.clear(in: temporary)
        #expect(manager.fileExists(atPath: hostFile.path))
        #expect(!manager.fileExists(atPath: export.path))
        try PickerTemporaryFiles.clear(in: temporary)
    }

    @Test("Removing an export deletes its directory and nothing else")
    func removesOnlyTheExport() throws {
        let manager = FileManager.default
        let temporary = manager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try manager.createDirectory(at: temporary, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: temporary) }
        let hostFile = temporary.appendingPathComponent("host.txt")
        try Data([1]).write(to: hostFile)
        let kept = PickerTemporaryFiles.uniqueExportURL(fileName: "kept.pdf", in: temporary)
        let removed = PickerTemporaryFiles.uniqueExportURL(fileName: "report.pdf", in: temporary)
        for file in [kept, removed] {
            try manager.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data([2]).write(to: file)
        }

        PickerTemporaryFiles.removeExport(removed, in: temporary)
        #expect(!manager.fileExists(atPath: removed.path))
        #expect(!manager.fileExists(atPath: removed.deletingLastPathComponent().path))
        #expect(manager.fileExists(atPath: kept.path))
        #expect(manager.fileExists(atPath: hostFile.path))

        // A second removal, of a file that is already gone, does nothing.
        PickerTemporaryFiles.removeExport(removed, in: temporary)
    }

    @Test("Removing a file outside the plugin directory does nothing")
    func ignoresOtherFiles() throws {
        let manager = FileManager.default
        let temporary = manager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let other = temporary.appendingPathComponent("other", isDirectory: true)
        try manager.createDirectory(at: other, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: temporary) }
        let file = other.appendingPathComponent("data.txt")
        try Data([1]).write(to: file)

        PickerTemporaryFiles.removeExport(file, in: temporary)
        #expect(manager.fileExists(atPath: file.path))
    }
}
