import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
import 'package:flutter/foundation.dart';

import 'file_picker_linux_options.dart';
import 'filters.dart';
import 'linux_platform_file.dart';
import 'xdp_filechooser.dart';
import 'xdp_request.dart';

/// An implementation of [FilePickerPlatform] for Linux using XDG Desktop Portal.
class FilePickerLinux extends FilePickerPlatform {
  /// Registers this class as the default instance of [FilePickerPlatform].
  static void registerWith() {
    FilePickerPlatform.instance = FilePickerLinux();
  }

  static const String destination = 'org.freedesktop.portal.Desktop';
  DBusClient? _client;
  OrgFreedesktopPortalFileChooser? _xdpChooser;

  FilePickerLinux({
    DBusClient? client,
    OrgFreedesktopPortalFileChooser? xdpChooser,
  }) : _client = client,
       _xdpChooser = xdpChooser;

  /// Gets the [DBusClient] instance, lazy-initializing it if needed.
  DBusClient get client => _client ??= DBusClient.session();

  /// Gets the [OrgFreedesktopPortalFileChooser] instance.
  OrgFreedesktopPortalFileChooser get xdpChooser =>
      _xdpChooser ??= OrgFreedesktopPortalFileChooser(
        client,
        destination,
        path: DBusObjectPath("/org/freedesktop/portal/desktop"),
      );

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
    LinuxOptions linuxOptions = const FilePickerLinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    final files = await _pickFilesInternal(
      allowMultiple: false,
      dialogTitle: dialogTitle,
      initialDirectory: initialDirectory,
      type: type,
      allowedExtensions: allowedExtensions,
      onFileLoading: onFileLoading,
      compressionQuality: compressionQuality,
      linuxOptions: linuxOptions,
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
    LinuxOptions linuxOptions = const FilePickerLinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    return _pickFilesInternal(
      allowMultiple: true,
      dialogTitle: dialogTitle,
      initialDirectory: initialDirectory,
      type: type,
      allowedExtensions: allowedExtensions,
      onFileLoading: onFileLoading,
      compressionQuality: compressionQuality,
      linuxOptions: linuxOptions,
    );
  }

  Future<List<PlatformFile>> _pickFilesInternal({
    required bool allowMultiple,
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    LinuxOptions linuxOptions = const FilePickerLinuxOptions(),
  }) async {
    final options = resolveOptions(linuxOptions);

    final filter = Filter(type, allowedExtensions);
    Map<String, DBusValue> xdpOption = {
      'handle_token': DBusString('flutter_picker'),
      'multiple': DBusBoolean(allowMultiple),
      'modal': DBusBoolean(options.lockParentWindow),
      'filters': filter.toDBusArray(),
    };

    if (options.acceptLabel != null) {
      xdpOption["accept_label"] = DBusString(options.acceptLabel!);
    }

    if (initialDirectory != null) {
      final Uint8List tmp = _encodeDirectory(initialDirectory);
      DBusArray directory = DBusArray.byte(tmp);
      xdpOption["current_folder"] = directory;
    }

    final replyPath = await xdpChooser.callOpenFile(
      _formatParentWindow(options.parentWindow),
      dialogTitle ?? "flutter picker",
      xdpOption,
    );

    List<Uri> uriPaths = [];

    final request = OrgFreedesktopPortalRequest(
      client,
      destination,
      path: replyPath,
    );

    await for (var response in request.response) {
      final status = response.response;
      if (status != 0) {
        return [];
      }
      final result = response.results;
      uriPaths =
          result["uris"]
              ?.asArray()
              .map((data) => Uri.parse(data.asString()))
              .toList() ??
          [];
      break;
    }

    return [
      for (final uri in uriPaths) LinuxPlatformFile.fromPath(uri.toFilePath()),
    ];
  }

  @override
  Future<List<String>> pickFileAndDirectoryPaths({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
  }) async {
    final files = await pickFiles(
      dialogTitle: dialogTitle,
      initialDirectory: initialDirectory,
      type: type,
      allowedExtensions: allowedExtensions,
    );
    return files.map((e) => e.path).nonNulls.toList();
  }

