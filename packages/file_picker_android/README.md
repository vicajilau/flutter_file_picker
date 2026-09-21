![File Picker for Android](https://raw.githubusercontent.com/vicajilau/flutter_file_picker/main/.github/assets/readme_banner_android.svg)

# android_file_picker

The Android implementation of `file_picker`.

## Usage

This package is endorsed, which means you can simply use `file_picker` as normal, and the Android implementation will be automatically included.

## Android setup

If your app overrides `onActivityResult` in a custom `MainActivity`, make sure it calls `super.onActivityResult(...)` for activities it doesn't handle itself. Otherwise the plugin's own `onActivityResult` (in `FilePickerDelegate`) never runs, and picking a file fails silently.

### `initialDirectory` is not supported for picking

`initialDirectory` currently has no effect on `pickFile()`, `pickFiles()`, `pickFileAndDirectoryPaths()`, or `getDirectoryPath()` on Android. The native side launches `ACTION_OPEN_DOCUMENT`, `ACTION_OPEN_DOCUMENT_TREE`, and `ACTION_GET_CONTENT` intents, none of which are given a starting location. It only works for `saveFile()` today.

Supporting it for picking would need turning a plain file path into a `content://` document tree URI for `DocumentsContract.EXTRA_INITIAL_URI`, which Android's Storage Access Framework does not map to directly, so this is tracked as a future improvement rather than a quick fix.
