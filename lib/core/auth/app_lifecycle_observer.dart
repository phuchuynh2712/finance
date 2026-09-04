import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_state_provider.dart';

/// FR-020's background-resume half of the re-entry gate: a safety net on
/// top of the free case where the OS has fully killed the app process while
/// backgrounded (which already re-triggers [AppLockNotifier]'s cold-start
/// check with zero extra code, since there's no in-memory state to resume
/// at all). This observer instead covers the case where the process
/// survives in memory past 5 minutes backgrounded — not guaranteed by any
/// OS, so an explicit timer is the only way to satisfy the constitution's
/// "gate access ... after launch or resume from background" deterministically.
class AppLifecycleObserver with WidgetsBindingObserver {
  AppLifecycleObserver(this._ref) {
    WidgetsBinding.instance.addObserver(this);
  }

  final Ref _ref;

  static const _lastBackgroundedAtKey = 'APP_LAST_BACKGROUNDED_AT';
  static const _storage = FlutterSecureStorage();
  static const lockThreshold = Duration(minutes: 5);

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      unawaited(_recordBackgroundedNow());
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_relockIfThresholdExceeded());
    }
  }

  Future<void> _recordBackgroundedNow() {
    return _storage.write(
      key: _lastBackgroundedAtKey,
      value: DateTime.now().toIso8601String(),
    );
  }

  Future<void> _relockIfThresholdExceeded() async {
    final raw = await _storage.read(key: _lastBackgroundedAtKey);
    final lastBackgroundedAt = raw == null ? null : DateTime.tryParse(raw);
    if (!shouldRelockOnResume(
      lastBackgroundedAt: lastBackgroundedAt,
      now: DateTime.now(),
      isSignedIn: _ref.read(isSignedInProvider),
    )) {
      return;
    }
    _ref.read(appLockProvider.notifier).lock();
  }
}

/// Pure threshold decision (FR-020), extracted from [AppLifecycleObserver]
/// so it's unit-testable without a platform channel for secure storage —
/// same rationale as `computeAuthRedirect` in `app_router.dart`.
bool shouldRelockOnResume({
  required DateTime? lastBackgroundedAt,
  required DateTime now,
  required bool isSignedIn,
}) {
  if (!isSignedIn) return false;
  if (lastBackgroundedAt == null) return false;
  return now.difference(lastBackgroundedAt) >
      AppLifecycleObserver.lockThreshold;
}

/// Instantiated once (kept alive for the app's lifetime) by [FinanceApp]
/// watching this provider at the root of the widget tree.
final appLifecycleObserverProvider = Provider<AppLifecycleObserver>((ref) {
  final observer = AppLifecycleObserver(ref);
  ref.onDispose(observer.dispose);
  return observer;
});
