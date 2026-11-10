## 2.1.5

- Fixed `onFileLoading` losing its status updates when a second pick started while one was still open. It now also gets `done` when a pick is cancelled or fails. [#2317](https://github.com/vicajilau/flutter_file_picker/pull/2317)
- Fixed `saveFile()` reporting success when the document provider gave nothing to write to, leaving the file empty. [#2320](https://github.com/vicajilau/flutter_file_picker/pull/2320)
- Fixed `lengthSync()` returning `null` for an empty file, and `length()` reading it again to find its size. [#2313](https://github.com/vicajilau/flutter_file_picker/pull/2313)
- The bytes of a saved file are released when the save ends, instead of staying in memory until the next one. [#2319](https://github.com/vicajilau/flutter_file_picker/pull/2319)

## 2.1.4

- Fixed `allowedExtensions` in upper case, such as `CSV`, missing the `text/csv` filter that Google Drive needs.
- Fixed `saveFile()` not recognizing an upper case extension with an `I`, such as `backup.ZIP`, on devices set to Turkish.

## 2.1.3

- Fixed picks and saves that never completed, leaving every later pick failing with `already_active`, when the picker or the save dialog ended with an unexpected result code, when a save came back without a location, or when a pick had no type. They now fail with `unknown_result` or `invalid_type`.
- Fixed the results of activities started by other plugins failing a pending pick.
- Fixed a `SecurityException` while writing a saved file crashing the app instead of failing the save.
- Fixed `onFileSaving` staying on `picking` when saving fails, and an error of the status stream escaping as an uncaught error.

## 2.1.2

- Fixed `explorer_not_found` on Android 11+ devices that hide the documents picker from apps, such as some Xiaomi HyperOS versions. [#2282](https://github.com/vicajilau/flutter_file_picker/pull/2282)
- The picker now opens directly and only reports `explorer_not_found` when no app can handle it, instead of asking Android first, which can miss apps hidden from the plugin.

## 2.1.1

- Fixed `AndroidSAFOptions` being ignored, so the grant, access mode and persistence they request now apply. [#2257](https://github.com/vicajilau/flutter_file_picker/issues/2257)
- Picking several files now fails with `unknown_path` when none of them can be read, instead of returning an empty list as if the user cancelled. [#2262](https://github.com/vicajilau/flutter_file_picker/issues/2262)

## 2.1.0

- Added `FilePickerAndroid.retrieveLostData()`, to recover the files picked when Android destroys the activity while the picker is open. [#1258](https://github.com/vicajilau/flutter_file_picker/issues/1258)

## 2.0.1

- Fixed `pickFileAndDirectoryPaths()` returning percent-encoded paths that do not exist. [#2225](https://github.com/vicajilau/flutter_file_picker/issues/2225)

## 2.0.0

- **BREAKING CHANGE**: `PlatformFile.length()` now returns `Future<int?>` instead of `Future<int>`. Returns `null` when the length could not be determined (e.g. a failed disk read), instead of `0`, matching `lengthSync()`. [#2197](https://github.com/vicajilau/flutter_file_picker/issues/2197)
- Removed the native code paths behind `withData`, dead since the Dart facade stopped forwarding it (`file_picker` 12.0.0). Picked files are no longer eagerly read into memory on the platform side; `PlatformFile.readAsBytes()` already reads lazily on demand. [#2202](https://github.com/vicajilau/flutter_file_picker/issues/2202)

## 1.1.1

- Fixed `saveFile()` garbling the file name for extensions Android doesn't recognize, e.g. saving `trace.gpx` produced `trace.gpx.xml.gpx`. [#2199](https://github.com/vicajilau/flutter_file_picker/issues/2199)

## 1.1.0

- Implemented `PlatformFile.lengthSync()`, returning the length Android already reports for a picked file synchronously.

## 1.0.4

- Restored the module local `buildscript` classpath (AGP 8.5.2, Kotlin Gradle Plugin 1.8.22) that #2154 removed. It fixed `Unresolved reference compileSdk/namespace/minSdk` on project configurations using AGP 9 with `android.newDsl=false` and custom root level Gradle configuration, reported and confirmed fixed against a real affected project in [#2170](https://github.com/vicajilau/flutter_file_picker/issues/2170).

  This is a temporary workaround, not a permanent fix. Pinning an older AGP via a module's own `buildscript` classpath while the consuming app applies a newer one through the `plugins` block is generally discouraged, and #2154 removed it for exactly that reason. Restoring it papers over a gap in Flutter's own AGP 9 `newDsl` migration, which is still in progress ([flutter/flutter#180137](https://github.com/flutter/flutter/issues/180137)): the interim compatibility shim that lets `android.newDsl=false` projects use AGP 9 does not appear to reliably reach plugin modules that don't declare their own classpath, at least for some custom root level Gradle setups. Remove this block again once that migration lands upstream and `android.newDsl=false` is no longer needed.

## 1.0.3

- Tightened the `file_picker_platform_interface` lower bound to `^3.2.0`. This package's `pickFile()`/`pickFiles()` signatures reference `DarwinOptions`, added in that version, so resolving against an older one would fail to compile.

## 1.0.2

- Removed the stale `buildscript` classpath from the Android module, which pinned AGP 8.5.2 and Kotlin Gradle Plugin 1.8.22 in a module that supports AGP 9 and Kotlin 2.3. [#2154](https://github.com/vicajilau/flutter_file_picker/pull/2154)
- Fixed `allowedExtensions` filters being discarded entirely and falling back to showing all files when only some of the requested extensions had no mime type known to Android (e.g. `pfx`, `p12`). Now the extensions that do resolve to a mime type are still used to filter, and `*/*` is only used when none of them resolve.

## 1.0.1

- Improved package description, added example, and added missing API documentation.

## 1.0.0

- Initial release of Android implementation package for `file_picker`.
- Removed the Apache Tika dependency (~300 KB) used for MIME type detection in `saveFile()`. MIME types are now resolved from the file name extension via `MimeTypeMap`, with `URLConnection.guessContentTypeFromStream` as a content-sniffing fallback when no extension is available. [#2101](https://github.com/vicajilau/flutter_file_picker/issues/2101)
