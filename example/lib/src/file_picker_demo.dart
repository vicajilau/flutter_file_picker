import 'package:file/local.dart';
import 'package:file_picker/file_picker.dart';
import 'package:android_file_picker/android_file_picker.dart';
import 'package:flutter/foundation.dart';
// Deprecated in favor of package:material_ui, which needs a newer Flutter than
// CI's oldest one. Migrating is tracked in #2210.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';

import 'file_picker_results.dart';
import 'file_picker_scope.dart';
import 'picked_directory_result.dart';
import 'picked_files_results.dart';
import 'file_picker_web_options.dart'
    if (dart.library.js_interop) 'file_picker_web_options_web.dart';

class FilePickerDemo extends StatefulWidget {
  const FilePickerDemo({super.key});

  @override
  State<FilePickerDemo> createState() => _FilePickerDemoState();
}

class _FilePickerDemoState extends State<FilePickerDemo> {
  static const _saveFileDisabledMessage =
      'Save file is disabled because it is not compatible with multiple file selection.';

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  final _defaultFileNameController = TextEditingController();
  final _dialogTitleController = TextEditingController();
  final _initialDirectoryController = TextEditingController();
  final _acceptLabelController = TextEditingController();
  final _fileExtensionController = TextEditingController();
  String? _extension;
  bool _isLoading = false;
  bool _isStreaming = false;
  bool _lockParentWindow = false;
  bool _userAborted = false;
  bool _multiPick = false;
  bool _orderedSelection = true;
  bool _copyMedia = true;
  bool _saveWithDialog = false;
  bool _safPersist = false;
  bool _safReadWrite = false;
  String? _streamingProgressText;
  Uint8List? _pickedFileBytes;
  String? _pickedFileBytesSource;
  FileType _pickingType = FileType.any;
  List<PlatformFile> pickedFiles = [];

  bool get _isSaveFileDisabled => _multiPick;

  // Each platform only shows the options it honors.
  bool _isPlatform(TargetPlatform platform) =>
      !kIsWeb && defaultTargetPlatform == platform;
  bool get _isAndroid => _isPlatform(TargetPlatform.android);
  bool get _isIOS => _isPlatform(TargetPlatform.iOS);
  bool get _canLockParentWindow =>
      _isPlatform(TargetPlatform.windows) || _isPlatform(TargetPlatform.linux);
  bool get _supportsAcceptLabel =>
      _canLockParentWindow || _isPlatform(TargetPlatform.macOS);

