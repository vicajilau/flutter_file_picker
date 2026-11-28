import 'package:flutter/services.dart';

/// The reasons a pick, a save or a directory choice can fail, the same on
/// every platform.
///
/// Each value carries the [code] that its [FilePickerException] reports as
/// its `PlatformException.code`. The set can grow in a minor release, so keep
/// a default case when you switch over it.
enum FilePickerErrorCode {
  /// Another pick or save was started while one was already open.
  alreadyActive('already_active'),

  /// The picked files could not be read or copied, or the platform ended the
  /// pick in an unexpected way.
  loadFailed('load_failed'),

  /// The platform rejected the arguments of the call.
  invalidArguments('invalid_arguments'),

  /// An extension of `allowedExtensions` has no matching file type on this
  /// platform.
  unsupportedExtension('unsupported_extension'),

  /// There is no app that can show a file picker, such as a file explorer on
  /// Android.
  noPickerAvailable('no_picker_available'),

  /// The window that should own the dialog is closed or hidden (macOS).
  windowNotFound('window_not_found'),

  /// The file could not be saved.
  saveFailed('save_failed'),

  /// The device ran out of memory while handling the picked files.
  outOfMemory('out_of_memory'),

  /// The macOS App Sandbox entitlements the call needs are missing.
  missingEntitlement('missing_entitlement'),

  /// Any other failure. The message of the exception tells more.
  unknown('unknown');

  const FilePickerErrorCode(this.code);

  /// The text reported as the `code` of the [FilePickerException].
  final String code;
}

/// A pick, a save or a directory choice that failed, as opposed to one the
/// user canceled, which completes with `null` or an empty list.
///
/// Switch over [errorCode] to handle each case. It extends
/// [PlatformException] only to keep existing `on PlatformException` handlers
/// working, and a later breaking release will stop doing so. Catch
/// [FilePickerException] instead.
///
/// Mistakes in the call itself, such as an invalid extension filter, are
/// still thrown as an [ArgumentError].
class FilePickerException extends PlatformException {
  /// Creates a [FilePickerException] for [errorCode].
  FilePickerException({
    required this.errorCode,
    super.message,
    super.details,
    super.stacktrace,
  }) : super(code: errorCode.code);

  /// Turns the [PlatformException] a platform channel threw into a
  /// [FilePickerException], keeping its message, details and stack trace.
  ///
  /// With [isSave], the failures that read as a failed pick, such as an
  /// activity that ended in an unexpected way, become
  /// [FilePickerErrorCode.saveFailed] instead of
  /// [FilePickerErrorCode.loadFailed].
  factory FilePickerException.fromPlatformException(
    PlatformException exception, {
    bool isSave = false,
  }) {
    if (exception is FilePickerException) return exception;

    final errorCode = _errorCodeOf(exception.code, isSave: isSave);
    return FilePickerException(
      errorCode: errorCode,
      // An unknown failure would otherwise lose the code the platform sent.
      message: errorCode == FilePickerErrorCode.unknown
          ? '${exception.code}: ${exception.message}'
          : exception.message,
      details: exception.details,
      stacktrace: exception.stacktrace,
    );
  }

  /// What went wrong.
  final FilePickerErrorCode errorCode;

  /// Runs [action], and throws a [FilePickerException] in place of the
  /// [PlatformException] it throws.
  ///
  /// Platform implementations send every call that can fail through this, so
  /// the codes the native side uses are translated in one place. Pass [isSave]
  /// for a call that saves a file.
  static Future<T> guard<T>(
    Future<T> Function() action, {
    bool isSave = false,
  }) async {
    try {
      return await action();
    } on FilePickerException {
      rethrow;
    } on PlatformException catch (e, stackTrace) {
      Error.throwWithStackTrace(
        FilePickerException.fromPlatformException(e, isSave: isSave),
        stackTrace,
      );
    }
  }

  static FilePickerErrorCode _errorCodeOf(
    String nativeCode, {
    required bool isSave,
  }) {
    // The codes the native sides send, and how they are named in Dart. They
    // stay as they are in Kotlin and Swift, so only this table knows them.
    return switch (nativeCode) {
      'already_active' ||
      'multiple_request' => FilePickerErrorCode.alreadyActive,
      'invalid_arguments' => FilePickerErrorCode.invalidArguments,
      'unsupported_extension' ||
      'Unsupported file extension' => FilePickerErrorCode.unsupportedExtension,
      'explorer_not_found' => FilePickerErrorCode.noPickerAvailable,
      'window_not_found' => FilePickerErrorCode.windowNotFound,
      'out_of_memory' => FilePickerErrorCode.outOfMemory,
      'ENTITLEMENT_NOT_FOUND' ||
      'ENTITLEMENT_REQUIRED_WRITE' ||
      'ENTITLEMENT_CHECK_FAILED' => FilePickerErrorCode.missingEntitlement,
      'Error while saving file' ||
      'save_file_error' => FilePickerErrorCode.saveFailed,
      'load_failed' ||
      'unknown_path' ||
      'unknown_activity' ||
      'unknown_result' ||
      'invalid_type' ||
      'file_picker_error' =>
        isSave
            ? FilePickerErrorCode.saveFailed
            : FilePickerErrorCode.loadFailed,
      _ => FilePickerErrorCode.unknown,
    };
  }

  @override
  String toString() =>
      'FilePickerException($errorCode, $message, $details, $stacktrace)';
}
