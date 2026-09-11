import 'dart:async';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
import 'package:path/path.dart' as p;

/// A [PlatformFile] implementation for Windows.
base class WindowsPlatformFile extends PlatformFile {
  WindowsPlatformFile({
    required this.name,
    required this.uri,
    XFile? xFile,
    int? bytesLength,
  }) : _xFile = xFile,
       _bytesLength = bytesLength;

  factory WindowsPlatformFile.fromPath(String path, {Uint8List? bytes}) {
    if (path.isEmpty) {
      throw ArgumentError(
        'path cannot be empty when creating WindowsPlatformFile',
      );
    }
    final uri = Uri.file(path, windows: true);
    final name = p.windows.basename(path);
    return WindowsPlatformFile(
      name: name,
      uri: uri,
      xFile: XFile(path, name: name, bytes: bytes),
      bytesLength: bytes?.lengthInBytes,
    );
  }

  @override
  final String name;

  @override
  final Uri uri;

  final XFile? _xFile;
  final int? _bytesLength;

  @override
  XFile get xFile {
    final file = _xFile;
    if (file != null) return file;
    if (uri.scheme == 'file') {
      return XFile(uri.toFilePath(), name: name);
    }
    return XFile(uri.toString(), name: name);
  }

  /// Only known when this file was created with its bytes already in hand.
  ///
  /// The native dialog returns a path and no size, so a picked file reports
  /// `null` here and [length] has to read the file to answer.
  @override
  int? lengthSync() {
    final len = _bytesLength;
    return (len != null && len > 0) ? len : null;
  }

  @override
  Future<int?> length() async {
    final len = _bytesLength;
    if (len != null && len > 0) return len;
    try {
      return await xFile.length();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Uint8List> readAsBytes() async {
    return xFile.readAsBytes();
  }

  @override
  Stream<Uint8List> readAsByteStream() {
    return xFile.openRead();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WindowsPlatformFile &&
        other.name == name &&
        other.uri == uri;
  }

  @override
  int get hashCode => Object.hash(name, uri);

  @override
  String toString() {
    return 'WindowsPlatformFile(name: $name, uri: $uri)';
  }
}
