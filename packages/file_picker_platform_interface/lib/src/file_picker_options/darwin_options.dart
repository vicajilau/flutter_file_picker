/// The representation that iOS should provide for assets selected with
/// `PHPickerViewController`.
enum DarwinAssetRepresentationMode {
  /// Lets the system select the best representation for the asset.
  automatic,

  /// Uses the current representation to avoid transcoding when possible.
  current,

  /// Uses a broadly compatible representation, transcoding when necessary.
  compatible,
}

/// Platform-specific options for file picking on Apple platforms.
class DarwinOptions {
  const DarwinOptions({
    this.assetRepresentationMode = DarwinAssetRepresentationMode.automatic,
    this.acceptLabel,
  });

  /// The preferred representation for media selected from the iOS photo
  /// library.
  ///
  /// This option only applies when `compressionQuality` is `0`. It has no
  /// effect on macOS or when selecting files with the iOS document picker.
  final DarwinAssetRepresentationMode assetRepresentationMode;

  /// The label for the confirm button of the file dialog.
  ///
  /// Maps to `NSOpenPanel.prompt` on macOS. Only honored by `pickFile()` and
  /// `pickFiles()`, the only entry points that accept [DarwinOptions] on
  /// macOS. Has no effect on iOS, `UIDocumentPickerViewController` has no
  /// equivalent there.
  final String? acceptLabel;

  /// Throws an [ArgumentError] if this configuration conflicts with
  /// [compressionQuality].
  ///
  /// A non-automatic [assetRepresentationMode] requests a specific,
  /// uncompressed representation of the asset, which [compressionQuality]
  /// would then recompress, defeating the point of requesting it. Callers
  /// (the `file_picker` facade and each platform implementation) call this
  /// before picking so the conflict is always reported the same way,
  /// regardless of platform or entry point.
  void validate(int compressionQuality) {
    if (compressionQuality != 0 &&
        assetRepresentationMode != DarwinAssetRepresentationMode.automatic) {
      throw ArgumentError.value(
        assetRepresentationMode,
        'assetRepresentationMode',
        'A non-automatic Darwin asset representation mode requires compressionQuality to be 0.',
      );
    }
  }
}
