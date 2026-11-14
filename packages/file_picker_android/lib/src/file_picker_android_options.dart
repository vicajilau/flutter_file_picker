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
  /// and its size as reported by the document provider. Read it through the
  /// content resolver. Use this for large files such as videos, where a second
  /// copy costs storage and time, together with [AndroidSAFGrant.lifetime] when
  /// the URI has to stay readable after the app restarts.
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
  const FilePickerAndroidOptions({this.safOptions = const AndroidSAFOptions()});

  /// Options for working with the Android Storage Access Framework.
  final AndroidSAFOptions safOptions;

  Map<String, Object?> toMap() {
    return {'safOptions': safOptions.toMap()};
  }
}
