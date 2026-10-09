import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finance/core/auth/auth_state_provider.dart';

/// Tells the [ActivityTracker] when the app is back in front, so it can lock
/// at once instead of waiting for its next periodic check (FR-001, FR-003).
///
/// Root-cause fix (constitution, Development Workflow): the old observer wrote
/// a timestamp on `paused` and read it on `resumed`. The framework documents
/// `paused` as "only entered on iOS and Android"; a hidden browser tab reaches
/// `hidden` at most, so on the web that rule never fired. The decision now
/// rests on the time of the last interaction, which no lifecycle state has to
/// report, so `hidden`, `inactive` and `paused` need no handling: whatever
/// happened while the app was away, the check on `resumed` measures the gap.
class AppLifecycleObserver with WidgetsBindingObserver {
  AppLifecycleObserver({required void Function() onResumed})
    : _onResumed = onResumed {
    WidgetsBinding.instance.addObserver(this);
  }

  final void Function() _onResumed;

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _onResumed();
  }
}

/// Instantiated once (kept alive for the app's lifetime) by [FinanceApp]
/// watching this provider at the root of the widget tree.
final appLifecycleObserverProvider = Provider<AppLifecycleObserver>((ref) {
  final observer = AppLifecycleObserver(
    onResumed: () => ref.read(activityTrackerProvider).onResumed(),
  );
  ref.onDispose(observer.dispose);
  return observer;
});
