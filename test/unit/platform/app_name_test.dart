import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The app is "Finance" in English and "Kiểm Soát" in Vietnamese, in the app
/// itself and on the home screen of both phone platforms. File-content
/// assertions only (no device needed), run from the repo root.
void main() {
  group('Android launcher label', () {
    test('the manifest takes the label from a string resource', () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      expect(manifest, contains('android:label="@string/app_name"'));
      expect(manifest, isNot(contains('android:label="finance"')));
    });

    test('English (the default) says "Finance"', () {
      final xml = File(
        'android/app/src/main/res/values/strings.xml',
      ).readAsStringSync();
      expect(xml, contains('<string name="app_name">Finance</string>'));
    });

    test('Vietnamese says "Kiểm Soát", capitalized', () {
      final xml = File(
        'android/app/src/main/res/values-vi/strings.xml',
      ).readAsStringSync();
      expect(xml, contains('<string name="app_name">Kiểm Soát</string>'));
    });
  });

  group('iOS home-screen name', () {
    late String plist;
    late String project;

    setUpAll(() {
      plist = File('ios/Runner/Info.plist').readAsStringSync();
      project = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    });

    test(
      'the plist declares English and Vietnamese and a capitalized name',
      () {
        expect(
          plist,
          contains(
            '<key>CFBundleLocalizations</key>\n\t\t<array>\n'
            '\t\t\t<string>en</string>\n\t\t\t<string>vi</string>',
          ),
        );
        expect(plist, contains('<key>CFBundleName</key>\n\t\t<string>Finance'));
        expect(
          plist,
          contains('<key>CFBundleDisplayName</key>\n\t\t<string>Finance'),
        );
      },
    );

    test(
      'the English and Vietnamese InfoPlist.strings carry the two names',
      () {
        final en = File(
          'ios/Runner/en.lproj/InfoPlist.strings',
        ).readAsStringSync();
        final vi = File(
          'ios/Runner/vi.lproj/InfoPlist.strings',
        ).readAsStringSync();
        expect(en, contains('"CFBundleDisplayName" = "Finance";'));
        expect(vi, contains('"CFBundleDisplayName" = "Kiểm Soát";'));
      },
    );

    test('the Xcode project knows Vietnamese and ships the strings files', () {
      expect(RegExp(r'knownRegions = \([^)]*\bvi,').hasMatch(project), isTrue);
      expect(project, contains('path = en.lproj/InfoPlist.strings'));
      expect(project, contains('path = vi.lproj/InfoPlist.strings'));
      expect(project, contains('InfoPlist.strings in Resources'));
    });
  });
}
