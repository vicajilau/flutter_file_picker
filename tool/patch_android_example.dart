import 'dart:convert';
import 'dart:io';

/// Rewrites the example Android host app to a given AGP toolchain.
///
/// The CI pipeline builds the example against several AGP, Gradle and Kotlin
/// combinations to catch compatibility regressions before users hit them. Each
/// lane runs this script first to pin the toolchain it wants to assert.
///
/// Run it the same way CI does to reproduce a failing lane locally:
///
/// ```
/// dart tool/patch_android_example.dart \
///   --agp 8.13.2 --gradle 8.14.3 --kotlin 2.2.20 --built-in-kotlin ""
/// cd example && flutter build apk --debug
/// ```
///
/// The patches are deliberately strict: if a pattern no longer matches, the
/// script fails instead of building an unpatched app that would report a green
/// lane for a toolchain it never used.
const String usage = '''
Usage: dart tool/patch_android_example.dart [options]

  --agp <version>               AGP version to apply (required).
  --gradle <version>            Gradle wrapper version to apply (required).
  --kotlin <version>            Kotlin plugin version to apply (required).
  --built-in-kotlin <value>     Value for android.builtInKotlin. Pass an empty
                                string to remove the flag entirely (default).
  --new-dsl <value>             Value for android.newDsl. Pass an empty string
                                to remove the flag. Left untouched if omitted.
  --root <path>                 Android host app directory
                                (default: example/android).
''';

/// Exit code for a bad invocation.
///
/// 64 is what the Flutter CLI and `package:args` report for usage errors, and
/// keeping it distinct from 1 separates the two ways this script can fail: the
/// workflow called it wrong, or the example app drifted away from the shape the
/// patches expect.
const int usageExitCode = 64;

/// Thrown when a file no longer matches the shape this script expects.
class PatchException implements Exception {
  /// Human readable explanation of what could not be patched.
  final String message;

  /// Creates a [PatchException] with the given [message].
  PatchException(this.message);

  @override
  String toString() => message;
}

Future<void> main(List<String> args) async {
  final Map<String, String> options;
  try {
    options = parseArgs(args);
  } on FormatException catch (e) {
    stderr.writeln('$e\n\n$usage');
    exit(usageExitCode);
  }

  final missing = [
    'agp',
    'gradle',
    'kotlin',
  ].where((key) => !options.containsKey(key)).toList();
  if (missing.isNotEmpty) {
    stderr.writeln('Missing required options: ${missing.join(', ')}\n\n$usage');
    exit(usageExitCode);
  }

  final root = Directory(options['root'] ?? 'example/android');
  final settingsFile = File('${root.path}/settings.gradle.kts');
  final wrapperFile = File(
    '${root.path}/gradle/wrapper/gradle-wrapper.properties',
  );
  final gradlePropertiesFile = File('${root.path}/gradle.properties');

  try {
    settingsFile.writeAsStringSync(
      patchSettingsGradle(
        settingsFile.readAsStringSync(),
        agpVersion: options['agp']!,
        kotlinVersion: options['kotlin']!,
      ),
    );
    wrapperFile.writeAsStringSync(
      patchGradleWrapper(
        wrapperFile.readAsStringSync(),
        gradleVersion: options['gradle']!,
      ),
    );
    gradlePropertiesFile.writeAsStringSync(
      patchGradleProperties(
        gradlePropertiesFile.readAsStringSync(),
        builtInKotlin: options['built-in-kotlin'] ?? '',
        newDsl: options['new-dsl'],
      ),
    );
  } on PatchException catch (e) {
    stderr.writeln('Error: $e');
    exit(1);
  } on FileSystemException catch (e) {
    stderr.writeln('Error: ${e.message} (${e.path})');
    exit(1);
  }
}

/// Prefix every option is expected to carry.
const String optionPrefix = '--';

