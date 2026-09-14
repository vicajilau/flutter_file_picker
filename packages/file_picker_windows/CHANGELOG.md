## 2.0.0

- **BREAKING CHANGE**: `PlatformFile.length()` now returns `Future<int?>` instead of `Future<int>`. Returns `null` when the length could not be determined (e.g. a failed disk read), instead of `0`, matching `lengthSync()`. [#2197](https://github.com/vicajilau/flutter_file_picker/issues/2197)

## 1.3.0

- Added `WindowsOptions.acceptLabel`, letting callers set the confirm ("OK") button text on `pickFile()`, `pickFiles()`, `getDirectoryPath()`, and `saveFile()` dialogs, via `IFileDialog.SetOkButtonLabel`. [#1861](https://github.com/vicajilau/flutter_file_picker/issues/1861)

## 1.2.0

- Implemented `PlatformFile.lengthSync()`. The picker only returns a file path, not its size, so this returns `null` on Windows, use `length()` to actually read it from disk.

## 1.1.0

- Migrated `pickFile()`, `pickFiles()`, and `saveFile()` from the legacy `GetOpenFileNameW`/`GetSaveFileNameW` common dialogs to the modern `IFileOpenDialog`/`IFileSaveDialog` COM APIs, the same pattern `getDirectoryPath()` already used. This is a prerequisite for supporting custom dialog button text and other Common Item Dialog features on those entry points. Fixes [#2173](https://github.com/vicajilau/flutter_file_picker/issues/2173).
- Removed the internal Win32 helpers tied to the legacy dialogs (`fileTypeToFileFilter`, `extractSelectedFilesFromOpenFileNameW`, `OPENFILENAMEW`, `GetOpenFileNameW`, `GetSaveFileNameW`, and the `ofn*` constants). These were implementation details of the removed dialog code, not part of the supported plugin API.
- Tightened the `file_picker_platform_interface` lower bound to `^3.2.0`. This package's `pickFile()`/`pickFiles()` signatures reference `DarwinOptions`, added in that version, so resolving against an older one would fail to compile.

## 1.0.2

- Fix saved files missing their extension when the user types a file name without one: set `lpstrDefExt` on `OPENFILENAMEW` so Windows appends the default extension (derived from the allowed extensions or the suggested file name). Fixes [#2139](https://github.com/vicajilau/flutter_file_picker/issues/2139).

## 1.0.1

- Improved package description, added example, and added missing API documentation.

## 1.0.0

- Initial release of Windows implementation package for `file_picker`.
