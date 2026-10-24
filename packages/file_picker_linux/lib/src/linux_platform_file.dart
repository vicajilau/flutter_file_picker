import 'dart:async';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
import 'package:path/path.dart' as p;

/// A [PlatformFile] implementation for Linux.
base class LinuxPlatformFile extends PlatformFile {
  LinuxPlatformFile({
    required this.name,
    required this.uri,
    XFile? xFile,
    int? bytesLength,
  }) : _xFile = xFile,
       _bytesLength = bytesLength;

  factory LinuxPlatformFile.fromPath(String path) {
    if (path.isEmpty) {
      throw ArgumentError(
        'path cannot be empty when creating LinuxPlatformFile',
      );
    }
    final uri = Uri.file(path);
    final name = p.posix.basename(path);
    return LinuxPlatformFile(name: name, uri: uri);
  }

  @override
  final String name;

  @override
  final Uri uri;

  final XFile? _xFile;
  final int? _bytesLength;

  @override
  XFile get xFile =>
      _xFile ??
      (uri.scheme == 'file'
          ? XFile.fileSystem(path: uri.toFilePath())
          : XFile.scopedStorage(uri: uri.toString()));

  /// Only known when this file was created with its bytes already in hand.
  ///
  /// XDG Desktop Portals return a path and no size, so a picked file reports
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
    return other is LinuxPlatformFile && other.name == name && other.uri == uri;
  }

  @override
  int get hashCode => Object.hash(name, uri);

  @override
  String toString() {
    return 'LinuxPlatformFile(name: $name, uri: $uri)';
  }
}
