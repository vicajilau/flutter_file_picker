import 'dart:async';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';

/// A Web-specific implementation of [PlatformFile].
///
/// Wraps a file selected in a web environment. Its content is read on demand
/// through [xFile], from a `blob:` or `data:` URI.
base class WebPlatformFile extends PlatformFile {
  /// Creates a new [WebPlatformFile] instance.
  ///
  /// Requires a file [name] and [uri]. Optional parameters include the file
  /// size in [bytesLength] and an underlying [xFile]. Without [xFile], the
  /// content is read from [uri].
  WebPlatformFile({
    required this.name,
    required this.uri,
    XFile? xFile,
    int? bytesLength,
  }) : _xFile = xFile,
       _bytesLength = bytesLength {
    if (name.isEmpty) {
      throw ArgumentError('name cannot be empty');
    }
  }

  /// The name of the file including extension.
  @override
  final String name;

  /// The web URI representing this file (typically a `blob:` or `data:` URL).
  @override
  final Uri uri;

  @override
  String? get path => null;

  final XFile? _xFile;
  final int? _bytesLength;

  /// Returns an [XFile] instance representing this web file.
  @override
  XFile get xFile => _xFile ?? XFile.scopedStorage(uri: uri.toString());

  /// The browser's `File.size`, if known.
  @override
  int? lengthSync() {
    final len = _bytesLength;
    return (len != null && len > 0) ? len : null;
  }

  /// Asynchronously calculates and returns the size of the file in bytes.
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

  /// Reads the file content as a byte array (`Uint8List`).
  ///
  /// Throws if the content cannot be read.
  @override
  Future<Uint8List> readAsBytes() => xFile.readAsBytes();

  /// Opens a stream to read the file content in chunks.
  ///
  /// Read failures are emitted as errors on the stream.
  @override
  Stream<Uint8List> readAsByteStream() => xFile.openRead();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WebPlatformFile && other.name == name && other.uri == uri;
  }

  @override
  int get hashCode => Object.hash(name, uri);

  @override
  String toString() {
    return 'WebPlatformFile(name: $name, uri: $uri)';
  }
}
