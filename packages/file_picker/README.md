![fluter_file_picker](https://user-images.githubusercontent.com/27860743/64064695-b88dab00-cbfc-11e9-814f-30921b66035f.png)
<p align="center">
  <a href="https://pub.dartlang.org/packages/file_picker">
    <img alt="File Picker" src="https://img.shields.io/pub/v/file_picker.svg">
  </a>
  <a href="https://github.com/Solido/awesome-flutter">
    <img alt="Awesome Flutter" src="https://img.shields.io/badge/Awesome-Flutter-blue.svg?longCache=true&style=flat-square">
  </a>
  <a href="https://github.com/vicajilau/flutter_file_picker/issues">
    <img src="https://img.shields.io/github/issues/vicajilau/flutter_file_picker" alt="GitHub issues badge">
  </a>
  <a href="https://github.com/vicajilau/flutter_file_picker?tab=MIT-1-ov-file">
    <img src="https://img.shields.io/github/license/vicajilau/flutter_file_picker" alt="GitHub license badge">
  </a>
  <a href="https://github.com/vicajilau/flutter_file_picker/actions/workflows/main.yml">
    <img alt="CI pipeline status" src="https://github.com/vicajilau/flutter_file_picker/actions/workflows/main.yml/badge.svg">
  </a>
</p>

# File Picker
A plugin that allows you to use the native file explorer to pick single or multiple files, with extensions filtering support.

## Currently supported features
* Uses OS default native pickers
* Supports multiple platforms (Mobile, Web, Desktop)
* Supports **WebAssembly (Wasm)** compilation
* Pick files using **custom format** filtering — you can provide a list of file extensions (pdf, svg, zip, etc.)
* Pick files from **cloud files** (GDrive, Dropbox, iCloud)
* Single or multiple file picks
* Supports retrieving as `XFile` (`cross_file`) for easy manipulation with other libraries
* Different default type filtering (media, image, video, audio or any)
* Picking directories
* Picking both files and directories simultaneously
* Read file content easily via `file.readAsBytes()` or stream via `file.readAsByteStream()`
* Open a save-file / save-as dialog (a dialog that lets the user specify the drive, directory, and name of a file to save)

If you have any feature that you want to see in this package, please feel free to issue a suggestion. 🎉

## Compatibility Chart

| API                           | Android            | iOS                | Linux              | macOS              | Windows            | Web                |
|-------------------------------|--------------------|--------------------|--------------------|--------------------|--------------------|--------------------|
| `clearTemporaryFiles()`       | :white_check_mark: | :white_check_mark: | :x:                | :x:                | :x:                | :x:                |
| `getDirectoryPath()`          | :white_check_mark: | :white_check_mark: | :white_check_mark: | :white_check_mark: | :white_check_mark: | :x:                |
| `pickFileAndDirectoryPaths()` | :x:                | :x:                | :x:                | :white_check_mark: | :x:                | :x:                |
| `pickFile()`                  | :white_check_mark: | :white_check_mark: | :white_check_mark: | :white_check_mark: | :white_check_mark: | :white_check_mark: |
| `pickFiles()`                 | :white_check_mark: | :white_check_mark: | :white_check_mark: | :white_check_mark: | :white_check_mark: | :white_check_mark: |
| `saveFile()`                  | :white_check_mark: | :white_check_mark: | :white_check_mark: | :white_check_mark: | :white_check_mark: | :white_check_mark: |

See the [official API reference on pub.dev](https://pub.dev/documentation/file_picker/latest/file_picker/FilePicker-class.html) for further details.

### Darwin implementation notes

The iOS and macOS native implementations live under the shared Darwin source tree (`file_picker_darwin`). The iOS implementation requires iOS 14.0 or newer because it uses `PHPickerViewController` and `PHPickerResult`.

## Migrating to v12

Version 12.0 transitions `file_picker` to a **federated plugin architecture**.

### Key Breaking Changes & Migration Steps

1. **`FilePicker.pickFiles()` Returns `List<PlatformFile>`**:
   - `FilePickerResult` has been removed in favor of direct lists of `PlatformFile`.
   - Returns an empty list (`[]`) if the user canceled the operation.
   - **v11**: `FilePickerResult? result = await FilePicker.pickFiles();`
   - **v12**: `List<PlatformFile> files = await FilePicker.pickFiles();`

2. **Single File Picking**:
   - Use `FilePicker.pickFile()` to pick a single file returning `PlatformFile?`.

3. **Reading Bytes and Streaming**:
   - Instead of using `withData: true` or `withReadStream: true` flags, use `PlatformFile` methods directly:
     - `Uint8List bytes = await file.readAsBytes();`
     - `Stream<Uint8List> stream = file.readAsByteStream();`

4. **Platform Options**:
   - Platform-specific parameters are grouped into configuration options, with implementations per platform:
     - `AndroidOptions` / `FilePickerAndroidOptions`
     - `DarwinOptions`
     - `WindowsOptions` / `FilePickerWindowsOptions`
     - `LinuxOptions` / `FilePickerLinuxOptions`
     - `WebOptions` / `FilePickerWebOptions`

5. **`PlatformFile.size` Removed**:
   - The `size` property is gone. Reading a file's length is now a method, because on some platforms it means touching the disk.
   - **v11**: `int bytes = file.size;`
   - **v12**: `int bytes = await file.length();`
   - Since 12.2.0 there is also `int? lengthSync()`, which returns the length the native picker already reported without doing any I/O, or `null` when it did not report one. Use `file.lengthSync() ?? await file.length()` when you want a value either way.


## Documentation
For platform-specific setup, see the README of the platform package you're targeting (e.g. [`file_picker_darwin`](https://pub.dev/packages/file_picker_darwin) for macOS entitlements, [`android_file_picker`](https://pub.dev/packages/android_file_picker) for Android notes). For the full API, see the [official API reference on pub.dev](https://pub.dev/documentation/file_picker/latest/file_picker/FilePicker-class.html).

## Usage

#### Single file
```dart
PlatformFile? file = await FilePicker.pickFile();

if (file != null) {
  print(file.name);
  print(await file.length());
} else {
  // User canceled the picker
}
```

#### Multiple files
```dart
List<PlatformFile> files = await FilePicker.pickFiles();

if (files.isNotEmpty) {
  for (final file in files) {
    print(file.name);
  }
} else {
  // User canceled the picker
}
```

#### Multiple files with extension filter
```dart
List<PlatformFile> files = await FilePicker.pickFiles(
  type: FileType.custom,
  allowedExtensions: ['jpg', 'pdf', 'doc'],
);
```

#### iOS photo-library asset representation
```dart
List<PlatformFile> files = await FilePicker.pickFiles(
  type: FileType.video,
  compressionQuality: 0,
  darwinOptions: const DarwinOptions(
    assetRepresentationMode: DarwinAssetRepresentationMode.current,
  ),
);
```

`DarwinAssetRepresentationMode.automatic` is the default. Use `current` to
avoid transcoding when possible, or `compatible` to request a broadly
compatible representation. Non-automatic modes require
`compressionQuality: 0` and only affect media selected from the iOS photo
library.

#### Confirm button text
```dart
List<PlatformFile> files = await FilePicker.pickFiles(
  windowsOptions: const WindowsOptions(acceptLabel: 'Choose'),
  linuxOptions: const LinuxOptions(acceptLabel: 'Choose'),
  darwinOptions: const DarwinOptions(acceptLabel: 'Choose'),
);
```

Sets the confirm button text of the file dialog. Supported on Windows
(`pickFile()`, `pickFiles()`, `getDirectoryPath()`, `saveFile()`), Linux (same
four), and macOS (`pickFile()`/`pickFiles()` only). Has no effect on iOS,
Android, or Web.

#### Pick a directory
```dart
String? selectedDirectory = await FilePicker.getDirectoryPath();

if (selectedDirectory == null) {
  // User canceled the picker
}
```

#### Save-file / save-as dialog
```dart
Uri? outputFile = await FilePicker.saveFile(
  dialogTitle: 'Please select an output file:',
  fileName: 'output-file.pdf',
  bytes: pdfBytes,
);

if (outputFile == null) {
  // User canceled the picker
}
```

## Credits

`file_picker` is [Miguel Ruivo](https://github.com/miguelpruivo)'s work.

He wrote the first commit on 23 June 2018 and spent the next eight years turning it into the package Flutter reaches for whenever an app needs a file. Six platform implementations, more than a hundred releases, millions of downloads every month, and over a hundred people who sent a patch along the way.

Maintenance moved to this repository in 2026. The architecture, the API and most of the hard problems were solved long before that, and everything here is built on top of them.

Thank you, Miguel.
