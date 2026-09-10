import 'dart:async';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';

import 'platform_file_web_fetch.dart';

/// A Web-specific implementation of [PlatformFile].
///
/// Wraps files selected or processed in a web environment, providing
/// access to file metadata, underlying bytes, stream readers, and `blob:` or
/// `data:` URIs.
base class WebPlatformFile extends PlatformFile {
  /// Creates a new [WebPlatformFile] instance.
  ///
  /// Requires a file [name] and [uri]. Optional parameters include preloaded
  /// [bytes], a custom [readStream], file size in [bytesLength], or an underlying [xFile].
  WebPlatformFile({
    required this.name,
    required this.uri,
    XFile? xFile,
    int? bytesLength,
    Uint8List? bytes,
    Stream<Uint8List>? readStream,
  }) : _xFile = xFile,
       _bytesLength = bytesLength,
       _bytes = bytes,
       _readStream = readStream {
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
  final Uint8List? _bytes;
  final Stream<Uint8List>? _readStream;

  /// Returns an [XFile] instance representing this web file.
  @override
  XFile get xFile {
    final file = _xFile;
    if (file != null) return file;
    return XFile(uri.toString(), name: name, bytes: _bytes);
  }

  /// The browser's `File.size`, or the loaded bytes' length.
  @override
  int? lengthSync() {
    final len = _bytesLength;
    if (len != null && len > 0) return len;
    return _bytes?.length;
  }

  /// Asynchronously calculates and returns the size of the file in bytes.
  @override
  Future<int?> length() async {
    final len = _bytesLength;
    if (len != null && len > 0) return len;
    final bytes = _bytes;
    if (bytes != null) return bytes.length;
    try {
      return await xFile.length();
    } catch (_) {
      return null;
    }
  }

  /// Asynchronously reads the file content as a byte array (`Uint8List`).
  ///
  /// If bytes are cached or readable from a `blob:`/`data:` URL, they will be
  /// retrieved directly; otherwise falls back to [xFile].
  @override
  Future<Uint8List> readAsBytes() async {
    final bytes = _bytes;
    if (bytes != null) return bytes;

    // Try fetching from blob or data URL
    final fetched = await fetchBytesFromWebPath(uri.toString());
    if (fetched != null) return fetched;

    return xFile.readAsBytes();
  }

  /// Asynchronously opens a stream to read the file content in chunks.
  @override
  Stream<Uint8List> readAsByteStream() async* {
    final readStream = _readStream;
    if (readStream != null) {
      yield* readStream;
      return;
    }

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
