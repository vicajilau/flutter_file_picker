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

### `initialDirectory` in a sandboxed app

In a sandboxed macOS app, the open/save dialog is presented by Powerbox, a system service that brokers file access for sandboxed apps. Powerbox will only navigate to a directory your app has already been granted access to (for example, one the user previously picked, or one covered by a security-scoped bookmark). If `initialDirectory` points somewhere outside that scope, Powerbox silently ignores it and falls back to a default location such as `~/Documents`, without any error.

This is not officially documented by Apple, but it is a widely reported limitation of App Sandbox, not something this plugin can work around: the app itself has no way to make Powerbox trust an arbitrary path it hasn't already granted. `initialDirectory` will only reliably take effect on macOS for locations your app already has access to.

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
