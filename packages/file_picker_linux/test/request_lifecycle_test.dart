import 'dart:typed_data';

import 'package:dbus/dbus.dart';
import 'package:file_picker_linux/file_picker_linux.dart';
import 'package:file_picker_linux/src/xdp_filechooser.dart';
import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

class _FailingChooser extends OrgFreedesktopPortalFileChooser {
  _FailingChooser(DBusClient client)
    : super(client, 'org.freedesktop.portal.Desktop');

  @override
  Future<DBusObjectPath> callOpenFile(
    String parentWindow,
    String title,
    Map<String, DBusValue> options, {
    bool noAutoStart = false,
    bool allowInteractiveAuthorization = false,
  }) async => throw StateError('portal unavailable');

  @override
  Future<DBusObjectPath> callSaveFile(
    String parentWindow,
    String title,
    Map<String, DBusValue> options, {
    bool noAutoStart = false,
    bool allowInteractiveAuthorization = false,
  }) async => throw StateError('portal unavailable');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'multiple pick preserves a portal error without status callbacks',
    () async {
      final client = DBusClient(DBusAddress('unix:path=/unused'));
      addTearDown(client.close);
      final picker = FilePickerLinux(
        client: client,
        xdpChooser: _FailingChooser(client),
      );
      final statuses = <FilePickerStatus>[];

      await expectLater(
        picker.pickFiles(onFileLoading: statuses.add),
        throwsStateError,
      );
      expect(statuses, isEmpty);
    },
  );

  test('directory preserves a portal error', () async {
    final client = DBusClient(DBusAddress('unix:path=/unused'));
    addTearDown(client.close);
    final picker = FilePickerLinux(
      client: client,
      xdpChooser: _FailingChooser(client),
    );

    await expectLater(picker.getDirectoryPath(), throwsStateError);
  });

  test('pick preserves a portal error without status callbacks', () async {
    final client = DBusClient(DBusAddress('unix:path=/unused'));
    addTearDown(client.close);
    final picker = FilePickerLinux(
      client: client,
      xdpChooser: _FailingChooser(client),
    );
    final statuses = <FilePickerStatus>[];

    await expectLater(
      picker.pickFile(onFileLoading: statuses.add),
      throwsStateError,
    );
    expect(statuses, isEmpty);
  });

  test('save preserves a portal error without status callbacks', () async {
    final client = DBusClient(DBusAddress('unix:path=/unused'));
    addTearDown(client.close);
    final picker = FilePickerLinux(
      client: client,
      xdpChooser: _FailingChooser(client),
    );
    final statuses = <FilePickerStatus>[];

    await expectLater(
      picker.saveFile(
        fileName: 'a.txt',
        bytes: Uint8List(0),
        mimeType: 'text/plain',
        onFileSaving: statuses.add,
      ),
      throwsStateError,
    );
    expect(statuses, isEmpty);
  });

  test('open, directory and save requests use different handles', () {
    const options = FilePickerLinuxOptions();
    final requests = [
      FilePickerLinux.openFileOptions(
        options,
        allowMultiple: false,
        filter: Filter(FileType.any, null),
      ),
      FilePickerLinux.directoryOptions(options),
      FilePickerLinux.saveFileOptions(options, fileName: 'a.txt'),
    ];
    final tokens = requests.map(
      (request) => request['handle_token']!.asString(),
    );
    expect(tokens.toSet(), hasLength(requests.length));
  });
}
