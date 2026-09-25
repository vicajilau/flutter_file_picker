import 'package:file_picker/file_picker.dart';
import 'package:android_file_picker/android_file_picker.dart';
import 'package:flutter/material.dart';

import 'file_picker_results.dart';

typedef OnRemoveAndroidFile =
    void Function(int index, AndroidPlatformFile androidPlatformFile);

class PickedFilesResults extends StatelessWidget {
  const PickedFilesResults({
    super.key,
    required this.pickedFiles,
    required this.onRemoveAndroidFile,
  });

  final List<PlatformFile> pickedFiles;
  final OnRemoveAndroidFile onRemoveAndroidFile;

  @override
  Widget build(BuildContext context) {
    return FilePickerResultsList(
      itemCount: pickedFiles.length,
      itemBuilder: (BuildContext context, int index) {
        final pickedFile = pickedFiles[index];
        final AndroidPlatformFile? androidPlatformFile =
            pickedFile is AndroidPlatformFile ? pickedFile : null;

        final Widget? trailingWidget = androidPlatformFile == null
            ? null
            : IconButton(
                icon: const Icon(Icons.delete_forever),
                onPressed: () =>
                    onRemoveAndroidFile(index, androidPlatformFile),
              );
        // On web, PlatformFile.path is always null (web files have no
        // filesystem path), so fall back to the blob/data URI instead.
        final path = pickedFile.path ?? pickedFile.uri.toString();

        return ListTile(
          leading: Text(
            index.toString(),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          title: Text('File path (SAF Grant: ${androidPlatformFile != null}):'),
          subtitle: Text(path),
          trailing: trailingWidget,
        );
      },
    );
  }
}
