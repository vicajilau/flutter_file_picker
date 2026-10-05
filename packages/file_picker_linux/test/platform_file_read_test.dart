import 'dart:convert';
import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:cross_file_io/cross_file_io.dart';
import 'package:file_picker_linux/file_picker_linux.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  late String path;

  setUpAll(CrossFileIO.registerWith);

  setUp(() {
    dir = Directory.systemTemp.createTempSync('file_picker_test');
    path = '${dir.path}${Platform.pathSeparator}notes.txt';
    File(path).writeAsStringSync('hello file_picker');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test('reads a picked file through cross_file', () async {
    final file = LinuxPlatformFile.fromPath(path);

    expect(file.xFile, isA<FileSystemXFile>());
    expect((file.xFile as FileSystemXFile).path, path);
    expect(utf8.decode(await file.readAsBytes()), 'hello file_picker');
    expect(
      utf8.decode(await file.readAsByteStream().expand((c) => c).toList()),
      'hello file_picker',
    );
    expect(await file.length(), 17);
  });
}
