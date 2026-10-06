# Quickstart: Verifying the Icon Package Replacement

**Feature**: `20261005-211030-fix-lucide-icons-compat` | **Date**: 2026-10-05

Run from the repository root on the supported toolchain (stable Flutter;
verified on 3.47.5 / Dart 3.13.4). Each scenario maps to spec success criteria.

## Scenario 1 — Clean, reproducible toolchain state (SC-005)

```bash
git status --short            # must be empty before starting
flutter pub get
flutter analyze
git status --short            # must be empty again: nothing rewritten
```

Expected: no tracked file changes after `pub get` + `analyze` (the lock file
and `analysis_options.yaml` drift were committed by this feature).

## Scenario 2 — No leftover references to the old package (FR-003, research Decision 3)

```bash
grep -rn "lucide_icons/" lib test pubspec.yaml     # expect no output
grep -rl "package:lucide_flutter" lib test --exclude=architecture_boundary_test.dart   # expect exactly one file: lib/core/theme/app_icons.dart
grep -rlE "package:finance/core/theme/app_icons.dart" lib test | wc -l   # 28 after the import rewrite (29 once the icon-key contract test is added)
```

## Scenario 3 — Build, analysis, format, tests (SC-001, SC-002, SC-003, SC-008)

```bash
flutter build web --debug              # SC-001: the command that failed before; completes, 0 compile errors
flutter build web --release            # also completes; feeds the Scenario 4 payload check
flutter analyze                        # SC-003: only the 2 existing 'onReorder' infos
dart format --output=none --set-exit-if-changed lib test   # SC-008: exit 0
flutter test                           # SC-002: every file loads, 0 failures
```

Baseline before the fix: build fails; 287 tests pass and 22 files cannot load;
format check exits 1 (11 files). Prototype result after the swap: 508 pass
(a newer `lucide_flutter` 1.x or other pub releases may shift exact figures).

Mobile (FR-001, attempted and recorded):

```bash
flutter build apk --debug
flutter build ios --debug --no-codesign
git status --short            # restore any tool-generated android/ ios/ changes: git checkout -- android ios
```

Record each as success or BLOCKED with the tool's stated reason (the Android
toolchain and Xcode are incomplete on the development machine). A Dart compile
error caused by the icon package or seam would be a real failure.

## Scenario 4 — Icon payload (SC-007)

From the `flutter build web --release` output, confirm a line like
`Font asset "lucide.ttf" was tree-shaken, reducing it from ~902,000 to ~20,000
bytes`, then:

```bash
find build/web/assets/packages -name "*.ttf" -exec ls -l {} \;
```

Expected: the Lucide font(s) from the icon package total **< 100 KB** (the
prototype measured 20,400 B, with no other icon fonts shipped). The font being
present as a build asset also confirms FR-010 (icons are bundled; no network
access is needed to render them).

## Scenario 5 — Visual review, light and dark (SC-004, FR-004, FR-007)

Run `flutter run -d chrome` with the Supabase public defines from the README,
and open each screen below in **light** and **dark** appearance (Hồ sơ →
Giao diện). **Baseline**: the design references (`specs/*/reference/icons.json`
pins 27 of the 52 icons; `screen-light.png`/`screen-dark.png` where present);
for the other 25 icons, the intended Lucide concept implied by the constant
name in data-model.md's inventory. For each icon check: same concept, 2px line
style/weight, same size, theme-driven color, tooltip/semantic label unchanged,
tap target ≥ 48×48dp. If unsure whether a difference is an acceptable upstream
stroke-level redraw or a changed line style/weight, record it (icon, screen,
light/dark) and let the owner decide.

