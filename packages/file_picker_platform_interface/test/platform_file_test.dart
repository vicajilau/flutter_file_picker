import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

base class _TestPlatformFile extends PlatformFile {
  _TestPlatformFile(this.name);

  @override
  final String name;

  @override
  Uri get uri => Uri.file(name);

  @override
  XFile get xFile => XFile(name);

  @override
  int? lengthSync() => null;

  @override
  Future<int?> length() async => 0;

  @override
  Future<Uint8List> readAsBytes() async => Uint8List(0);

  @override
  Stream<Uint8List> readAsByteStream() => const Stream.empty();
}

void main() {
  group('PlatformFile.extension', () {
    test('returns the extension without the leading dot', () {
      expect(_TestPlatformFile('report.pdf').extension, 'pdf');
    });

    test('returns the last extension for multi-dot names', () {
      expect(_TestPlatformFile('archive.tar.gz').extension, 'gz');
    });

    test('returns null when there is no extension', () {
      expect(_TestPlatformFile('README').extension, isNull);
    });

    test('returns null for a dotfile with no other dot', () {
      expect(_TestPlatformFile('.gitignore').extension, isNull);
    });

    test('returns the extension for a dotfile with a real extension', () {
      expect(_TestPlatformFile('.env.local').extension, 'local');
    });
  });
}
