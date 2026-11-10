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
  _FakeWritable([this.failAt]);

  final String? failAt;
  final List<Uint8List> written = [];
  bool closed = false;

  JSPromise<JSAny?> write(JSUint8Array data) {
    if (failAt == 'write') {
      return Future<JSAny?>.error(StateError('write failed')).toJS;
    }
    written.add(data.toDart);
    return Future<JSAny?>.value().toJS;
  }

  JSPromise<JSAny?> close() {
    if (failAt == 'close') {
      return Future<JSAny?>.error(StateError('close failed')).toJS;
    }
    closed = true;
    return Future<JSAny?>.value().toJS;
  }
}

/// The file handle `showSaveFilePicker()` resolves with when the user saves.
@JSExport()
class _FakeFileHandle {
  _FakeFileHandle(this.name, {String? failAt})
    : writable = _FakeWritable(failAt);

  final String name;
  final _FakeWritable writable;

  JSPromise<JSObject> createWritable() => writable.failAt == 'createWritable'
      ? Future<JSObject>.error(StateError('createWritable failed')).toJS
      : Future.value(createJSInteropWrapper(writable)).toJS;
}

void main() {
  final bytes = Uint8List.fromList(utf8.encode('hello'));

  late final FilePickerWeb picker;
  late final JSFunction? originalSaveFilePicker;
  late final JSFunction originalAnchorClick;

  final downloads = <String>[];
  final pickerCalls = <Map<Object?, Object?>>[];
  final savingStatuses = <FilePickerStatus>[];

  setUpAll(() {
    FilePickerWeb.registerWith(webPluginRegistrar);
    picker = FilePickerPlatform.instance as FilePickerWeb;
    originalSaveFilePicker = window.showSaveFilePicker;
    originalAnchorClick = _anchorPrototype.click;
  });

  setUp(() {
    downloads.clear();
    pickerCalls.clear();
    savingStatuses.clear();
    // Record downloads instead of triggering them.
    _anchorPrototype.click = ((HTMLAnchorElement anchor) {
      downloads.add(anchor.download);
    }).toJSCaptureThis;
  });

  tearDown(() {
    window.showSaveFilePicker = originalSaveFilePicker;
    _anchorPrototype.click = originalAnchorClick;
    expect(savingStatuses, isEmpty);
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

  Future<Uri?> save({
    WebSaveFileMode? saveMode,
    Function(FilePickerStatus)? onFileSaving,
  }) {
    return picker.saveFile(
      fileName: 'report.txt',
      bytes: bytes,
      mimeType: 'text/plain',
      onFileSaving: onFileSaving ?? savingStatuses.add,
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

  test('empty downloads leave Web saving callbacks unused', () async {
    final statuses = <FilePickerStatus>[];
    final uri = await picker.saveFile(
      fileName: 'empty.txt',
      bytes: Uint8List(0),
      mimeType: 'text/plain',
      onFileSaving: statuses.add,
    );

    expect(uri, isNull);
    expect(downloads, ['empty.txt']);
    expect(statuses, isEmpty);
  });

  test('writes an empty file through the native browser dialog', () async {
    final handle = _FakeFileHandle('empty.txt');
    stubPicker(() => Future.value(createJSInteropWrapper(handle)).toJS);
    final statuses = <FilePickerStatus>[];

    final uri = await picker.saveFile(
      fileName: 'empty.txt',
      bytes: Uint8List(0),
      mimeType: 'text/plain',
      onFileSaving: statuses.add,
      webOptions: const FilePickerWebOptions(saveMode: WebSaveFileMode.dialog),
    );

    expect(uri, Uri(path: 'empty.txt'));
    expect(handle.writable.written, hasLength(1));
    expect(handle.writable.written.single, isEmpty);
    expect(handle.writable.closed, isTrue);
    expect(statuses, isEmpty);
  });

  test('cancel leaves Web save callbacks unused', () async {
    stubPickerError('AbortError');
    final statuses = <FilePickerStatus>[];

    expect(
      await save(saveMode: WebSaveFileMode.dialog, onFileSaving: statuses.add),
      isNull,
    );
    expect(statuses, isEmpty);
    expect(downloads, isEmpty);
  });

  test('unsupported dialog propagates without Web save callbacks', () async {
    window.showSaveFilePicker = null;
    final statuses = <FilePickerStatus>[];

    await expectLater(
      save(saveMode: WebSaveFileMode.dialog, onFileSaving: statuses.add),
      throwsUnsupportedError,
    );
    expect(statuses, isEmpty);
  });

  test('downloads without opening the dialog by default', () async {
    stubPickerError('NotAllowedError');

    expect(await save(), isNull);
    expect(await save(saveMode: WebSaveFileMode.download), isNull);
    expect(pickerCalls, isEmpty);
    expect(downloads, ['report.txt', 'report.txt']);
  });

  for (final failAt in ['createWritable', 'write', 'close']) {
    test('preserves $failAt errors without Web save callbacks', () async {
      final handle = _FakeFileHandle('report.txt', failAt: failAt);
      stubPicker(() => Future.value(createJSInteropWrapper(handle)).toJS);
      final statuses = <FilePickerStatus>[];

      await expectLater(
        save(saveMode: WebSaveFileMode.dialog, onFileSaving: statuses.add),
        throwsA(anything),
      );
      expect(statuses, isEmpty);
      expect(downloads, isEmpty);
    });
  }

  test('fallback downloads without Web save callbacks', () async {
    stubPickerError('SecurityError');
    final statuses = <FilePickerStatus>[];

    expect(
      await save(saveMode: WebSaveFileMode.dialog, onFileSaving: statuses.add),
      isNull,
    );
    expect(downloads, ['report.txt']);
    expect(statuses, isEmpty);
  });

  test(
    'ignores an unsupported callback without disrupting the dialog write',
    () async {
      final handle = _FakeFileHandle('report.txt');
      stubPicker(() => Future.value(createJSInteropWrapper(handle)).toJS);
      final statuses = <FilePickerStatus>[];

      final uri = await save(
        saveMode: WebSaveFileMode.dialog,
        onFileSaving: (status) {
          statuses.add(status);
          throw StateError('callback must not run');
        },
      );
      expect(uri, Uri(path: 'report.txt'));
      expect(handle.writable.closed, isTrue);
      expect(statuses, isEmpty);
    },
  );
}