| Screen / area | Icons to look at |
|---------------|------------------|
| Navigation bar (compact) and rail (≥ 600dp) | `layoutDashboard`, `slidersHorizontal`, `receipt`, `pieChart`, `user` |
| Sign-in | `fingerprint`, `eye`, `eyeOff` |
| Sign-up | `userPlus`, `chevronLeft`, `check`, `eye`, `eyeOff` |
| Hồ sơ (Profile) | `user`, `bell`, `shieldCheck`, `helpCircle`, `sunMoon`, `languages`, `logOut`, `chevronRight`, `check` |
| Not-available placeholders (3 Hồ sơ rows + Tổng quan bell) | `bell`, `shieldCheck`, `helpCircle` |
| Tổng quan (Overview) | `banknote`, `wallet`, `receipt`, `history`, `bell`, `alertTriangle` (negative-balance banner), `layoutDashboard` |
| Kiểm soát (Expense Control) | `plus`, `pencil`, `trash2`, `gripVertical`, `chevronDown`, `chevronRight`, `check`, `info`, `slidersHorizontal`, the allocation banner's `pieChart` |
| Category icon picker | all 16 category icons (see contracts/persisted-icon-keys.md) |
| Thu nhập (Income) | `chevronLeft`, `briefcase`, `walletCards`, `arrowUpCircle`, `plus`, `trash2`, `check` |
| Chi tiêu (Expense) | `chevronLeft`, `camera`, `scanLine`, `delete`, `cornerDownRight`, `check`, `checkCircle2`, `pencil`, `arrowDownCircle`, `walletCards` |
| Thu chi hub (Spending) | `arrowUpCircle`, `arrowDownCircle`, `history`, `chevronRight`, `chevronDown`, `walletCards` |
| Lịch sử giao dịch | `history`, `chevronLeft`, `chevronRight`, `home`, `utensils`, `walletCards` |
| Báo cáo (Report) | `pieChart`, `alertTriangle`, `chevronLeft`, `chevronRight` |

Pay particular attention to the 12 icons whose upstream name differs from the
constant (research.md Decision 4): `alertTriangle`, `arrowDownCircle`,
`arrowUpCircle`, `building2`, `checkCircle2`, `fingerprint`, `helpCircle`,
`history`, `home`, `moreHorizontal`, `pieChart`, `utensils`.

## Scenario 6 — Persisted icons keep resolving (FR-005)

1. In Kiểm soát, confirm every existing group/item shows its previously chosen
   icon (not the fallback circle).
2. Open the category icon picker on an existing item: the current icon is
   highlighted and all 16 icons are offered.
3. Sign in on a second device/profile with synced data (#23): pulled items
   render with the correct icons.
4. `flutter test test/unit/core/widgets/expense_control_icons_test.dart`
   passes (pins the 16 keys and the `circle` fallback).

## Scenario 7 — Project instructions (SC-006, FR-009)

```bash
sed -n 1,6p CLAUDE.md
ls specs/20261005-211030-fix-lucide-icons-compat/plan.md
git diff --stat -- CLAUDE.md          # only the plan path line changed
```

Expected: the block between `<!-- SPECKIT START -->` and
`<!-- SPECKIT END -->` names this feature's `plan.md`; the Language and Asset
conventions sections are unchanged.

## Scenario 8 — First sign-in navigates (US4, SC-009)

```bash
flutter test test/unit/core/router/app_router_refresh_test.dart   # 2 tests, green
```

Manually, on a fresh install (no stored session) of web, Android and iOS:
sign in **once** with a valid account → Tổng quan opens; sign out → sign-in
screen; sign in **once** again → Tổng quan opens. On a biometric-capable device
the "Bật đăng nhập vân tay?" offer still appears after the first sign-in. To
see the regression guard work, change the router's `ref.listen(isSignedInProvider
…)` back to `ref.listen(authStateChangesProvider …)` and re-run the test: it fails.

## Limits of verification on this machine

- **Android / iOS**: attempted in Scenario 3 and recorded as success or BLOCKED
  (the Android toolchain and Xcode are reported incomplete by `flutter doctor`).
  If blocked, run `flutter build apk --debug` / `flutter build ios --debug
  --no-codesign` on a fully set-up machine; the package adds one font asset and
  plain `IconData` constants, so no platform-specific difference is expected.
- **Older Flutter**: only the installed 3.47.5 is verified; versions down to the
  declared Dart floor (`^3.11.0`) are not re-verified.
