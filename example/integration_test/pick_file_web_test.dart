import 'package:file_picker_example/src/file_picker_demo.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('picks a real file through the browser file chooser', (
    tester,
  ) async {
    // The test driver (test_driver/integration_test.dart) arms Chrome's
    // file-chooser interception before this runs and auto-accepts the same
    // fixture bundled here, so the byte count below is what proves a real
    // <input type=file> selection round-tripped end to end.
    final fixtureBytes = await rootBundle.load(
      'integration_test/fixtures/sample.txt',
    );

    await tester.pumpWidget(FilePickerDemo());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FloatingActionButton, 'Pick file'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(FloatingActionButton, 'Read picked file as bytes'),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('readAsBytes completed: ${fixtureBytes.lengthInBytes} bytes'),
      findsOneWidget,
    );
  });
}
