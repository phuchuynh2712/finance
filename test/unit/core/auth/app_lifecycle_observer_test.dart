import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/auth/app_lifecycle_observer.dart';

/// The observer's only job is to ask the tracker to check as soon as the app is
/// back in front. It replaced `shouldRelockOnResume`, whose "time since the app
/// was backgrounded" rule never fired on the web (a hidden tab does not reach
/// `paused`); the decision now rests on the last interaction.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late int resumed;
  late AppLifecycleObserver observer;

  setUp(() {
    resumed = 0;
    observer = AppLifecycleObserver(onResumed: () => resumed++);
  });

  tearDown(() => observer.dispose());

  test('resumed asks the tracker to check at once', () {
    observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(resumed, 1);
  });

  test('hidden, paused and inactive do nothing', () {
    for (final state in [
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.inactive,
    ]) {
      observer.didChangeAppLifecycleState(state);
    }
    expect(resumed, 0);
  });

  test('a web tab (hidden, then visible) is checked on return like a phone '
      'app (inactive, hidden, paused, then resumed)', () {
    observer
      ..didChangeAppLifecycleState(AppLifecycleState.hidden)
      ..didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(resumed, 1);
    observer
      ..didChangeAppLifecycleState(AppLifecycleState.inactive)
      ..didChangeAppLifecycleState(AppLifecycleState.hidden)
      ..didChangeAppLifecycleState(AppLifecycleState.paused)
      ..didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(resumed, 2);
  });

  test('after dispose it no longer listens to the binding', () {
    observer.dispose();
    WidgetsBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
    expect(resumed, 0);
  });
}