  @override
  Future<String?> getDirectoryPath({
    String? dialogTitle,
    String? initialDirectory,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const FilePickerLinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    final options = resolveOptions(linuxOptions);

    Map<String, DBusValue> xdpOption = {
      'handle_token': DBusString('flutter_picker'),
      'directory': DBusBoolean(true),
      'modal': DBusBoolean(options.lockParentWindow),
    };
    if (initialDirectory != null) {
      final Uint8List tmp = _encodeDirectory(initialDirectory);
      DBusArray directory = DBusArray.byte(tmp);
      xdpOption["current_folder"] = directory;
    }
    final replyPath = await xdpChooser.callOpenFile(
      _formatParentWindow(options.parentWindow),
      dialogTitle ?? "flutter picker",
      xdpOption,
    );

    List<Uri> uriPaths = [];

    final request = OrgFreedesktopPortalRequest(
      client,
      destination,
      path: replyPath,
    );

    await for (var response in request.response) {
      final status = response.response;
      if (status != 0) {
        return null;
      }
      final result = response.results;
      uriPaths =
          result["uris"]
              ?.asArray()
              .map((data) => Uri.parse(data.asString()))
              .toList() ??
          [];
      break;
    }

    return uriPaths.firstOrNull?.toFilePath();
  }

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? dialogTitle,
    String? initialDirectory,
    Function(FilePickerStatus)? onFileSaving,
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const FilePickerLinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    final options = resolveOptions(linuxOptions);

    Map<String, DBusValue> xdpOption = {
      'handle_token': DBusString('flutter_picker'),
      'current_name': DBusString(fileName),
      'modal': DBusBoolean(options.lockParentWindow),
    };
    if (initialDirectory != null) {
      final Uint8List tmp = _encodeDirectory(initialDirectory);
      DBusArray directory = DBusArray.byte(tmp);
      xdpOption["current_folder"] = directory;
    }

    final replyPath = await xdpChooser.callSaveFile(
      _formatParentWindow(options.parentWindow),
      dialogTitle ?? "flutter picker",
      xdpOption,
    );
    final request = OrgFreedesktopPortalRequest(
      client,
      destination,
      path: replyPath,
    );

    List<Uri> saveUris = [];
    await for (var response in request.response) {
      final status = response.response;
      if (status != 0) {
        return null;
      }
      final result = response.results;
      saveUris =
          result["uris"]
              ?.asArray()
              .map((data) => Uri.parse(data.asString()))
              .toList() ??
          saveUris;
      break;
    }

    final savedFilePath = saveUris.firstOrNull?.toFilePath();

    if (savedFilePath != null) {
      final file = File(savedFilePath);
      await file.writeAsBytes(bytes);
      return Uri.file(savedFilePath);
    }

    return null;
  }

  Uint8List _encodeDirectory(String initialDirectory) {
    return Uint8List.fromList([...utf8.encode(initialDirectory), 0]);
  }

  /// Narrows [linuxOptions] to the Linux specific type the portal calls need.
  ///
  /// Callers may pass either a plain [LinuxOptions] or a
  /// [FilePickerLinuxOptions]. Only the latter carries `parentWindow`, but
  /// everything the supertype defines has to survive the narrowing, otherwise
  /// options set by the caller are silently dropped on the way to the portal.
  @visibleForTesting
  static FilePickerLinuxOptions resolveOptions(LinuxOptions linuxOptions) {
    return switch (linuxOptions) {
      FilePickerLinuxOptions opts => opts,
      _ => FilePickerLinuxOptions(
        acceptLabel: linuxOptions.acceptLabel,
        lockParentWindow: linuxOptions.lockParentWindow,
      ),
    };
  }

  static String _formatParentWindow(String? parentWindow) {
    if (parentWindow == null || parentWindow.trim().isEmpty) {
      return '';
    }
    final trimmed = parentWindow.trim();
    if (trimmed.startsWith('x11:') || trimmed.startsWith('wayland:')) {
      return trimmed;
    }
    if (trimmed.startsWith('0x')) {
      return 'x11:$trimmed';
    }
    final intVal = int.tryParse(trimmed);
    if (intVal != null) {
      return 'x11:0x${intVal.toRadixString(16)}';
    }
    return trimmed;
  }
}
