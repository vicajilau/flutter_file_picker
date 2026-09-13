![File Picker](.github/assets/readme_banner.svg)

<p align="center">
  <a href="https://pub.dev/packages/file_picker">
    <img alt="pub package" src="https://img.shields.io/pub/v/file_picker.svg">
  </a>
  <a href="https://github.com/vicajilau/flutter_file_picker/actions/workflows/main.yml">
    <img alt="CI pipeline status" src="https://github.com/vicajilau/flutter_file_picker/actions/workflows/main.yml/badge.svg">
  </a>
  <a href="https://github.com/vicajilau/flutter_file_picker/issues">
    <img alt="GitHub issues" src="https://img.shields.io/github/issues/vicajilau/flutter_file_picker">
  </a>
  <a href="https://github.com/vicajilau/flutter_file_picker/blob/main/LICENSE">
    <img alt="License" src="https://img.shields.io/github/license/vicajilau/flutter_file_picker">
  </a>
  <a href="https://github.com/Solido/awesome-flutter">
    <img alt="Awesome Flutter" src="https://img.shields.io/badge/Awesome-Flutter-blue.svg?longCache=true&style=flat-square">
  </a>
</p>

# File Picker

A Flutter plugin that lets you use the native file explorer to pick single or multiple files, with extension filtering, directory selection, and save-file dialogs, across Android, iOS, Linux, macOS, Windows, and Web.

This repository is a [Melos](https://melos.invertase.dev/) workspace hosting `file_picker` as a **federated plugin**: a single cross-platform API package on top of one implementation package per platform, all versioned and published independently.

## Packages

| Package | Pub | Description |
|---|---|---|
| [`file_picker`](packages/file_picker) | [![pub](https://img.shields.io/pub/v/file_picker.svg)](https://pub.dev/packages/file_picker) | The main package. Add this to your app, it pulls in the right platform implementation automatically. |
| [`file_picker_platform_interface`](packages/file_picker_platform_interface) | [![pub](https://img.shields.io/pub/v/file_picker_platform_interface.svg)](https://pub.dev/packages/file_picker_platform_interface) | The shared interface and data contracts (`PlatformFile`, `FileType`, platform option classes) every implementation builds on. |
| [`file_picker_darwin`](packages/file_picker_darwin) | [![pub](https://img.shields.io/pub/v/file_picker_darwin.svg)](https://pub.dev/packages/file_picker_darwin) | iOS and macOS implementation. |
| [`android_file_picker`](packages/file_picker_android) | [![pub](https://img.shields.io/pub/v/android_file_picker.svg)](https://pub.dev/packages/android_file_picker) | Android implementation, including Storage Access Framework (SAF) support. |
| [`file_picker_linux`](packages/file_picker_linux) | [![pub](https://img.shields.io/pub/v/file_picker_linux.svg)](https://pub.dev/packages/file_picker_linux) | Linux implementation, using GTK3 and XDG Desktop Portals. |
| [`windows_file_picker`](packages/file_picker_windows) | [![pub](https://img.shields.io/pub/v/windows_file_picker.svg)](https://pub.dev/packages/windows_file_picker) | Windows implementation, using the Win32 COM APIs. |
| [`file_picker_web`](packages/file_picker_web) | [![pub](https://img.shields.io/pub/v/file_picker_web.svg)](https://pub.dev/packages/file_picker_web) | Web implementation, including Wasm compilation support. |

Almost all apps should only ever depend on `file_picker` directly. The platform packages are pulled in transitively and registered automatically by Flutter's plugin system; you only reach for one of them directly if you need a platform-specific API that isn't exposed on the shared facade (for example `FilePickerDarwin.skipEntitlementsChecks()` on macOS).

## Quick start

```yaml
dependencies:
  file_picker: ^13.0.0
```

```dart
import 'package:file_picker/file_picker.dart';

final file = await FilePicker.pickFile();

if (file != null) {
  print(file.name);
  print(await file.length()); // Returns Future<int?> (or use file.lengthSync())
}
```

See [`packages/file_picker/README.md`](packages/file_picker/README.md) for the full feature list, platform compatibility chart, and more usage examples (multiple files, extension filters, directory picking, save-file dialogs).

## Migration

- **Upgrading to v13?** See the [Migrating to v13 Guide](packages/file_picker/README.md#migrating-to-v13) for details on `PlatformFile.length()` returning `Future<int?>` and the removal of legacy v12-deprecated parameters.
- **Upgrading from pre-v12?** See the [Migrating to v12 Guide](packages/file_picker/README.md#migrating-to-v12) for the federated architecture changes (`FilePicker.pickFiles()` returning `List<PlatformFile>`, platform options, and streaming).

## Documentation

- [`packages/file_picker/README.md`](packages/file_picker/README.md) for usage, platform compatibility chart, and [migration guides](packages/file_picker/README.md#migrating-to-v13).
- Platform-specific setup in each package's README (e.g. [`file_picker_darwin`](packages/file_picker_darwin/README.md) for macOS entitlements, [`android_file_picker`](packages/file_picker_android/README.md) for Android notes).
- [API reference on pub.dev](https://pub.dev/documentation/file_picker/latest/file_picker/FilePicker-class.html).
- [`packages/file_picker/CHANGELOG.md`](packages/file_picker/CHANGELOG.md) and each platform package's own `CHANGELOG.md` for release notes.

## Contributing

Contributions are welcome. Please read [`CONTRIBUTING.md`](CONTRIBUTING.md) before opening a pull request, it covers testing requirements, versioning, and changelog conventions for this workspace.

To work on this repository locally:

```sh
dart pub global activate melos
melos bootstrap
melos run analyze   # flutter analyze across every package
melos run test       # flutter test across every package
```

Each package keeps its own `pubspec.yaml` and `CHANGELOG.md` and is released independently, only the package(s) you actually changed need a version bump.

## Credits

`file_picker` was created and maintained by [Miguel Ruivo](https://github.com/miguelpruivo), starting in 2018, growing it from a single Android/iOS plugin into the federated, cross-platform package it is today. This repository continues that work under new ownership, built entirely on the foundation of his years of effort.

Thank you, Miguel.

## License

MIT, see [`LICENSE`](LICENSE). Every package in this repository is released under the same license.
