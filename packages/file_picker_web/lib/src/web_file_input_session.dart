import 'dart:async';
import 'dart:js_interop';

import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
import 'package:meta/meta.dart';
import 'package:web/web.dart';

import 'file_picker_web_options.dart';

/// Callback delegate used to process and convert native [FileList] to [PlatformFile]s.
typedef ProcessFilesCallback =
    Future<List<PlatformFile>> Function(
      FileList files,
      FilePickerWebOptions options,
    );

/// Manages one attached file input and its selection/cancellation completion.
@internal
class WebFileInputSession {
  /// Creates a new [WebFileInputSession] instance.
  WebFileInputSession({
    required this.target,
    required this.accept,
    required this.allowMultiple,
    required this.webOptions,
    required this.onFileLoading,
    required this.processFiles,
  });

  /// The target DOM container element where the `<input>` element is temporarily attached.
  final Element target;

  /// The HTML `accept` attribute string filtering allowed file extensions/MIME types.
  final String accept;

  /// Whether multiple files can be selected.
  final bool allowMultiple;

  /// Web-specific configuration options.
  final FilePickerWebOptions webOptions;

  /// Optional callback triggered during file picking status transitions.
  final Function(FilePickerStatus)? onFileLoading;

  /// Callback delegate used to process and convert the native [FileList] to [PlatformFile]s.
  final ProcessFilesCallback processFiles;

  final Completer<List<PlatformFile>?> _completer = Completer();
  bool _eventTriggered = false;

  // WebKit requires the input to remain attached while the picker is open
  // or its change event may never arrive.
  HTMLInputElement? _input;

  // Cache JS function identities so removeEventListener can match the
  // exact listeners registered earlier.
  late final JSFunction _onFileSelectionListener = _onFileSelection.toJS;
  late final JSFunction _onCancelListener = _onCancel.toJS;

  /// Starts the file picker input interaction and returns a list of picked files or `null`.
  Future<List<PlatformFile>?> start() async {
    final uploadInput = HTMLInputElement()
      ..type = 'file'
      ..draggable = true
      ..multiple = allowMultiple
      ..accept = accept
      ..style.display = 'none';

    onFileLoading?.call(FilePickerStatus.picking);

    uploadInput.addEventListener('change', _onFileSelectionListener);
    uploadInput.addEventListener('cancel', _onCancelListener);

    if (webOptions.cancelUploadOnWindowBlur) {
      window.addEventListener('focus', _onCancelListener);
    }

    _input = uploadInput;
    _clearTargetChildren();
    target.appendChild(uploadInput);
    uploadInput.click();

    return _completer.future;
  }

  /// Completes a picker superseded by a newer request without a browser event.
  void cancel() {
    _eventTriggered = true;
    _finish(null);
  }

  void _onFileSelection(Event e) async {
    if (_eventTriggered) return;
    _eventTriggered = true;

    final targetInput = e.target as HTMLInputElement?;
    _cleanupListeners(targetInput);
    await _complete(targetInput?.files);
  }

  void _onCancel(Event _) {
    _cleanupListeners(null);

    Future.delayed(const Duration(milliseconds: 500)).then((_) async {
      if (_eventTriggered) return;
      _eventTriggered = true;

      // Safari may send focus before change; keep an existing selection
      // instead of reporting cancellation.
      final input = _input;
      final files = input?.files;
      _cleanupListeners(input);
      await _complete(files != null && files.length > 0 ? files : null);
    });
  }

  Future<void> _complete(FileList? files) async {
    _removeInput();
    if (_completer.isCompleted) return;

    if (files == null) {
      _finish(null);
      return;
    }

    final List<PlatformFile> pickedFiles;
    try {
      pickedFiles = await processFiles(files, webOptions);
    } catch (error, stackTrace) {
      // Without this the error escapes the event listener uncaught and the
      // returned future never completes.
      _finish(null, error: error, stackTrace: stackTrace);
      return;
    }

    _finish(pickedFiles);
  }

  void _finish(
    List<PlatformFile>? files, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (_completer.isCompleted) return;
    _cleanupListeners(_input);
    _removeInput();
    if (error == null) {
      _completer.complete(files);
    } else {
      _completer.completeError(error, stackTrace);
    }
    onFileLoading?.call(FilePickerStatus.done);
  }

  void _removeInput() {
    final input = _input;
    _input = null;
    if (input != null && input.parentNode == target) {
      target.removeChild(input);
    }
  }

  void _cleanupListeners(HTMLInputElement? input) {
    window.removeEventListener('focus', _onCancelListener);
    if (input != null) {
      input.removeEventListener('change', _onFileSelectionListener);
      input.removeEventListener('cancel', _onCancelListener);
    }
  }

  void _clearTargetChildren() {
    Node? firstChild = target.firstChild;
    while (firstChild != null) {
      target.removeChild(firstChild);
      firstChild = target.firstChild;
    }
  }
}
