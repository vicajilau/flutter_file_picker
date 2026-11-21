![File Picker for Web](https://raw.githubusercontent.com/vicajilau/flutter_file_picker/main/.github/assets/readme_banner_web.svg)

# file_picker_web

The Web implementation of [`file_picker`](https://pub.dev/packages/file_picker).

## Usage

This package is endorsed, which means you can simply use `file_picker` as normal, and the Web implementation will be automatically included.

## Saving large files

`FilePicker.saveFile()` builds a `Blob` from the bytes you give it, so the whole file is held in memory. Avoid saving large files on web. Safari, for one, cannot build a `Blob` of 2 GiB (2147483648 bytes) or more, and closes the tab. On Safari 27.2 a file of 2047 MB saved and one of 2049 MB failed. The package does not decide it, since a page with no Flutter fails the same way. Saving a large file properly needs a way to stream it into a file handle, which `saveFile()` does not offer yet. Reading a file that size works, because `PlatformFile.readAsByteStream()` reads it in chunks.

## WebAssembly in Safari and Firefox

`flutter build web --wasm` also builds a JavaScript version, and the loader decides which one each browser runs. With Flutter 3.50, only Chrome runs the WebAssembly version by default. Safari 26.2 or later and Firefox 147 or later run the JavaScript one, until they are enabled by default in a future stable release. To try WebAssembly there, allow them in `web/flutter_bootstrap.js`:

```js
{{flutter_js}}
{{flutter_build_config}}
_flutter.loader.load({
  config: {
    wasmAllowList: {
      blink: true,
      webkit: true,
      gecko: true,
    },
  },
});
```

Without it, testing this package on Safari tests the JavaScript version. See the [Flutter 3.50 announcement](https://flutter.dev/blog/whats-new-in-flutter-3-50). This package was tried with WebAssembly on Safari 27.2.
