import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final projectRoot = Directory.current;

  test('domain files do not import framework or data-layer packages', () {
    final domainFiles =
        _dartFilesUnder(
          Directory('${projectRoot.path}${Platform.pathSeparator}lib'),
        ).where(
          (file) => file.path.contains(
            '${Platform.pathSeparator}domain${Platform.pathSeparator}',
          ),
        );

    final violations = <String>[];
    for (final file in domainFiles) {
      final source = file.readAsStringSync();
      if (RegExp(r'''import ['"]package:flutter''').hasMatch(source) ||
          RegExp(
            r'''import ['"]package:(drift|supabase_flutter)''',
          ).hasMatch(source) ||
          RegExp(r'''import ['"]package:flutter_riverpod''').hasMatch(source)) {
        violations.add(file.path);
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Domain imports must remain framework-free.',
    );
  });

  test('features do not import another feature presentation internals', () {
    final featureRoot = Directory(
      '${projectRoot.path}${Platform.pathSeparator}lib${Platform.pathSeparator}features',
    );
    final violations = <String>[];

    for (final file in _dartFilesUnder(featureRoot)) {
      final source = file.readAsStringSync();
      final currentFeature = _featureName(file.path);
      final imports = RegExp(
        r'''import ['"]package:finance/features/([^/]+)/presentation/''',
      ).allMatches(source);
      if (imports.any((match) => match.group(1) != currentFeature)) {
        violations.add(file.path);
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Feature code must not import another feature presentation internals.',
    );
  });

  test('core code does not import feature presentation internals', () {
    final coreRoot = Directory(
      '${projectRoot.path}${Platform.pathSeparator}lib${Platform.pathSeparator}core',
    );
    final violations = <String>[];

    for (final file in _dartFilesUnder(coreRoot)) {
      final source = file.readAsStringSync();
      if (RegExp(
        r'''import ['"][^'"]*(?:features/[^'"]+/presentation/|\.\./[^'"]*/presentation/)''',
      ).hasMatch(source)) {
        violations.add(file.path);
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Core code must not import feature presentation internals.',
    );
  });

  test('icon package is imported only through core/theme/app_icons.dart', () {
    final iconPackageImport = RegExp(
      r'''import\s+['"]package:(lucide_flutter|lucide_icons|lucide_icons_flutter)\b''',
    );
    final violations = <String>[];

    for (final rootName in ['lib', 'test']) {
      final root = Directory(
        '${projectRoot.path}${Platform.pathSeparator}$rootName',
      );
      for (final file in _dartFilesUnder(root)) {
        final normalized = file.path.replaceAll('\\', '/');
        if (normalized.endsWith('/lib/core/theme/app_icons.dart')) continue;
        if (iconPackageImport.hasMatch(file.readAsStringSync())) {
          violations.add(file.path);
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Only lib/core/theme/app_icons.dart may name the icon package, so a '
          'future package swap stays a one-file change.',
    );
  });
}

String? _featureName(String path) {
  final normalized = path.replaceAll('\\', '/');
  final match = RegExp(r'/features/([^/]+)/').firstMatch(normalized);
  return match?.group(1);
}

Iterable<File> _dartFilesUnder(Directory directory) sync* {
  if (!directory.existsSync()) return;
  for (final entity in directory.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) yield entity;
  }
}
