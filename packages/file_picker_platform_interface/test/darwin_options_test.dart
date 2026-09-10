import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DarwinOptions.validate', () {
    test('allows automatic mode regardless of compressionQuality', () {
      const options = DarwinOptions();
      expect(() => options.validate(0), returnsNormally);
      expect(() => options.validate(50), returnsNormally);
    });

    test('allows a non-automatic mode when compressionQuality is 0', () {
      const options = DarwinOptions(
        assetRepresentationMode: DarwinAssetRepresentationMode.current,
      );
      expect(() => options.validate(0), returnsNormally);
    });

    test(
      'throws when a non-automatic mode is combined with compressionQuality',
      () {
        const options = DarwinOptions(
          assetRepresentationMode: DarwinAssetRepresentationMode.compatible,
        );
        expect(() => options.validate(50), throwsArgumentError);
      },
    );
  });

  group('DarwinOptions.acceptLabel', () {
    test('defaults to null', () {
      const options = DarwinOptions();
      expect(options.acceptLabel, isNull);
    });

    test('carries the provided value', () {
      const options = DarwinOptions(acceptLabel: 'Choose');
      expect(options.acceptLabel, equals('Choose'));
    });
  });
}
