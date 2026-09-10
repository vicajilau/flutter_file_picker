import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:win32/win32.dart';

import 'file_picker_windows_options.dart';
import 'open_save_file_args.dart';
import 'windows_platform_file.dart';

/// An implementation of [FilePickerPlatform] for Windows.
class FilePickerWindows extends FilePickerPlatform {
  /// Registers this class as the default instance of [FilePickerPlatform].
  static void registerWith() {
    FilePickerPlatform.instance = FilePickerWindows();
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
    WindowsOptions windowsOptions = const FilePickerWindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
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
      windowsOptions: windowsOptions,
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
    WindowsOptions windowsOptions = const FilePickerWindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
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
      windowsOptions: windowsOptions,
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
    WindowsOptions windowsOptions = const FilePickerWindowsOptions(),
  }) async {
    final (lockParentWindow, parentWindowHandle, acceptLabel) =
        _resolveWindowsOptions(windowsOptions);

    final port = ReceivePort();
    await Isolate.spawn(
      _callPickFiles,
      OpenSaveFileArgs(
        port: port.sendPort,
        dialogTitle: dialogTitle,
        initialDirectory: initialDirectory,
        type: type,
        allowedExtensions: allowedExtensions,
        allowMultiple: allowMultiple,
        lockParentWindow: lockParentWindow,
        parentWindowHandle: parentWindowHandle,
        acceptLabel: acceptLabel,
      ),
    );

    final fileNames = (await port.first) as List<String>? ?? [];
    if (fileNames.isEmpty) {
      return [];
    }

    return [for (final path in fileNames) WindowsPlatformFile.fromPath(path)];
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
    return files.map((e) => e.uri.path).toList();
  }

  @override
  Future<String?> getDirectoryPath({
    String? dialogTitle,
    String? initialDirectory,
    AndroidOptions androidOptions = const AndroidOptions(),
    WindowsOptions windowsOptions = const FilePickerWindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    final (lockParentWindow, parentWindowHandle, acceptLabel) =
        _resolveWindowsOptions(windowsOptions);

    return compute(_getDirectoryPathIsolate, {
      'dialogTitle': dialogTitle,
      'initialDirectory': initialDirectory,
      'lockParentWindow': lockParentWindow,
      'parentWindowHandle': parentWindowHandle,
      'acceptLabel': acceptLabel,
    });
  }

  /// Runs [IFileOpenDialog] inside a separate isolate to prompt for a directory path.
  static String? _getDirectoryPathIsolate(Map<String, Object?> args) {
    String? dialogTitle = args['dialogTitle'] as String?;
    String? initialDirectory = args['initialDirectory'] as String?;
    bool lockParentWindow = args['lockParentWindow'] as bool? ?? false;
    int? parentWindowHandle = args['parentWindowHandle'] as int?;
    String? acceptLabel = args['acceptLabel'] as String?;

    final hr = CoInitializeEx(
      COINIT_APARTMENTTHREADED | COINIT_DISABLE_OLE1DDE,
    );

    if (hr.isError) {
      throw WindowsException(hr);
    }

    try {
      return using((arena) {
        final fileDialog = arena.com<IFileOpenDialog>(FileOpenDialog);

        final options =
            fileDialog.getOptions() |
            FOS_PICKFOLDERS |
            FOS_FORCEFILESYSTEM |
            FOS_NOCHANGEDIR;
        fileDialog.setOptions(FILEOPENDIALOGOPTIONS(options));

        fileDialog.setTitle(arena.pcwstr(dialogTitle ?? 'Select Folder'));
        if (acceptLabel != null && acceptLabel.isNotEmpty) {
          fileDialog.setOkButtonLabel(arena.pcwstr(acceptLabel));
        }

        if (initialDirectory != null && initialDirectory.isNotEmpty) {
          final item = arena.adopt(
            SHCreateItemFromParsingName<IShellItem>(
              arena.pcwstr(initialDirectory),
              null,
            ),
          );
          fileDialog.setFolder(item);
        }

        try {
          HWND? parentHwnd;
          if (lockParentWindow) {
            parentHwnd = parentWindowHandle != null
                ? Pointer.fromAddress(parentWindowHandle) as HWND
                : GetForegroundWindow();
          }
          fileDialog.show(parentHwnd);
        } on WindowsException catch (e) {
          if (e.hr == HRESULT_FROM_WIN32(ERROR_CANCELLED)) {
            return null;
          }
          rethrow;
        }

        final selectedItem = fileDialog.getResult();
        if (selectedItem == null) {
          return null;
        }

        final item = arena.adopt(selectedItem);
        final pathPtr = item.getDisplayName(SIGDN_FILESYSPATH);
        try {
          return pathPtr.toDartString();
        } finally {
          CoTaskMemFree(pathPtr);
        }
      });
    } finally {
      CoUninitialize();
    }
  }

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? dialogTitle,
    String? initialDirectory,
    Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const FilePickerWindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    final (lockParentWindow, parentWindowHandle, acceptLabel) =
        _resolveWindowsOptions(windowsOptions);

    final port = ReceivePort();
    await Isolate.spawn(
      _callSaveFile,
      OpenSaveFileArgs(
        port: port.sendPort,
        defaultFileName: fileName,
        dialogTitle: dialogTitle,
        initialDirectory: initialDirectory,
        lockParentWindow: lockParentWindow,
        confirmOverwrite: true,
        parentWindowHandle: parentWindowHandle,
        acceptLabel: acceptLabel,
      ),
    );

    final savedFilePath = (await port.first) as String?;
    if (savedFilePath != null) {
      final file = File(savedFilePath);
      await file.writeAsBytes(bytes);
      return Uri.file(savedFilePath);
    }

    return null;
  }

  /// Opens the [IFileOpenDialog] to select one or more files.
  List<String>? _pickFiles(OpenSaveFileArgs args) {
    final hr = CoInitializeEx(
      COINIT_APARTMENTTHREADED | COINIT_DISABLE_OLE1DDE,
    );

    if (hr.isError) {
      throw WindowsException(hr);
    }

    try {
      return using((arena) {
        final fileDialog = arena.com<IFileOpenDialog>(FileOpenDialog);

        var options =
            fileDialog.getOptions() |
            FOS_FORCEFILESYSTEM |
            FOS_FILEMUSTEXIST |
            FOS_NOCHANGEDIR;
        if (args.allowMultiple) {
          options |= FOS_ALLOWMULTISELECT;
        }
        fileDialog.setOptions(FILEOPENDIALOGOPTIONS(options));

        fileDialog.setTitle(arena.pcwstr(args.dialogTitle ?? 'Select File'));
        if (args.acceptLabel case final label? when label.isNotEmpty) {
          fileDialog.setOkButtonLabel(arena.pcwstr(label));
        }
        _setFileTypeFilters(
          arena,
          fileDialog,
          args.type,
          args.allowedExtensions,
        );

        if (args.initialDirectory case final initialDirectory?
            when initialDirectory.isNotEmpty) {
          final item = arena.adopt(
            SHCreateItemFromParsingName<IShellItem>(
              arena.pcwstr(initialDirectory),
              null,
            ),
          );
          fileDialog.setFolder(item);
        }

        try {
          fileDialog.show(_resolveParentHwnd(args));
        } on WindowsException catch (e) {
          if (e.hr == HRESULT_FROM_WIN32(ERROR_CANCELLED)) {
            return null;
          }
          rethrow;
        }

        final results = fileDialog.getResults();
        if (results == null) {
          return null;
        }

        final itemArray = arena.adopt(results);
        return [
          for (var i = 0; i < itemArray.getCount(); i++)
            if (itemArray.getItemAt(i) case final item?)
              _shellItemPath(arena.adopt(item)),
        ];
      });
    } finally {
      CoUninitialize();
    }
  }

  /// Opens the save-file dialog ([IFileSaveDialog]).
  String? _saveFile(OpenSaveFileArgs args) {
    final hr = CoInitializeEx(
      COINIT_APARTMENTTHREADED | COINIT_DISABLE_OLE1DDE,
    );

    if (hr.isError) {
      throw WindowsException(hr);
    }

    try {
      return using((arena) {
        final fileDialog = arena.com<IFileSaveDialog>(FileSaveDialog);

        var options =
            fileDialog.getOptions() | FOS_FORCEFILESYSTEM | FOS_NOCHANGEDIR;
        if (args.confirmOverwrite) {
          options |= FOS_OVERWRITEPROMPT;
        }
        fileDialog.setOptions(FILEOPENDIALOGOPTIONS(options));

        fileDialog.setTitle(arena.pcwstr(args.dialogTitle ?? 'Save File'));
        if (args.acceptLabel case final label? when label.isNotEmpty) {
          fileDialog.setOkButtonLabel(arena.pcwstr(label));
        }
        _setFileTypeFilters(
          arena,
          fileDialog,
          args.type,
          args.allowedExtensions,
        );

        if (args.initialDirectory case final initialDirectory?
            when initialDirectory.isNotEmpty) {
          final item = arena.adopt(
            SHCreateItemFromParsingName<IShellItem>(
              arena.pcwstr(initialDirectory),
              null,
            ),
          );
          fileDialog.setFolder(item);
        }

        if (args.defaultFileName case final defaultFileName?) {
          validateFileName(defaultFileName);
          fileDialog.setFileName(arena.pcwstr(defaultFileName));
        }

        // Without a default extension, Windows does not append one when the
        // user types a file name without one, producing extension-less files.
        if (resolveDefaultExtension(args) case final defaultExtension?) {
          fileDialog.setDefaultExtension(arena.pcwstr(defaultExtension));
        }

        try {
          fileDialog.show(_resolveParentHwnd(args));
        } on WindowsException catch (e) {
          if (e.hr == HRESULT_FROM_WIN32(ERROR_CANCELLED)) {
            return null;
          }
          rethrow;
        }

        final selectedItem = fileDialog.getResult();
        if (selectedItem == null) {
          return null;
        }

        return _shellItemPath(arena.adopt(selectedItem));
      });
    } finally {
      CoUninitialize();
    }
  }

  /// Validates that a file name does not contain reserved Win32 characters.
  void validateFileName(String fileName) {
    if (fileName.contains(RegExp(r'[<>:/\\|?*"]'))) {
      throw ArgumentError(
        'Reserved characters may not be used in file names. See: https://docs.microsoft.com/en-us/windows/win32/fileio/naming-a-file#naming-conventions',
      );
    }
  }

  /// Resolves the default extension (without a leading dot) that
  /// `IFileDialog.SetDefaultExtension` appends when the user types a file
  /// name without one.
  ///
  /// Prefers the first entry of [OpenSaveFileArgs.allowedExtensions], falling
  /// back to the extension of [OpenSaveFileArgs.defaultFileName].
  @visibleForTesting
  String? resolveDefaultExtension(OpenSaveFileArgs args) {
    return switch (args.allowedExtensions) {
      [final first, ...] => first,
      _ => switch (args.defaultFileName) {
        final name? when extension(name).length > 1 => extension(
          name,
        ).substring(1),
        _ => null,
      },
    };
  }

  /// Reads `lockParentWindow` and `acceptLabel` from [windowsOptions]
  /// regardless of its runtime type, since callers construct the base
  /// [WindowsOptions] (the only publicly exported type) rather than the
  /// internal [FilePickerWindowsOptions]. `parentWindowHandle` is
  /// Windows-specific and is only available when [windowsOptions] happens to
  /// be a [FilePickerWindowsOptions].
  static (bool lockParentWindow, int? parentWindowHandle, String? acceptLabel)
  _resolveWindowsOptions(WindowsOptions windowsOptions) {
    return (
      windowsOptions.lockParentWindow,
      switch (windowsOptions) {
        FilePickerWindowsOptions opts => opts.parentWindowHandle,
        _ => null,
      },
      windowsOptions.acceptLabel,
    );
  }

  /// Resolves the owner [HWND] for a dialog based on
  /// [OpenSaveFileArgs.lockParentWindow] and [OpenSaveFileArgs.parentWindowHandle].
  static HWND? _resolveParentHwnd(OpenSaveFileArgs args) {
    if (!args.lockParentWindow) {
      return null;
    }
    return args.parentWindowHandle != null
        ? Pointer.fromAddress(args.parentWindowHandle!) as HWND
        : GetForegroundWindow();
  }

  /// Reads the absolute file system path of a resolved [IShellItem].
  static String _shellItemPath(IShellItem item) {
    final pathPtr = item.getDisplayName(SIGDN_FILESYSPATH);
    try {
      return pathPtr.toDartString();
    } finally {
      CoTaskMemFree(pathPtr);
    }
  }

  /// Builds and applies the `IFileDialog` file-type filter for [type] and
  /// [allowedExtensions].
  static void _setFileTypeFilters(
    Arena arena,
    IFileDialog fileDialog,
    FileType type,
    List<String>? allowedExtensions,
  ) {
    final filters = fileTypeFilterSpecs(type, allowedExtensions);
    final specs = arena<COMDLG_FILTERSPEC>(filters.length);
    for (var i = 0; i < filters.length; i++) {
      specs[i]
        ..pszName = arena.pwstr(filters[i].name)
        ..pszSpec = arena.pwstr(filters[i].pattern);
    }
    fileDialog.setFileTypes(filters.length, specs);
  }

  /// Converts a [FileType] enum and allowed extension list into `IFileDialog`
  /// filter specs (a display name paired with a `;`-separated glob pattern).
  @visibleForTesting
  static List<({String name, String pattern})> fileTypeFilterSpecs(
    FileType type,
    List<String>? allowedExtensions,
  ) {
    if (type == FileType.custom &&
        (allowedExtensions == null || allowedExtensions.isEmpty)) {
      throw ArgumentError(
        'If type is set to FileType.custom, allowedExtensions cannot be null or empty.',
      );
    }
    return switch (type) {
      FileType.any => const [(name: 'All Files (*.*)', pattern: '*.*')],
      FileType.audio => const [
        (
          name: 'Audio (*.aac,*.midi,*.mp3,*.ogg,*.wav,*.m4a)',
          pattern: '*.aac;*.midi;*.mp3;*.ogg;*.wav;*.m4a',
        ),
      ],
      FileType.custom => [
        (
          name: 'Files (*.${allowedExtensions!.join(',*.')})',
          pattern: '*.${allowedExtensions.join(';*.')}',
        ),
      ],
      FileType.image => const [
        (
          name: 'Images (*.bmp,*.gif,*.jpeg,*.jpg,*.png,*.webp)',
          pattern: '*.bmp;*.gif;*.jpeg;*.jpg;*.png;*.webp',
        ),
      ],
      FileType.media => const [
        (
          name: 'Videos (*.avi,*.flv,*.mkv,*.mov,*.mp4,*.mpeg,*.webm,*.wmv)',
          pattern: '*.avi;*.flv;*.mkv;*.mov;*.mp4;*.mpeg;*.webm;*.wmv',
        ),
        (
          name: 'Images (*.bmp,*.gif,*.jpeg,*.jpg,*.png)',
          pattern: '*.bmp;*.gif;*.jpeg;*.jpg;*.png',
        ),
      ],
      FileType.video => const [
        (
          name: 'Videos (*.avi,*.flv,*.mkv,*.mov,*.mp4,*.mpeg,*.webm,*.wmv)',
          pattern: '*.avi;*.flv;*.mkv;*.mov;*.mp4;*.mpeg;*.webm;*.wmv',
        ),
      ],
    };
  }

  /// Top-level isolate callback to invoke [_pickFiles].
  static void _callPickFiles(OpenSaveFileArgs args) {
    final impl = FilePickerWindows();
    args.port.send(impl._pickFiles(args));
  }

  /// Top-level isolate callback to invoke [_saveFile].
  static void _callSaveFile(OpenSaveFileArgs args) {
    final impl = FilePickerWindows();
    args.port.send(impl._saveFile(args));
  }
}
