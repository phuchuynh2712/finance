# Quickstart: Architecture Audit and Shared Widget Refactor

## Before changing code

1. Confirm the active branch is `20260923-170533-architecture-widget-refactor`.
2. Run `flutter pub get` only if dependencies are missing; no new package is expected.
3. Record the current baseline with:

```powershell
flutter analyze
flutter test
```

4. Review the audit record and choose one finding at a time. Do not merge widgets based on visual similarity alone.

## Recommended implementation order

1. Add focused tests for the shared dashed-border contract and any uncovered consumer behavior.
2. Move the duplicate dashed-top-border primitive into `lib/core/widgets/` and update `expense_control` and `expenses` consumers.
3. Move concrete expense-control repository construction into the composition/DI boundary while preserving provider override points in tests.
4. Introduce the explicit application-facing contract needed by `expenses`; remove imports from `expense_control/presentation` and keep feature domain ownership intact.
5. Move balance/expense/income orchestration out of screen builds and presentation-only widgets in focused slices.
6. Move external auth exception classification out of `SignUpScreen` into an application/error boundary and preserve localized outcomes.
7. Record deferred findings, including group-card and account-field abstractions that do not yet have equivalent contracts.

## Verification after each slice

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test test/widget/core test/widget/features test/unit
```

Then run the full suite:

```powershell
flutter test
```

For changes affecting navigation, persistence, authentication, or critical financial flows, run the relevant integration test files under `test/integration/` and inspect both light and dark themes where a shared widget is changed.

## Completion evidence

The implementation is ready for review when:

- every reviewed source area is classified;
- each completed finding has focused verification evidence;
- shared widgets have explicit feature-neutral contracts;
- no feature imports another feature's presentation internals;
- `dart format`, `flutter analyze`, and `flutter test` pass;
- deferred work and residual risks are recorded.
