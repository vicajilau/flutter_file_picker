## 13.1.0

- Added support for UIScene on iOS.

## 13.0.0

### General

- **BREAKING CHANGE**: `PlatformFile.length()` now returns `Future<int?>` instead of `Future<int>`, matching `lengthSync()`. `null` means the length could not be determined (e.g. a failed disk read), distinct from a genuinely empty file, which still returns `0`. Previously both cases returned `0`, with no way to tell them apart. [#2197](https://github.com/vicajilau/flutter_file_picker/issues/2197)
- **BREAKING CHANGE**: Removed the parameters deprecated since the 12.0.0 federated rewrite: `allowMultiple` and `withData`/`withReadStream`/`readSequential` on `pickFiles()`, `lockParentWindow` on `pickFiles()`/`pickFile()`/`getDirectoryPath()`/`saveFile()`, `cancelUploadOnWindowBlur` on `pickFiles()`/`pickFile()`, and `androidSafOptions` on `pickFiles()`/`pickFile()`/`getDirectoryPath()`. Use `pickFile()` for single-file selection, `PlatformFile.readAsBytes()`/`readAsByteStream()` to read file data, `WindowsOptions.lockParentWindow`/`LinuxOptions.lockParentWindow`, `WebOptions.cancelUploadOnWindowBlur`, and `androidOptions` respectively. [#2202](https://github.com/vicajilau/flutter_file_picker/issues/2202)
- Raised lower bounds of all platform implementation packages: `file_picker_platform_interface ^4.0.0`, `android_file_picker ^2.0.0`, `file_picker_darwin ^2.0.0`, `file_picker_linux ^2.0.0`, `windows_file_picker ^2.0.0`, and `file_picker_web ^4.0.0`.

### Web

- Fixed `FilePickerWebOptions.readSequential` having no effect (`file_picker_web 4.0.0`). [#2206](https://github.com/vicajilau/flutter_file_picker/issues/2206)

### Android & iOS

- Removed the dead native code paths behind `withData` (`android_file_picker 2.0.0`, `file_picker_darwin 2.0.0`). [#2202](https://github.com/vicajilau/flutter_file_picker/issues/2202)

## 12.3.0

### Desktop (Windows)

- Added `WindowsOptions.acceptLabel`, letting callers set the confirm ("OK") button text on `pickFile()`, `pickFiles()`, `getDirectoryPath()`, and `saveFile()` dialogs. [#1861](https://github.com/vicajilau/flutter_file_picker/issues/1861)

### macOS

- Added `DarwinOptions.acceptLabel`, letting callers set the confirm button text for `pickFile()`/`pickFiles()` (`NSOpenPanel.prompt`). Has no effect on iOS. [#1861](https://github.com/vicajilau/flutter_file_picker/issues/1861)

## 12.2.0

### General

- Added `PlatformFile.lengthSync()`, replacing the `size` property removed in 12.0. It returns the length the native picker already reported, without any I/O, or `null` when the platform did not report one, in which case `length()` still reads it from disk. [#2187](https://github.com/vicajilau/flutter_file_picker/issues/2187)
- Raised the lower bounds on the platform implementations and the platform interface together. `PlatformFile.lengthSync()` is abstract, so an implementation published before it does not satisfy the new interface, and leaving the old bounds would let pub resolve a combination that compiles nowhere.

## 12.1.3

### General

- Raised the lower bounds on the platform implementations to the first versions built against `file_picker_platform_interface` 3.2.0. The facade already required `^3.2.0` for the interface itself, but still allowed implementations predating the `DarwinOptions` parameter added there, so pub could legally resolve a combination that does not compile. [#2186](https://github.com/vicajilau/flutter_file_picker/issues/2186)

## 12.1.2

### General

- Stopped importing `file_picker_darwin` directly from the facade package. `skipEntitlementsChecks()` now dispatches through the new `FilePickerPlatform.skipEntitlementsChecks()` hook instead of a type test on `FilePickerPlatform.instance`. That import pulled `dart:io` into `file_picker`'s import graph, making the package incompatible with wasm and breaking analysis when resolved against the lowest allowed dependency versions. No behavior change on any platform.

### iOS

- Added `darwinOptions` (`DarwinOptions`) to `pickFile()`/`pickFiles()`, letting callers set `DarwinAssetRepresentationMode` to request the photo library return media in its `current` or a `compatible` representation instead of always transcoding to the system default (`automatic`). Restores a way to avoid expensive transcoding for large HEVC, HDR, or slow-motion videos, which existed before the Darwin implementation was rewritten. Non-automatic modes require `compressionQuality: 0`, mixing the two throws an `ArgumentError`.

## 12.1.1

### macOS

- Fixed `FilePicker.skipEntitlementsChecks()` being a permanent no-op. It now delegates to `FilePickerDarwin.skipEntitlementsChecks()` when running on macOS, so non-sandboxed apps can actually skip the App Sandbox entitlement checks again.

## 12.1.0

### General

- Added `PlatformFile.extension`, restoring the pre-12.0 convenience getter that was dropped during the federated rewrite. Returns the file extension of `name` without the leading dot, or `null` if there is none.

### iOS

- Fixed a crash (`FileSystemException`/`OSError: Is a directory`) when picking a Live Photo from the gallery. Live Photos are saved by iOS as `.pvt` packages (directories); the still image contained in the package is now extracted instead of returning the package itself.

## 12.0.0

### Breaking Changes

- **Minimum Requirements:** Raised minimum supported versions to Flutter `3.38` / Dart `3.10`.
- **iOS Target:** Raised minimum supported iOS deployment target to `14.0`. Removed `DKImagePickerController` / `DKPhotoGallery` dependency chain.
- **API Modifications:**
  - `saveFile()`: `fileName` and `bytes` are now required parameters across all platforms.
  - Removed `FilePickerResult`. `pickFiles()` now returns `Future<List<PlatformFile>>` directly (an empty list instead of `null`, no `.files`/`.count`/`.isSinglePick` wrapper), and `pickFile()` returns `Future<PlatformFile?>` for a single selection.
  - `pickFiles()`: `allowMultiple` now defaults to `true`. Use `pickFile()` for single file selection (`allowMultiple` is deprecated).
  - Deprecated `withData`, `withReadStream`, and `readSequential` on `pickFiles()`/`pickFile()` in favor of `PlatformFile.readAsBytes()` and `PlatformFile.readAsByteStream()`.
  - Deprecated top-level `lockParentWindow` and `cancelUploadOnWindowBlur` parameters in favor of platform-specific option classes (`WindowsOptions`, `LinuxOptions`, `WebOptions`).

### Architecture

- **Federated Plugin:** Refactored `file_picker` into a federated architecture with dedicated platform implementation packages (`file_picker_platform_interface`, `android_file_picker`, `file_picker_darwin`, `file_picker_linux`, `windows_file_picker`, and `file_picker_web`).

### Features & Enhancements

- **New API:** Added `pickFile()` static method as a convenience wrapper for single file selection.
- **Platform Options:** Introduced `WindowsOptions`, `LinuxOptions` (with `acceptLabel` and `parentWindow`), and `WebOptions`.
- **Android:** Added support for Storage Access Framework (SAF) Persistable URI Grants (`AndroidSAFOptions`, `AndroidSAFHandle`, `AndroidPlatformFile`). Optimized image compression to prevent `OutOfMemoryError`.
- **iOS & macOS:** Unified native implementations into shared Darwin sources. Selection order is now preserved when picking multiple files on iOS.
- **Exception Handling:** Exported `IllegalCharacterInFileNameException` in `file_picker.dart`.

## 12.0.0-beta.8

### General

- Exported `IllegalCharacterInFileNameException` in `file_picker.dart` so exception handling can be performed by callers. [#2077](https://github.com/vicajilau/flutter_file_picker/pull/2077)

### Android

- Decodes images with `inSampleSize` in `compressImage` to prevent excessive memory usage and `OutOfMemoryError` on large images. [#2083](https://github.com/vicajilau/flutter_file_picker/pull/2083)

### Desktop & Web

- Added `WindowsOptions` (with `parentWindowHandle` and `lockParentWindow`), `LinuxOptions` (with `parentWindow` and `lockParentWindow`), and `WebOptions` (with `cancelUploadOnWindowBlur`). [#2079](https://github.com/vicajilau/flutter_file_picker/pull/2079)
- `LinuxOptions.parentWindow` automatically formats raw decimal and hex X11 window IDs as `x11:0x...`, while preserving Wayland handle strings.
- Deprecated top-level `lockParentWindow` parameter in favor of `WindowsOptions.lockParentWindow` and `LinuxOptions.lockParentWindow`.
- Deprecated top-level `cancelUploadOnWindowBlur` parameter in favor of `WebOptions.cancelUploadOnWindowBlur`.

### macOS

- Passes the custom `dialogTitle` when selecting a directory via `getDirectoryPath()`. [#2087](https://github.com/vicajilau/flutter_file_picker/pull/2087)

## 12.0.0-beta.7

### Web

- Ensures `XFile.fromData` is only used on the web if bytes is not null, preventing potential null check errors.

## 12.0.0-beta.6

### General

- Improved `PlatformFile.readAsBytes()` so picked files can be read even when `withData` was not used and the file only has a local `path` or a stream source.
- `FileType.custom` now shares a consistent `allowedExtensions` validation across platforms, throwing `ArgumentError` when filters are missing or used with a non-custom file type.
- The `ffi`, `win32`, and `flutter_lints` dependencies have been updated.

### Android

- Prevents unresolved references when extracting hashCode under a forced JVM version. [#2070](https://github.com/vicajilau/flutter_file_picker/issues/2070)

## 12.0.0-beta.5

### Android

- `saveFile` now writes file data using Kotlin Coroutines (`CoroutineScope(Dispatchers.IO).launch`), keeping all I/O off the main thread and preventing UI freezes.

### iOS

- Fixed a race condition when dismissing the file picker with a fast swipe, preventing the picker from getting stuck in a `multiple_request` state until app restart. [#2021](https://github.com/vicajilau/flutter_file_picker/issues/2021)
- iOS now preserves the selection order when picking multiple files: the list of returned files will match the order in which the user selected them.
- `saveFile` now performs file writing on a background thread (`DispatchQueue.global`), preventing UI freezes when saving large files.

### Web

- Fixed `PlatformFile.readAsBytes()` so files picked on Web can recover data from `blob:` and `data:` URLs when `withData` was not used.
- Added Web fallback to stream file bytes from `blob:`/`data:` URLs: when the `ReadableStream` API is supported.

## 12.0.0-beta.4

### General

- Added `pickFile()` static method as a convenience wrapper for single file selection, returning `PlatformFile?` directly. [#1469](https://github.com/vicajilau/flutter_file_picker/issues/1469)
- **BREAKING CHANGE**: Refactored `saveFile()` to make `fileName` and `bytes` required parameters across all platforms for a more consistent API. Improved the method's documentation for better clarity.
- Improved documentation for `PlatformFile` properties (`path`, `bytes`, `readStream`) to clarify nullability and usage across platforms. [#1469](https://github.com/vicajilau/flutter_file_picker/issues/1469)
- **BREAKING CHANGE**: The `allowMultiple` parameter on `pickFiles()` now defaults to `true`. Use `pickFile()` for single-file selection. (`allowMultiple` is deprecated and will be removed in a future release.)
- Deprecated `withData`, `withReadStream`, and `readSequential` on `pickFiles()`/`pickFile()`. Users should call `PlatformFile.readAsBytes()` or `PlatformFile.readAsByteStream()` to load file data on demand. These parameters will be removed in a future release.
- Improved `PlatformFile.toString()` output to display byte length instead of full content.

### Android

- Fixed an issue where `FileType.any` would prevent subdirectories from being listed in the system file explorer by ensuring `EXTRA_MIME_TYPES` is correctly passed as an array. [#2013](https://github.com/vicajilau/flutter_file_picker/issues/2013)
- Removed explicit Kotlin Gradle Plugin (KGP) application and dependencies from build files to resolve warnings under AGP 9.0+.
- Updated Android build tooling and dependencies: Android Gradle Plugin bumped to `8.5.2`, `androidx.core:core` and `androidx.core:core-ktx` updated to `1.18.0`, `androidx.lifecycle:lifecycle-runtime` updated to `2.10.0`, and `org.apache.tika:tika-core` updated to `3.3.0`.
- Migrated Android build files from Groovy to Kotlin DSL (`build.gradle.kts`, `settings.gradle.kts`).
- Added Android AGP compatibility CI workflow.

### Darwin

- Added missing `FlutterFramework` dependency to `Package.swift` for Swift Package Manager (SPM) compatibility.

## 12.0.0-beta.3

### General

- Added `onFileLoading` callback to `saveFile` and implemented status tracking via an event channel. `saveFile` now reports loading status (for example `FilePickerStatus.loading` and `FilePickerStatus.done`).
- Offloaded file saving (writing bytes) to a background isolate to avoid blocking the UI when saving large files.
- Ensured the event subscription used for loading status is always cancelled in a `finally` block to prevent leaks and spurious events.

### Android

- Fixed Android plugin registration when using AGP 9+ with `android.builtInKotlin=false`, while preserving support for older AGP setups.

## 12.0.0-beta.2

### General

- Updated dependencies: `flutter_plugin_android_lifecycle` to `2.0.34`, `path` to `1.9.1`, `win32` to `6.2.0`, `cross_file` to `0.3.5+2`, `web` to `1.1.1`, and `dbus` to `0.7.12`.

### Android

- Added a controlled `out_of_memory` error when picking large files with `withData`, avoiding Android crashes and recommending `withReadStream` as a safer alternative for large or multiple selections. [#1997](https://github.com/vicajilau/flutter_file_picker/issues/1997)
**Breaking Change**: `FileType.image` now opens the native image gallery instead of the document picker, ignoring `allowedExtensions` on Android. [#2004](https://github.com/vicajilau/flutter_file_picker/pull/2004)

## 12.0.0-beta.1

### General

- Raised the minimum supported Flutter/Dart version to Flutter 3.38 / Dart 3.10 across all platforms. [#1980](https://github.com/vicajilau/flutter_file_picker/issues/1980)

### Windows

- Migrated `win32` dependency to `6.0.0` and updated the Windows file picker implementation to match the new Win32/COM APIs. [#1980](https://github.com/vicajilau/flutter_file_picker/issues/1980)

### Darwin

- Migrated the iOS and macOS native implementations to shared Darwin sources.
- **BREAKING CHANGE**: The minimum supported iOS deployment target is now 14.0.
- Removed the DKImagePickerController / DKPhotoGallery dependency chain from the Darwin iOS path.

### Android

- Implemented support for Android Storage Access Framework (SAF) Persistable URI Grants, allowing long-term access to files and directories across device reboots. [#1825](https://github.com/vicajilau/flutter_file_picker/issues/1825) [#721](https://github.com/vicajilau/flutter_file_picker/issues/721)
- Added `AndroidSAFOptions` and `AndroidSAFHandle` to configure and manage persistent permissions.
- Introduced `AndroidPlatformFile` as a subclass of `PlatformFile` to encapsulate SAF-specific metadata.
- Updated the Android Gradle Wrapper to `8.7` to ensure compatibility with Android Gradle Plugin (AGP) `8.5.1`.
- Improved `saveFile` naming behavior when a duplicate file exists, normalizing duplicate names to keep the extension suffix (for example, `file (1).bak` instead of `file.bak (1)`). [#1947](https://github.com/vicajilau/flutter_file_picker/issues/1947)

### Web

- Fixed `pickFiles()` default `withData` behavior in the public API to correctly default to `true` on web when not explicitly provided. [#1987](https://github.com/vicajilau/flutter_file_picker/issues/1987)

## 11.0.3

### Android

- Removed the Apache Tika dependency (~300 KB) used for MIME type detection in `saveFile()`. MIME types are now resolved from the file name extension via `MimeTypeMap`, with `URLConnection.guessContentTypeFromStream` as a content-sniffing fallback when no extension is available. [#2101](https://github.com/vicajilau/flutter_file_picker/issues/2101)

## 11.0.2

### Android

- Fixed a Path Traversal vulnerability (CWE-22) when resolving file paths from external content providers. [#1967](https://github.com/vicajilau/flutter_file_picker/issues/1967)

### Linux

- Fixed "Cannot add to a fixed-length list" crash when opening or saving files with an initial directory on Linux. [#1976](https://github.com/vicajilau/flutter_file_picker/issues/1976)

## 11.0.1

### Android

- Fixed backward compatibility with Android Gradle Plugin (AGP) versions below 9.0. [#1973](https://github.com/vicajilau/flutter_file_picker/issues/1973)

## 11.0.0

### General

- **BREAKING CHANGE**: Refactored `FilePicker` class to use `static` methods instead of an instance-based approach. Users should now call `FilePicker.pickFiles()`, `FilePicker.getDirectoryPath()`, and `FilePicker.saveFile()` directly.
- Added `cancelUploadOnWindowBlur` to the public `pickFiles` API (Web only). [#1961](https://github.com/vicajilau/flutter_file_picker/issues/1961)
- Reordered and cleaned up exports in `file_picker.dart`.

### Web

- Added WASM support for the web file picker. [#1950](https://github.com/vicajilau/flutter_file_picker/pull/1950)

### Android

- Fixed an issue where file type selection (`audio`, `video`, `media`) was not being considered correctly on Android. [#1959](https://github.com/vicajilau/flutter_file_picker/pull/1959)
- Updated Android package to support AGP 9. [#1942](https://github.com/vicajilau/flutter_file_picker/issues/1942)

### Desktop (macOS)

- Added a new method, `skipEntitlementsChecks()`, to allow users to bypass entitlements checks on macOS when using the plugin without Sandbox enabled. [#1845](https://github.com/vicajilau/flutter_file_picker/issues/1845)

## 10.3.11

### Linux

- Fixed a crash when initialDirectory contains special characters [#1963](https://github.com/vicajilau/flutter_file_picker/pull/1963)

## 10.3.10

### General

- Reverted breaking changes accidentally introduced in 10.3.9 to maintain Semantic Versioning compliance.

### Android

- Updated Tika library to resolve vulnerability CVE-2025-66516 and CVE-2025-54988 (Critical XXE vulnerability).

## 10.3.9

### Android

- Updated Apache Tika to 3.2.3 to address CVE-2025-66516 and CVE-2025-54988 (Critical XXE vulnerability).
- Support Gradle 9

## 10.3.8

### iOS

- Rename FileUtils to FilePickerUtils [#1921](https://github.com/vicajilau/flutter_file_picker/issues/1921)

### Android

- Restores the ms[df] URI handling logic in FileUtils.kt to fix file selection returning null on some devices.

## 10.3.7

### Android

- Fixed an issue where file type filtering was not being applied correctly, now only displaying files that match the selected MIME types. [#1906](https://github.com/vicajilau/flutter_file_picker/pull/1906)

## 10.3.6

### Android

- Added support for 16 KB page sizes. [#1888](https://github.com/vicajilau/flutter_file_picker/issues/1888)

## 10.3.5

### iOS

- Fixed an error when loading large files (>= 2GB~).

## 10.3.4

### Android

- Detect HEIC and HEIF extensions as valid image
- Use compression format based file extension when compressing images.

## 10.3.3

### Android

- Updated compileSdk to use flutter.compileSdkVersion. [#1842](https://github.com/vicajilau/flutter_file_picker/issues/1842)

### Linux

- Fixed an issue where initialDirectory was not working. [#1878](https://github.com/vicajilau/flutter_file_picker/issues/1878)

## 10.3.2

### Linux

- Fixed an issue filtering files by extension on Linux. [#1870](https://github.com/vicajilau/flutter_file_picker/pull/1870) [@Decodetalkers](https://github.com/Decodetalkers)

## 10.3.1

### General

- Fixed onFileLoading handler to process status changes only when data is a bool.

## 10.3.0

### Desktop

- Support xdg desktop portal filechooser on linux. [#1827](https://github.com/vicajilau/flutter_file_picker/issues/1827) [@Decodetalkers](https://github.com/Decodetalkers)

### Android

- Fixed an issue where CSV files were not properly filtered during file selection. [#1849](https://github.com/vicajilau/flutter_file_picker/pull/1849) [@SoftWyer](https://github.com/SoftWyer)

### Web

- Introduced bool flag to control upload behavior on window blur. [#1833](https://github.com/vicajilau/flutter_file_picker/issues/1833) [@mugglmenzel](https://github.com/mugglmenzel)

## 10.2.4

### Android

- Fixed an issue where custom MIME types were failing to load picking files on Chromebook. [#1858](https://github.com/vicajilau/flutter_file_picker/issues/1858) [@vicajilau](https://github.com/vicajilau)

## 10.2.3

### General

- Fixed build failures on Flutter 3.24 caused by changes to address Win32 deprecation warnings on Windows. [#1855](https://github.com/vicajilau/flutter_file_picker/issues/1855) [@vicajilau](https://github.com/vicajilau)

## 10.2.2

### Android

- Fixed an issue where some files would incorrectly append a `.txt` extension when saving files on Android. [@vicajilau](https://github.com/vicajilau)

## 10.2.1

### Android

- Fixed an issue where the image upload would not display the loading indicator.

## 10.2.0

### Desktop

- Added support for webp images on Desktop platforms. [#1491](https://github.com/vicajilau/flutter_file_picker/issues/1491)

### Android

- Fixed an issue where saving files was failing with some MimeTypes [#1789](https://github.com/vicajilau/flutter_file_picker/issues/1789), [#1818](https://github.com/vicajilau/flutter_file_picker/issues/1818), [#1819](https://github.com/vicajilau/flutter_file_picker/issues/1819) and [#1820](https://github.com/vicajilau/flutter_file_picker/issues/1820)

## 10.1.9

### Android

- Fixed an issue when a folder is selected on an external storage [#1801](https://github.com/vicajilau/flutter_file_picker/issues/1801)

## 10.1.8

### Android

- Fixed an issue when a folder is selected [#1802](https://github.com/vicajilau/flutter_file_picker/issues/1802)

## 10.1.7

### Web

- Fixed a memory leak on the web.

## 10.1.6

### Android

- Fixed an issue when you try to select more than one file[#1796](https://github.com/vicajilau/flutter_file_picker/issues/1796)
- Fixed the app not filter correctly for the selected file types [#1792](https://github.com/vicajilau/flutter_file_picker/issues/1792)

## 10.1.5

### iOS

- Fixed an app crash when calling `.saveFile` twice and cancelling the native save operation via the UI [#1626](https://github.com/vicajilau/flutter_file_picker/issues/1626) [@Leapward-Koex](https://github.com/Leapward-Koex)
- Fixed a `.saveFile` future never completing when `.saveFile` is called twice without waiting for the first completion. [@Leapward-Koex](https://github.com/Leapward-Koex)

## 10.1.4

### Android

- Fixed an issue where paths were loaded with duplicated endings. [#1767](https://github.com/vicajilau/flutter_file_picker/pull/1767)

## 10.1.3

### Android

- Fixed an issue loading files. [#1777](https://github.com/vicajilau/flutter_file_picker/pull/1777)

## 10.1.2

### Android

- Improved mimetype detection. [@vicajilau](https://github.com/vicajilau)

## 10.1.1

### Android

- Migrated Android code base from Java to Kotlin.
- Fixed an issue where compressed images were always saved as JPEG files. [#1738](https://github.com/vicajilau/flutter_file_picker/pull/1753)[@vicajilau](https://github.com/vicajilau)
- Fixed an issue where files without extension were not saved properly. [@vicajilau](https://github.com/vicajilau)

### iOS

- Fixed an issue where `compressionQuality` on iOS was not loaded properly. [#1761](https://github.com/vicajilau/flutter_file_picker/pull/1761)

## 10.1.0

### Desktop (macOS)

- Introduced a new method, `pickFileAndDirectoryPaths()`, which displays a dialog enabling users to select both files and directories simultaneously. The method returns their absolute paths. Only available for macOS.

## 10.0.0

### General

- **BREAKING CHANGE:** The `compressionQuality` property in the `pickFiles` method now defaults to `0`.
- **BREAKING CHANGE:** The `allowCompression` property has been deprecated in favor of `compressionQuality`, and now defaults to `false`.

### Android

- Fixed a permission denied exception on Android 11 or lower when `compressionQuality` is not `0`. ([#1742](https://github.com/vicajilau/flutter_file_picker/issues/1742)). [@vicajilau](https://github.com/vicajilau)
- Fixed an issue where images were duplicated to the "Pictures" folder on Android. ([#1743](https://github.com/vicajilau/flutter_file_picker/issues/1743)) [@vicajilau](https://github.com/vicajilau)

## 9.2.3

### Desktop (macOS)

- Fixed an issue when the active viewController is not a FlutterViewController.

## 9.2.2

### Desktop (macOS)

- Updated the file picker to check for missing entitlements, instead of failing silently. [@vicajilau](https://github.com/vicajilau).

## 9.2.1

### Desktop (macOS)

- Present file picker panel as a sheet modal to the Flutter application window. [#1734](https://github.com/vicajilau/flutter_file_picker/pull/1734)

## 9.2.0

### Desktop (macOS, Windows, Linux)

- Fixes an inconsistency for saveFile that did not save the file, when bytes are provided on desktop platforms. [@vicajilau](https://github.com/vicajilau).

## 9.1.0

### Web

- Added an implementation for `saveFile()` on the web. [@vicajilau](https://github.com/vicajilau).

## 9.0.3

### Android

- Added ProGuard consumer rules to automatically exclude `androidx.lifecycle.DefaultLifecycleObserver` from obfuscation.

## 9.0.2

### Android

- Fixes: File streams not getting closed.

## 9.0.1

### Windows

- Move `getDirectoryPath()` to its own isolate to avoid COM initialization conflicts with other plugins [#1713](https://github.com/vicajilau/flutter_file_picker/pull/1713) [@tguerin](https://github.com/tguerin).

## 9.0.0

### Web

- **BREAKING CHANGE:** `pickFiles()` now loads files as blobs. See the note in the updated [wiki](https://github.com/vicajilau/flutter_file_picker/wiki/api#-pickfiles)

## 8.3.7

### Android

- Updated example project Android sources. [@vicajilau](https://github.com/vicajilau)

## 8.3.6

### General

- Added compatibility with Flutter 3.29. [@vicajilau](https://github.com/vicajilau).

### Desktop (Windows)

- Fixes the issue under Windows that could be raised when another plugin uses `CoInitializeEx` and the File Explorer windows doesn't popup. [#1708](https://github.com/vicajilau/flutter_file_picker/pull/1708)

## 8.3.5

### Android

- Fixes allowCompression not working on Android. [1633](https://github.com/vicajilau/flutter_file_picker/issues/1633)

## 8.3.4

### Android

- Fix: Handle Null Byte Array in saveFile Method [#1662](https://github.com/vicajilau/flutter_file_picker/issues/1662) [@vicajilau](https://github.com/vicajilau).

## 8.3.3

### General

- Updates flutter_plugin_android_lifecycle, ffi, path, win32, cross_file and web dependencies [@vicajilau](https://github.com/vicajilau).
- Updates CI/CD with new dependencies [@vicajilau](https://github.com/vicajilau).

## 8.3.2

### Android

- Fix pickFiles for Android with launchMode=singleInstance [#1700](https://github.com/vicajilau/flutter_file_picker/issues/1700), [#1404](https://github.com/vicajilau/flutter_file_picker/issues/1404)

## 8.3.1

### iOS

- Fix [1367](https://github.com/vicajilau/flutter_file_picker/issues/1367)

## 8.3.0

### Desktop (macOS) && iOS

- Adds support for Swift Package Manager for compatibility with new projects [#1582](https://github.com/vicajilau/flutter_file_picker/issues/1582)

## 8.2.0

### Desktop (macOS)

- Reimplement macOS file picker using method channels (fixes [#1492](https://github.com/vicajilau/flutter_file_picker/issues/1492), [#1445](https://github.com/vicajilau/flutter_file_picker/issues/1445), [#1674](https://github.com/vicajilau/flutter_file_picker/issues/1674), [#1685](https://github.com/vicajilau/flutter_file_picker/issues/1685))
- **BREAKING CHANGE:** `pickFiles()` now requires the `com.apple.security.files.user-selected.read-only` entitlement on macOS. Without this entitlement, the file picker will not open, and the method will return `null`. See the note in the updated [wiki](https://github.com/vicajilau/flutter_file_picker/wiki/Setup#macos)

## 8.1.7

### iOS

- Fix Image Picker to Handle Partial Failures Gracefully [#1554](https://github.com/vicajilau/flutter_file_picker/issues/1554)

## 8.1.6

### Android

- Fix Android compile error [#1643](https://github.com/vicajilau/flutter_file_picker/issues/1643)

## 8.1.5

### Android

- Fix [#872](https://github.com/vicajilau/flutter_file_picker/issues/872) by removing unnecessary external storage permission

## 8.1.4

### iOS

- Fixes a crash when sometimes user swipe the modal down and call it again. [1357](https://github.com/vicajilau/flutter_file_picker/issues/1357)

## 8.1.3

### Android

- Fixes a null object reference error [#1604](https://github.com/vicajilau/flutter_file_picker/issues/1604)

## 8.1.2

### Android

- Fixes a cache deletion issue [#1505](https://github.com/vicajilau/flutter_file_picker/issues/1505)

## 8.1.1

### Web

- Migrate the web example to use the new web bootstrapping, introduced in Flutter 3.22.

## 8.1.0

### General

- Updates the minimum Flutter version to 3.22.0, to support Dart 3.4.

### Web

- Updates the `package:web` dependency to 1.0.0.
- Removes a redundant `FilePickerWeb.platform` static field. Use `FilePicker.platform` instead.

## 8.0.7

### General

- Fixes an issue relating to incorrect registration of platform-specific implementations. [#1555](https://github.com/vicajilau/flutter_file_picker/issues/1555).
- Fixes an issue that required users to use `kIsWeb` and `FilePickerWeb` when running on the web.

## 8.0.6

### Android

Updates the minimum Android SDK version to 21, to match the current Flutter minimum Android SDK version. Fixes [#1522](https://github.com/vicajilau/flutter_file_picker/issues/1522), [#1528](https://github.com/vicajilau/flutter_file_picker/issues/1528), and [#1531](https://github.com/vicajilau/flutter_file_picker/issues/1531). Thanks @navaronbracke.

## 8.0.5

### Web

Release picked file data in memory to avoid memory leak

## 8.0.4

### Android

Removes references to Flutter v1 android embedding classes.

## 8.0.3

### Web

Fixes a TypeError with `pickFiles()` when using the HTML renderer.

## 8.0.2

### iOS

Fixes the bug [#1412](https://github.com/vicajilau/flutter_file_picker/issues/1412) that picking a folder in iOS causes the original folder to be deleted.

## 8.0.1

### iOS

Fixes an issue preventing compilation on iOS when using Pod::PICKER_DOCUMENT = false.

## 8.0.0+1

Removes linter warnings and fixes CI/CD.

## 8.0.0

### Desktop

Removes Flutter GO support.

### iOS

Adds privacy manifest [#1418](https://github.com/vicajilau/flutter_file_picker/issues/1418).

## 7.1.0+1

Fixes typo on docs (there was some refernces to `FileType.all` instead of the correct `FileType.any`).

## 7.1.0

### General

- Adds `xFiles` getter to [FilePickerResult] and `XFile` to `PlatformFile` to retrieve a `List<XFile>` or single `XFile` accordingly.
- Bumps win32, flutter_plugin_android_lifecycle, plugin_platform_interface and lints versions.
- Fixes NPE when compressing images from gallery on Android 14 [#1455](https://github.com/vicajilau/flutter_file_picker/pull/1458). Thanks @mauriziopinotti.
- Other minor bugs & fixes.

## 7.0.2

### Desktop (Linux)

- File picker extensions for Linux Zenity are case insensitive now
- Fixes [#1322](https://github.com/vicajilau/flutter_file_picker/issues/1322)

## 7.0.1

### Android

Fixes an issue where sequencial picks could replace the previous file [#1466](https://github.com/vicajilau/flutter_file_picker/pull/1466). Thanks @Arsanjuan87.

## 7.0.0

### iOS & Android

- Adds possibility to save files on mobile platforms as well [#1452](https://github.com/vicajilau/flutter_file_picker/pull/1452). Thanks @Samoy.

- Save file to mobile platforms with `bytes`.

## 6.2.1

### Desktop (Windows)

The `initialDirectory` parameter of `getDirectoryPath()` now works ([#970](https://github.com/vicajilau/flutter_file_picker/issues/970)).

## 6.2.0

### Android

Add ability to compress images on android by specifying a compression quality value ([#735]
(<https://github.com/vicajilau/flutter_file_picker/issues/735>)).

## 6.1.1

### Android

Android's CSV mime type is `text/comma-separated-values`. Added standard `text/csv` when the
CSV extension is specified which fixes issues when picking CSV files from Google Drive
on Android devices.

## 6.1.0

### Web

- Fixed endless loop on ios safari when canceling picking. ([#1364](https://github.com/vicajilau/flutter_file_picker/issues/1364)). Thank you @test0terter0n!
- Add `readSequential` flag for web. If `readSequential` is true, order of picked files will be preserved. If flag is false, files will be read parallel. Thank you @test0terter0n!

## 6.0.0

Update minimum Flutter version to 3.7.0.

### iOS

- Update minimum iOS version to 11.0.
- Fix several warnings in the iOS plugin implementation.

## 5.5.0

### iOS

- Fix if selecting from gallery multiple files from remote sources (eg GoPro, Drone) imported to the device gallery and uploaded to iCloud they would have the same file name and it shows only one image repeated
- Fix returned images are in different onder from the gallery selection

## 5.3.4

Fix [#1317](https://github.com/vicajilau/flutter_file_picker/issues/1317)

## 5.3.3

Fix [#1312](https://github.com/vicajilau/flutter_file_picker/issues/1312)

## 5.3.2

### Desktop (Windows)

Bumps the dependency `win32` to 5.0.2 ([#1281](https://github.com/vicajilau/flutter_file_picker/pull/1281)). Thank you @frg2089!

## 5.3.1

Bump Dart SDK lower bound to <4.0.0 to support Dart 3

## 5.3.0

### Android

Updates Gradle to version 7.5
Adds the namespace property for compatibility with Gradle 8

## 5.2.11

### Desktop (Windows)

Updates dependencies, including win32 bump to 4.1.3 ([#1255](https://github.com/vicajilau/flutter_file_picker/issues/1255)).

## 5.2.10

### Desktop (Windows)

Fixes the bug that the result of the save-file dialog was incorrect when it was invoked with a long default file name but the user selected a file with a much short file name ([#1257](https://github.com/vicajilau/flutter_file_picker/issues/1257)).

## 5.2.9

### General

Fixes the errors `Type 'Uint8List' not found` and `'Uint8List' isn't a type` ([#1260](https://github.com/vicajilau/flutter_file_picker/issues/1260)). Thank you @miguelslemos!

## 5.2.8

### Desktop (Windows)

Fixes the bug that the current directory sometimes changed after the user picked a file. Now, after the dialog is closed, the current directory is automatically restored to its original value even if the user changed the directory while searching for files ([#1254](https://github.com/vicajilau/flutter_file_picker/issues/1254)). Thank you @Tokenyet!

### Desktop (Linux)

Fixes the behavior of the `saveFile()` dialog on Ubuntu/Kubuntu. This fix should have been committed in the previous version _5.2.7_ but was forgotten. Now, when the user selects an already existing file, then Ubuntu prompts the user to confirm overwriting this file. This change finally makes the dialog behave the same on all desktop platforms (macOS, Linux, and Windows) ([#989](https://github.com/vicajilau/flutter_file_picker/issues/989)).

## 5.2.7

### Desktop (Windows)

Fixes the behavior of the `saveFile()` dialog on Windows. Now, when the user selects an already existing file, then Windows prompts the user to confirm overwriting this file. This change makes the dialog behave the same on all desktop platforms (macOS, Linux, and Windows). Previously, Windows would not have asked the user for confirmation ([#989](https://github.com/vicajilau/flutter_file_picker/issues/989)).

## 5.2.6

### Web

- Increase time to wait on js result

## 5.2.5

### iOS

- Fix preprocessor definitions in podspec (thanks @tomk9)

## 5.2.4

### Desktop (Windows)

- Calling pick/save file dialog will no longer freeze ui thread.

## 5.2.3

### iOS

- Fixes an issue when picking live photos where the key photo was changed.

## 5.2.2

### Android

- Fix deprecation warning for `getParcelable(String key)` method.

## 5.2.1

### Android

- Removed build constant TIRAMISU to fix build error if targeting API 32 or less ([#1140](https://github.com/vicajilau/flutter_file_picker/issues/1140), [#1124](https://github.com/vicajilau/flutter_file_picker/issues/1124))

## 5.2.0+1

- Reverts 5.2.0 due to multiple regressions.

## 5.2.0

### Android

- Fixes issue with caching on android
- Files will be retrieved without caching to avoid delay (Only cached if paths cannot be retrieved directly )

## 5.1.0

### Desktop (Windows)

- Update Dependencies to latest versions (Win32 2.7.0 to 3.0.0). (Thank you @ishangavidusha)
- Set default dialog title to empty. (Thank you @whuhewei)

### iOS

Fixes an issue when picking live photos. (Thank you @nagibazad)

### Android

Removes READ_EXTERNAL_STORAGE on SDKs targeting 33 or above. (Thank you @alexmercerind)

## 5.0.1

### Android

Replaces random number generation with milliseconds timestamp in file name fallback.

## 5.0.0

### General

Updated dependecies (most importantly is upgrade from ffi 1.1.2 to 2.0.1).
Update lints from 1.0.1 to 2.0.0 (with several fixes of code).

## 4.6.1

### iOS

Handle `UTTypeCreatePreferredIdentifierForTag` returning `NULL`. This prevents a crash observed
on the iOS simulator on Apple Silicon ([#1040](https://github.com/vicajilau/flutter_file_picker/issues/783)).

## 4.6.0

### iOS

Add conditional compilation of media, audio and document pickers for iOS.
This prevents error messages for permissions (NSPhotoLibraryUsageDescription, NSAppleMusicUsageDescription, etc.) when publishing to app store connect, in case you don't need either category. This addresses [#783](https://github.com/vicajilau/flutter_file_picker/issues/783) in a different way.

## 4.5.1

### Web

Adds `display:none` to the internal input element to fix a display issue in specific scenario's.

## 4.5.0

### Desktop (Windows)

Changes the implementation of `getDirectoryPath()` on Windows to provide a modern dialog that looks the same as a file picker dialog ([#915](https://github.com/vicajilau/flutter_file_picker/issues/915)).

## 4.4.0

### Desktop (Linux, macOS, and Windows)

Adds the additional parameter `initialDirectory` to configure the initial directory where the dialog should be opened. This parameter is supported for all three dialogs (pick files, pick directory, and save file). The only exception is that the parameter does not work on Windows for the function `getDirectoryPath()`. Please note that this feature has not been implemented for Android and iOS.

## 4.3.3

### Desktop (Linux)

Introduces two fixes for the KDE Plasma Linux implementation which uses `kdialog` to open the file picker dialogs. Firstly, the selection of multiple files is fixed so that file paths with blanks/spaces are handled correctly. Secondly, file type filters are implemented. Thank you @w1th0utnam3.

## 4.3.2

### Desktop (Windows)

Fixes the issue under Windows that the save-file dialog did not open if the specified file name contained an illegal character. Windows prohibits the usage of [reserved characters in file names](https://docs.microsoft.com/en-us/windows/win32/fileio/naming-a-file#naming-conventions). Now the exception `IllegalCharacterInFileNameException` is thrown if the specified file name contains forbidden characters
([#926](https://github.com/vicajilau/flutter_file_picker/issues/926)).

## 4.3.1

### Desktop (Linux)

Adds KDE Plasma's `kdialog` arguments, allowing `filepicker` to invoke `kdialog` for file system manipulation using shell scripts on distributions that use KDE Plasma as their Desktop Environment and don't ship `zenity` or `qarma`.

## 4.3.0

##### Desktop (Windows)

Adds the parameter `lockParentWindow` for Windows desktop. This parameter makes the file picker dialog behave like a modal window. That is, the file picker always stays in front of the Flutter window until it is closed. Thank you @vinicios-cervantes.

## 4.2.8

##### Desktop (Windows)

Fixes the issue under Windows that the user could not select more than about 256 files (depending on the length of the file paths) because the buffer size for storing the selected file paths was too small. ([#918](https://github.com/vicajilau/flutter_file_picker/issues/918)).

## 4.2.7

##### Desktop (macOS & Windows)

Fixes the issue under Windows that the user could select all file types even though a file type filter was enabled. This error existed because the user could select the entry `All Files (*.*)` in the file type filter dropdown. Also, fixes the bug under macOS that users could select files without file extension even when one of the pre-defined file type filters (audio, image, video, or media) was enabled. ([#871](https://github.com/vicajilau/flutter_file_picker/issues/871)).

## 4.2.6

##### Android

Fixes linting error during builds ([#851](https://github.com/vicajilau/flutter_file_picker/issues/851)).

## 4.2.5

##### Desktop (macOS)

Fixes the issue of picking filenames that contain a comma followed by a space ([#890](https://github.com/vicajilau/flutter_file_picker/issues/890)).

## 4.2.4

##### iOS

Improves error handling when device can't fetch files due to low storage space ([#885](https://github.com/vicajilau/flutter_file_picker/issues/885)).

## 4.2.3

##### iOS

Fixed an issue that was creating a crash when media in PHPickerViewController in iOs was tapped several times very fast, we check that _result is not empty to avoid the crash. No Github issue created.

## 4.2.2+1

##### Android

Reverts Android `READ_EXTERNAL_STORAGE` permission removal.

## 4.2.2

##### Android

Removes `<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>` permission from the platform implementation Manifest since may not be required for some applications and devs can manually add it to their own application if needed ([#864](https://github.com/vicajilau/flutter_file_picker/issues/864)).

## 4.2.1

##### Android

Fixes an issue where `onFileLoading` would be called while picking directories ([#863](https://github.com/vicajilau/flutter_file_picker/issues/863)).

## 4.2.0

Adds the `identifier` property to the `PlatformFile` which references the original file identifier for both iOS & Android ([#804](https://github.com/vicajilau/flutter_file_picker/issues/804)).

## 4.1.6

##### Desktop (macOS)

Fixes the issue that users could not pick `.app` files on macOS because FilePicker tried to determine the file size of `.app` files. On macOS, these special kind of files are actually Unix directories in a special format ([read more on StackExchange](https://apple.stackexchange.com/a/112213)). Now, if a file is picked, which is actually a directory, then the file size will be zero. ([#856](https://github.com/vicajilau/flutter_file_picker/issues/856))

## 4.1.5

##### Web

- Fixes an issue that would prevent the call to return when both `withReadStream` and `allowMultiple` were set. ([#843](https://github.com/vicajilau/flutter_file_picker/issues/843)).
- Addresses an issue in the example app.

## 4.1.4

##### Android

Addresses an issue where multiple media files couldn't be picked in some 3rd party explorers ([#846](https://github.com/vicajilau/flutter_file_picker/issues/846)). Thank you @innim98.

## 4.1.3

##### iOS

Fixes an issue where Live Photos were being picked as `.pvt` packages (since iOS 15). From now on, if `allowCompression` is set to `true`, Live Photos will automatically be converted to static JPEG pictures. ([#835](https://github.com/vicajilau/flutter_file_picker/issues/835))

## 4.1.2

##### Desktop (Linux)

Fixes the issue that on Linux the file type filter `FileType.any` did not allow the selection of files without file extension. ([#836](https://github.com/vicajilau/flutter_file_picker/issues/836))

## 4.1.1

##### iOS

Fixes an issue that would result in picker being dismissed by pulling down the modal sheet without an event. ([#828](https://github.com/vicajilau/flutter_file_picker/issues/828))

##### Web

Addresses an issue when comparing files on Web would result in an error due to `path` not being accessible. ([#822](https://github.com/vicajilau/flutter_file_picker/issues/822))

## 4.1.0

Extends API by new function `saveFiles()` for opening a save-file dialog as requested in [#799](https://github.com/vicajilau/flutter_file_picker/issues/799). This feature is only supported on desktop platforms (Linux, macOS, and Windows).

## 4.0.3

Makes the `path` getter nullable to match with its property ([#823](https://github.com/vicajilau/flutter_file_picker/issues/823)).

## 4.0.2

##### Desktop (Windows)

Fixes custom extension filter. Thank you @jgoyvaerts.

## 4.0.1

##### General

Overrides equality and toString for `platform_file` and `file_picker_result` for better comparison different results. Thank you @Nolence.

##### iOS

- Changes the presentation type of the picker from `UIModalPresentationCurrentContext` to `UIModalPresentationAutomatic` ([#813](https://github.com/vicajilau/flutter_file_picker/issues/813)).

##### Web

- Fixes regression of [#746](https://github.com/vicajilau/flutter_file_picker/issues/746).
- Updates exception text when trying to access `path` on Web. Thank you @maxzod.

## 4.0.0

### Desktop support added for all platforms (MacOS, Linux & Windows) ([#271](https://github.com/vicajilau/flutter_file_picker/issues/271))

From now on, you'll be able to use file_picker with all your platforms, a big thanks to @philenius, which made this possible and allowed the [flutter_file_picker_desktop](https://github.com/philenius/flutter_file_picker_desktop) to be merged with this one.

Have in mind that because of platforms differences, that the following API methods aren't available to use on Desktop:

- The `onFileLoading()` isn't necessary, hence, `FilePickerStatus` won't change, since it hasn't any effect on those;
- `clearTemporaryFiles()` isn't necessary since those files aren't created - the platforms will always use a reference to the original file;
- There is a new optional parameter `dialogTitle` which can be used to set the title of the modal dialog when picking the files;

##### Web

Adds `onFileLoading()` to Web. ([#766](https://github.com/vicajilau/flutter_file_picker/issues/766)).

## 3.0.4

##### Android

- Addresses an issue where an invalid custom file extension wouldn't throw an error when it should. Thank you @Jahn08.
- Fixes `getDirectoryPath()` [#745](https://github.com/vicajilau/flutter_file_picker/issues/745). Thank you @tomm1e.

## 3.0.3

### Web

- Removes analysis_options.yaml from the plugin and fixes the _Don't import implementation files from another package_ warning (#746).

### Android

- Addresses an issue where bytes might be missing after first picking when `withData` is set to `true`. ([#616](https://github.com/vicajilau/flutter_file_picker/issues/616)).

### Desktop (GO)

- Patches README import path. (Thank you @voynichteru)

## 3.0.2+2

- Fixes [#725](https://github.com/vicajilau/flutter_file_picker/issues/725).

## 3.0.2

##### General

- `name` and `size` properties are now non-nullable types.

##### Docs

- Updates README;
- Updates API docs;

##### Example

- Updates Android example app to V2;

##### Android

- Removes deprecated call warnings;

##### Other

- Adds analysis_options.yaml with linter rule to surpress warnings from generated_plugin_registrant.

## 3.0.1

### Android

- Use MediaStore Opener (which goes through the gallery) instead of default explorer. (Thank you @tmthecoder).

### Web

- Add event when canceling the picker. (Thank you @letranloc).

### Other

- Updates example app to null safety.

## 3.0.0

Adds null safety support ([#510](https://github.com/vicajilau/flutter_file_picker/issues/510)).

## 2.1.7

### iOS

- Fixes an issue where a crash could happen when picking a lot of media files in low memory devices ([#606](https://github.com/vicajilau/flutter_file_picker/issues/606)).
- Updates `preferredAssetRepresentationMode`. Thank you @nrikiji.

## 2.1.6

- Addresses an issue on iOS 14 and later where events `onFileLoading` events weren't being provided ([#577](https://github.com/vicajilau/flutter_file_picker/issues/577)).

## 2.1.5+1

- Web: Updates `size` property from `PlatformFile` to be in bytes instead of kb;
- Applies minor refactor to example app. Thank you @Abhishek01039;

## 2.1.5

iOS & Android: Updates `size` property from `PlatformFile` to be in bytes instead of kb.

## 2.1.4

iOS: Fixes iOS ViewController which is nil when UIWindow.rootViewController have changed. ([#525](https://github.com/vicajilau/flutter_file_picker/issues/525)). Thank you @devcxm.

## 2.1.3

Android: Updates file name handling method. ([#487](https://github.com/vicajilau/flutter_file_picker/issues/487))

## 2.1.2

Desktop (Go): Fixed desktop plugin implementation. Thank you @DenchikBY. ([#382](https://github.com/vicajilau/flutter_file_picker/issues/382#issuecomment-744055654))

## 2.1.1

iOS: Fixes an issue that could result in a crash when selecting a media item twice. ([#518](https://github.com/vicajilau/flutter_file_picker/issues/518))

## 2.1.0

Adds `withReadStream` that allows bigger files to be streamed read into a `Stream<List<int>>`. Thanks @redsolver.

## 2.0.13

Updates `extension` helper getter to use the `name` property instead of `path`, since the latest isn't available on the Web, hence, the extension wouldn't be as well. Thank you @markgrancapal.

## 2.0.12

Android:

- Fixes an issue that could result in some files not being properly retrieved due to special characters on their names. ([#472](https://github.com/vicajilau/flutter_file_picker/issues/472))
- Fixes a NPE that could happen with some devices. ([#482](https://github.com/vicajilau/flutter_file_picker/issues/482))

## 2.0.11

iOS: Fixes `FileType.audio` exports to support ipod-library content (non DRM protected). From now on, a cached asset (m4a) will be exported from the selected music file in the Music app, so it can later be used. Fixes ([#441](https://github.com/vicajilau/flutter_file_picker/issues/441)).

## 2.0.10

Adds missing extension to `name` property of `PlatformFile`. ([#444](https://github.com/vicajilau/flutter_file_picker/issues/444))

## 2.0.9+1

Minor fix on CHANGELOG regarding version `2.0.9`.

## 2.0.9

Android: Updates package visibility to fully support Android 11 (SDK 30 and later). ([#440](https://github.com/vicajilau/flutter_file_picker/issues/440))

_Note: If you have build issues from now on because `<queries>` aren't recognized, you'll need to update your build.gradle to use one of the [following patched versions](https://github.com/vicajilau/flutter_file_picker/wiki/Troubleshooting#android)._

## 2.0.8+1

- iOS: Updates media picker to launch in app context (instead of modal).
- Minor update to README file.

## 2.0.8

Fixes an issue on iOS 14, where canceling with swipe gestures, could result in cancel event not being dispatched. ([#431](https://github.com/vicajilau/flutter_file_picker/issues/431)).

## 2.0.7

Fixes [#425](https://github.com/vicajilau/flutter_file_picker/issues/425) and updates iOS to use NSDocumentDirectory on iOS 12 or lower. Thanks @allanwolski.

## 2.0.6

iOS: Fixes iOS 14 media picker (image & video) (#405, #407).

## 2.0.5

Android: Fixes [#402](https://github.com/vicajilau/flutter_file_picker/issues/402).

## 2.0.4

Desktop (Go): Fixes directory pick on Linux.

## 2.0.3

Android: Fixes out of memory issue on some devices when picking big files.

## 2.0.2+2

Fixes multi-pick example on README.

## 2.0.2+1

iOS: Fixes conditional import for backwards compatibility with Xcode 11.

## 2.0.2

Web: Adds mobile Safari support and other minor improvements.
iOS: Adds conditional import for backwards compatibility with Xcode 11.

## 2.0.1+2

iOS: Addresses an issue that could prevent users from viewing picked media elements (pictures/videos) from gallery on iOS 14.

## 2.0.1+1

Fixes README screenshots.

## 2.0.1

iOS: Updates picker to use new PHPickerController for both single and multi media (image/video) picks (iOS 14 and above only).

## 2.0.0

**Breaking Changes**

- Unifies all platforms (IO, Web and Desktop) in a single plugin (file_picker) that can be used seamlessly across all. Both [file_picker_interface](https://pub.dev/packages/file_picker_platform_interface) and [file_picker_web](https://pub.dev/packages/file_picker_web) are no longer mantained from now on.
- You'll now have to use `FilePicker.platform.pickFiles()` and extract the files from `FilePickerResult`;
- Because platforms are unified and mixing `File` instances from dart:io and dart:html required stubbing and bloated code, it's no longer available as helper method so you'll have to instanciate a `File` with the picked paths;

**New features**

- Simplified usage, now you only need to use `FilePicker.platform.pickFiles()` with desired parameters which will return a `FilePickerResult` with a `List<PlatformFile>` containing the picked data;
- Added classes `FilePickerResult` and `PlatformFile` classes with helper getters;
- On Android all picked files are scoped cached which should result in most of files being available. Caching process is only made once, so once done, the picked instance should be the same;
- On iOS picking audio now supports multiple and cloud picks;
- Added parameter `withData` that allows file data to be immediately available on memory as `Uint8List` (part of `PlatformFile` instance). This is particularly helpful on web or if you are going to upload to somehwere else;
- Major refactor with some clean-up and improvements;

**Removed**

- Single methods such as `getFilePath()`, `getMultiFilePath()`, `getFile()` and `getMultiFile()` are no longer availble in favor o `pickFiles()`;

## 1.13.3

Go: Updates MacOS directory picker to applescript (thank you @trister1997).

## 1.13.2

Android: fixes picking paths from Downloads directory on versions below Android Q.

## 1.13.1

Android: adds support to non-legacy picking on Android Q or above (thank you @lakshyab1995).

## 1.13.0+1

Fixes an issue that could prevent `1.13.0` from being built due to missing `allowCompression` property.

## 1.13.0

Adds `allowCompression` property that will define if media (video & image) files are allowed to be compressed by OS when picked. On Android this has no effect as it already returns the original file or an integral copy.

## 1.12.0

Adds `getDirectoryPath()` desktop (go) implementation.

## 1.11.0+3

Updates tearDown() call order on Android's implementation.

## 1.11.0+2

Updates README file (iOS preview).

## 1.11.0+1

Updates README file.

## 1.11.0

Adds `onFileLoading` handler for every picking method that will provide picking status: `FilePickerStatus.loading` and `FilePickerStatus.done` so you can, for example, display a custom loader.

## 1.10.0

Adds `getDirectoryPath()` method that allows you to select and pick directory paths. Android, requires SDK 21 or above for this to work, and iOS requires iOS 11 or above.

## 1.9.0+1

Adds a temporary workaround on Android where it can trigger `onRequestPermissionsResult` twice, related to Flutter issue [49365](https://github.com/flutter/flutter/issues/49365) for anyone affected in Flutter versions below 1.14.6.

## 1.9.0

Adds `clearTemporaryFiles()` that allows you to explicitly remove cached files - on Android applies typically to those picked from remote providers, on iOS _all_ picked files are cached.

## 1.8.0+2

Updates podspec to use only PhotoGallery from DKImagePickerController (thanks @jamesdixon!)

## 1.8.0+1

Minor fix on `getFile()` method - should affect only those on 1.8.0.

## 1.8.0

Adds `FileType.media` that will allow you to pick video and images at the same time. On iOS, this will let you pick directly from Photos app (gallery), if you want to use Files app, you _must_ use `FileType.custom` with desired extensions.

## 1.7.1

Updates iOS multi gallery picker dependency and adds a modal loading while fetching exporting assets.

## 1.7.0

**Breaking change**

Added support for multi-picks of videos and photos from Photos app on iOS through [DKImagePicker](https://github.com/zhangao0086/DKImagePickerController) - use any of the `getMulti` methods with `FileType.image` or `FileType.video`. From now on, you'll need to add `use_frameworks!` in your ios/Podfile.

## 1.6.3+2

- Fixes a crash on Android when a file has an id that can't be resolved and uses a name instead (#221);
- Minor fix on Go (Desktop) - Windows (thanks @marchellodev);

## 1.6.3+1

Addresses an issue with plugin calls on Go (Desktop) - Linux & Windows

## 1.6.3

Addresses an issue with plugin calls on Go (Desktop) - MacOS

## 1.6.2

Updates Go (Desktop) to support multiple extension filters.

## 1.6.1

Addresses an issue that could result in permission handler resolving requests from other activities.

## 1.6.0

- Adds multiple file extension filter support. From now on, you _must_ provide a `List` of extensions with type `FileType.custom` when restricting types while picking.
- Other minor improvements;

## 1.5.1

- iOS: Fixes an issue that could result in a crash when selecting files (with repeated taps) from 3rd party remote providers (Google Drive, Dropbox etc.);
- Go: Updates channel name;
- Adds check that ensures that you one uses `FileType.custom` when providing a custom file extension filter;

## 1.5.0+2

Updates channel name on iOS.

## 1.5.0+1

Adds temporary workaround for (#49365)(<https://github.com/flutter/flutter/issues/49365>) until 1.14.6 lands on stable channel.

## 1.5.0

- **Breaking change:** Refactored `FileType` to match lower camelCase Dart guideline (eg. `FileType.ALL` now is `FileType.any`);
- Added support for new [Android plugins APIs](https://flutter.dev/docs/development/packages-and-plugins/plugin-api-migration) (Android V2 embedding);

## 1.4.3+2

Updates dependencies.

## 1.4.3+1

Removes checked flutter_export_environment.sh from example app.

## 1.4.3

**Bug fix**

- Fixes an issue that could result in a crash when tapping multiple times in the same media file while picking, on some iOS devices (#171).

## 1.4.2+1

Updates go-flutter dependencies.

## 1.4.2

**Bug fix**

- Fixes an issue that could cause a crash when picking video files in iOS 13 or above due to SDK changes.
- Updates Go-Flutter with go 1.13.

## 1.4.1

**Bug fix:** Fixes an issue that could result in some cached files, picked from Google Photos (remote file), to have the name set as `null`.

## 1.4.0+1

**Bug fix:** Fixes an issue that could prevent internal storage files from being properly picked.

## 1.4.0

**New features**

- Adds Desktop support throught **[go-flutter](https://github.com/go-flutter-desktop/go-flutter)**, you can see [detailed instructions on how to get it running](https://github.com/go-flutter-desktop/hover).
- Adds Desktop example, to run it just do `hover init` and then `hover run` within the plugin's example folder (you must have go and hover installed, check the previous point).
- Similar to `getFile`, now there is also a `getMultiFile` which behaves the same way, but returning a list of files instead.

**Improvements**

- Updates Android SDK deprecated code.
- Sometimes when a big file was being picked from a remote directory (GDrive for example), the UI could be blocked. Now this shouldn't happen anymore.

## 1.3.8

**Bug fix:** Fixes an issue that could cause a crash when picking files with very long names.

**Changes:** Updates Android target API to 29.

## 1.3.7

**Rollback - Breaking change:** Re-adds runtime verification for external storage read permission. Don't forget to add the permission to the `AndroidManifest.xml` file as well. More info in the README file.

**Bug fix:** Fixes a crash that could cause some Android API to crash when multiple files were selected from external storage.

## 1.3.6

**Improvements**

- Removes the Android write permissions requirement.
- Minor improvements in the example app.
- Now the exceptions are rethrown in case the user wants to handle them, despite that already being done in the plugin call.

## 1.3.5

**Bug fix:** Fixes an issue that could prevent users to pick files from the iCloud Drive app, on versions below iOS 11.

## 1.3.4+1

**Rollback:** Removes a local dependency that shouldn't have been committed with `1.3.4` which would cause Android build to fail.

## 1.3.4

**Bug fix:** Protects the `registrar.activity()` in the Android side of being accessed when it's `null`.

## 1.3.3

**Bug fixes**

- Fixes an issue where sometimes a single file path was being returned as a `List` instead of `String`.
- `requestCode` in Android intents are now restricted to 16 bits.

## 1.3.2

**Bug fix:** Returns a `null` value in the `getFile()` when the picker is canceled.

## 1.3.1

**Bug fix:** Fixes an issue on Android, where other activity would try to call `FilePicker`'s result object when it shouldn't.

## 1.3.0

**Breaking changes**

- `FileType.CAMERA` is no longer available, if you need it, you can use this package along with [image_picker](https://pub.dartlang.org/packages/image_picker).

**New features**

- You can now pick multiple files by using the `getMultiFilePath()` method which will return a `Map<String,String>` with all paths from selected files, where the key matches the file name and the value its path. Optionally, it also supports filtering by file extension, otherwise all files will be selectable. Nevertheless, you should keep using `getFilePath()` for single path picking.
- You can now use `FileType.AUDIO` to pick audio files. In iOS this will let you select from your music library. Paths from DRM protected files won't be loaded (see README for more details).
- Adds `getFile()` utility method that does the same of `getFilePath()` but returns a `File` object instead, for the returned path.

**Bug fixes and updates**

- This package is no longer attached to the [image_picker](https://pub.dartlang.org/packages/image_picker), and because of that, camera permission is also no longer required.
- Fixes an issue where sometimes the _InputStream_ wasn't being properly closed. Also, its exception is now being forward to the plugin caller.
- Fixes an issue where the picker, when canceled, wasn't calling the result callback on the underlying platforms.

## 1.2.0

**Breaking change**: Migrate from the deprecated original Android Support Library to AndroidX. This shouldn't result in any functional changes, but it requires any Android apps using this plugin to [also migrate](https://developer.android.com/jetpack/androidx/migrate) if they're using the original support library.

## 1.1.1

- Updates README file.

## 1.1.0

**Breaking changes**

- `FileType.PDF` was removed since now it can be used along with custom file types by using the `FileType.CUSTOM` and providing the file extension (e.g. PDF, SVG, ZIP, etc.).
- `FileType.CAPTURE` is now `FileType.CAMERA`

**New features**

- Now it is possible to provide a custom file extension to filter file picking options by using `FileType.CUSTOM`

**Bug fixes and updates**

- Fixes file names from cloud on Android. Previously it would always display **Document**
- Fixes an issue on iOS where an exception was being thrown after canceling and re-opening the picker.
- Fixes an issue where collision could happen with request codes on Android.
- Adds public documentation to `file_picker`
- Example app updated.
- Updates .gitignore

## 1.0.3

- Fixes `build.gradle`.

## 1.0.2

- Minor update of README file.

## 1.0.1

- Adds comments for public API

## 1.0.0

- **Version 1.0** release.
- Adds support for ANY and VIDEO files.
- Fixes an issue where permissions were recursively asked on Android.
- Fixes an issue where some paths from document files couldn't be loaded with Android 8.0.
- Updates README file to match changes.
- General refactor & cleanup.

## 0.1.6

- Replaces commons dependency with FilePath class on Android, to handle path resolution on different SDK.

## 0.1.5

- Minor correction in the README file.

## 0.1.4

- Changed Meta minimum version due to versioning conflict with flutter_localization.

## 0.1.3

- Updated readme.

## 0.1.2

- Changed license from Apache 2.0 to MIT.
- Adds demo screenshot.

## 0.1.1

- Adds license information (Apache 2.0).
- Adds CHANGELOG details.

## 0.1.0

- Initial release.
- Supports picking paths from files on local storage, cloud.
- Supports picking paths from both gallery & camera due to [image_picker](https://pub.dartlang.org/packages/image_picker) dependency.
