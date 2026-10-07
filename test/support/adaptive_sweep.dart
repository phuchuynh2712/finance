import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/theme/app_theme.dart';

import 'expense_control_fixtures.dart' show withRail;

/// The final sweep's matrix (specs/20261007-100751-adaptive-web-remaining-
/// screens/contracts/final-sweep.md, layer 1): every screen is mounted at each
/// case and must lay out without a single framework exception (no
/// `RenderFlex overflowed`, no layout assertion).
const sweepWidths = [320.0, 412.0, 600.0, 840.0, 1200.0, 1600.0, 2560.0];

class SweepCase {
  const SweepCase(this.width, this.height, this.dark, this.textScale);

  final double width;
  final double height;
  final bool dark;
  final double textScale;

  ThemeData get theme => dark ? AppTheme.dark : AppTheme.light;

  /// The navigation rail (83dp) sits beside any screen of the app shell from
  /// 600dp up.
  bool get hasRail => width >= 600;

  String get name =>
      '${width.toInt()}×${height.toInt()} ${dark ? 'dark' : 'light'}'
      '${textScale == 1.0 ? '' : ' text ${(textScale * 100).toInt()}%'}';
}

/// Every width × both themes at 800dp high, text scale 1.0.
final sweepWidthCases = [
  for (final dark in [false, true])
    for (final w in sweepWidths) SweepCase(w, 800, dark, 1.0),
];

/// A 500dp-high window (the smallest height FR-003 promises) at a phone and a
/// laptop width.
final sweepShortCases = [
  for (final dark in [false, true])
    for (final w in [412.0, 1440.0]) SweepCase(w, 500, dark, 1.0),
];

/// 130 % text size at a small phone, a phone and a laptop width.
final sweepTextCases = [
  for (final dark in [false, true])
    for (final w in [320.0, 412.0, 1440.0]) SweepCase(w, 800, dark, 1.3),
];

final sweepCases = [...sweepWidthCases, ...sweepShortCases, ...sweepTextCases];

/// Mounts the screen that [build] returns for [sweepCase] and asserts that it
/// lays out without a framework exception. [rail] places the screen beside the
/// shell's rail at ≥ 600dp, as in the real app.
Future<void> pumpSweepCase(
  WidgetTester tester,
  SweepCase sweepCase,
  Widget Function(ThemeData theme) build, {
  bool rail = true,
  Widget Function(Widget app)? wrap,
}) async {
  tester.view.physicalSize = Size(sweepCase.width, sweepCase.height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  // The platform's text size, so an app that builds its own `MaterialApp`
  // (the startup error screen) follows it too.
  tester.platformDispatcher.textScaleFactorTestValue = sweepCase.textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final screen = build(sweepCase.theme);
  final app = rail && sweepCase.hasRail ? withRail(screen) : screen;

  // Collect framework errors instead of letting the first one hide the rest,
  // and report where each one came from (the widget's source line).
  final errors = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = errors.add;
  try {
    await tester.pumpWidget(
      KeyedSubtree(key: UniqueKey(), child: wrap == null ? app : wrap(app)),
    );
    await tester.pumpAndSettle();
  } finally {
    FlutterError.onError = previous;
  }
  if (errors.isNotEmpty) {
    fail('layout exception at ${sweepCase.name}:\n${_summaries(errors)}');
  }
  expect(tester.takeException(), isNull);
}

String _summaries(List<FlutterErrorDetails> errors) {
  final lines = <String>{};
  for (final error in errors) {
    final text = error.toString().split('\n');
    final headline = text.firstWhere((l) => l.trim().isNotEmpty);
    final sources = text
        .where((l) => l.contains('lib/') && l.contains('.dart:'))
        .map((l) => l.trim())
        .take(2)
        .join(' | ');
    lines.add('  ${headline.trim()} [$sources]');
  }
  return lines.join('\n');
}

/// The screen's page-level vertical scroll view that has something to scroll:
/// the one with the tallest viewport, and at least 40 % of the window height
/// (an inner scroll area, such as the account chooser, is not the page).
ScrollableState? pageScrollable(WidgetTester tester, double windowHeight) {
  ScrollableState? best;
  for (final element in find.byType(Scrollable).evaluate()) {
    final state = (element as StatefulElement).state as ScrollableState;
    final position = state.position;
    if (position.axis != Axis.vertical || position.maxScrollExtent <= 0) {
      continue;
    }
    // An inner scroll area (the account chooser: ~100dp) is not the page.
    if (position.viewportDimension < windowHeight * 0.4) continue;
    if (best == null ||
        position.viewportDimension > best.position.viewportDimension) {
      best = state;
    }
  }
  return best;
}

/// The page's scroll view must span the whole viewport (the window minus the
/// navigation rail, if any) and so react to the mouse wheel over the empty side
/// margin ([left] dp from the window's left edge: 10, or 93 beside the 83dp
/// rail): no dead zone beside the column. Does nothing when the content fits
/// the window.
Future<void> expectNoDeadZone(
  WidgetTester tester,
  double windowWidth,
  double height, {
  double left = 10,
}) async {
  final state = pageScrollable(tester, height);
  if (state == null) return;
  final box = state.context.findRenderObject() as RenderBox;
  final viewportWidth = windowWidth - (left - 10);
  expect(
    box.size.width,
    greaterThanOrEqualTo(viewportWidth - 4),
    reason:
        'the page scroll view is only ${box.size.width}dp wide in a '
        '${viewportWidth}dp viewport: the margins beside it are dead zones',
  );
  final position = state.position;
  final before = position.pixels;
  final mouse = TestPointer(1, PointerDeviceKind.mouse);
  await tester.sendEventToBinding(mouse.hover(Offset(left, height / 2)));
  await tester.sendEventToBinding(mouse.scroll(const Offset(0, 80)));
  await tester.pump();
  expect(
    position.pixels,
    greaterThan(before),
    reason: 'the mouse wheel over the side margin did not scroll',
  );
}

/// [expectNoDeadZone] for a sweep case: only checked on a wide window (≥ 1200dp,
/// where the margins are wide enough to matter) and, with a rail, probed just
/// beside the rail.
Future<void> expectNoDeadZoneFor(WidgetTester tester, SweepCase c) async {
  if (c.width < 1200) return;
  await expectNoDeadZone(tester, c.width, c.height, left: c.hasRail ? 93 : 10);
}
