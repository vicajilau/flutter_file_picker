import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
import 'package:flutter/foundation.dart';

import 'file_picker_android.dart';

/// The outcome of a file selection, that was interrupted because the calling application was killed by the operating system, due to low memory constraints on the device at the time of the file selection.
///
/// Android can destroy the activity, or the whole app process, while the file
/// picker is open. The files the user picked are then delivered to a fresh
/// instance of the app, which can recover them through
/// [FilePickerAndroid.retrieveLostData].
@immutable
class LostFilePickerResult {
  /// Creates a [LostFilePickerResult] with the picked [files] or the
  /// [exception] that prevented processing them.
  const LostFilePickerResult({this.files = const [], this.exception});

  /// The files the user picked, or empty if [exception] is set.
  final List<PlatformFile> files;

  /// The error raised while processing the picked files, if any.
  final FilePickerException? exception;
}