/// Parses `--name value` and `--name=value` pairs into a map.
///
/// Throws a [FormatException] on anything else, so a typo fails loudly instead
/// of silently leaving a version unpatched.
Map<String, String> parseArgs(List<String> args) {
  final options = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (!arg.startsWith(optionPrefix)) {
      throw FormatException('Unexpected argument: $arg');
    }
    final name = arg.substring(optionPrefix.length);
    final separator = name.indexOf('=');
    if (separator != -1) {
      options[name.substring(0, separator)] = name.substring(separator + 1);
      continue;
    }
    if (i + 1 >= args.length) {
      throw FormatException('Missing value for $arg');
    }
    options[name] = args[++i];
  }
  return options;
}

/// Applies [agpVersion] and [kotlinVersion] to a `settings.gradle.kts` source.
///
/// Throws a [PatchException] if either plugin declaration is missing.
String patchSettingsGradle(
  String source, {
  required String agpVersion,
  required String kotlinVersion,
}) {
  final agpPattern = RegExp(
    r'id\("com\.android\.application"\) version "[^"]+" apply false',
  );
  final kotlinPattern = RegExp(
    r'id\("org\.jetbrains\.kotlin\.android"\) version "[^"]+" apply false',
  );

  if (agpPattern.firstMatch(source) == null ||
      kotlinPattern.firstMatch(source) == null) {
    throw PatchException('Unable to patch settings.gradle.kts');
  }

  return source
      .replaceFirst(
        agpPattern,
        'id("com.android.application") version "$agpVersion" apply false',
      )
      .replaceFirst(
        kotlinPattern,
        'id("org.jetbrains.kotlin.android") version "$kotlinVersion" apply false',
      );
}

/// Applies [gradleVersion] to a `gradle-wrapper.properties` source.
///
/// Only the version changes. The distribution type is read back and written
/// out untouched, so a wrapper regenerated as `bin` (Gradle's own default for
/// the `wrapper` task) does not silently become `all`, and does not fail the
/// lane either.
///
/// The match is anchored to the `distributionUrl` property so a distribution
/// name quoted in a comment is never rewritten by accident.
///
/// Throws a [PatchException] if the property is missing.
String patchGradleWrapper(String source, {required String gradleVersion}) {
  final pattern = RegExp(
    r'^(distributionUrl=.*/)gradle-[^-]+-(all|bin)\.zip',
    multiLine: true,
  );
  if (pattern.firstMatch(source) == null) {
    throw PatchException('Unable to patch gradle-wrapper.properties');
  }
  return source.replaceFirstMapped(
    pattern,
    (match) => '${match[1]}gradle-$gradleVersion-${match[2]}.zip',
  );
}

/// Rewrites `android.builtInKotlin`, and optionally `android.newDsl`, in a
/// `gradle.properties` source.
///
/// Any existing `android.builtInKotlin` declaration and the comment Flutter's
/// migrator writes above it are dropped first, so lanes never inherit the
/// previous lane's value. An empty [builtInKotlin] removes the flag instead of
/// setting it.
///
/// A null [newDsl] leaves `android.newDsl` as the example declares it. Any
/// other value replaces the declaration, and an empty one removes it, which
/// on AGP 9 means the new DSL is on.
String patchGradleProperties(
  String source, {
  required String builtInKotlin,
  String? newDsl,
}) {
  const migratorComment =
      '# This builtInKotlin flag was added automatically by Flutter migrator';

  final lines = const LineSplitter()
      .convert(source)
      .where((line) => !line.startsWith('android.builtInKotlin='))
      .where((line) => line.trim() != migratorComment)
      .where((line) => newDsl == null || !line.startsWith('android.newDsl='))
      .toList();

  if (newDsl != null && newDsl.isNotEmpty) {
    lines.add('android.newDsl=$newDsl');
  }
  if (builtInKotlin.isNotEmpty) {
    lines.add('android.builtInKotlin=$builtInKotlin');
  }

  return '${lines.join('\n')}\n';
}
