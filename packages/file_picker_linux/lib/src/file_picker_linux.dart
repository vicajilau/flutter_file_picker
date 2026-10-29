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

    final replyPath = await xdpChooser.callOpenFile(
      formatParentWindow(options.parentWindow),
      dialogTitle ?? "flutter picker",
      openFileOptions(
        options,
        allowMultiple: allowMultiple,
        filter: Filter(type, allowedExtensions),
        initialDirectory: initialDirectory,
      ),
    );

    final paths = await _awaitPaths(replyPath) ?? [];
    return [for (final path in paths) LinuxPlatformFile.fromPath(path)];
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
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const FilePickerLinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    final options = resolveOptions(linuxOptions);

    final replyPath = await xdpChooser.callOpenFile(
      formatParentWindow(options.parentWindow),
      dialogTitle ?? "flutter picker",
      directoryOptions(options, initialDirectory: initialDirectory),
    );

    return (await _awaitPaths(replyPath))?.firstOrNull;
  }

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? dialogTitle,
    String? initialDirectory,
    Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const FilePickerLinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    final options = resolveOptions(linuxOptions);

    final replyPath = await xdpChooser.callSaveFile(
      formatParentWindow(options.parentWindow),
      dialogTitle ?? "flutter picker",
      saveFileOptions(
        options,
        fileName: fileName,
        initialDirectory: initialDirectory,
      ),
    );

    final savedFilePath = (await _awaitPaths(replyPath))?.firstOrNull;

    if (savedFilePath != null) {
      final file = File(savedFilePath);
      await file.writeAsBytes(bytes);
      return Uri.file(savedFilePath);
    }

    return null;
  }

  /// Waits for the portal's response to the request at [replyPath] and
  /// returns the chosen paths, or `null` if the user cancelled or the
  /// request failed.
  Future<List<String>?> _awaitPaths(DBusObjectPath replyPath) async {
    final request = OrgFreedesktopPortalRequest(
      client,
      destination,
      path: replyPath,
    );
    await for (final response in request.response) {
      return pathsFromResponse(response.response, response.results);
    }
    return null;
  }

  /// The options every portal request shares.
  static Map<String, DBusValue> _requestOptions(
    FilePickerLinuxOptions options,
    String? initialDirectory,
  ) {
    return {
      'handle_token': DBusString('flutter_picker'),
      'modal': DBusBoolean(options.lockParentWindow),
      if (initialDirectory != null)
        // The portal expects a null terminated byte string.
        'current_folder': DBusArray.byte(
          Uint8List.fromList([...utf8.encode(initialDirectory), 0]),
        ),
    };
  }

  /// The portal options to pick files with.
  @visibleForTesting
  static Map<String, DBusValue> openFileOptions(
    FilePickerLinuxOptions options, {
    required bool allowMultiple,
    required Filter filter,
    String? initialDirectory,
  }) {
    return {
      ..._requestOptions(options, initialDirectory),
      'multiple': DBusBoolean(allowMultiple),
      'filters': filter.toDBusArray(),
      if (options.acceptLabel != null)
        'accept_label': DBusString(options.acceptLabel!),
    };
  }

  /// The portal options to pick a directory with.
  @visibleForTesting
  static Map<String, DBusValue> directoryOptions(
    FilePickerLinuxOptions options, {
    String? initialDirectory,
  }) {
    return {
      ..._requestOptions(options, initialDirectory),
      'directory': DBusBoolean(true),
    };
  }

  /// The portal options to save [fileName] with.
  @visibleForTesting
  static Map<String, DBusValue> saveFileOptions(
    FilePickerLinuxOptions options, {
    required String fileName,
    String? initialDirectory,
  }) {
    return {
      ..._requestOptions(options, initialDirectory),
      'current_name': DBusString(fileName),
    };
  }

  /// The file paths in a portal response, or `null` if [status] says the
  /// user cancelled (1) or the request failed (2).
  @visibleForTesting
  static List<String>? pathsFromResponse(
    int status,
    Map<String, DBusValue> results,
  ) {
    if (status != 0) {
      return null;
    }
    return results['uris']
            ?.asArray()
            .map((uri) => Uri.parse(uri.asString()).toFilePath())
            .toList() ??
        [];
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

  /// The `parent_window` identifier for [parentWindow], accepting an X11
  /// window id in hex or decimal, or an already prefixed `x11:` or
  /// `wayland:` handle.
  @visibleForTesting
  static String formatParentWindow(String? parentWindow) {
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