  Widget _resultsWidget = const Row(
    children: [
      Expanded(
        child: Center(
          child: SizedBox(
            width: 300,
            child: ListTile(
              leading: Icon(Icons.error_outline),
              contentPadding: EdgeInsets.symmetric(vertical: 40.0),
              title: Text('No action taken yet'),
              subtitle: Text(
                'Please use on one of the buttons above to get started',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ),
        ),
      ),
    ],
  );

  @override
  void initState() {
    super.initState();
    _fileExtensionController.addListener(
      () => _extension = _fileExtensionController.text,
    );
    _retrieveLostData();
  }

  @override
  void dispose() {
    _defaultFileNameController.dispose();
    _dialogTitleController.dispose();
    _initialDirectoryController.dispose();
    _acceptLabelController.dispose();
    _fileExtensionController.dispose();
    super.dispose();
  }

  void _pickFiles() async {
    bool hasUserAborted = true;
    _resetState();
    _clearPickedFileBytes();

    try {
      printInDebug("lockParentWindow: $_lockParentWindow");
      if (_multiPick) {
        pickedFiles = await FilePickerScope.of(context).pickFiles(
          type: _pickingType,
          onFileLoading: _onFileLoading,
          allowedExtensions: _allowedExtensionsFromInput(),
          dialogTitle: _dialogTitleController.text,
          initialDirectory: _initialDirectoryController.text,
          windowsOptions: WindowsOptions(
            lockParentWindow: _lockParentWindow,
            acceptLabel: _acceptLabelFromInput(),
          ),
          linuxOptions: LinuxOptions(
            lockParentWindow: _lockParentWindow,
            acceptLabel: _acceptLabelFromInput(),
          ),
          darwinOptions: DarwinOptions(
            acceptLabel: _acceptLabelFromInput(),
            orderedSelection: _orderedSelection,
            copyMedia: _copyMedia,
          ),
          androidOptions:
              _androidSafOptionsFromFlags() ?? const AndroidOptions(),
        );
        printInDebug("pickedFiles: $pickedFiles");
      } else {
        final file = await FilePickerScope.of(context).pickFile(
          type: _pickingType,
          onFileLoading: _onFileLoading,
          allowedExtensions: _allowedExtensionsFromInput(),
          dialogTitle: _dialogTitleController.text,
          initialDirectory: _initialDirectoryController.text,
          windowsOptions: WindowsOptions(
            lockParentWindow: _lockParentWindow,
            acceptLabel: _acceptLabelFromInput(),
          ),
          linuxOptions: LinuxOptions(
            lockParentWindow: _lockParentWindow,
            acceptLabel: _acceptLabelFromInput(),
          ),
          darwinOptions: DarwinOptions(
            acceptLabel: _acceptLabelFromInput(),
            orderedSelection: _orderedSelection,
            copyMedia: _copyMedia,
          ),
          androidOptions:
              _androidSafOptionsFromFlags() ?? const AndroidOptions(),
        );
        printInDebug("pickedFile: $file");
        pickedFiles = file != null ? [file] : [];
      }
      hasUserAborted = pickedFiles.isEmpty;
    } on PlatformException catch (e) {
      _logException('Pick failed: $e');
    } catch (e) {
      _logException(e.toString());
    }
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _userAborted = hasUserAborted;

      _updatePickedFilesResults();
    });
  }

  void _updatePickedFilesResults() {
    _resultsWidget = PickedFilesResults(
      pickedFiles: pickedFiles,
      onRemoveAndroidFile:
          (int index, AndroidPlatformFile androidPlatformFile) {
            androidPlatformFile.safHandle?.releaseGrant();
            _scaffoldMessengerKey.currentState?.showSnackBar(
              const SnackBar(content: Text("SAF Permission Released!")),
            );
            setState(() {
              pickedFiles.removeAt(index);
              _updatePickedFilesResults();
            });
          },
    );
  }

