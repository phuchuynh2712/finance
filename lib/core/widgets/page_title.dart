import 'package:flutter/material.dart';

import 'package:finance/core/theme/app_semantic_colors.dart';

/// The title of a page's app bar: a 34dp tinted chip holding the page's icon,
/// then the title text, left-aligned.
///
/// One widget for every page that titles itself this way (Hồ sơ, Thu chi, the
/// placeholders), so they read alike on every platform: a bare `Text` title is
/// centered on iOS and on a desktop browser and left-aligned on Android.
class PageTitle extends StatelessWidget {
  const PageTitle({super.key, required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;

    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: semantic.primarySoft,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(icon, size: 17, color: theme.colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
