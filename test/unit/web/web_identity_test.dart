import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// File-content assertions only — no browser needed (research.md Decision
/// 10). Reads the repo's real web/ files directly, run from the repo root
/// (flutter_test's default working directory).
void main() {
  group('web/manifest.json (FR-008, FR-009)', () {
    late Map<String, dynamic> manifest;

    setUpAll(() {
      manifest =
          jsonDecode(File('web/manifest.json').readAsStringSync())
              as Map<String, dynamic>;
    });

    test(
      'name/short_name/description show the real product, not Flutter defaults',
      () {
        expect(manifest['name'], isNot(contains('finance')));
        expect(manifest['short_name'], isNot(contains('finance')));
        expect(manifest['description'], isNot('A new Flutter project.'));
        expect(manifest['name'], contains('Kiểm Soát'));
      },
    );

    test('no orientation lock remains (FR-009)', () {
      expect(manifest.containsKey('orientation'), isFalse);
    });
  });

  group('web/index.html (FR-008)', () {
    late String html;

    setUpAll(() {
      html = File('web/index.html').readAsStringSync();
    });

    test('title is not the Flutter scaffolding default', () {
      expect(html, isNot(contains('<title>finance</title>')));
      expect(html, contains('<title>Kiểm Soát</title>'));
    });

    test('description meta is not the Flutter scaffolding default', () {
      expect(html, isNot(contains('A new Flutter project.')));
    });
  });
}
