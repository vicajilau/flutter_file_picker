import Foundation

/// Isolates temporary picker files from the host app's own temporary files.
enum PickerTemporaryFiles {
    static let directoryName = "flutter_file_picker"

    static func root(in temporaryDirectory: URL = URL(
        fileURLWithPath: NSTemporaryDirectory(),
        isDirectory: true
    )) -> URL {
        temporaryDirectory.appendingPathComponent(directoryName, isDirectory: true)
    }

    /// Gives each export its own directory, keeping its original extension.
    static func uniqueExportURL(
        fileName: String,
        in temporaryDirectory: URL = URL(
            fileURLWithPath: NSTemporaryDirectory(),
            isDirectory: true
        )
    ) -> URL {
        let safeName = fileName.isEmpty ? "" : URL(fileURLWithPath: fileName).lastPathComponent
        let name = safeName.isEmpty || safeName == "." || safeName == ".."
            ? "document"
            : safeName
        return root(in: temporaryDirectory)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent(name, isDirectory: false)
    }

    /// Removes an export made by `uniqueExportURL`, with the directory that
    /// holds it. The picker exports a copy, so the destination does not need
    /// this file once the request is over.
    ///
    /// Anything outside the plugin directory is left alone.
    static func removeExport(
        _ file: URL,
        in temporaryDirectory: URL = URL(
            fileURLWithPath: NSTemporaryDirectory(),
            isDirectory: true
        )
    ) {
        let directory = file.deletingLastPathComponent()
        guard directory.deletingLastPathComponent().standardizedFileURL
            == root(in: temporaryDirectory).standardizedFileURL
        else { return }
        try? FileManager.default.removeItem(at: directory)
    }

    /// Only remove files created by the picker, never unrelated app temp data.
    static func clear(in temporaryDirectory: URL = URL(
        fileURLWithPath: NSTemporaryDirectory(),
        isDirectory: true
    )) throws {
        let directory = root(in: temporaryDirectory)
        let manager = FileManager.default
        if manager.fileExists(atPath: directory.path) {
            try manager.removeItem(at: directory)
        }
    }
}
