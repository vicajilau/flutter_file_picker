## 2.0.1

- Raised the `dbus` dependency lower bound to `^0.8.0`.

## 2.0.0

- **BREAKING CHANGE**: `PlatformFile.length()` now returns `Future<int?>` instead of `Future<int>`. Returns `null` when the length could not be determined (e.g. a failed disk read), instead of `0`, matching `lengthSync()`. [#2197](https://github.com/vicajilau/flutter_file_picker/issues/2197)

## 1.1.0

- Implemented `PlatformFile.lengthSync()`. XDG Desktop Portals only return a file path, not its size, so this returns `null` on Linux, use `length()` to actually read it from disk.

## 1.0.2

- Fixed `LinuxOptions.lockParentWindow` and `LinuxOptions.acceptLabel` being silently ignored. Passing a plain `LinuxOptions` fell back to a default `FilePickerLinuxOptions`, dropping whatever the caller had set, which is the exact API the deprecation on `FilePicker.pickFiles` points to. [#2183](https://github.com/vicajilau/flutter_file_picker/issues/2183)
- `FilePickerLinuxOptions` now accepts `acceptLabel`, so it no longer has to be traded away in order to set `parentWindow`.
- Documented the Linux specific options in the README, including that `lockParentWindow` needs `parentWindow` to have any visible effect.
- Expanded the package example to show resolving `parentWindow` at runtime, which is what makes `lockParentWindow` lock anything.
- Tightened the `file_picker_platform_interface` lower bound to `^3.2.0`. This package's `pickFile()`/`pickFiles()` signatures reference `DarwinOptions`, added in that version, so resolving against an older one would fail to compile.

## 1.0.1

- Relax `dbus` to `^0.7.13` so dependents can resolve `xml` 7. [#2130](https://github.com/vicajilau/flutter_file_picker/issues/2130)
- Improved package description, added example, and added missing API documentation.

## 1.0.0

- Initial release of Linux implementation package for `file_picker`.
- Added support for `acceptLabel` in `LinuxOptions` to customize the confirmation button label in file dialogs. [#2120](https://github.com/vicajilau/flutter_file_picker/pull/2120)
