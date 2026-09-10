![File Picker for Android](https://raw.githubusercontent.com/vicajilau/flutter_file_picker/main/.github/assets/readme_banner_android.svg)

# android_file_picker

The Android implementation of `file_picker`.

## Usage

This package is endorsed, which means you can simply use `file_picker` as normal, and the Android implementation will be automatically included.

## Android setup

If your app overrides `onActivityResult` in a custom `MainActivity`, make sure it calls `super.onActivityResult(...)` for activities it doesn't handle itself. Otherwise the plugin's own `onActivityResult` (in `FilePickerDelegate`) never runs, and picking a file fails silently.
