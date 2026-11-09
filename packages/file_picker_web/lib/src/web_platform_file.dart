import 'dart:async';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';

import 'platform_file_web_fetch.dart';

/// A Web-specific implementation of [PlatformFile].
///
/// Wraps a file selected in a web environment. Its content is read on demand
/// from a `blob:` or `data:` URI.
base class WebPlatformFile extends PlatformFile {
  /// Creates a new [WebPlatformFile] instance.
  ///
  /// Requires a file [name] and [uri]. Optional parameters include the file
  /// size in [bytesLength] and an underlying [xFile].
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
  XFile get xFile {
    final file = _xFile;
    if (file != null) return file;
    return XFile(uri.toString(), name: name);
  }

  /// The browser's `File.size`, if known.
  @override
  int? lengthSync() {
    return _bytesLength;
  }

  /// Asynchronously calculates and returns the size of the file in bytes.
  @override
  Future<int?> length() async {
    final len = _bytesLength;
    if (len != null) return len;
    try {
      return await xFile.length();
    } catch (_) {
      return null;
    }
  }

  /// Asynchronously reads the file content as a byte array (`Uint8List`).
  ///
  /// Reads a `blob:` or `data:` URL directly, otherwise falls back to [xFile].
  @override
  Future<Uint8List> readAsBytes() async {
    // Try fetching from blob or data URL
    final fetched = await fetchBytesFromWebPath(uri.toString());
    if (fetched != null) return fetched;

    return xFile.readAsBytes();
  }

  /// The size of the chunks emitted by [readAsByteStream].
  static const int streamChunkSize = webStreamChunkSize;

  /// Asynchronously opens a stream to read the file content in chunks.
  ///
  /// Every chunk is [streamChunkSize] bytes long except the last one, which
  /// may be shorter, so consumers can rely on evenly sized buffers.
  @override
  Stream<Uint8List> readAsByteStream() async* {
    final webStream = fetchStreamFromWebPath(uri.toString());
    if (webStream != null) {
      yield* webStream;
      return;
    }

    yield* xFile.openRead();
  }

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
