import 'package:file_picker/file_picker.dart';
import 'package:file_picker_darwin/file_picker_darwin.dart';
import 'package:file_picker/file_picker_view_scope.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<FilePickerPlatform> pickerFor(
    WidgetTester tester, {
    bool withScope = true,
  }) async {
    late FilePickerPlatform picker;
    final probe = Builder(
      builder: (context) {
        picker = FilePickerViewScope.of(context);
        return const SizedBox();
      },
    );
    await tester.pumpWidget(
      withScope ? FilePickerViewScope(child: probe) : probe,
    );
    return picker;
  }

  testWidgets('on macOS the picker is bound to the enclosing view', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      final picker = await pickerFor(tester);
      expect(picker, isA<FilePickerDarwin>());
      expect((picker as FilePickerDarwin).viewId, tester.view.viewId);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('elsewhere the registered instance is used', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      expect(await pickerFor(tester), same(FilePickerPlatform.instance));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('without a scope the registered instance is used', (
    tester,
  ) async {
    expect(
      await pickerFor(tester, withScope: false),
      same(FilePickerPlatform.instance),
    );
  });
}
