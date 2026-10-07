# Research: Restore Buildability — Fix Icon Library Incompatibility

**Feature**: `20261005-211030-fix-lucide-icons-compat` | **Date**: 2026-10-05

All measurements below were taken on 2026-10-05 on the installed stable
toolchain (Flutter 3.47.5 / Dart 3.13.4, macOS arm64). Candidate packages were
trialled in **throwaway copies of the repository** (scratch directories, not the
working tree): the 28 import lines (18 in `lib/`, 10 in `test/`) and the one
`pubspec.yaml` dependency line were rewritten, then `pub get`, `flutter
analyze`, `flutter build web --release` and the full `flutter test` were run.

## Decision 1 — Root cause, and why a version bump cannot fix it

**Decision**: Replace the `lucide_icons` dependency; do not try to upgrade,
patch, or pin around it.

**Evidence**:

- `flutter build web --debug` and 22 test files fail with
  `The class 'IconData' can't be extended outside of its library because it's a
  final class` at `lucide_icons-0.257.0/lib/src/icon_data.dart:3`
  (`class LucideIconData extends IconData`).
- `lucide_icons 0.257.0` is the newest published version (published
  2023-06-29; pub score 45/160; the package declares `sdk: >=2.12.0 <3.0.0`).
  `dart pub outdated` lists no newer release, so there is nothing to upgrade to.
- The failing construct is the package's core design (every icon is a
  `LucideIconData`), so a local patch would amount to owning a fork of an
  abandoned package.

**Alternatives considered**:

| Alternative | Why rejected |
|-------------|--------------|
| Pin an older Flutter | Blocks every other dependency/SDK upgrade, contradicts FR-001 and the constitution's dependency-hygiene rule. |
| Fork/patch `lucide_icons` via `dependency_overrides` or a git dependency | The team would own an abandoned package; the glyph set stays frozen at Lucide mid-2023. |
| In-repo icon font generated from SVG | Owner direction (spec Clarifications): the team does not draw, trace or freeze glyphs; a custom set is only commissioned from a designer if a package gap is ever found. No gap exists (Decision 4). |

## Decision 2 — Use `lucide_flutter` ^1.47.0

**Decision**: Depend on `lucide_flutter` (pub.dev), used exactly as published.

**Candidates** (all on pub.dev, all MIT, all font-based with plain
`const IconData(...)`, so none hits the `final class` error):

| | `lucide_flutter` 1.47.0 | `lucide_icons_flutter` 3.1.22 | `flutter_lucide` 1.52.0 |
|---|---|---|---|
| Last release | 2026-09-20 | 2026-10-05 | 2026-10-04 |
| Upstream Lucide tracked | ~1.47 (repo already merged 1.48.0) | 1.52.0 | 1.52.0 |
| Upgrade mechanism | bot PRs (`github-actions`, `renovate`) | maintainer-driven, frequent | bot PRs per Lucide release |
| pub points / likes / 30-day downloads | 160 / 4 / ~15k | 160 / 206 / ~247k | 160 / 93 / ~22k |
| Repo | `cliq-ssh/lucide_flutter` (3 stars, 4 open issues) | `vqh2602/lucide-flutter-main` (44 stars, 0 open issues) | `ravikovind/flutter_lucide` (26 stars, 3 open issues) |
| Constants / naming | 2,108, camelCase, upstream aliases kept | 29,764 (adds weight & `Dir` variants), camelCase, aliases kept | 1,866, **snake_case**, aliases dropped |
| Coverage of our 52 icons under **current names** | **52 / 52** | **52 / 52** | 40 / 52 (12 would need renames, e.g. `alertTriangle`, `home`, `helpCircle`) |
| Font assets bundled | 1 (`lucide.ttf`, 902 KB) | **7** (`lucide.ttf` + six variable-weight fonts, ~0.46–0.52 MB each) | 1 (910 KB) |
| Dart source size | 748 KB | **13.8 MB** (one 134k-line file) | 3.2 MB |

**Prototype results** (identical import-only change in each trial):

