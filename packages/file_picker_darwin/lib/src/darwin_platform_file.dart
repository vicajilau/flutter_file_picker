import 'dart:async';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
import 'package:path/path.dart' as p;

/// A [PlatformFile] implementation for Apple platforms (iOS and macOS).
base class DarwinPlatformFile extends PlatformFile {
  DarwinPlatformFile({
    required this.name,
    required this.uri,
    this.assetIdentifier,
    XFile? xFile,
    int? bytesLength,
  }) : _xFile = xFile,
       _bytesLength = bytesLength;

  factory DarwinPlatformFile.fromMap(Map<Object?, Object?> data) {
    final String path = data['path'] as String? ?? '';
    final String rawName = data['name'] as String? ?? '';
    final String name = rawName.isNotEmpty
        ? rawName
        : (path.isNotEmpty ? p.basename(path) : '');

    if (path.isEmpty && data['uri'] == null) {
      throw ArgumentError(
        'path or uri cannot be empty when creating DarwinPlatformFile',
      );
    }
    if (name.isEmpty) {
      throw ArgumentError(
        'name cannot be empty when creating DarwinPlatformFile',
      );
    }

    final Uri uri = path.isEmpty
        ? Uri.parse(data['uri']! as String)
        : path.contains('://')
        ? (Uri.tryParse(path) ?? Uri.file(path))
        : Uri.file(path);

    return DarwinPlatformFile(
      name: name,
      uri: uri,
      assetIdentifier: data['assetIdentifier'] as String?,
      bytesLength: data['size'] as int?,
    );
  }

  @override
  final String name;

  @override
  final Uri uri;

  /// The photo library identifier of media picked from the iOS photo library,
  /// or `null` for any other file.
  ///
  /// It identifies the original asset, so an app with photo library access
  /// can open it again later, for example through `photo_manager`, without
  /// the copy. With `DarwinOptions(copyMedia: false)` it is the only way to
  /// reach the content, since nothing is copied.
  final String? assetIdentifier;

  /// Whether this file only references a photo library asset, picked with
  /// `DarwinOptions(copyMedia: false)`, and has no readable copy: a `ph` URI
  /// and no [XFile] to read it through.
  bool get _isAssetReference => uri.scheme == 'ph' && _xFile == null;

  UnsupportedError get _assetReferenceError => UnsupportedError(
    'This file was picked with DarwinOptions(copyMedia: false), so it has no '
    'readable copy. Open the original asset by its assetIdentifier instead.',
  );

  final XFile? _xFile;
  final int? _bytesLength;

  @override
  XFile get xFile =>
      _xFile ??
      (uri.scheme == 'file'
          ? XFile.fileSystem(path: uri.toFilePath())
          : XFile.scopedStorage(uri: uri.toString()));

  /// The size iOS/macOS already reported for this file when it was picked.
  @override
  int? lengthSync() {
    final len = _bytesLength;
    return (len != null && len > 0) ? len : null;
  }

  @override
  Future<int?> length() async {
    if (_isAssetReference) return null;
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
    if (_isAssetReference) throw _assetReferenceError;
    return xFile.readAsBytes();
  }

  @override
  Stream<Uint8List> readAsByteStream() {
    if (_isAssetReference) return Stream.error(_assetReferenceError);
    return xFile.openRead();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DarwinPlatformFile &&
        other.name == name &&
        other.uri == uri;
  }

  @override
  int get hashCode => Object.hash(name, uri);

  @override
  String toString() {
    final asset = assetIdentifier == null
        ? ''
        : ', assetIdentifier: $assetIdentifier';
    return 'DarwinPlatformFile(name: $name, uri: $uri$asset)';
  }
}
