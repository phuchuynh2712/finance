/// When the app locks itself because nobody has used it (FR-001, FR-004).
///
/// One rule measuring one thing: the time since the last interaction. It
/// replaces the old "backgrounded for 5 minutes" rule, which never fired in a
/// browser (a hidden tab does not report the state that rule waited for) and
/// never covered an app left open in the foreground.
///
/// Pure Dart on purpose: no Flutter import, so every row of
/// `contracts/inactivity-lock.md` is a plain unit test.
class AppLockPolicy {
  AppLockPolicy._();

  /// The one named setting (FR-004): lock after this long without interaction.
  /// Matches the old background rule and the banking baseline's "the
  /// institution sets the period" (Circular 50/2024/TT-NHNN, Art. 7 cl. 6c).
  static const Duration defaultInactivityPeriod = Duration(minutes: 5);

  /// `--dart-define=INACTIVITY_LOCK_SECONDS=N` shortens the period for manual
  /// verification (waiting 5 minutes per scenario is impractical). `0` means
  /// "not set". It is ignored in a release build, see [resolvePeriod].
  static const int _overrideSeconds = int.fromEnvironment(
    'INACTIVITY_LOCK_SECONDS',
  );

  /// Same constant `kReleaseMode` reads; used directly to stay free of any
  /// Flutter import.
  static const bool _isRelease = bool.fromEnvironment('dart.vm.product');

  /// The period in force for this build.
  static final Duration inactivityPeriod = resolvePeriod(
    isRelease: _isRelease,
    overrideSeconds: _overrideSeconds,
  );

  /// A release build always uses [defaultInactivityPeriod]: the override can
  /// never ship. Parameters (not constants) so this is testable.
  static Duration resolvePeriod({
    required bool isRelease,
    required int overrideSeconds,
  }) {
    if (isRelease || overrideSeconds <= 0) return defaultInactivityPeriod;
    return Duration(seconds: overrideSeconds);
  }

  /// `true` when the app is signed in, not yet locked, and the last
  /// interaction is at least [period] ago.
  ///
  /// A [lastActivityAt] in the future (the clock moved back) counts as [now]:
  /// it never extends the period.
  static bool shouldLock({
    required DateTime? lastActivityAt,
    required DateTime now,
    required bool isSignedIn,
    required bool isLocked,
    Duration? period,
  }) {
    if (!isSignedIn || isLocked || lastActivityAt == null) return false;
    final last = lastActivityAt.isAfter(now) ? now : lastActivityAt;
    return now.difference(last) >= (period ?? inactivityPeriod);
  }
}
