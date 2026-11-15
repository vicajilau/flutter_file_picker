![File Picker for Android](https://raw.githubusercontent.com/vicajilau/flutter_file_picker/main/.github/assets/readme_banner_android.svg)

# android_file_picker

The Android implementation of `file_picker`.

## Usage

This package is endorsed, which means you can simply use `file_picker` as normal, and the Android implementation will be automatically included.

## Android setup

If your app overrides `onActivityResult` in a custom `MainActivity`, make sure it calls `super.onActivityResult(...)` for activities it doesn't handle itself. Otherwise the plugin's own `onActivityResult` (in `FilePickerDelegate`) never runs, and picking a file fails silently.

### Filtering by MIME type

Android filters the picker by MIME type, not by extension. With `FileType.custom`, each of `allowedExtensions` is turned into a MIME type through Android's own mapping. An extension that is not in that mapping cannot be used as a filter, so the pick throws a `PlatformException` with the `unsupported_extension` code before the picker opens.

Files with such an extension still have a MIME type, the one their provider reports. If you know it, pass it in `FilePickerAndroidOptions.mimeTypes`, and the picker filters by it instead of looking up the extensions:

```dart
final files = await FilePicker.pickFiles(
  type: FileType.custom,
  // Used on the other platforms.
  allowedExtensions: ['abc', 'zip'],
  // Used on Android instead of the extensions.
  androidOptions: const FilePickerAndroidOptions(
    mimeTypes: ['application/zip', 'application/octet-stream'],
  ),
);
```

`application/octet-stream` is the type Android gives to files it cannot classify, so it also lets the user select every file of an unknown type, such as an `.abc` file, but not the ones with a known type, such as PDF or CSV files. Wildcards such as `image/*` are accepted. Several extensions can share a MIME type, so the user may be able to select files with other extensions: check `PlatformFile.extension` of the result if it matters. `mimeTypes` is ignored with any other `FileType`.

### `initialDirectory` is not supported for picking

`initialDirectory` currently has no effect on `pickFile()`, `pickFiles()`, `pickFileAndDirectoryPaths()`, or `getDirectoryPath()` on Android. The native side launches `ACTION_OPEN_DOCUMENT`, `ACTION_OPEN_DOCUMENT_TREE`, and `ACTION_GET_CONTENT` intents, none of which are given a starting location. It only works for `saveFile()` today.

Supporting it for picking would need turning a plain file path into a `content://` document tree URI for `DocumentsContract.EXTRA_INITIAL_URI`, which Android's Storage Access Framework does not map to directly, so this is tracked as a future improvement rather than a quick fix.
