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
}
