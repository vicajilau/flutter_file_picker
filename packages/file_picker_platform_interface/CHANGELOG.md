## 3.4.0

- Added `acceptLabel` to `WindowsOptions` and `DarwinOptions`, letting callers set the confirm button text of the file dialog. On Windows it applies to `pickFile()`, `pickFiles()`, `getDirectoryPath()`, and `saveFile()`; on macOS only to `pickFile()`/`pickFiles()` (`getDirectoryPath()`/`saveFile()` do not accept `DarwinOptions`). Has no effect on iOS, Android or Web. [#1861](https://github.com/vicajilau/flutter_file_picker/issues/1861)

## 3.3.0

- Added `PlatformFile.lengthSync()`, a nullable `int` returning the file's length in bytes as provided by the underlying file picker result, or `null` when it did not report one. Named to pair with the existing `length()`, the same way `dart:io`'s `File` does.

## 3.2.0

- Added `FilePickerPlatform.skipEntitlementsChecks()`, a no-op default hook that platform implementations can override. Lets `file_picker` dispatch through the platform interface instead of importing `file_picker_darwin` directly, which kept the facade package from being wasm compatible.
- Added `DarwinOptions` and `DarwinAssetRepresentationMode`, letting callers request a specific asset representation (`current` or `compatible`) for media selected from the iOS photo library, instead of always using the system default (`automatic`). Restores functionality that was available before the Darwin implementation was rewritten (previously exposed as a way to disable compression), useful to avoid expensive transcoding for large HEVC, HDR, or slow-motion videos.

## 3.1.0

- Added `PlatformFile.extension`, restoring the pre-12.0 convenience getter that was dropped during the federated rewrite. Returns the file extension of `name` without the leading dot, or `null` if there is none.

## 3.0.1

- Improved package description, added example, and added missing API documentation.

## 3.0.0

* Unified platform interface release for federated `file_picker` architecture.

## 2.0.0

* Deprecates interface in favor of standalone `file_picker` for all platforms.

## 1.3.1

* Removes `allowCompression` from interface as it should only be used from `file_picker` (Android & iOS).

## 1.3.0

* Adds `allowCompression` parameter.

## 1.2.0

* Adds `FilePickerStatus`.

## 1.1.0

* Implements `getDirectoryPath()`.

## 1.0.0

* Implements `getFiles()`.

## 0.0.3

* Removes `getFilePath()`.

## 0.0.2

* Updates methods from File Picker interface.

## 0.0.1

* Added File Picker platform interface.