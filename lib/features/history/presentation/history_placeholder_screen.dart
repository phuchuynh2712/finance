import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/widgets/empty_state_view.dart';

/// Placeholder for the "Lịch sử/Báo cáo" tab (FR-020) — real content is a
/// separate, unspecified future feature (spec.md Assumptions).
class HistoryPlaceholderScreen extends StatelessWidget {
  const HistoryPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabHistory)),
      body: EmptyStateView(
        icon: LucideIcons.history,
        message: l10n.historyPlaceholderMessage,
      ),
    );
  }
}
