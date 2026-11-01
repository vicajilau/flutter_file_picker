// The channel between the Dart and Kotlin sides of android_file_picker.
//
// After changing it, regenerate both sides from this package's folder, and
// format the Dart output, which CI checks:
//
//   dart run pigeon --input pigeons/messages.dart && dart format lib
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/messages.g.dart',
    kotlinOut:
        'android/src/main/kotlin/com/mr/flutter/plugin/filepicker/Messages.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'com.mr.flutter.plugin.filepicker',
      errorClassName: 'FilePickerFlutterError',
    ),
    dartPackageName: 'android_file_picker',
  ),
)
/// The kind of files a pick offers.
enum FileTypeMessage { any, custom, image, video, media, audio }

/// How long a Storage Access Framework grant lasts.
enum SafGrantMessage { transient, lifetime }

/// The access a Storage Access Framework grant gives.
enum SafAccessMessage { readOnly, readWrite }

/// The Storage Access Framework options of a pick.
class SafOptionsMessage {
  SafOptionsMessage({
    required this.grant,
    required this.access,
    required this.autoPersist,
  });

  SafGrantMessage grant;
  SafAccessMessage access;
  bool autoPersist;
}

/// The Storage Access Framework grant of a picked file.
class SafHandleMessage {
  SafHandleMessage({required this.uri, required this.access});

  String uri;
  SafAccessMessage access;
}

/// A picked file.
class PickedFileMessage {
  PickedFileMessage({
    this.path,
    this.name,
    required this.size,
    this.identifier,
    this.safHandle,
  });

  /// The path of the cached copy, or the URI when the file is not copied.
  String? path;
  String? name;
  int size;

  /// The URI the file was picked from.
  String? identifier;
  SafHandleMessage? safHandle;
}

/// The outcome of a pick lost when Android destroyed the activity: its
/// files, or the error it failed with.
class LostDataMessage {
  LostDataMessage({this.files, this.errorCode, this.errorMessage});

  List<PickedFileMessage>? files;
  String? errorCode;
  String? errorMessage;
}

/// The calls Dart makes to the Android side of the plugin.
@HostApi()
abstract class FilePickerApi {
  /// Picks files, or answers `null` when the user cancels.
  @asyncCallback
  List<PickedFileMessage>? pickFiles(
    FileTypeMessage type,
    bool allowMultiple,
    List<String> allowedExtensions,
    int compressionQuality,
    SafOptionsMessage? safOptions,
  );

  /// Picks a directory and answers its path or URI, or `null` when the user
  /// cancels.
  @asyncCallback
  String? pickDirectory(SafOptionsMessage? safOptions);

  /// Saves [bytes] and answers the URI of the saved document, or `null` when
  /// the user cancels.
  @asyncCallback
  String? saveFile(
    String fileName,
    String mimeType,
    String? initialDirectory,
    Uint8List bytes,
  );

  /// Answers the outcome of the pick lost when Android destroyed the
  /// activity, once, or `null` when there is none.
  @asyncCallback
  LostDataMessage? retrieveLostData();

  /// Removes the cached copies of picked files.
  void clearTemporaryFiles();

  /// Releases the persisted Storage Access Framework grant of [uri].
  void releaseSafGrant(String uri);
}
