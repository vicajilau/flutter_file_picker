## 2.0.0

- **BREAKING CHANGE**: `PlatformFile.length()` now returns `Future<int?>` instead of `Future<int>`. Returns `null` when the length could not be determined (e.g. a failed disk read), instead of `0`, matching `lengthSync()`. [#2197](https://github.com/vicajilau/flutter_file_picker/issues/2197)
- Removed the native code path behind `withData` on iOS, dead since the Dart facade stopped forwarding it (`file_picker` 12.0.0). Picked files are no longer eagerly read into memory on the platform side; `PlatformFile.readAsBytes()` already reads lazily on demand. [#2202](https://github.com/vicajilau/flutter_file_picker/issues/2202)

## 1.2.0

- Added `DarwinOptions.acceptLabel`, letting callers set the confirm button text (`NSOpenPanel.prompt`) on macOS for `pickFile()`/`pickFiles()`. Has no effect on iOS, `UIDocumentPickerViewController` has no equivalent there. [#1861](https://github.com/vicajilau/flutter_file_picker/issues/1861)

## 1.1.0

- Implemented `PlatformFile.lengthSync()`, returning the length iOS/macOS already reports for a picked file synchronously, without doing any I/O.

## 1.0.4

- `skipEntitlementsChecks()` now overrides the new `FilePickerPlatform.skipEntitlementsChecks()` hook instead of being called through a type test on `FilePickerPlatform.instance`. No behavior change on iOS or macOS.
- Added `DarwinOptions.assetRepresentationMode` support on iOS, mapped to `PHPickerConfiguration.preferredAssetRepresentationMode`. Requesting `current` or `compatible` lets large HEVC, HDR, or slow-motion videos skip the transcoding `automatic` (the default) would otherwise require. Non-automatic modes require `compressionQuality` to be `0`.

## 1.0.3

- Fixed a regression where `PrivacyInfo.xcprivacy` was never being bundled by Swift Package Manager, because SwiftPM resolves resource paths relative to the target's own directory. [#2175](https://github.com/vicajilau/flutter_file_picker/issues/2175)

## 1.0.2

- Fixed a crash (`FileSystemException`/`OSError: Is a directory`) when picking a Live Photo from the iOS gallery. Live Photos are saved by iOS as `.pvt` packages (directories), which `loadFileRepresentation(forTypeIdentifier: UTType.item...)` returned as-is; the still image contained in the package is now extracted instead.
- Fixed `getDirectoryPath`, `pickFiles`, `pickFileAndDirectoryPaths`, and `saveFile` on macOS defaulting to the sandbox container's `Data` folder instead of the user's real home directory when no `initialDirectory` is provided and the app has App Sandbox enabled.
- Fixed the Save dialog on macOS auto-selecting the file extension along with the rest of the file name, making it easy to accidentally delete the extension when renaming. The extension is now hidden by default via `NSSavePanel.isExtensionHidden`.
- Fixed bundle-like directories (e.g. `.app`, `.fcpbundle`) not being selectable as files on macOS file pickers, a regression since 8.2.0. `NSOpenPanel.treatsFilePackagesAsDirectories` is now explicitly set to `false` so these are presented as selectable files, matching Finder and other native apps.
- Fixed `saveFile` on macOS never enforcing an extension on the destination file when the user cleared it from the suggested name. `allowedExtensions` is not forwarded to `saveFile` yet, so the dialog now falls back to the extension of the suggested file name.
- Fixed `saveFile` returning a scheme-less, percent-encoded `Uri` on macOS instead of a proper `file://` Uri, unlike Windows and Linux.
- Added `FilePickerDarwin.skipEntitlementsChecks()`, letting non-sandboxed macOS apps opt out of the App Sandbox entitlement checks performed before showing a dialog. This was previously only reachable through a deprecated, no-op method on `FilePicker` in the root package.
- Fixed a brief UI freeze on macOS right when calling `pickFiles`, `pickFileAndDirectoryPaths`, `getDirectoryPath`, or `saveFile`. The entitlement check now runs on a background queue before the dialog is created, instead of blocking the main thread synchronously.

## 1.0.1

- Fixed `pickFileAndDirectoryPaths` never returning directories on iOS and macOS. It now calls the native combined file and directory picker instead of silently falling back to file only selection.
- Fixed `MissingPluginException` on macOS by registering the event channel stream handler.
- Fixed method channel handling on macOS to support all file types and actions (`any`, `image`, `video`, `audio`, `media`, `custom`, `dir`, `save`).
- Fixed `saveFile` on macOS not writing the provided file `bytes` to the chosen location.
- Added safe argument unwrapping in macOS handler to prevent runtime crashes when arguments are null.
- Added native `UTType` file type filtering for macOS file dialogs.
- Improved package description, added example, and added missing API documentation.

## 1.0.0

- Initial release of iOS and macOS implementation package for `file_picker`.
