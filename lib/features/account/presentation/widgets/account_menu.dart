import 'package:flutter/material.dart';

import 'package:finance/core/theme/app_icons.dart';
import 'package:finance/core/theme/app_semantic_colors.dart';

/// The grouped, bordered card the Hồ sơ menu and the Security screen share:
/// a surface-colored container with rounded corners and a hairline border that
/// stacks [children] (usually [AccountMenuRow]s) in a column.
class AccountMenuCard extends StatelessWidget {
  const AccountMenuCard({
    super.key,
    required this.semantic,
    required this.children,
  });

  final AppSemanticColors semantic;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: semantic.border1),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

/// One row of an [AccountMenuCard]: a leading icon, a [label], an optional
/// [caption] line under it and a [trailing] widget (a chevron unless a control
/// such as a `Switch` is supplied). [onTap] is nullable because a row whose
/// control sits in [trailing] is operated through that control.
class AccountMenuRow extends StatelessWidget {
  const AccountMenuRow({
    super.key,
    required this.icon,
    required this.label,
    required this.semantic,
    required this.showDivider,
    this.onTap,
    this.trailing,
    this.caption,
    this.captionKey,
  });

  final IconData icon;
  final String label;
  final AppSemanticColors semantic;
  final bool showDivider;
  final VoidCallback? onTap;

  /// Defaults to the right-pointing chevron used by navigation rows.
  final Widget? trailing;

  /// An optional smaller second line under [label].
  final String? caption;

  /// A key for the [caption] text, so a test can find it.
  final Key? captionKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final row = InkWell(
      onTap: onTap,
      child: Container(
        decoration: showDivider
            ? BoxDecoration(
                border: Border(bottom: BorderSide(color: semantic.border1)),
              )
            : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 18, color: semantic.fg2),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (caption != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        caption!,
                        key: captionKey,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: semantic.fg3,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            trailing ??
                Icon(LucideIcons.chevronRight, size: 16, color: semantic.fg3),
          ],
        ),
      ),
    );

    // Every row is its own semantics node: label, caption and any control
    // (a Switch) read as one item for a screen reader. Without this boundary a
    // lone tappable row has no conflicting sibling to separate it, so its
    // semantics were merged UP into an ancestor node spanning the whole card
    // (found on web: one "Đổi mật khẩu" target covering the biometric row too).
    return MergeSemantics(child: row);
  }
}
