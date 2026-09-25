import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/theme/app_semantic_colors.dart';
import 'package:finance/core/theme/app_theme.dart';

// WCAG 2.1 relative luminance and contrast ratio, per
// https://www.w3.org/TR/WCAG21/#dfn-relative-luminance
double _relativeLuminance(Color color) {
  double channel(double c) {
    return c <= 0.03928
        ? c / 12.92
        : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  final r = channel(color.r);
  final g = channel(color.g);
  final b = channel(color.b);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double _contrastRatio(Color a, Color b) {
  final la = _relativeLuminance(a);
  final lb = _relativeLuminance(b);
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('AppTheme.light WCAG AA contrast', () {
    final scheme = AppTheme.light.colorScheme;
    final semantic = AppTheme.light.extension<AppSemanticColors>()!;

    test('onPrimary on primary >= 4.5:1', () {
      expect(
        _contrastRatio(scheme.onPrimary, scheme.primary),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('onError on error >= 4.5:1', () {
      expect(
        _contrastRatio(scheme.onError, scheme.error),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('onSurface on surface >= 4.5:1', () {
      expect(
        _contrastRatio(scheme.onSurface, scheme.surface),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('success on bgApp >= 4.5:1 (text-safe)', () {
      expect(
        _contrastRatio(semantic.success, semantic.bgApp),
        greaterThanOrEqualTo(4.5),
      );
    });

    // warning (gold) is non-text/large-UI/banner use only in the light
    // theme (see research.md §4) — verified against the non-text/large-UI
    // 3:1 threshold, not the 4.5:1 text threshold.
    test('warning on bgApp >= 3:1 (non-text/large-UI threshold)', () {
      expect(
        _contrastRatio(semantic.warning, semantic.bgApp),
        greaterThanOrEqualTo(3.0),
      );
    });
  });

  group('AppTheme.dark WCAG AA contrast', () {
    final scheme = AppTheme.dark.colorScheme;
    final semantic = AppTheme.dark.extension<AppSemanticColors>()!;

    test('onPrimary on primary >= 4.5:1', () {
      expect(
        _contrastRatio(scheme.onPrimary, scheme.primary),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('onError on error >= 4.5:1', () {
      expect(
        _contrastRatio(scheme.onError, scheme.error),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('onSurface on surface >= 4.5:1', () {
      expect(
        _contrastRatio(scheme.onSurface, scheme.surface),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('success on bgApp >= 4.5:1', () {
      expect(
        _contrastRatio(semantic.success, semantic.bgApp),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('warning on bgApp >= 4.5:1', () {
      expect(
        _contrastRatio(semantic.warning, semantic.bgApp),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('successFg on bgApp >= 4.5:1', () {
      expect(
        _contrastRatio(semantic.successFg, semantic.bgApp),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('successFg on surface >= 4.5:1', () {
      expect(
        _contrastRatio(semantic.successFg, scheme.surface),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('warningFg on bgApp >= 4.5:1', () {
      expect(
        _contrastRatio(semantic.warningFg, semantic.bgApp),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('warningFg on surface >= 4.5:1', () {
      expect(
        _contrastRatio(semantic.warningFg, scheme.surface),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('dangerFg on bgApp >= 4.5:1', () {
      expect(
        _contrastRatio(semantic.dangerFg, semantic.bgApp),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('dangerFg on surface >= 4.5:1', () {
      expect(
        _contrastRatio(semantic.dangerFg, scheme.surface),
        greaterThanOrEqualTo(4.5),
      );
    });
  });

  group('AppTheme color values match the derived brand palette', () {
    test('light scheme matches data-model.md ColorScheme mapping', () {
      final scheme = AppTheme.light.colorScheme;
      expect(scheme.primary.toARGB32(), 0xFF1A72E0);
      expect(scheme.onPrimary.toARGB32(), 0xFFFFFFFF);
      expect(scheme.error.toARGB32(), 0xFFA42619);
      expect(scheme.onError.toARGB32(), 0xFFFFFFFF);
      expect(scheme.surface.toARGB32(), 0xFFFFFFFF);
      expect(scheme.onSurface.toARGB32(), 0xFF1A1714);
    });

    test('dark scheme matches data-model.md ColorScheme mapping', () {
      final scheme = AppTheme.dark.colorScheme;
      expect(scheme.primary.toARGB32(), 0xFF3B8DF8);
      expect(scheme.onPrimary.toARGB32(), 0xFF1A1714);
      expect(scheme.error.toARGB32(), 0xFFE07A6D);
      expect(scheme.onError.toARGB32(), 0xFF1A1714);
      expect(scheme.surface.toARGB32(), 0xFF241F1A);
      expect(scheme.onSurface.toARGB32(), 0xFFFAF8F5);
    });

    test('light AppSemanticColors matches data-model.md table', () {
      final semantic = AppTheme.light.extension<AppSemanticColors>()!;
      expect(semantic.success.toARGB32(), 0xFF237A50);
      expect(semantic.warning.toARGB32(), 0xFFAE8015);
      expect(semantic.bgApp.toARGB32(), 0xFFFAF8F5);
      // Light mode has no distinct *Fg tokens — they alias the base color.
      expect(semantic.successFg.toARGB32(), semantic.success.toARGB32());
      expect(semantic.warningFg.toARGB32(), semantic.warning.toARGB32());
    });

    test('dark AppSemanticColors matches data-model.md table', () {
      final semantic = AppTheme.dark.extension<AppSemanticColors>()!;
      expect(semantic.success.toARGB32(), 0xFF62BB91);
      expect(semantic.warning.toARGB32(), 0xFFDFB04A);
      expect(semantic.bgApp.toARGB32(), 0xFF1A1714);
      expect(semantic.successFg.toARGB32(), 0xFF8FD6B0);
      expect(semantic.warningFg.toARGB32(), 0xFFECCB7E);
      expect(semantic.dangerFg.toARGB32(), 0xFFF0B3A8);
    });
  });

  group(
    'tap target overridden for desktop platforms (adaptive-layout-foundation FR-007)',
    () {
      // Flutter's own ThemeData defaults to VisualDensity.compact and
      // MaterialTapTargetSize.shrinkWrap on linux/macOS/windows (a desktop
      // Web build's defaultTargetPlatform included) — both explicitly
      // overridden here so every tap target stays >=48x48dp regardless of
      // platform (research.md Decision 6).
      test('AppTheme.light', () {
        expect(AppTheme.light.visualDensity, VisualDensity.standard);
        expect(
          AppTheme.light.materialTapTargetSize,
          MaterialTapTargetSize.padded,
        );
      });

      test('AppTheme.dark', () {
        expect(AppTheme.dark.visualDensity, VisualDensity.standard);
        expect(
          AppTheme.dark.materialTapTargetSize,
          MaterialTapTargetSize.padded,
        );
      });
    },
  );
}
