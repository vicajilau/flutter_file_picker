// The overrides have to keep the names of the generated FilePickerApi.
// ignore_for_file: non_constant_identifier_names

import 'package:android_file_picker/src/messages.g.dart';
import 'package:flutter/services.dart';

/// A [FilePickerApi] that records every call and answers through [respond],
/// in place of the Android side.
class FakeFilePickerApi implements FilePickerApi {
  FakeFilePickerApi([this.respond = _answerNull]);

  /// Answers a call to [method] with [arguments], or throws to fail it.
  final Future<Object?> Function(String method, List<Object?> arguments)
  respond;

  /// The calls made so far, in order.
  final calls = <({String method, List<Object?> arguments})>[];

  static Future<Object?> _answerNull(String _, List<Object?> _) async => null;

  Future<T> _call<T>(String method, List<Object?> arguments) async {
    calls.add((method: method, arguments: arguments));
    return await respond(method, arguments) as T;
  }

  @override
  BinaryMessenger? get pigeonVar_binaryMessenger => null;

  @override
  String get pigeonVar_messageChannelSuffix => '';

  @override
  Future<List<PickedFileMessage>?> pickFiles(
    FileTypeMessage type,
    bool allowMultiple,
    List<String> allowedExtensions,
    int compressionQuality,
    SafOptionsMessage? safOptions,
  ) => _call('pickFiles', [
    type,
    allowMultiple,
    allowedExtensions,
    compressionQuality,
    safOptions,
  ]);

  @override
  Future<String?> pickDirectory(SafOptionsMessage? safOptions) =>
      _call('pickDirectory', [safOptions]);

  @override
  Future<String?> saveFile(
    String fileName,
    String mimeType,
    String? initialDirectory,
    Uint8List bytes,
  ) => _call('saveFile', [fileName, mimeType, initialDirectory, bytes]);

  @override
  Future<LostDataMessage?> retrieveLostData() =>
      _call('retrieveLostData', const []);

  @override
  Future<void> clearTemporaryFiles() => _call('clearTemporaryFiles', const []);

  @override
  Future<void> releaseSafGrant(String uri) => _call('releaseSafGrant', [uri]);
}
