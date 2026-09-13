# Security policy

## Reporting a vulnerability

Please report security issues privately, through GitHub's
[private vulnerability reporting](https://github.com/vicajilau/flutter_file_picker/security/advisories/new).
It is enabled on this repository, so the report stays between you and the
maintainers until there is a fix.

Do not open a public issue or pull request for something you believe is
exploitable. A normal issue is the right place for a crash or a bug that has no
security impact, and if you are unsure, report it privately and we will tell
you.

Useful things to include, as far as you have them: the affected package and
version, the platform, what an attacker controls, and the smallest reproduction
you can manage.

We aim to acknowledge a report within a week and to keep you updated while we
work on it. This is a small volunteer team, so please bear with us if a fix
takes longer than the acknowledgement.

## Supported versions

Security fixes go to the latest published version of each package. Older major
versions are not patched, so if you are on one, the fix will be an upgrade.

| Package | Supported |
| --- | --- |
| `file_picker` | Latest 13.x |
| `file_picker_platform_interface` | Latest 4.x |
| `android_file_picker` | Latest 2.x |
| `file_picker_darwin` | Latest 2.x |
| `file_picker_linux` | Latest 2.x |
| `file_picker_web` | Latest 4.x |
| `windows_file_picker` | Latest 2.x |

## What is in scope

This is a plugin that opens the platform's own file dialogs and hands the
results back to a Flutter app. The interesting boundary is what happens to a
file, a file name, or a URI on the way through. For example:

- Path handling that lets a crafted file name or a symlink reach somewhere it
  should not, including the temporary files `saveFile()` writes.
- Android SAF permission handling, such as a `content://` URI keeping access it
  should have lost, or persisted permissions being broader than requested.
- The macOS App Sandbox entitlement checks, including
  `skipEntitlementsChecks()`, if the escape hatch can be reached in a way the
  host app did not ask for.
- The native code in each implementation: the Kotlin plugin on Android, the
  Swift plugin on iOS and macOS, the Win32 Common Item Dialog calls on Windows,
  and the XDG Desktop Portal calls over DBus on Linux.
- Anything that lets a picked file influence the host app beyond returning its
  path, bytes or stream.

## What is out of scope

- Vulnerabilities in the operating system's own file dialogs or portals. Those
  belong upstream, with Apple, Google, Microsoft or the portal implementation.
- An app choosing to do something unsafe with a file the user deliberately
  picked. Validating file contents is the host app's job, this plugin does not
  inspect them.
- Reports from an automated scanner against a dependency, with no explanation
  of how it is reachable through this plugin. Those are welcome as normal
  issues.
- The example app under `example/`, which exists to demonstrate the API and is
  not shipped to anyone.
