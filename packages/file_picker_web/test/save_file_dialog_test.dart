@TestOn('browser')
library;

import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
import 'package:file_picker_web/file_picker_web.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart';

extension on Window {
  @JS('showSaveFilePicker')
  external JSFunction? get showSaveFilePicker;

  @JS('showSaveFilePicker')
  external set showSaveFilePicker(JSFunction? value);
}

extension type _AnchorPrototype._(JSObject _) implements JSObject {
  external JSFunction get click;
  external set click(JSFunction value);
}

@JS('HTMLAnchorElement.prototype')
external _AnchorPrototype get _anchorPrototype;

@JS('Promise.reject')
external JSPromise<JSObject> _rejectedPromise(JSAny reason);

/// The writable stream of [_FakeFileHandle], recording what is written.
@JSExport()
class _FakeWritable {
  final List<Uint8List> written = [];
  bool closed = false;

  JSPromise<JSAny?> write(JSUint8Array data) {
    written.add(data.toDart);
    return Future<JSAny?>.value().toJS;
  }

  JSPromise<JSAny?> close() {
    closed = true;
    return Future<JSAny?>.value().toJS;
  }
}

/// The file handle `showSaveFilePicker()` resolves with when the user saves.
@JSExport()
class _FakeFileHandle {
  _FakeFileHandle(this.name);

  final String name;
  final writable = _FakeWritable();

  JSPromise<JSObject> createWritable() =>
      Future.value(createJSInteropWrapper(writable)).toJS;
}

void main() {
  final bytes = Uint8List.fromList(utf8.encode('hello'));

  late final FilePickerWeb picker;
  late final JSFunction? originalSaveFilePicker;
  late final JSFunction originalAnchorClick;

  final downloads = <String>[];
  final pickerCalls = <Map<Object?, Object?>>[];

  setUpAll(() {
    FilePickerWeb.registerWith(webPluginRegistrar);
    picker = FilePickerPlatform.instance as FilePickerWeb;
    originalSaveFilePicker = window.showSaveFilePicker;
    originalAnchorClick = _anchorPrototype.click;
  });

  setUp(() {
    downloads.clear();
    pickerCalls.clear();
    // Record downloads instead of triggering them.
    _anchorPrototype.click = ((HTMLAnchorElement anchor) {
      downloads.add(anchor.download);
    }).toJSCaptureThis;
  });

  // Leave the browser as each test found it, so no test depends on what an
  // earlier one replaced or removed.
  tearDown(() {
    window.showSaveFilePicker = originalSaveFilePicker;
    _anchorPrototype.click = originalAnchorClick;
  });

  /// Replaces `showSaveFilePicker` with one that records its options and
  /// completes with [respond].
  void stubPicker(JSPromise<JSObject> Function() respond) {
    window.showSaveFilePicker = ((JSObject options) {
      pickerCalls.add(options.dartify()! as Map<Object?, Object?>);
      return respond();
    }).toJS;
  }

  /// Makes `showSaveFilePicker` reject with a `DOMException` named [name].
  void stubPickerError(String name) {
    stubPicker(() => _rejectedPromise(DOMException('', name)));
  }

  Future<Uri?> save({WebSaveFileMode? saveMode}) {
    return picker.saveFile(
      fileName: 'report.txt',
      bytes: bytes,
      mimeType: 'text/plain',
      webOptions: saveMode == null
          ? const WebOptions()
          : FilePickerWebOptions(saveMode: saveMode),
    );
  }

  test('saves through the dialog and returns the chosen name', () async {
    final handle = _FakeFileHandle('chosen.txt');
    stubPicker(() => Future.value(createJSInteropWrapper(handle)).toJS);

    final uri = await save(saveMode: WebSaveFileMode.dialog);

    expect(uri, Uri(path: 'chosen.txt'));
    expect(uri!.scheme, isEmpty);
    expect(uri.hasAuthority, isFalse);
    expect(uri.hasQuery, isFalse);
    expect(uri.hasFragment, isFalse);
    expect(downloads, isEmpty);
    expect(handle.writable.written.map(utf8.decode), ['hello']);
    expect(handle.writable.closed, isTrue);
    expect(pickerCalls.single['suggestedName'], 'report.txt');
    expect(pickerCalls.single['types'], [
      {
        'accept': {
          'text/plain': ['.txt'],
        },
      },
    ]);
  });

  test('returns null without downloading when the user cancels', () async {
    stubPickerError('AbortError');

    expect(await save(saveMode: WebSaveFileMode.dialog), isNull);
    expect(pickerCalls, hasLength(1));
    expect(downloads, isEmpty);
  });

  test(
    'falls back to a download when the browser refuses the dialog',
    () async {
      stubPickerError('SecurityError');

      expect(await save(saveMode: WebSaveFileMode.dialog), isNull);
      expect(pickerCalls, hasLength(1));
      expect(downloads, ['report.txt']);
    },
  );

  test('throws without downloading when the dialog is not supported', () async {
    window.showSaveFilePicker = null;

    expect(supportsShowSaveFileDialog, isFalse);
    await expectLater(
      save(saveMode: WebSaveFileMode.dialog),
      throwsUnsupportedError,
    );
    expect(downloads, isEmpty);
  });

  // Stubbed so the test does not depend on the browser running it, since
  // only Chromium based browsers ship the API.
  test('reports support when the dialog is available', () {
    stubPickerError('AbortError');

    expect(supportsShowSaveFileDialog, isTrue);
  });

  test('downloads without opening the dialog by default', () async {
    stubPickerError('NotAllowedError');

    expect(await save(), isNull);
    expect(await save(saveMode: WebSaveFileMode.download), isNull);
    expect(pickerCalls, isEmpty);
    expect(downloads, ['report.txt', 'report.txt']);
  });
}
