# Icon verification evidence (tasks T015, T023–T026, SC-004)

Generated 2026-10-06 for `lucide_icons 0.257.0` (2023 glyphs) → `lucide_flutter 1.47.0`.

The pre-fix app cannot be built on Flutter 3.47.5, so there is no running
"before" app to screenshot. Instead, throwaway widget tests (run in a scratch
copy of the repository, not committed) loaded the **2023 font file** directly
and rendered each of the 52 icons by its old codepoint next to the new
`LucideIcons.*` constant. In every image below, **left = old 2023 glyph,
right = new glyph**, then the constant name.

| File | Content |
|------|---------|
| `icon-compare-light.png` | all 52 icons, light background |
| `icon-compare-dark.png` | all 52 icons, dark background |
| `icon-compare-zoom-light.png` | the 12 icons that differ most, at 80 px |

## Result

- All 52 icons resolve in the new package under their existing names and render.
- Every icon is still the same concept, drawn with the same 2px round-cap line
  style and the same visual weight, in light and dark.
- A quantitative check (bounding-box-aligned overlap of the two renders at
  72 px, best over ±2 px shifts; "diff" = 1 − overlap/union) found 40 of 52
  icons at ≤ 13 % (mostly anti-aliasing noise; 22 of them under 3 %, i.e.
  pixel-identical in practice). The 12 above that are upstream Lucide redraws
  between mid-2023 and now:

| Icon | Aligned diff | What changed (judged by eye) |
|------|-------------:|------------------------------|
| `sunMoon` | 58 % | Most visible: sun with an inner circle → crescent moon with rays on one side |
| `building2` | 47 % | Different building drawing, now with an entrance door |
| `slidersHorizontal` | 46 % | Same sliders; knob positions differ, slightly shorter frame |
| `film` | 44 % | Same film strip, slightly smaller frame |
| `piggyBank` | 34 % | Same pig, slightly different pose |
| `gift` | 33 % | Same gift box, shorter bow |
| `car` | 28 % | Sedan with large wheels → hatch/SUV profile |
| `shieldCheck` | 19 % | Minor outline tweak |
| `graduationCap` | 18 % | Minor outline tweak |
| `home` | 16 % | Door shape |
| `pencil` | 16 % | Detached eraser stroke fused into the body |
| `shield` | 15 % | Top-edge notch |

Per the spec's escalation rule, these redraws are recorded for the owner to
decide. None changes the icon's concept, line style, weight or size class, so
under the clarified rule (minor upstream redraws accepted, glyphs used exactly
as published, never edited by the team) they are expected to be acceptable. The
three most noticeable are `sunMoon` (Hồ sơ → Giao diện row), `building2`
(category icon `building`) and `car` (category icon `car`).

## In-app review on a real device build (2026-10-06)

The debug APK built with the public Supabase defines was installed on the
Android emulator (Pixel 10, Android 17, compact 1080x2424 and a 1600x2400
wide layout) and driven with `adb`/`uiautomator` using the QA test account.
Read-only: nothing was saved, no transaction was created. Each montage shows
**light (left) | dark (right)**.

| File | What it shows |
|------|---------------|
| `android-overview.jpg` | Tổng quan: header badge, bell, wallet icons, transaction icons, bottom navigation |
| `android-category-icon-picker.jpg` | "Sửa khoản" dialog: all 16 category icons, current icon (`utensils`) highlighted |
| `android-income.jpg`, `android-expense.jpg` | Thu nhập / Chi tiêu: chevronLeft, briefcase, plus, trash2, check, camera, pencil, delete |
| `android-history-previous-month.jpg` | History with real data: `utensils`, `home`, `walletCards` rows |
| `android-profile.jpg` | Hồ sơ: sunMoon, languages, bell, shieldCheck, helpCircle, logOut, chevronRight |
| `android-signup.jpg` | Sign-up: userPlus, chevronLeft, eye |
| `android-extra-states.jpg` | Over-balance expense (`cornerDownRight`), language sheet (`check`), sign-up checkbox (`check`), sign-in (`eyeOff`) |
| `android-wide-navigation-rail.jpg` | ≥ 600dp navigation rail with the five tab icons (light) |

Also seen on screen: Kiểm soát (`slidersHorizontal`, `pencil`, `trash2`,
`gripVertical`, `chevronDown`, `info`, category icons `utensils`, `car`,
`shoppingBag`, `heartPulse`, `shield`, `piggyBank`, `home`), Thu chi hub
(`arrowUpCircle`, `arrowDownCircle`, `history`, `chevronRight`), Báo cáo
(`pieChart`, `chevronLeft`, `chevronRight`), the four not-available
placeholders (`bell`, `shieldCheck`, `helpCircle`) and the scan tab (`camera`,
`scanLine`).

Result: every icon rendered, tinted by the theme in both appearances, and
persisted category keys resolved to the same icons on a fresh install whose data
arrived through the sync pull.

Not exercised in the running app (need state this review deliberately did not
create): `alertTriangle` (negative-balance banner), `checkCircle2` (shown after
saving an expense, which would write data) and `fingerprint` (needs an
enrolled biometric). Their glyph-level comparison above is 1.9 %, 9.7 % and
2.5 % respectively.

Tap-target size (≥ 48×48dp) is covered by the existing widget tests, which
pass. The selected-item indicator in the wide navigation rail looks teal
rather than the blue used by the bottom bar; that is theme styling, untouched
by this feature, noted only for the owner.

## iOS Simulator (2026-10-06)

After the owner ran `sudo xcode-select --switch
/Applications/Xcode.app/Contents/Developer`, `flutter build ios --simulator
--debug --dart-define-from-file=tool/env.json` succeeded and the app ran on the
iPhone 17 Simulator (iOS 26.3), driven with AXe. The same screens as on Android
were walked in light and dark: Tổng quan, Kế hoạch (all 16 category icons in the
edit dialog), Thu chi, Thu nhập, Chi tiêu, history, Báo cáo, Hồ sơ and the
placeholders. Every icon rendered and followed the theme. The biometric
enable prompt that iOS shows after sign-in was declined ("Để sau").

| File | Content (light \| dark) |
|------|------------------------|
| `ios-overview.jpg` | Tổng quan with the bottom navigation |
| `ios-category-icon-picker.jpg` | Edit dialog with the 16 icons, `utensils` highlighted |
| `ios-profile.jpg` | Hồ sơ |

The first-sign-in navigation problem reproduced on iOS exactly as on Android
and web (first press stays on the sign-in screen, second press navigates).

## First sign-in navigation fix (US4, 2026-10-06)

Before: one press of "Đăng nhập" on a fresh session stayed on the sign-in screen
(web, Android and iOS); a second press navigated. After the fix, with the app
rebuilt for each platform and the local state reset (Playwright on Chrome, an
`adb`-cleared Android app, an erased iPhone 17 Simulator), **one press** reached
Tổng quan on all three; on Android a sign-out followed by one sign-in also
worked; on iOS the biometric-enable offer still appeared over Tổng quan and was
declined ("Để sau"). The unit test `app_router_refresh_test.dart` reproduces the
original defect (red) and passes with the fix.

