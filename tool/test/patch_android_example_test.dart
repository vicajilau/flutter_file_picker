import 'package:flutter_test/flutter_test.dart';

import '../patch_android_example.dart';

/// Mirrors the shape of example/android/settings.gradle.kts.
const settingsSource = '''
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.2.1" apply false
    id("org.jetbrains.kotlin.android") version "2.3.21" apply false
}
include(":app")
''';

/// Mirrors the shape of example/android/gradle.properties.
const gradlePropertiesSource = '''
org.gradle.jvmargs=-Xmx8G
android.useAndroidX=true
android.newDsl=false
android.enableJetifier=true
# This builtInKotlin flag was added automatically by Flutter migrator
android.builtInKotlin=false
''';

void main() {
  group('patchSettingsGradle', () {
    test('replaces the AGP and Kotlin plugin versions', () {
      final result = patchSettingsGradle(
        settingsSource,
        agpVersion: '8.9.1',
        kotlinVersion: '2.2.20',
      );

      expect(
        result,
        contains('id("com.android.application") version "8.9.1" apply false'),
      );
      expect(
        result,
        contains(
          'id("org.jetbrains.kotlin.android") version "2.2.20" apply false',
        ),
      );
    });

    test('leaves unrelated plugin declarations untouched', () {
      final result = patchSettingsGradle(
        settingsSource,
        agpVersion: '8.9.1',
        kotlinVersion: '2.2.20',
      );

      expect(
        result,
        contains('id("dev.flutter.flutter-plugin-loader") version "1.0.0"'),
      );
      expect(result, contains('include(":app")'));
    });

    test('throws when the AGP declaration is missing', () {
      expect(
        () => patchSettingsGradle(
          'plugins {\n    id("org.jetbrains.kotlin.android") '
          'version "2.3.21" apply false\n}\n',
          agpVersion: '8.9.1',
          kotlinVersion: '2.2.20',
        ),
        throwsA(isA<PatchException>()),
      );
    });

    test('throws when the Kotlin declaration is missing', () {
      expect(
        () => patchSettingsGradle(
          'plugins {\n    id("com.android.application") '
          'version "9.2.1" apply false\n}\n',
          agpVersion: '8.9.1',
          kotlinVersion: '2.2.20',
        ),
        throwsA(isA<PatchException>()),
      );
    });
  });

  group('patchGradleWrapper', () {
    test('replaces the distribution version', () {
      const source =
          'distributionUrl=https\\://services.gradle.org/distributions/'
          'gradle-9.5.0-all.zip\n';

      expect(
        patchGradleWrapper(source, gradleVersion: '8.14.3'),
        contains('gradle-8.14.3-all.zip'),
      );
    });

    test('preserves the surrounding properties', () {
      const source =
          'distributionBase=GRADLE_USER_HOME\n'
          'distributionUrl=https\\://services.gradle.org/distributions/'
          'gradle-9.5.0-all.zip\n';

      final result = patchGradleWrapper(source, gradleVersion: '8.14.3');

      expect(result, startsWith('distributionBase=GRADLE_USER_HOME\n'));
      expect(result, isNot(contains('gradle-9.5.0-all.zip')));
    });

    test('keeps an all distribution as all', () {
      const source =
          'distributionUrl=https\\://services.gradle.org/distributions/'
          'gradle-9.5.0-all.zip\n';

      expect(
        patchGradleWrapper(source, gradleVersion: '8.14.3'),
        contains('gradle-8.14.3-all.zip'),
      );
    });

    test('keeps a bin distribution as bin', () {
      const source =
          'distributionUrl=https\\://services.gradle.org/distributions/'
          'gradle-9.5.0-bin.zip\n';

      final result = patchGradleWrapper(source, gradleVersion: '8.14.3');

      expect(result, contains('gradle-8.14.3-bin.zip'));
      expect(result, isNot(contains('all.zip')));
    });

    test('ignores a distribution name quoted in a comment', () {
      const source =
          '# was gradle-7.0.0-all.zip before the upgrade\n'
          'distributionUrl=https\\://services.gradle.org/distributions/'
          'gradle-9.5.0-all.zip\n';

      final result = patchGradleWrapper(source, gradleVersion: '8.14.3');

      expect(result, contains('# was gradle-7.0.0-all.zip before the upgrade'));
      expect(result, contains('distributions/gradle-8.14.3-all.zip'));
    });

    test('throws when the distribution URL is missing', () {
      expect(
        () => patchGradleWrapper(
          'distributionBase=GRADLE_USER_HOME\n',
          gradleVersion: '8.14.3',
        ),
        throwsA(isA<PatchException>()),
      );
    });

    test('throws when only a comment mentions a distribution', () {
      expect(
        () => patchGradleWrapper(
          '# gradle-9.5.0-all.zip\n',
          gradleVersion: '8.14.3',
        ),
        throwsA(isA<PatchException>()),
      );
    });
  });

  group('patchGradleProperties', () {
    test('replaces an existing builtInKotlin flag', () {
      final result = patchGradleProperties(
        gradlePropertiesSource,
        builtInKotlin: 'true',
      );

      expect(result, contains('android.builtInKotlin=true'));
      expect(result, isNot(contains('android.builtInKotlin=false')));
    });

    test('removes the flag when the value is empty', () {
      final result = patchGradleProperties(
        gradlePropertiesSource,
        builtInKotlin: '',
      );

      expect(result, isNot(contains('android.builtInKotlin')));
    });

    test('drops the comment written by the Flutter migrator', () {
      final result = patchGradleProperties(
        gradlePropertiesSource,
        builtInKotlin: 'false',
      );

      expect(result, isNot(contains('Flutter migrator')));
    });

    test('keeps every other property in order', () {
      final result = patchGradleProperties(
        gradlePropertiesSource,
        builtInKotlin: 'false',
      );

      expect(
        result,
        startsWith(
          'org.gradle.jvmargs=-Xmx8G\n'
          'android.useAndroidX=true\n'
          'android.newDsl=false\n'
          'android.enableJetifier=true\n',
        ),
      );
    });

    test('ends with a single trailing newline', () {
      final result = patchGradleProperties(
        gradlePropertiesSource,
        builtInKotlin: 'false',
      );

      expect(result, endsWith('android.builtInKotlin=false\n'));
      expect(result, isNot(endsWith('\n\n')));
    });

    test('is idempotent across repeated lanes', () {
      final once = patchGradleProperties(
        gradlePropertiesSource,
        builtInKotlin: 'false',
      );
      final twice = patchGradleProperties(once, builtInKotlin: 'false');

      expect(twice, once);
    });

    test('leaves the newDsl flag untouched when it is not given', () {
      final result = patchGradleProperties(
        gradlePropertiesSource,
        builtInKotlin: 'true',
      );

      expect(result, contains('android.newDsl=false'));
    });

    test('replaces an existing newDsl flag', () {
      final result = patchGradleProperties(
        gradlePropertiesSource,
        builtInKotlin: 'true',
        newDsl: 'true',
      );

      expect(result, contains('android.newDsl=true'));
      expect(result, isNot(contains('android.newDsl=false')));
    });

    test('removes the newDsl flag when the value is empty', () {
      final result = patchGradleProperties(
        gradlePropertiesSource,
        builtInKotlin: 'true',
        newDsl: '',
      );

      expect(result, isNot(contains('android.newDsl')));
    });

    test('is idempotent with a newDsl flag', () {
      final once = patchGradleProperties(
        gradlePropertiesSource,
        builtInKotlin: 'true',
        newDsl: 'true',
      );
      final twice = patchGradleProperties(
        once,
        builtInKotlin: 'true',
        newDsl: 'true',
      );

      expect(twice, once);
    });
  });

  group('parseArgs', () {
    test('accepts space separated values', () {
      expect(parseArgs(['--agp', '8.9.1', '--gradle', '8.14.3']), {
        'agp': '8.9.1',
        'gradle': '8.14.3',
      });
    });

    test('accepts equals separated values', () {
      expect(parseArgs(['--agp=8.9.1', '--gradle=8.14.3']), {
        'agp': '8.9.1',
        'gradle': '8.14.3',
      });
    });

    test('accepts an explicitly empty value', () {
      expect(parseArgs(['--built-in-kotlin', '']), {'built-in-kotlin': ''});
    });

    test('throws on a positional argument', () {
      expect(() => parseArgs(['8.9.1']), throwsFormatException);
    });

    test('throws when a flag has no value', () {
      expect(() => parseArgs(['--agp']), throwsFormatException);
    });
  });
}
