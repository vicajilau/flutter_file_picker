import 'package:dbus/dbus.dart';
import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';

typedef FilterInfo = Map<String, List<(int, String)>>;

class Filter {
  static const List<String> _audioExtensions = [
    "*.aac",
    "*.midi",
    "*.mp3",
    "*.ogg",
    "*.wav",
  ];

  static const List<String> _imageExtensions = [
    "*.bmp",
    "*.gif",
    "*.jpeg",
    "*.jpg",
    "*.png",
    "*.webp",
  ];

  static const List<String> _mediaExtensions = [
    "*.avi",
    "*.flv",
    "*.m4v",
    "*.mkv",
    "*.mov",
    "*.mp4",
    "*.mpeg",
    "*.webm",
    "*.wmv",
    "*.bmp",
    "*.gif",
    "*.jpeg",
    "*.jpg",
    "*.png",
    "*.webp",
  ];

  static const List<String> _videoExtensions = [
    "*.avi",
    "*.flv",
    "*.mkv",
    "*.mov",
    "*.mp4",
    "*.m4v",
    "*.mpeg",
    "*.webm",
    "*.wmv",
  ];

  FilterInfo info = {};

  Filter(FileType type, List<String>? allowedExtensions) {
    if (type == FileType.custom &&
        (allowedExtensions == null || allowedExtensions.isEmpty)) {
      throw ArgumentError(
        'If type is set to FileType.custom, allowedExtensions cannot be null or empty.',
      );
    }
    switch (type) {
      case FileType.any:
        return;
      case FileType.audio:
        info["Audio"] = [for (final ext in _audioExtensions) (0, ext)];
      case FileType.custom:
        info["Custom"] = [for (final ext in allowedExtensions!) (0, "*.$ext")];
      case FileType.image:
        info["Image"] = [for (final ext in _imageExtensions) (0, ext)];
      case FileType.media:
        info["Media"] = [for (final ext in _mediaExtensions) (0, ext)];
      case FileType.video:
        info["Video"] = [for (final ext in _videoExtensions) (0, ext)];
    }
  }

  DBusArray toDBusArray() {
    final dataList = <DBusValue>[];

    for (final entry in info.entries) {
      final tmpList = <DBusStruct>[
        for (final (posO, val) in entry.value)
          DBusStruct([DBusUint32(posO), DBusString(val)]),
      ];

      final dataArray = DBusArray(
        DBusSignature.struct([DBusSignature.uint32, DBusSignature.string]),
        tmpList,
      );

      dataList.add(DBusStruct([DBusString(entry.key), dataArray]));
    }

    return DBusArray(
      DBusSignature.struct([
        DBusSignature.string,
        DBusSignature.array(
          DBusSignature.struct([DBusSignature.uint32, DBusSignature.string]),
        ),
      ]),
      dataList,
    );
  }
}