| | `lucide_flutter` | `lucide_icons_flutter` |
|---|---|---|
| `flutter pub get` | OK, 7 deps changed (see Decision 5) | OK, same 7 |
| `flutter analyze` | 2 issues (the 2 existing `onReorder` infos) | same 2 |
| `flutter build web --release` | OK, 21.9 s | OK, 23.8 s |
| Main Lucide font after tree-shaking | 902,460 → **20,400 B** (97.7%) | 910,776 → **20,400 B** (97.8%) |
| Other bundled icon fonts | none | six weight fonts, **2,923,332 B shipped untouched** |
| Total icon-font payload on web | **20,400 B** | **~2.94 MB** |
| `build/web` total | 43 MB | 46 MB |
| `flutter test` | **508 passed**, 0 failed, 32 s | **508 passed**, 0 failed, 35 s |

(Baseline for comparison: `master` on this toolchain → 287 passed, 22 files
cannot load, no build.)

**Rationale**: Both full-coverage candidates fix the build and need only an
import-line change. `lucide_icons_flutter` is more widely used, but it forces
~2.9 MB of unused font weights into every web and mobile bundle (Flutter's
icon tree-shaker subsets only the font family the code actually references),
which cuts against Principle IV (Performance) and fails SC-007.
`lucide_flutter` ships 20 KB for the same 52 icons. `flutter_lucide` would
force 12 call-site renames plus a snake_case style foreign to the codebase for
no payload advantage.

**Dependency-hygiene review** (constitution, Security): maintenance — see the
release cadence and repository activity above; license — MIT; **permissions
requested — none** (the package's `pubspec.yaml` declares only a font asset:
no native plugin, no platform channel, no manifest or entitlement entries);
`dart pub outdated` was checked and shows the old package at its final
release.

**Risks accepted (and mitigations)**:

- *Low adoption / single small maintainer group.* Mitigated by Decision 3: the
  package is imported in exactly one file, and both full-coverage packages
  expose the same `LucideIcons` class and constant names, so falling back to
  `lucide_icons_flutter` is a one-line edit in that file plus `pubspec.yaml`
  (trade-off: +2.9 MB). The prototypes proved this compiles and passes all
  tests with no other code change.
- *Publish lag* (repo merged Lucide 1.48.0 on 2026-09-25 but pub.dev still
  shows 1.47.0). Acceptable: icons already used exist today; FR-003 is met
  (release within 12 months).
- *Upstream may remove an icon in a later release.* Every one of the 52
  constants is referenced from compiled code, so removal surfaces as a compile
  error on upgrade, never as a silent visual change.

## Decision 3 — One import seam for the icon package

**Decision**: Add `lib/core/theme/app_icons.dart` containing a single
re-export, and make every other file import the icon class from it:

```dart
export 'package:lucide_flutter/lucide_flutter.dart' show LucideIcons;
```

Call sites stay `LucideIcons.xyz`; only the import line changes (28 files, same
count as a direct swap). A new architecture-boundary test asserts that
`package:lucide_flutter` is imported only by that file.

**Rationale**: The incident that triggered this feature is a third-party icon
package breaking 28 files at once. The constitution already requires
third-party plugin wrappers to be isolated behind an abstraction in `core/`
(Recommended Architecture). A one-line re-export is the cheapest such seam and
turns the next package swap into a one-file change. It adds no new type and no
runtime cost (re-exports are compile-time only; tree-shaking is unaffected
because the constants stay `static const IconData`).

