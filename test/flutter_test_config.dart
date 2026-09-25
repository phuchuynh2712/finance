import 'dart:async';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';

/// Pins every widget test's default view to a compact phone-width
/// reference (`WindowSizeClass.compact`) before each test runs.
///
/// `flutter_test`'s own unpinned default is 800×600 logical pixels — a
/// width already past this project's 600dp compact/expanded breakpoint
/// (research.md Decision 4 in
/// specs/20260925-024749-adaptive-layout-foundation/). Without this file,
/// every existing test that never sets its own `tester.view.physicalSize`
/// would silently run at what the adaptive shell treats as "expanded"
/// (a navigation rail, not the bottom bar most of them assert), breaking
/// for a reason unrelated to what they're actually testing.
///
/// 410×864 is this app's own design reference frame — every screen's
/// reference mockup under specs/*/reference/screen-*.png is an 820×1728
/// @2x export of it (confirmed by reading their PNG headers) — not an
/// arbitrary "generic phone" pick. Using it here caught a real,
/// pre-existing requirement this feature doesn't touch:
/// app_shell_nav_bar_test.dart's FR-017/SC-006 (every bottom-nav
/// destination label renders on a single line) failed at a narrower,
/// externally-plausible-but-unvalidated 390-logical-pixel width this file
/// originally used — the app was never actually designed or verified
/// against that width, so that failure was this file's own default being
/// wrong, not an app bug.
///
/// A test that needs a different width still calls
/// `tester.view.physicalSize = ...` itself, exactly as
/// `test/widget/features/expenses/expense_screen_test.dart` already does —
/// that per-test override always wins for the duration of that test; this
/// file only sets what applies when nothing more specific is set.
const _compactPhysicalSize = Size(410, 864);
const _compactDevicePixelRatio = 1.0;

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .implicitView!;
    view.physicalSize = _compactPhysicalSize;
    view.devicePixelRatio = _compactDevicePixelRatio;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });
  });
  await testMain();
}
