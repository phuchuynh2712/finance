import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

    test('onPrimary on primary >= 4.5:1', () {
      expect(
        _contrastRatio(scheme.onPrimary, scheme.primary),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('onSurface on surface >= 4.5:1', () {
      expect(
        _contrastRatio(scheme.onSurface, scheme.surface),
        greaterThanOrEqualTo(4.5),
      );
    });

    // secondary (gold) is accent/non-text use only in the light theme (see
    // research.md §2) — verified here against the non-text/large-UI 3:1
    // threshold, not the 4.5:1 text threshold.
    test('onSecondary on secondary >= 3:1 (non-text/large-UI threshold)', () {
      expect(
        _contrastRatio(scheme.onSecondary, scheme.secondary),
        greaterThanOrEqualTo(3.0),
      );
    });
  });

  group('AppTheme.dark WCAG AA contrast', () {
    final scheme = AppTheme.dark.colorScheme;

    test('onPrimary on primary >= 4.5:1', () {
      expect(
        _contrastRatio(scheme.onPrimary, scheme.primary),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('onSecondary on secondary >= 4.5:1', () {
      expect(
        _contrastRatio(scheme.onSecondary, scheme.secondary),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('onSurface on surface >= 4.5:1', () {
      expect(
        _contrastRatio(scheme.onSurface, scheme.surface),
        greaterThanOrEqualTo(4.5),
      );
    });
  });

  group('AppTheme color values match the derived brand palette', () {
    test('light scheme matches data-model.md Theme Palette', () {
      final scheme = AppTheme.light.colorScheme;
      expect(scheme.primary.toARGB32(), 0xFF287A53);
      expect(scheme.onPrimary.toARGB32(), 0xFFFFFFFF);
      expect(scheme.secondary.toARGB32(), 0xFFDFB04A);
      expect(scheme.onSecondary.toARGB32(), 0xFF153F2A);
      expect(scheme.surface.toARGB32(), 0xFFEBF5F0);
      expect(scheme.onSurface.toARGB32(), 0xFF153F2A);
    });

    test('dark scheme matches data-model.md Theme Palette', () {
      final scheme = AppTheme.dark.colorScheme;
      expect(scheme.primary.toARGB32(), 0xFF8FD3AB);
      expect(scheme.onPrimary.toARGB32(), 0xFF0C2318);
      expect(scheme.secondary.toARGB32(), 0xFFDFB04A);
      expect(scheme.onSecondary.toARGB32(), 0xFF0C2318);
      expect(scheme.surface.toARGB32(), 0xFF0C2318);
      expect(scheme.onSurface.toARGB32(), 0xFFFFFFFF);
    });
  });
}
