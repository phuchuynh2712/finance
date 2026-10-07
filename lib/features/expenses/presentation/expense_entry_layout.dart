import 'dart:ui' show Size;

import 'package:finance/core/theme/app_layout.dart';

/// Layout numbers of the "Chi tiêu" entry screen, derived from the window
/// size alone (no `BuildContext`), so the arithmetic is unit-testable and
/// `build()` only reads values (specs/20261007-100751-adaptive-web-remaining-
/// screens/data-model.md §1.3, research.md Decision 3).
///
/// Compact (< 600dp) reproduces the pre-change layout exactly. Wide
/// (≥ 600dp, [WindowSizeClass.medium] and up) shrinks the pad so that the
/// amount, the twelve keys, the account chooser and Save fit a 640dp-high
/// window: the pad keys stop growing with the width and take a bounded
/// height, the amount stays pinned, and the chooser wraps inside a bounded
/// two-row area.
class ExpenseEntryLayout {
  const ExpenseEntryLayout._({
    required this.isWide,
    required this.keyHeight,
    required this.keyGap,
    required this.amountPinned,
    required this.chooserWraps,
    required this.chooserMaxHeight,
    required this.tabHeight,
    required this.tabsTopPadding,
    required this.contentTopGap,
    required this.amountVerticalPadding,
    required this.keypadVerticalPadding,
    required this.eyebrowBottomPadding,
    required this.bannerBottomMargin,
    required this.saveTopPadding,
    required this.saveBottomPadding,
    required this.saveHeight,
  });

  /// The window is wide enough (≥ 600dp) for the bounded entry panel.
  final bool isWide;

  /// Fixed pad key height in wide mode; `null` in compact mode, where the key
  /// height follows the width through [compactKeyAspectRatio] as before.
  final double? keyHeight;

  final double keyGap;

  /// Whether the amount block stays above the scrolling area (wide windows at
  /// least [pinAmountMinHeight] high). Otherwise it scrolls with the pad.
  final bool amountPinned;

  /// Wide mode lays the account chips out in a wrapping, bounded area;
  /// compact mode keeps the horizontal strip.
  final bool chooserWraps;

  /// Height of the wrapping chooser (two rows of chips); `null` in compact.
  final double? chooserMaxHeight;

  final double tabHeight;
  final double tabsTopPadding;

  /// Gap between the mode tabs and the first thing below them (the pinned
  /// amount, or the top of the scrolling list).
  final double contentTopGap;
  final double amountVerticalPadding;
  final double keypadVerticalPadding;
  final double eyebrowBottomPadding;
  final double bannerBottomMargin;
  final double saveTopPadding;
  final double saveBottomPadding;
  final double saveHeight;

  /// Below this window height the amount scrolls with the pad even in wide
  /// mode: the pinned parts (app bar, tabs, amount, Save ≈ 250dp) would leave
  /// a phone held sideways (844 × 390) a scroll region too small to use.
  static const double pinAmountMinHeight = 500;

  /// Key aspect ratio of the compact pad (width / height), unchanged.
  static const double compactKeyAspectRatio = 2.2;

  /// Smallest and largest wide key height: 48dp is the touch-target minimum,
  /// 64dp keeps the pad compact on tall windows (the spec's cap is 72dp).
  static const double minKeyHeight = 48;
  static const double maxKeyHeight = 64;

  /// One chip row is at least this tall (`_ItemChip` minHeight) and rows are
  /// [chipRunSpacing] apart; the wrapping chooser shows two of them.
  static const double chipRowHeight = 50;
  static const double chipRunSpacing = 6;

  factory ExpenseEntryLayout.of(Size window) {
    final wide =
        windowSizeClassFor(window.width).index >= WindowSizeClass.medium.index;
    if (!wide) {
      return const ExpenseEntryLayout._(
        isWide: false,
        keyHeight: null,
        keyGap: 8,
        amountPinned: false,
        chooserWraps: false,
        chooserMaxHeight: null,
        // 48dp is the touch-target minimum (it was 38); the top padding gives
        // back the same 10dp, so everything below the tabs stays where it was.
        tabHeight: 48,
        tabsTopPadding: 6,
        contentTopGap: 8,
        amountVerticalPadding: 8,
        keypadVerticalPadding: 14,
        eyebrowBottomPadding: 8,
        bannerBottomMargin: 14,
        saveTopPadding: 0,
        saveBottomPadding: 20,
        saveHeight: 52,
      );
    }
    final keyHeight = (minKeyHeight + (window.height - 640) / 8).clamp(
      minKeyHeight,
      maxKeyHeight,
    );
    return ExpenseEntryLayout._(
      isWide: true,
      keyHeight: keyHeight,
      keyGap: 6,
      amountPinned: window.height >= pinAmountMinHeight,
      chooserWraps: true,
      chooserMaxHeight: 2 * chipRowHeight + chipRunSpacing,
      tabHeight: 48,
      // Trimmed until amount, pad, chooser, banner and Save fit a 640dp-high
      // window (research.md Decision 3, calibrated in the widget test).
      tabsTopPadding: 4,
      contentTopGap: 4,
      amountVerticalPadding: 2,
      keypadVerticalPadding: 4,
      eyebrowBottomPadding: 4,
      bannerBottomMargin: 6,
      saveTopPadding: 6,
      saveBottomPadding: 12,
      saveHeight: 48,
    );
  }
}
