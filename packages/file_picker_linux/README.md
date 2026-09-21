![File Picker for Linux](https://raw.githubusercontent.com/vicajilau/flutter_file_picker/main/.github/assets/readme_banner_linux.svg)

# file_picker_linux

The Linux implementation of `file_picker`.

## Usage

This package is endorsed, which means you can simply use `file_picker` as normal, and the Linux implementation will be automatically included.

## Linux specific options

Pass `LinuxOptions` for the options shared with other desktop platforms, or
`FilePickerLinuxOptions` when you also need `parentWindow`.

```dart
final file = await FilePicker.pickFile(
  linuxOptions: const FilePickerLinuxOptions(
    acceptLabel: 'Choose',
    lockParentWindow: true,
    parentWindow: 'x11:0x1c00007',
  ),
);
```

### `acceptLabel`

Replaces the text on the dialog's confirmation button. Only applies to file
picking (`pickFile`, `pickFiles`), the portal does not take it for directory
selection or saving.

### `lockParentWindow`

Sent to the portal as `modal`. On its own it has no visible effect: the portal
needs to know *which* window to be modal against, so it only locks the parent
once `parentWindow` is also set.

Whether you can set `parentWindow` at all depends on the session type, which
makes this option behave very differently on X11 and on Wayland:

| Session | Handle the portal expects | Practical result |
| --- | --- | --- |
| X11 | the window XID | obtainable, so the dialog is parented and genuinely modal |
| Wayland | an [`xdg_foreign`](https://wayland.app/protocols/xdg-foreign-unstable-v2) exported handle | Flutter does not expose one, so the dialog stays unparented and `lockParentWindow` has no visible effect |

Wayland is the default on current desktops, Ubuntu GNOME and Fedora included,
so the second row is the common case rather than the exception. The option is
still sent to the portal correctly, there is simply no window for the portal to
attach the dialog to.

If you need real modality today, the X11 path works. On a Wayland session the
app has to be running on XWayland, which `GDK_BACKEND=x11` forces:

```bash
GDK_BACKEND=x11 flutter run -d linux
```

The XID changes on every run, so it has to be read at runtime rather than
hardcoded. There is no Flutter API for it, so it takes an external tool such as
`xdotool`:

```dart
// Search for an X window belonging to this process. Do not use
// `xdotool getactivewindow`: with XWayland running it returns the focused X
// window, which on a Wayland session belongs to a different application.
final result = await Process.run(
  'xdotool',
  ['search', '--pid', '$pid', '--onlyvisible'],
);
final ids = (result.stdout as String)
    .split('\n')
    .map((line) => line.trim())
    .where((line) => line.isNotEmpty);

final file = await FilePicker.pickFile(
  linuxOptions: FilePickerLinuxOptions(
    lockParentWindow: true,
    parentWindow: ids.isEmpty ? null : ids.last, // e.g. 25165834
  ),
);
```

On a native Wayland session the search comes back empty, which is the correct
answer: the process genuinely has no X window to parent to.

`parentWindow` takes the decimal value directly and converts it, see the table
below. Depending on `xdotool` at runtime is obviously not great for a shipped
app, it is shown here because it is the only way to get the handle today.

### `parentWindow`

The window identifier handed to the portal so it can parent the dialog. Accepted
forms:

| You pass | Sent as |
| --- | --- |
| `x11:0x1c00007` | unchanged |
| `wayland:<handle>` | unchanged |
| `0x1c00007` | `x11:0x1c00007` |
| `29360135` (decimal) | `x11:0x1c00007` |
| `null` or empty | no parent window |

Flutter does not expose the native window handle, so obtaining it is on you.
See the session table under `lockParentWindow` for what that means in practice.

## Development

The DBus bindings in `lib/src/xdp_filechooser.dart` and `lib/src/xdp_request.dart` are generated using `dart-dbus` from the XDG Desktop Portal DBus interface specifications on Linux:

1. Install `dart-dbus` globally via Pub:

   ```bash
   dart pub global activate dbus
   ```

2. Regenerate bindings against a running DBus daemon or XML interface definition:

   ```bash
   dart-dbus generate-remote-object org.freedesktop.portal.FileChooser
   dart-dbus generate-remote-object org.freedesktop.portal.Request
   ```
