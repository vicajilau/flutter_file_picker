import 'dart:async';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
import 'package:path/path.dart' as p;

import 'android_saf_handle.dart';

/// A [PlatformFile] implementation for Android.
base class AndroidPlatformFile extends PlatformFile {
  /// Creates a new [AndroidPlatformFile] instance from the given [name], [uri] and [safHandle].
  AndroidPlatformFile({
    required this.name,
    required this.uri,
    this.safHandle,
    XFile? xFile,
    int? bytesLength,
  }) : _xFile = xFile,
       _bytesLength = bytesLength;

  /// Creates an [AndroidPlatformFile] from a platform channel map payload.
  factory AndroidPlatformFile.fromMap(Map<Object?, Object?> data) {
    final String path = data['path'] as String? ?? '';
    final String rawName = data['name'] as String? ?? '';
    final String name = rawName.isNotEmpty
        ? rawName
        : (path.isNotEmpty ? p.basename(path) : '');

    if (path.isEmpty && data['uri'] == null) {
      throw ArgumentError(
        'path or uri cannot be empty when creating AndroidPlatformFile',
      );
    }
    if (name.isEmpty) {
      throw ArgumentError(
        'name cannot be empty when creating AndroidPlatformFile',
      );
    }

    final Uri uri = path.contains('://')
        ? (Uri.tryParse(path) ?? Uri.file(path))
        : Uri.file(path);

    AndroidSAFHandle? safHandle;
    if (data case {'safHandle': final Map<Object?, Object?> safMap}) {
      safHandle = AndroidSAFHandle.fromMap(safMap);
    }

    final Uint8List? bytes = data['bytes'] as Uint8List?;

    return AndroidPlatformFile(
      name: name,
      uri: uri,
      safHandle: safHandle,
      xFile: path.isNotEmpty ? XFile(path, name: name, bytes: bytes) : null,
      bytesLength: bytes?.lengthInBytes ?? (data['size'] as int?),
    );
  }

  @override
  final String name;

  @override
  final Uri uri;

  /// The handle to the Storage Access Framework URI, if applicable.
  final AndroidSAFHandle? safHandle;

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

  /// The size Android already reported for this file when it was picked.
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
    return other is AndroidPlatformFile &&
        other.name == name &&
        other.uri == uri &&
        other.safHandle == safHandle;
  }

  @override
  int get hashCode => Object.hash(name, uri, safHandle);

  @override
  String toString() {
    return 'AndroidPlatformFile(name: $name, uri: $uri, safHandle: $safHandle)';
  }
}