**Placement**: `lib/core/theme/` rather than `lib/core/widgets/`. Icons are
design-system tokens consumed through the theme by every screen, which is what
the constitution's `theme/` slot is for. The existing
`lib/core/widgets/expense_control_icons.dart` is a different concern (a
persisted-key → icon lookup for one feature's data) and keeps its place; it
simply imports the seam like everyone else.

**Alternatives considered**: import the package directly in 28 files (status
quo; rejected for the reason above); a wrapper class with one getter per icon
(rejected: 52 hand-maintained getters is exactly the indirection this seam
avoids, and it would break `const` map usage in `expenseControlIcons`).

## Decision 4 — Icon identity is preserved (aliases share a codepoint)

**Decision**: Keep every existing constant name unchanged; no call site is
renamed.

**Evidence**: In `lucide_flutter`, upstream-renamed icons keep their old name
as an alias constant with the **same codepoint** as the new canonical name, so
the glyph is the same icon. The 12 names that differ from today's canonical
Lucide naming:

| Existing constant | Current canonical Lucide name | Same codepoint |
|---|---|---|
| `alertTriangle` | `triangle-alert` | yes |
| `arrowDownCircle` / `arrowUpCircle` | `circle-arrow-down` / `circle-arrow-up` | yes |
| `building2` | `building-complex` | yes |
| `checkCircle2` | `circle-check` | yes |
| `fingerprint` | `fingerprint-pattern` | yes |
| `helpCircle` | `circle-help` (`circle-question-mark`) | yes |
| `history` | `rotate-ccw-clock` | yes |
| `home` | `house` | yes |
| `moreHorizontal` | `ellipsis` | yes |
| `pieChart` | `chart-pie` | yes |
| `utensils` | `fork-knife` | yes |

The other 40 names are unchanged in upstream. Therefore FR-004 (same icon,
upstream stroke-level redraws allowed) holds by construction; the visual
review in `quickstart.md` confirms it and covers redraws.

**Baseline for SC-004**: the design references
(`specs/*/reference/icons.json`) pin 27 of the 52 icons with an explicit
`flutterConstant` and size; the remaining 25 (mostly category icons such as
`car`, `plane`, `gift`, plus `circle`/`delete`/`user`) take their intended
Lucide concept from the existing constant name.

## Decision 5 — Reconcile toolchain drift so a clean checkout stays clean

**Decision**: Commit the results of one `flutter pub get` and one
`flutter analyze` on the supported toolchain, and bring the format check to
green with a mechanical, separately reviewable commit.

**Evidence** (identical for both prototypes, so it is independent of the
package choice):

- `pubspec.lock` (as resolved on 2026-10-05; a newer 1.x `lucide_flutter` or
  other pub releases may alter the exact set later): besides swapping the icon
  package, `intl` 0.20.2→0.20.3,
  `matcher` 0.12.18→0.12.20, `meta` 1.17.0→1.19.0, `test_api` 0.7.8→0.7.12,
  `vector_math` 2.2.0→2.4.3 (7 changes in total). A second `pub get` produced
  zero further changes (stable).
- `analysis_options.yaml`: the toolchain rewrites it on `pub get`/`analyze`
  ("Upgrading analysis_options.yaml to exclude build and platform
  directories"), adding an `analyzer: exclude:` block (in the real repo: `build/**`,
  `android/**`, `ios/**`, `web/**`; the scratch copies had no `android/`/`ios/`). A second run produced no further change (stable). It was
  reverted during research and will be committed in implementation.
- `dart format --output=none --set-exit-if-changed lib test` exits 1 on
  `master`: 11 files would change — `lib/core/database/app_database.dart`,
  `lib/core/sync/initial_pull_complete_provider.dart`,
  `lib/core/sync/pull_service.dart`, `lib/core/sync/remote_row_writer.dart`
  and 7 files under `test/unit/core/` (database migration, sync). All come
  from the previously merged sync work; none touch icons. The import-line edits
  of this feature do not add any new format violation.

**Rationale**: The constitution's Development Workflow requires analyze,
format check and the full test suite to pass before merge. Leaving the format
gate red would make this feature's PR unmergeable by the project's own rule.
The reformat is isolated in its own commit/phase (FR-011) so it can be
reviewed as pure whitespace or dropped independently.

**Alternatives considered**: ignore the format failures (rejected: gate stays
red); revert the lock/analysis changes after each run (rejected: every
contributor's first command would dirty the tree again).

## Decision 6 — Test strategy

**Decision**: No new test framework; keep every existing test's intent and add
two small tests.

1. **Existing suite** — the 22 unloadable files load again; all 508 tests pass
   (prototype). Test files only change their import line (10 files); no
   assertion is edited.
2. **New: persisted icon-key contract**
   (`test/unit/core/widgets/expense_control_icons_test.dart`): pins the 16
   `expenseControlIcons` keys, asserts every key resolves, and asserts an
   unknown key falls back to `LucideIcons.circle`. This guards FR-005 for
   data already stored locally and synced from Supabase (`icon_key`,
   `display_icon_key`).
3. **New: seam enforcement** (extend
   `test/unit/architecture/architecture_boundary_test.dart`): fails if any
   file other than `lib/core/theme/app_icons.dart` imports
   `package:lucide_flutter` or a legacy icon package, so the single-seam
   property cannot rot.
4. **Manual**: the Chrome light/dark visual review and the payload check in
   `quickstart.md` (SC-004, SC-007). Visual review cannot be automated
   against the pre-fix app because it no longer builds.

## Decision 7 — Verification scope and platform statement

- **Web**: verified in this environment (release build, full test suite,
  Chrome available) — satisfies the constitution's "state whether verified on
  Web" rule.
- **Android / iOS**: `flutter doctor` reports the Android toolchain and Xcode
  as `[!]` (incomplete) on this machine, so these builds may not be possible
  here. Implementation still **attempts** `flutter build apk --debug` and
  `flutter build ios --debug --no-codesign` (tasks.md T015) and records the
  outcome: success, or BLOCKED with the tool's stated reason. Risk is low: the
  package contributes one font asset and plain `IconData` constants, behaving
  identically across platforms. A blocked mobile build is reported, not treated
  as a defect of this feature (matches the spec's "Build verification scope"
  assumption).
- **Outcome (2026-10-06)**: Android **passes** — with JDK 21 selected via
  `flutter config --jdk-dir`, `flutter build apk --debug` succeeds and the app
  was installed and exercised on a Pixel 10 emulator. iOS **passes** — after the
  owner pointed `xcode-select` at Xcode and CocoaPods 1.17.0 was installed,
  `flutter build ios --simulator --debug` succeeds and the app was exercised on
  the iPhone 17 Simulator (iOS 26.3). Evidence in `verification/README.md`. A
  signed device build (`--no-codesign` is not enough for this Flutter) would still
  need a Development Team.
- **Flutter version range**: verified only on 3.47.5; older Flutter within the
  declared Dart floor (`^3.11.0`) is **not** re-verified. The package uses a
  plain `const IconData(...)`, which is expected to compile on older Flutter
  too, and `lucide_flutter` requires Dart `^3.8.1`, below our floor, so the
  floor does not need to rise.

## Decision 8 — `CLAUDE.md` plan pointer

**Decision**: The plan workflow rewrites the pointer between the
`<!-- SPECKIT START -->` / `<!-- SPECKIT END -->` markers to this feature's
plan. Correction to an earlier statement: the pointer on disk named
`specs/20260929-014317-supabase-realtime-pull/plan.md` (merged in #23), not the
secure-storage plan; the spec's Background was fixed accordingly. The Language
and Asset convention sections stay byte-for-byte unchanged (FR-009).

## Decision 9 — Fix the first-sign-in navigation defect at its root (US4, FR-012)

**Decision**: In `lib/core/router/app_router.dart`, make the router's refresh
signal listen to `isSignedInProvider` (the state the redirect reads) instead of
the upstream `authStateChangesProvider`. Expose the refresh listenable as a
`@visibleForTesting` provider so a unit test can observe the timing.

**Evidence** (the owner reported "first press spins, nothing happens, second
press navigates"; reproduced on web, the Android emulator and the iOS Simulator):
an instrumented scratch copy of the app logged the redirect inputs. When the
`signedIn` event arrived the refresh listener fired and the redirect ran, but
`isSignedInProvider` still returned `false`; nothing re-evaluated afterwards
because `AppLockNotifier.unlock()` is a no-op on a fresh session
(`false`→`false`). A second sign-in worked because the cached derived value was
already `true`. The unit test `app_router_refresh_test.dart` reproduces it
without any UI: before the fix the observed value at refresh time was `false`
after a sign-in event and `true` after a sign-out event (both stale); after the
fix it is current in both cases.

**Rationale**: Riverpod notifies a `ref.listen` on a provider before the
providers derived from it have recomputed, so reading a derived provider
inside a listener on its source is stale. Listening to the derived provider
itself runs the callback after it has the new value. The router already did
this for the lock and password-recovery state; only the auth state used the
upstream stream. One line changes behavior; no new state, no timers.

**Why it is in this feature**: the constitution (Development Workflow) requires
a bug discovered in shared `core/` code to be fixed at its root rather than
worked around; the owner also asked for it. FR-008 was amended with this single
exception.

**Alternatives considered**: have the sign-in screen navigate explicitly after
`signInWithPassword` (rejected: a per-caller workaround that leaves sign-up and
any future sign-in path broken); call `ref.read(authStateChangesProvider)`
inside the redirect instead of the derived provider (rejected: duplicates
`isSignedInProvider`'s own logic and leaves the ordering trap in place);
ping twice (rejected: papering over the ordering).

**Verification**: new regression tests (2, red before / green after); full
suite 514 passed; on web, Android and iOS one press now reaches Tổng quan, and
a sign-out followed by one sign-in also works. On iOS (biometric-capable
simulator) the biometric-enable offer still appears, over Tổng quan. A residual
timing dependency remains in `maybeShowBiometricEnablePrompt`, which checks
`context.mounted` after awaits on a screen the router may already have left; it
worked in the observed run and is unchanged, but the owner may want to harden it
by using the root navigator's context.

## Observations recorded but out of scope

- `transaction_history_screen.dart` has its own `_iconFor(String?)` that maps
  only `home` and `utensils` and falls back to `walletCards`, while every other
  screen resolves keys through `resolveExpenseControlIcon`. This is a
  pre-existing inconsistency in a separate feature's code, unrelated to the
  package swap; it is left untouched and can be raised as its own item.
- Four icons named in the design references (`arrowLeftRight`, `circleHelp`,
  `pencilLine`, `userRound`) are not used by the code (the code uses
  equivalents such as `helpCircle`). Documentation drift only.
- Historical `specs/*/reference/README.md` files still say
  `flutter pub add lucide_icons`. They are archived design inputs and are not
  rewritten.
- **Fresh-session sign-in did not navigate (pre-existing) — FIXED in this
  feature**, see Decision 9. Kept here only as the discovery record: found on
  2026-10-06 while testing in the running app, confirmed by the owner on web.
- **Cold-start lock looks racy (pre-existing, same session).** One relaunch
  with a stored session showed the lock/sign-in screen, a later relaunch went
  straight to Tổng quan. `AppLockNotifier` only locks if
  `authStateChangesProvider` already holds data when the notifier is first
  built (its `fireImmediately` callback sets `_initialCheckDone` even while the
  stream is still loading). If confirmed, FR-020's cold-start gate is not
  deterministic. Deferred for the same reason.
  **Resolved (2026-10-08, pull request #31):** confirmed and fixed at the root.
  `AppLockNotifier` now waits for the first real auth event (it ignores the
  "still loading" value), so a saved session locks on every cold start however
  early the notifier is created. `app_lock_notifier_test` has a test that fails
  without the fix; on web a page reload, a direct address and a second tab, and
  on Android and iOS every cold start with a saved session, land on the lock
  screen.
- **Local environment changes made while verifying** (outside the repo): Flutter
  user setting `jdk-dir` now points at JBR 21; Homebrew `cocoapods` 1.17.0 and
  its `ruby` dependency installed; Android Gradle auto-installed CMake 3.22.1
  into the SDK. Scratch tooling (Playwright venv, instrumented build copies)
  lives only in the session scratchpad.

