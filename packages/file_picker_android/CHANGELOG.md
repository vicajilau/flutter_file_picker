## 2.0.0

- **BREAKING CHANGE**: `PlatformFile.length()` now returns `Future<int?>` instead of `Future<int>`. Returns `null` when the length could not be determined (e.g. a failed disk read), instead of `0`, matching `lengthSync()`. [#2197](https://github.com/vicajilau/flutter_file_picker/issues/2197)

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
