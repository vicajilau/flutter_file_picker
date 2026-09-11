## 4.0.0

- **BREAKING CHANGE**: `PlatformFile.length()` now returns `Future<int?>` instead of `Future<int>`. Returns `null` when the length could not be determined (e.g. a failed disk read), instead of `0`, matching `lengthSync()`. [#2197](https://github.com/vicajilau/flutter_file_picker/issues/2197)
- Fixed `FilePickerWebOptions.readSequential` having no effect. Files are now genuinely read one at a time when `true`, and concurrently (the default) when `false`, preserving selection order in the result either way. [#2206](https://github.com/vicajilau/flutter_file_picker/issues/2206)

## 3.1.0

- Implemented `PlatformFile.lengthSync()`, returning the browser's `File.size` (or the loaded bytes' length) synchronously, without doing any I/O.

## 3.0.3

- Tightened the `file_picker_platform_interface` lower bound to `^3.2.0`. This package's `pickFile()`/`pickFiles()` signatures reference `DarwinOptions`, added in that version, so resolving against an older one would fail to compile.

## 3.0.2

- Fixed the `window` `focus` listener used to detect a cancelled picker dialog never being removed after use. `removeEventListener` was passed a freshly created `.toJS` function object on every call, which never matches the one originally passed to `addEventListener`, so the listener leaked on `window` on every `pickFiles`/`pickFile` call. The JS function references are now cached and reused for both add and remove.

## 3.0.1

- Improved package description, added example, and added missing API documentation.

## 3.0.0

* Unified Web platform release for federated `file_picker` architecture using `package:web` and `dart:js_interop`.

## 2.0.0

* Deprecates plugin in favor of standalone `file_picker` for all platforms.

## 1.0.2+1

* Fix custom filter String creation.

## 1.0.2

* Addresses an issue that would cause dot being required on filters for web (#343).

## 1.0.1+2

* Bumps `file_picker_platform_interface` dependency version.

## 1.0.1+1

* Updates homepage & description.

## 1.0.1

* Updates API to support `onFileLoading` from `FilePickerInterface`.

## 1.0.0

* Adds public API documentation and updates `file_picker_platform_interface` dependency.

## 0.0.2

* Added no-op iOS podspec to prevent build issues on iOS.

## 0.0.1

* Creation of File Picker Web project draft.
