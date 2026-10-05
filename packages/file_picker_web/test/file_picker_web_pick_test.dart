@TestOn('browser')
library;

import 'dart:convert';
import 'dart:js_interop';

import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
import 'package:cross_file_web/cross_file_web.dart';
import 'package:file_picker_web/file_picker_web.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart';

void main() {
  setUpAll(() {
    FilePickerWeb.registerWith(webPluginRegistrar);
    CrossFileWeb.registerWith(webPluginRegistrar);
  });

  Future<List<PlatformFile>> pick(List<File> files) {
    final result = FilePickerPlatform.instance.pickFiles();

    final input =
        document.querySelector('flt-file-picker-inputs input')!
            as HTMLInputElement;
    final transfer = DataTransfer();
    for (final file in files) {
      transfer.items.add(file);
    }
    input.files = transfer.files;
    input.dispatchEvent(Event('change'));

    return result;
  }

  File fileWith({required String name, required String content}) =>
      File([utf8.encode(content).toJS].toJS, name);

  test('picked files point at a readable blob: URL', () async {
    final files = await pick([fileWith(name: 'a.txt', content: 'hello')]);

    expect(files.single.uri.scheme, 'blob');
    expect(utf8.decode(await files.single.readAsBytes()), 'hello');
  });

  test('an empty picked file still gets a blob: URL', () async {
    final files = await pick([fileWith(name: 'empty.txt', content: '')]);

    expect(files.single.uri.scheme, 'blob');
    expect(await files.single.readAsBytes(), isEmpty);
  });
}
