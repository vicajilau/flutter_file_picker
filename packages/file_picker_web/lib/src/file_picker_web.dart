import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:cross_file_web/cross_file_web.dart';
import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:path/path.dart' as p;
import 'package:web/web.dart';

import 'file_picker_web_options.dart';
import 'web_file_input_session.dart';
import 'web_platform_file.dart';

/// An implementation of [FilePickerPlatform] for the Web platform.
///
/// Uses standard HTML5 `<input type="file">` element interop via `package:web`
/// to provide single and multiple file picking, as well as file saving capabilities
/// in browser environments.
class FilePickerWeb extends FilePickerPlatform {
  static const String _kFilePickerInputsDomId = '__file_picker_web-file-input';

  late Element _target;

  FilePickerWeb._() {
    _target = _ensureInitialized(_kFilePickerInputsDomId);
  }

  /// Registers this class as the default instance of [FilePickerPlatform].
  static void registerWith(Registrar registrar) {
    FilePickerPlatform.instance = FilePickerWeb._();
  }

  /// Initializes a DOM container element where input elements can be appended.
  Element _ensureInitialized(String id) {
    Element? target = document.querySelector('#$id');
    if (target == null) {
      final Element targetElement = document.createElement(
        'flt-file-picker-inputs',
      )..id = id;

      document.body!.appendChild(targetElement);
      target = targetElement;
    }
    return target;
  }

  /// Directory picking is not supported on web platforms.
  ///
  /// Always throws an [UnsupportedError].
  @override
  Future<String?> getDirectoryPath({
    String? dialogTitle,
    String? initialDirectory,
    AndroidOptions androidOptions = const AndroidOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    throw UnsupportedError('getDirectoryPath() is not supported on Web.');
  }

  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    final files = await _pickFiles(
      type: type,
      allowedExtensions: allowedExtensions,
      onFileLoading: onFileLoading,
      webOptions: webOptions,
      allowMultiple: false,
    );
    return files.firstOrNull;
  }

  @override
  Future<List<PlatformFile>> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) {
    return _pickFiles(
      type: type,
      allowedExtensions: allowedExtensions,
      onFileLoading: onFileLoading,
      webOptions: webOptions,
      allowMultiple: true,
    );
  }

  Future<List<PlatformFile>> _pickFiles({
    required FileType type,
    required List<String>? allowedExtensions,
    required Function(FilePickerStatus)? onFileLoading,
    required WebOptions webOptions,
    required bool allowMultiple,
  }) async {
    if (type == FileType.custom &&
        (allowedExtensions == null || allowedExtensions.isEmpty)) {
      throw ArgumentError(
        'If type is set to FileType.custom, allowedExtensions cannot be null or empty.',
      );
    }

    final FilePickerWebOptions effectiveWebOptions =
        webOptions is FilePickerWebOptions
        ? webOptions
        : const FilePickerWebOptions();

    final session = WebFileInputSession(
      target: _target,
      accept: _fileType(type, allowedExtensions),
      allowMultiple: allowMultiple,
      webOptions: effectiveWebOptions,
      onFileLoading: onFileLoading,
      processFiles: _processSelectedFiles,
    );

    final List<PlatformFile>? files = await session.start();
    return files ?? <PlatformFile>[];
  }

  /// Wraps each selected [File] in a [WebPlatformFile] without reading it.
  ///
  /// The content is read on demand through [PlatformFile.readAsBytes] and
  /// [PlatformFile.readAsByteStream].
  Future<List<PlatformFile>> _processSelectedFiles(
    FileList files,
    FilePickerWebOptions webOptions,
  ) async {
    return [
      for (var i = 0; i < files.length; i++)
        if (files.item(i) case final file?) _createWebPlatformFile(file),
    ];
  }

  /// Creates a [WebPlatformFile] backed by the picked [file] itself.
  ///
  /// Its `blob:` URI is not revoked automatically, so it stays valid for as
  /// long as the page is open.
  WebPlatformFile _createWebPlatformFile(File file) {
    final xFile = ScopedStorageXFile.fromCreationParams(
      WebScopedStorageXFileCreationParams.fromBlob(
        file,
        autoRevokeObjectUrl: false,
      ),
    );
    return WebPlatformFile(
      name: file.name,
      uri: Uri.parse(xFile.uri),
      xFile: xFile,
      bytesLength: file.size,
    );
  }

  /// Triggers a browser download to save a file with the given [fileName],
  /// [bytes], and [mimeType].
  ///
  /// Returns a `blob:` [Uri] pointing to the generated download object.
  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? dialogTitle,
    String? initialDirectory,
    Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    if (bytes.isEmpty) {
      throw ArgumentError(
        'The bytes are required when saving a file on the web.',
      );
    }

    if (fileName.isEmpty) {
      throw ArgumentError(
        'A file name is required when saving a file on the web.',
      );
    }

    if (p.extension(fileName).isEmpty) {
      throw ArgumentError(
        'The file name should include a valid file extension.',
      );
    }

    final blob = Blob([bytes.toJS].toJS, BlobPropertyBag(type: mimeType));
    final url = URL.createObjectURL(blob);

    HTMLAnchorElement()
      ..href = url
      ..target = 'blank'
      ..download = fileName
      ..click();

    URL.revokeObjectURL(url);
    return null;
  }

  /// Converts a [FileType] enum and [allowedExtensions] list into an HTML
  /// `accept` attribute string.
  static String _fileType(FileType type, List<String>? allowedExtensions) {
    return switch (type) {
      FileType.any => '',
      FileType.audio => 'audio/*',
      FileType.image => 'image/*',
      FileType.video => 'video/*',
      FileType.media => 'video/*|image/*',
      FileType.custom => allowedExtensions!.fold(
        '',
        (prev, next) => '${prev.isEmpty ? '' : '$prev,'} .$next',
      ),
    };
  }
}
