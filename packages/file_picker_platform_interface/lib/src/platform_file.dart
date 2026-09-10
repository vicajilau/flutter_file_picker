import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:path/path.dart' as p;

/// The abstract representation of a picked file on the current platform.
///
/// Depending on the current platform,
/// an implementation may provide additional properties or methods specific to that platform.
abstract base class PlatformFile {
  /// The name of the underlying file, including the extension.
  String get name;

  /// The file extension of [name], without the leading dot, or `null` if
  /// [name] has none.
  ///
  /// Delegates to `package:path`'s `extension()` for the parsing (so a
  /// dotfile like `.gitignore` does not count as an extension), stripping
  /// the leading dot it includes to match [name]'s own convention and the
  /// rest of this package's API (`allowedExtensions` is also dot-less).
  String? get extension {
    final ext = p.extension(name);
    return ext.isEmpty ? null : ext.substring(1);
  }

  /// An [Uri] to the underlying file.
  ///
  /// Depending on the platform, this may point to a local file, a blob, a data URI, or a network resource.
  Uri get uri;

  /// The local file path of the underlying file, or `null` if not on local disk.
  String? get path => uri.scheme == 'file' ? uri.toFilePath() : null;

  /// Get this file as an [XFile].
  XFile get xFile;

  /// The length of the file in bytes, if already known without doing I/O, or
  /// `null` otherwise.
  ///
  /// Native pickers usually report a file's size as part of the pick result,
  /// in which case this returns it immediately. When they don't, use
  /// [length] instead, which falls back to reading the file to find out.
  int? lengthSync();

  /// Get the length of the file in bytes, or `null` if it could not be
  /// determined (e.g. a failed disk read), distinct from a genuinely empty
  /// file, which returns `0`.
  Future<int?> length();

  /// Read the bytes of the file as a single chunk.
  ///
  /// Prefer [readAsByteStream] for large files.
  Future<Uint8List> readAsBytes();

  /// Read the file content as a stream of bytes.
  Stream<Uint8List> readAsByteStream();
}
