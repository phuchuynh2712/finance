# Specification Quality Checklist: Lock Inline Formula Input, Move to Dialog Edit

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-09-18
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Success criteria are technology-agnostic (no implementation details)
- [x] All acceptance scenarios are defined
- [x] Edge cases are identified
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria
- [x] User scenarios cover primary flows
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification

## Notes

- All decisions in this spec (lock inline input, dialog-based formula editing, staged-then-committed persistence via "Lưu công thức", tab-switch confirmation) were explicitly confirmed with the user across multiple clarifying questions before this spec was written — no [NEEDS CLARIFICATION] markers were needed.
- 2026-09-18 `/speckit-clarify` session (1st pass): 2 questions resolved 2 gaps found during ambiguity review (dialog behavior for a group vs. a leaf item; whether over-budget validation blocks or merely warns on dialog "Lưu"). Reflected in Clarifications, Acceptance Scenarios (US1 #5-#6), and FR-003/FR-004/FR-006.
- 2026-09-18 `/speckit-clarify` session (2nd pass): 2 more questions resolved (a) what visual/interactive feedback the locked field gives on tap — resolved as "none; it becomes a plain static label, not an input widget at all" — and (b) whether the now-non-interactive %/₫ mode display must still visually match the original mockup's pill-toggle — resolved as "no, left to implementation judgment since the control is purely informational now." This changed the nature of FR-001/FR-002 from "a disabled input" to "a replaced-by-label display," and terminology throughout the spec (Edge Cases, FR-005, SC-001) was updated to consistently say "static label" instead of "read-only field."
- 2026-09-18 mid-session addition: user raised, and 2 follow-up questions resolved, a new standalone concern about the group header's allocation-summary line getting truncated — resolved as "show only while collapsed, hide entirely while expanded, and never truncate while shown." Added as User Story 4 (P3), FR-014/FR-015, and SC-005, since it touches the same group-header widget already being modified by this feature.
- 2026-09-18 `/speckit-clarify` session (3rd pass): 1 question resolved the Vietnamese button labels for the navigation-confirmation prompt (FR-009) — "Lưu" / "Không lưu" / "Hủy". Replaced the generic "save"/"discard"/"cancel" wording throughout User Story 3, FR-009/FR-010/FR-011, and the Edge Cases section with these exact labels for full terminology consistency.
- 2026-09-18 `/speckit-clarify` session (4th pass): 1 question resolved whether the dialog's mode selector should switch from its current full-text `DropdownButton` to the same compact %/₫ pill-toggle already used in the list — resolved as "yes, switch to the pill-toggle" for one consistent control across the screen. FR-013 now names the specific widget change; a leftover generic "save first, discard, or cancel" phrase in User Story 3's overview (missed in the 3rd pass) was also corrected to the exact button labels.
- 2026-09-18 mid-session addition: user asked to also audit and fix the bottom navigation bar's icon/color/text against the design. A hands-on device review (screenshot + pixel measurement) found and confirmed three real mismatches: the selected-tab indicator renders in Flutter's default teal (`#03DAC6`, `colorScheme.secondary`) instead of the brand primary color; the "Lịch sử/Báo cáo" label wraps to two lines while the other four fit on one; and the bar is missing its top border line. (Icon size measured at ~19-20dp vs. the design's 22dp was judged close enough to not warrant a fix.) Added as User Story 5 (P3), FR-016/FR-017/FR-018, and SC-006, plus an Assumptions note that this fix affects the shared nav bar app-wide, not just Expense Control.
- 2026-09-18 full-screen design audit: user flagged that the spec had drifted from its original intent ("make the Kiểm soát screen match the two design mockups") into being framed narrowly around the inline-input-lock behavior change. Performed a systematic element-by-element comparison of the two provided mockup images against the current widget tree (`expense_control_screen.dart`, `expense_group_card.dart`, `expense_item_row.dart`). Found and resolved 2 real deltas not previously captured: (1) the group allocation-summary line's collapsed-only visibility (User Story 4) actually contradicts the mockups, which show it present even while a group is expanded — re-confirmed with the user as an intentional deviation and documented as such in Assumptions rather than reverted; (2) the inline value label (post-lock, per User Story 1) had no stated width behavior, risking the same truncation bug it was meant to fix if implemented with a fixed width — FR-001 now explicitly requires it to size to its content, citing the mockups' own side-by-side short ("24%") and long ("4.000.000 ₫") examples as evidence. The spec's H1 title was also renamed from the narrowly-scoped "Lock Inline Formula Input, Move to Dialog Edit" to "Align Expense Control Screen with Design (Formula Editing, Group Summary, Bottom Nav)" to accurately reflect the full scope now covered (feature branch/directory names unchanged). No other deltas were found in this pass — the remaining visual details (card radius/padding/shadow, icon badges, dashed buttons, allocation banner, "Lưu công thức" button) all matched the mockups.
- All 16 checklist items remained passing after every update in this session — no regressions.
- Items marked incomplete require spec updates before `/speckit-clarify` or `/speckit-plan`.
