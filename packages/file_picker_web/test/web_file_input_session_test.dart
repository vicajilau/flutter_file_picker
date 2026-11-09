@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
import 'package:file_picker_web/file_picker_web.dart';
import 'package:file_picker_web/src/web_file_input_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart';

void main() {
  late HTMLDivElement target;

  setUp(() {
    target = HTMLDivElement();
    document.body!.append(target);
  });

  tearDown(() => target.remove());

  WebFileInputSession createSession({
    FilePickerWebOptions webOptions = const FilePickerWebOptions(),
    Function(FilePickerStatus)? onFileLoading,
  }) {
    return WebFileInputSession(
      target: target,
      accept: '',
      allowMultiple: false,
      webOptions: webOptions,
      onFileLoading: onFileLoading,
      processFiles: (files, _) async => [
        for (var i = 0; i < files.length; i++)
          WebPlatformFile(
            name: files.item(i)!.name,
            uri: Uri.parse('blob:test'),
          ),
      ],
    );
  }

  HTMLInputElement attachedInput() => target.firstChild! as HTMLInputElement;

  void selectFile(HTMLInputElement input, String name) {
    final transfer = DataTransfer();
    transfer.items.add(File(<JSAny>[].toJS, name));
    input.files = transfer.files;
  }

  test('keeps the input attached while the dialog is open', () async {
    final result = createSession().start();

    expect(target.childNodes.length, 1);
    expect(target.firstChild, isA<HTMLInputElement>());

    attachedInput().dispatchEvent(Event('cancel'));
    expect(await result, isNull);
  });

  test(
    'completes with the selected file on change and detaches the input',
    () async {
      final result = createSession().start();
      final input = attachedInput();

      selectFile(input, 'a.pdf');
      input.dispatchEvent(Event('change'));

      final files = await result;
      expect(files?.single.name, 'a.pdf');
      expect(target.childNodes.length, 0);
    },
  );

  test(
    'completes with null when the window regains focus without a selection',
    () async {
      final result = createSession().start();

      window.dispatchEvent(Event('focus'));

      expect(await result, isNull);
      expect(target.childNodes.length, 0);
    },
  );

  test(
    'uses the selection when focus returns before the change event',
    () async {
      final result = createSession().start();

      selectFile(attachedInput(), 'b.png');
      window.dispatchEvent(Event('focus'));

      final files = await result;
      expect(files?.single.name, 'b.png');
      expect(target.childNodes.length, 0);
    },
  );

  test('notifies status completion even when the user cancels', () async {
    final statuses = <FilePickerStatus>[];
    final result = createSession(onFileLoading: statuses.add).start();

    attachedInput().dispatchEvent(Event('cancel'));

    expect(await result, isNull);
    expect(statuses, [FilePickerStatus.picking, FilePickerStatus.done]);
  });

  test('completes with null on the input cancel event', () async {
    final result = createSession(
      webOptions: const FilePickerWebOptions(cancelUploadOnWindowBlur: false),
    ).start();

    attachedInput().dispatchEvent(Event('cancel'));

    expect(await result, isNull);
  });

  test('completes with an error when processing the files fails', () async {
    final session = WebFileInputSession(
      target: target,
      accept: '',
      allowMultiple: false,
      webOptions: const FilePickerWebOptions(),
      onFileLoading: null,
      processFiles: (_, _) async => throw StateError('read failed'),
    );
    final result = session.start();
    final input = attachedInput();

    selectFile(input, 'big.bin');
    input.dispatchEvent(Event('change'));

    await expectLater(result, throwsStateError);
  });
}
