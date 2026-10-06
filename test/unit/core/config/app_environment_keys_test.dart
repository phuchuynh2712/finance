import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/config/app_environment.dart';

/// SC-008 made executable: every runtime value the app reads is listed once in
/// [AppEnvironment.keys], present in the example file a developer copies, and
/// explained in the README table, so none can be missing or undocumented.
void main() {
  final readme = File('README.md').readAsStringSync();

  test('AppEnvironment.keys lists exactly the values the code reads', () {
    final read = <String>{};
    final pattern = RegExp(
      r'''(?:String|bool|int)\.fromEnvironment\(\s*['"]([A-Za-z0-9_]+)['"]''',
    );
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is File && file.path.endsWith('.dart')) {
        for (final match in pattern.allMatches(file.readAsStringSync())) {
          read.add(match.group(1)!);
        }
      }
    }

    expect(
      AppEnvironment.keys.toSet(),
      read,
      reason:
          'A fromEnvironment key was added, renamed or removed without '
          'updating AppEnvironment.keys',
    );
    expect(
      AppEnvironment.keys.toSet().length,
      AppEnvironment.keys.length,
      reason: 'AppEnvironment.keys must not list a key twice',
    );
  });

  test('tool/env.example.json has exactly those keys, each with a value', () {
    final example =
        jsonDecode(File('tool/env.example.json').readAsStringSync())
            as Map<String, dynamic>;

    expect(example.keys.toSet(), AppEnvironment.keys.toSet());
    for (final entry in example.entries) {
      expect(entry.value, isA<String>(), reason: entry.key);
      expect((entry.value as String).trim(), isNotEmpty, reason: entry.key);
    }
  });

  test('the dotenv copy .env.example lists the same keys (no second, '
      'incomplete example may exist)', () {
    final keys = File('.env.example')
        .readAsLinesSync()
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !line.startsWith('#'))
        .map((line) => line.split('=').first)
        .toSet();

    expect(keys, AppEnvironment.keys.toSet());
  });

  test('the README explains every key in a table row', () {
    for (final key in AppEnvironment.keys) {
      expect(
        RegExp('^\\|\\s*`$key`\\s*\\|', multiLine: true).hasMatch(readme),
        isTrue,
        reason: 'README.md needs a table row starting with `$key`',
      );
    }
  });

  test('the README states the supported toolchain correctly and documents '
      'the steps that were previously undocumented', () {
    expect(readme, isNot(contains('Flutter SDK 3.11+')));
    expect(readme, contains('3.41'));
    expect(readme, contains('flutter config --jdk-dir'));
    expect(readme, contains('xcode-select'));
    expect(readme, contains('CocoaPods'));
  });

  test('pubspec.yaml enforces the Flutter floor the README documents', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(pubspec, contains('flutter: ">=3.41.0"'));
  });
}
