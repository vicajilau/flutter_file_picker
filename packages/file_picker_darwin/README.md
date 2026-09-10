![File Picker for iOS and macOS](https://raw.githubusercontent.com/vicajilau/flutter_file_picker/main/.github/assets/readme_banner_darwin.svg)

# file_picker_darwin

The iOS and macOS implementation of `file_picker`.

## Usage

This package is endorsed, which means you can simply use `file_picker` as normal, and the iOS and macOS implementations will be automatically included.

## macOS setup

A sandboxed macOS app needs a files entitlement before the picker can return a usable path, without it every pick or save fails with an entitlement error. Add one of the following to both `macos/Runner/DebugProfile.entitlements` and `macos/Runner/Release.entitlements`, depending on whether your app only needs to read picked files or also needs to write to them:

Read-only access:

```xml
<key>com.apple.security.files.user-selected.read-only</key>
<true/>
```

Read and write access (required for `saveFile()`):

```xml
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
```

You can also add these from Xcode, under your target's *Signing & Capabilities* tab, in the *App Sandbox* section.

#### Pick iOS media using its current representation
```dart
List<PlatformFile> files = await FilePicker.pickFiles(
  type: FileType.video,
  compressionQuality: 0,
  darwinOptions: const DarwinOptions(
    assetRepresentationMode: DarwinAssetRepresentationMode.current,
  ),
);
```

The available modes are `automatic` (the default), `current`, and
`compatible`. This option applies only to the iOS photo-library picker.
Non-automatic modes require `compressionQuality` to be `0`.