  /// Recovers files picked before Android destroyed the activity, for example
  /// with "Don't keep activities" enabled in the developer options.
  Future<void> _retrieveLostData() async {
    final lost = switch (FilePickerPlatform.instance) {
      final FilePickerAndroid android => await android.retrieveLostData(),
      _ => null,
    };
    if (lost == null || !mounted) return;

    if (lost.exception case final error?) {
      _logException('Could not recover the lost pick: ${error.message}');
      return;
    }

    setState(() {
      pickedFiles = lost.files;
      _updatePickedFilesResults();
    });
    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(
          'Recovered ${lost.files.length} file(s) picked before the app was '
          'restarted',
        ),
      ),
    );
  }

  void _pickFileAndDirectoryPaths() async {
    List<String> pickedFilesAndDirectories = [];
    bool hasUserAborted = true;
    _resetState();

    try {
      pickedFilesAndDirectories = await FilePickerScope.of(context)
          .pickFileAndDirectoryPaths(
            dialogTitle: _dialogTitleController.text,
            type: _pickingType,
            allowedExtensions: _allowedExtensionsFromInput(),
            initialDirectory: _initialDirectoryController.text,
          );
      hasUserAborted = pickedFilesAndDirectories.isEmpty;
    } on PlatformException catch (e) {
      _logException('Pick failed: $e');
    } catch (e) {
      _logException(e.toString());
    }
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _userAborted = hasUserAborted;
      _resultsWidget = FilePickerResultsList(
        itemCount: pickedFilesAndDirectories.length,
        itemBuilder: (BuildContext context, int index) {
          String name = 'File path:';
          if (!kIsWeb) {
            final fs = LocalFileSystem();
            name = fs.isFileSync(pickedFilesAndDirectories[index])
                ? 'File path:'
                : 'Directory path:';
          }
          return ListTile(
            leading: Text(
              index.toString(),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            title: Text(name),
            subtitle: Text(pickedFilesAndDirectories[index]),
          );
        },
      );
    });
  }

  void _clearCachedFiles() async {
    pickedFiles = [];
    _resetState();
    _clearPickedFileBytes();
    try {
      await FilePicker.clearTemporaryFiles();
      _scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
      _scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Temporary files removed with success.')),
      );
    } on PlatformException catch (e) {
      _logException('Clearing temporary files failed: $e');
    } catch (e) {
      _logException(e.toString());
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  void _selectFolder() async {
    String? pickedDirectoryPath;
    bool hasUserAborted = true;
    _resetState();

    try {
      pickedDirectoryPath = await FilePickerScope.of(context).getDirectoryPath(
        dialogTitle: _dialogTitleController.text,
        initialDirectory: _initialDirectoryController.text,
        windowsOptions: WindowsOptions(lockParentWindow: _lockParentWindow),
        linuxOptions: LinuxOptions(lockParentWindow: _lockParentWindow),
        androidOptions: _androidSafOptionsFromFlags() ?? const AndroidOptions(),
      );
      hasUserAborted = pickedDirectoryPath == null;
    } on PlatformException catch (e) {
      _logException('Picking a folder failed: $e');
    } catch (e) {
      _logException(e.toString());
    }

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _userAborted = hasUserAborted;
      void updateResults() {
        _resultsWidget = PickedDirectoryResult(
          pickedDirectoryPath: pickedDirectoryPath,
          readWriteAccess: _safReadWrite,
          onDirectoryRemoved: () {
            _scaffoldMessengerKey.currentState?.showSnackBar(
              const SnackBar(content: Text("SAF Permission Released!")),
            );
            setState(() {
              pickedDirectoryPath = null;
              updateResults();
            });
          },
        );
      }

      updateResults();
    });
  }

  Future<void> _saveFile() async {
    Uri? pickedSaveFileUri;
    bool hasUserAborted = true;

    if (_isSaveFileDisabled) {
      _showSaveFileDisabledSnackBar();
      return;
    }

    final file = pickedFiles.firstOrNull;
    if (file == null) {
      _logException('Please pick a file first before saving.');
      return;
    }

    final fileName = _defaultFileNameController.text.trim();
    final targetFileName = fileName.isNotEmpty ? fileName : file.name;

    if (targetFileName.isEmpty) {
      _logException('Unable to determine a file name to save.');
      return;
    }

    final bytes = _pickedFileBytes;
    if (bytes == null) {
      _logException(
        'No file bytes loaded yet. Press "Stream picked file" or '
        '"Read picked file as bytes" first.',
      );
      return;
    }

    _resetState();

    try {
      pickedSaveFileUri = await FilePickerScope.of(context).saveFile(
        mimeType: 'application/octet-stream',
        dialogTitle: _dialogTitleController.text,
        fileName: targetFileName,
        initialDirectory: _initialDirectoryController.text,
        windowsOptions: WindowsOptions(lockParentWindow: _lockParentWindow),
        linuxOptions: LinuxOptions(lockParentWindow: _lockParentWindow),
        webOptions: filePickerWebOptions(useDialog: _saveWithDialog),
        bytes: bytes,
      );
      hasUserAborted = pickedSaveFileUri == null;
    } on PlatformException catch (e) {
      _logException('Save failed: $e');
    } catch (e) {
      _logException(e.toString());
    }
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _userAborted = hasUserAborted;
      _resultsWidget = FilePickerResultsList(
        itemCount: pickedSaveFileUri != null ? 1 : 0,
        itemBuilder: (BuildContext context, int index) {
          return ListTile(
            title: const Text('Save file URI:'),
            subtitle: Text(
              pickedSaveFileUri != null
                  ? '$pickedSaveFileUri (bytes loaded via ${_pickedFileBytesSource ?? 'unknown'})'
                  : '',
            ),
          );
        },
      );
    });
  }

  Future<void> _streamPickedFile() async {
    final file = pickedFiles.firstOrNull;
    if (file == null) {
      _logException('No file picked. Pick a file first to stream it.');
      return;
    }

    _clearPickedFileBytes();
    _resetState();
    if (!mounted) return;
    setState(() {
      _userAborted = false;
      _isStreaming = true;
      _resultsWidget = const Center(child: Text('Starting stream...'));
    });

    int total = 0;
    int chunks = 0;
    final bytes = BytesBuilder(copy: false);

    try {
      await for (final chunk in file.readAsByteStream()) {
        total += chunk.length;
        chunks++;
        bytes.add(chunk);
        if (!mounted) return;
        setState(() {
          _streamingProgressText =
              'Streaming... chunks: $chunks, bytes: $total';
          _resultsWidget = Center(child: Text(_streamingProgressText!));
        });
      }

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isStreaming = false;
        _streamingProgressText = null;
        _userAborted = false;
        _pickedFileBytes = bytes.takeBytes();
        _pickedFileBytesSource = 'stream';
        _resultsWidget = Center(
          child: Text('Stream completed: $chunks chunks, $total bytes'),
        );
      });
    } catch (e) {
      _logException(e.toString());
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isStreaming = false;
          _streamingProgressText = null;
          _userAborted = false;
        });
      }
    }
  }

  Future<void> _readPickedFileAsBytes() async {
    final file = pickedFiles.firstOrNull;
    if (file == null) {
      _logException('No file picked. Pick a file first to read its bytes.');
      return;
    }

    _clearPickedFileBytes();
    _resetState();

    try {
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isStreaming = false;
        _streamingProgressText = null;
        _userAborted = false;
        _pickedFileBytes = bytes;
        _pickedFileBytesSource = 'readAsBytes';
        _resultsWidget = Center(
          child: Text('readAsBytes completed: ${bytes.lengthInBytes} bytes'),
        );
      });
    } catch (e) {
      _logException(e.toString());
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isStreaming = false;
          _streamingProgressText = null;
          _userAborted = false;
        });
      }
    }
  }

  void _logException(String message) {
    printInDebug(message);
    _scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
      ),
    );
  }

  void _showSaveFileDisabledSnackBar() {
    _scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
    _scaffoldMessengerKey.currentState?.showSnackBar(
      const SnackBar(
        content: Text(
          _saveFileDisabledMessage,
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  void _resetState() {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _isStreaming = false;
      _streamingProgressText = null;
      _userAborted = true;
    });
  }

  void _clearPickedFileBytes() {
    _pickedFileBytes = null;
    _pickedFileBytesSource = null;
  }

  void _onFileLoading(FilePickerStatus status) {
    setState(() {
      _isLoading = status == FilePickerStatus.picking;
    });
  }

  List<String>? _allowedExtensionsFromInput() {
    return (_extension?.isNotEmpty ?? false)
        ? _extension?.replaceAll(' ', '').split(',')
        : null;
  }

  String? _acceptLabelFromInput() {
    final acceptLabel = _acceptLabelController.text.trim();
    return acceptLabel.isNotEmpty ? acceptLabel : null;
  }

  AndroidOptions? _androidSafOptionsFromFlags() {
    return (_safPersist || _safReadWrite)
        ? FilePickerAndroidOptions(
            safOptions: AndroidSAFOptions(
              grant: _safPersist
                  ? AndroidSAFGrant.lifetime
                  : AndroidSAFGrant.transient,
              accessMode: _safReadWrite
                  ? AndroidSAFAccessMode.readWrite
                  : AndroidSAFAccessMode.readOnly,
            ),
          )
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final fileTypeItems = <DropdownMenuItem<FileType>>[
      for (final fileType in FileType.values)
        DropdownMenuItem<FileType>(
          value: fileType,
          child: Text(fileType.toString()),
        ),
    ];

    final configurationFields = <Widget>[
      SizedBox(
        width: 400,
        child: TextField(
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Dialog Title',
          ),
          controller: _dialogTitleController,
        ),
      ),
      SizedBox(
        width: 400,
        child: TextField(
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Initial Directory',
          ),
          controller: _initialDirectoryController,
        ),
      ),
      SizedBox(
        width: 400,
        child: TextField(
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Default File Name',
          ),
          controller: _defaultFileNameController,
        ),
      ),
      if (_supportsAcceptLabel)
        SizedBox(
          width: 400,
          child: TextField(
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Accept Label',
            ),
            controller: _acceptLabelController,
          ),
        ),
      SizedBox(
        width: 400,
        child: DropdownButtonFormField<FileType>(
          initialValue: _pickingType,
          icon: const Icon(Icons.expand_more),
          alignment: Alignment.centerLeft,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: fileTypeItems,
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _pickingType = value;
                if (_pickingType != FileType.custom) {
                  _fileExtensionController.text = _extension = '';
                }
              });
            }
          },
        ),
      ),
      if (_pickingType == FileType.custom)
        SizedBox(
          width: 400,
          child: TextFormField(
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'File Extension',
              hintText: 'jpg, png, gif',
            ),
            autovalidateMode: AutovalidateMode.always,
            controller: _fileExtensionController,
            keyboardType: TextInputType.text,
            maxLength: 15,
          ),
        ),
    ];

    final optionsFields = <Widget>[
      if (_canLockParentWindow)
        SizedBox(
          width: 400.0,
          child: SwitchListTile.adaptive(
            title: const Text('Lock parent window', textAlign: TextAlign.left),
            onChanged: (value) => setState(() => _lockParentWindow = value),
            value: _lockParentWindow,
          ),
        ),
      ConstrainedBox(
        constraints: const BoxConstraints.tightFor(width: 400.0),
        child: SwitchListTile.adaptive(
          title: const Text('Pick multiple files', textAlign: TextAlign.left),
          onChanged: (value) {
            setState(() => _multiPick = value);
            if (value) {
              _showSaveFileDisabledSnackBar();
            }
          },
          value: _multiPick,
        ),
      ),
      if (_isIOS) ...[
        ConstrainedBox(
          constraints: const BoxConstraints.tightFor(width: 400.0),
          child: SwitchListTile.adaptive(
            title: const Text(
              'Ordered selection (iOS photo library)',
              textAlign: TextAlign.left,
            ),
            onChanged: (value) => setState(() => _orderedSelection = value),
            value: _orderedSelection,
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints.tightFor(width: 400.0),
          child: SwitchListTile.adaptive(
            title: const Text(
              'Copy media (iOS photo library)',
              textAlign: TextAlign.left,
            ),
            onChanged: (value) => setState(() => _copyMedia = value),
            value: _copyMedia,
          ),
        ),
      ],
      if (kIsWeb)
        ConstrainedBox(
          constraints: const BoxConstraints.tightFor(width: 400.0),
          child: SwitchListTile.adaptive(
            title: Text(
              supportsSaveDialog
                  ? 'Save with dialog (web)'
                  : 'Save with dialog is not supported by your browser',
              textAlign: TextAlign.left,
            ),
            onChanged: supportsSaveDialog
                ? (value) => setState(() => _saveWithDialog = value)
                : null,
            value: _saveWithDialog,
          ),
        ),
      if (_isAndroid) ...[
        ConstrainedBox(
          constraints: const BoxConstraints.tightFor(width: 400.0),
          child: SwitchListTile.adaptive(
            title: const Text(
              'SAF Persist (Android 10+)',
              textAlign: TextAlign.left,
            ),
            onChanged: (value) => setState(() => _safPersist = value),
            value: _safPersist,
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints.tightFor(width: 400.0),
          child: SwitchListTile.adaptive(
            title: const Text(
              'SAF ReadWrite (Android 10+)',
              textAlign: TextAlign.left,
            ),
            onChanged: (value) => setState(() => _safReadWrite = value),
            value: _safReadWrite,
          ),
        ),
      ],
    ];

    final actionButtons = <Widget>[
      SizedBox(
        width: 120,
        child: FloatingActionButton.extended(
          onPressed: _pickFiles,
          label: Text(_multiPick ? 'Pick files' : 'Pick file'),
          icon: const Icon(Icons.description),
        ),
      ),
      SizedBox(
        width: 120,
        child: FloatingActionButton.extended(
          onPressed: _selectFolder,
          label: const Text('Pick folder'),
          icon: const Icon(Icons.folder),
        ),
      ),
      SizedBox(
        width: 250,
        child: FloatingActionButton.extended(
          onPressed: _pickFileAndDirectoryPaths,
          label: const Text('Pick files and directories'),
          icon: const Icon(Icons.folder_open),
        ),
      ),
      SizedBox(
        width: 120,
        child: FloatingActionButton.extended(
          onPressed: _isSaveFileDisabled ? null : _saveFile,
          backgroundColor: _isSaveFileDisabled ? Colors.grey.shade700 : null,
          foregroundColor: _isSaveFileDisabled ? Colors.white70 : null,
          disabledElevation: 0,
          label: const Text('Save file'),
          icon: const Icon(Icons.save_as),
        ),
      ),
      SizedBox(
        width: 200,
        child: FloatingActionButton.extended(
          onPressed: _clearCachedFiles,
          label: const Text('Clear temporary files'),
          icon: const Icon(Icons.delete_forever),
        ),
      ),
      SizedBox(
        width: 200,
        child: FloatingActionButton.extended(
          onPressed: _streamPickedFile,
          label: const Text('Stream picked file'),
          icon: const Icon(Icons.stream),
        ),
      ),
      SizedBox(
        width: 240,
        child: FloatingActionButton.extended(
          onPressed: _readPickedFileAsBytes,
          label: const Text('Read picked file as bytes'),
          icon: const Icon(Icons.data_array),
        ),
      ),
    ];

    final loadingIndicator = Row(
      children: const [
        Expanded(
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40.0),
              child: CircularProgressIndicator(),
            ),
          ),
        ),
      ],
    );

    final streamingIndicator = Column(
      children: [
        loadingIndicator,
        if (_streamingProgressText != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: Center(
              child: Text(_streamingProgressText!, textAlign: TextAlign.center),
            ),
          ),
      ],
    );

    final userAbortedContent = Row(
      children: const [
        Expanded(
          child: Center(
            child: SizedBox(
              width: 300,
              child: ListTile(
                leading: Icon(Icons.error_outline),
                contentPadding: EdgeInsets.symmetric(vertical: 40.0),
                title: Text('User has aborted the dialog'),
              ),
            ),
          ),
        ),
      ],
    );

    late final Widget resultsContent;
    if (_isLoading && _isStreaming) {
      resultsContent = streamingIndicator;
    } else if (_isLoading) {
      resultsContent = loadingIndicator;
    } else if (_userAborted) {
      resultsContent = userAbortedContent;
    } else {
      resultsContent = _resultsWidget;
    }

    return MaterialApp(
      scaffoldMessengerKey: _scaffoldMessengerKey,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: Colors.deepPurple,
        ),
      ),
      home: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(title: const Text('File Picker example app')),
        body: Padding(
          padding: const EdgeInsets.only(left: 5.0, right: 5.0),
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(left: 15.0, right: 15.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Configuration',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                ),
                const SizedBox(height: 20.0),
                Wrap(
                  spacing: 10.0,
                  runSpacing: 10.0,
                  children: configurationFields,
                ),
                const SizedBox(height: 20.0),
                Wrap(
                  alignment: WrapAlignment.start,
                  runAlignment: WrapAlignment.start,
                  crossAxisAlignment: WrapCrossAlignment.start,
                  direction: Axis.horizontal,
                  spacing: 10.0,
                  runSpacing: 10.0,
                  children: optionsFields,
                ),
                const SizedBox(height: 20.0),
                const Divider(),
                const SizedBox(height: 20.0),
                const Text(
                  'Actions',
                  textAlign: TextAlign.start,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 20.0, bottom: 20.0),
                  child: Wrap(
                    spacing: 10.0,
                    runSpacing: 10.0,
                    children: actionButtons,
                  ),
                ),
                const Divider(),
                const SizedBox(height: 20.0),
                const Text(
                  'File Picker Result',
                  textAlign: TextAlign.start,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                ),
                resultsContent,
                const SizedBox(height: 10.0),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void printInDebug(Object object) => debugPrint(object.toString());
}
