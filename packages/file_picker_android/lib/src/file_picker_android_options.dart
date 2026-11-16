import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';

/// The access mode that is coupled to an [AndroidSAFGrant].
enum AndroidSAFAccessMode {
  /// Only allow read permission for a URI.
  readOnly,

  /// Allow both read and write permissions for a URI.
  readWrite,
}

/// The grant type for an Android Storage Access Framework grant.
enum AndroidSAFGrant {
  /// Grant permission to the requested URI for the current request only.
  transient,

  /// Grant permission to the requested URI, until permission is explicitly revoked.
  lifetime,
}

/// Configuration options for working with Android Storage Access Framework (SAF).
final class AndroidSAFOptions {
  const AndroidSAFOptions({
    this.grant = AndroidSAFGrant.transient,
    this.accessMode = AndroidSAFAccessMode.readOnly,
    this.persistGrant = true,
    this.copyToCache = true,
  });

  /// The grant to use with the Android Storage Access Framework.
  ///
  /// Defaults to [AndroidSAFGrant.transient].
  final AndroidSAFGrant grant;

  /// The access mode to use with the Android Storage Access Framework.
  ///
  /// Defaults to [AndroidSAFAccessMode.readOnly].
  final AndroidSAFAccessMode accessMode;

  /// Whether to persist the [grant], so that it is preserved across device reboots.
  ///
  /// Defaults to `true`.
  final bool persistGrant;

  /// Whether a picked document is copied into the app's cache directory.
  ///
  /// When `false` the document is not copied: the picked file reports its
  /// `content://` URI as [PlatformFile.uri] (so [PlatformFile.path] is `null`)
  /// and its size as reported by the document provider, or no size when the
  /// provider reports none. Use this for large files such as videos, where a
  /// second copy costs storage and time, together with
  /// [AndroidSAFGrant.lifetime] when the URI has to stay readable after the app
  /// restarts.
  ///
  /// The plugin does not read content URIs itself, so
  /// [PlatformFile.readAsBytes], [PlatformFile.readAsByteStream] and
  /// [PlatformFile.xFile] do not work for a file that was not copied. Read the
  /// URI through the system instead, for example with a `ContentResolver`.
  ///
  /// Defaults to `true`.
  final bool copyToCache;

  Map<String, Object?> toMap() {
    return {
      'grant': grant.name,
      'access': accessMode.name,
      'autoPersist': persistGrant,
      'copyToCache': copyToCache,
    };
  }
}

/// Configuration options specific to the Android platform.
final class FilePickerAndroidOptions extends AndroidOptions {
  const FilePickerAndroidOptions({
    this.safOptions = const AndroidSAFOptions(),
    this.mimeTypes = const [],
  });

  /// Options for working with the Android Storage Access Framework.
  final AndroidSAFOptions safOptions;

  /// The MIME types the picker lets the user select with `FileType.custom`,
  /// such as `application/zip` or `image/*`.
  ///
  /// Android filters by MIME type, and by default the plugin turns
  /// `allowedExtensions` into MIME types through Android's own mapping. An
  /// extension that is not in that mapping cannot be used as a filter, so
  /// the pick throws a `PlatformException` with the `unsupported_extension`
  /// code. Files with such an extension still have a MIME type, the one
  /// their provider reports, so pass it here to filter by it:
  ///
  /// ```dart
  /// await FilePicker.pickFiles(
  ///   type: FileType.custom,
  ///   // Used on the other platforms.
  ///   allowedExtensions: ['abc', 'zip'],
  ///   // Used on Android instead of the extensions.
  ///   androidOptions: const FilePickerAndroidOptions(
  ///     mimeTypes: ['application/zip', 'application/octet-stream'],
  ///   ),
  /// );
  /// ```
  ///
  /// `application/octet-stream` is the type Android gives to files it cannot
  /// classify, so it also lets the user select every file of an unknown type,
  /// but not the ones with a known type, such as PDF or CSV files.
  ///
  /// When not empty, these are the filter and `allowedExtensions` is not
  /// looked up on Android, so no extension is rejected. Since several
  /// extensions can share a MIME type, the user may be able to select files
  /// with other extensions: check the extension of the result if it matters.
  ///
  /// Ignored with any other `FileType`. An entry that is not a MIME type,
  /// such as an extension, throws an [ArgumentError].
  final List<String> mimeTypes;

  Map<String, Object?> toMap() {
    return {'safOptions': safOptions.toMap(), 'mimeTypes': mimeTypes};
  }

  // Only catches what is clearly not a MIME type, such as an extension: it
  // needs a type and a subtype around one slash, without spaces.
  static final RegExp _mimeType = RegExp(r'^[^\s/]+/[^\s/]+$');

  /// Throws an [ArgumentError] if an entry of [mimeTypes] is not a MIME
  /// type, such as `application/zip` or `image/*`.
  void validate() {
    for (final mimeType in mimeTypes) {
      if (!_mimeType.hasMatch(mimeType)) {
        throw ArgumentError.value(
          mimeType,
          'mimeTypes',
          'Not a MIME type. Use a value such as application/zip or image/*.',
        );
      }
    }
  }
}
