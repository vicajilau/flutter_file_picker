import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
import 'package:meta/meta.dart';
import 'package:web/web.dart';

import 'platform_file_web_fetch.dart';

/// A Web-specific implementation of [PlatformFile].
///
/// Wraps files selected or processed in a web environment, providing
/// access to file metadata, underlying bytes, stream readers, and `blob:` or
/// `data:` URIs.
base class WebPlatformFile extends PlatformFile {
  /// Creates a new [WebPlatformFile] instance.
  ///
  /// Requires [name] and either [uri] or [sourceFile]. Optional parameters
  /// include preloaded [bytes], a custom [readStream], the file size in
  /// [bytesLength], and an underlying [xFile].
  WebPlatformFile({
    required this.name,
    Uri? uri,
    File? sourceFile,
    XFile? xFile,
    int? bytesLength,
    Uint8List? bytes,
    Stream<Uint8List>? readStream,
  }) : _sourceFile = sourceFile,
       _explicitUri = uri,
       _xFile = xFile,
       _bytesLength = bytesLength,
       _bytes = bytes,
       _readStream = readStream {
    if (name.isEmpty) {
      throw ArgumentError('name cannot be empty');
    }
    if (uri == null && sourceFile == null) {
      throw ArgumentError('uri or sourceFile must be provided');
    }
  }

  /// The name of the file including extension.
  @override
  final String name;

  final File? _sourceFile;
  final Uri? _explicitUri;
  Uri? _createdObjectUrl;

  /// The web URI representing this file (typically a `blob:` or `data:` URL).
  ///
  /// A browser file does not need a global object URL merely to read its bytes
  /// or name. Create one lazily only when a caller actually requests [uri].
  @override
  Uri get uri =>
      _explicitUri ??
      (_createdObjectUrl ??= Uri.parse(URL.createObjectURL(_sourceFile!)));

  /// Whether this instance created a browser object URL on demand.
  @visibleForTesting
  bool get hasCreatedObjectUrl => _createdObjectUrl != null;

  /// Revokes an object URL created by this instance. Files can still be read
  /// directly from the browser [File]. A future [uri] access creates a new URL.
  /// This does not revoke a URI supplied by the caller.
  void releaseObjectUrl() {
    final created = _createdObjectUrl;
    if (created == null) return;
    URL.revokeObjectURL(created.toString());
    _createdObjectUrl = null;
  }

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
  /// Returns cached bytes first, then reads directly from the browser [File]
  /// when available, and otherwise uses a `blob:` or `data:` URL.
  @override
  Future<Uint8List> readAsBytes() async {
    final bytes = _bytes;
    if (bytes != null) return bytes;

    final sourceFile = _sourceFile;
    if (sourceFile != null) {
      final buffer = await sourceFile.arrayBuffer().toDart;
      return buffer.toDart.asUint8List();
    }

    // Fallback for WebPlatformFile instances created with a blob/data URI.
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
    final readStream = _readStream;
    if (readStream != null) {
      yield* readStream;
      return;
    }

    final sourceFile = _sourceFile;
    if (sourceFile != null) {
      yield* streamBlobInChunks(sourceFile);
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
    return other is WebPlatformFile &&
        other.name == name &&
        (other._explicitUri ?? other._sourceFile) ==
            (_explicitUri ?? _sourceFile);
  }

  @override
  int get hashCode => Object.hash(name, _explicitUri ?? _sourceFile);

  @override
  String toString() {
    return 'WebPlatformFile(name: $name, uri: $uri)';
  }
}
