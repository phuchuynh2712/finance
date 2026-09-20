import 'package:flutter/material.dart';

import 'empty_state_view.dart';

/// Generalized "not yet available" placeholder, reused by every entry
/// point whose real destination is a separate, unspecified future feature
/// (research.md Decision 4): the "Báo cáo" tab, "Thu chi"'s Thu nhập/Chi
/// tiêu/Xem lịch sử giao dịch entry points, and the "Tổng quan" tab.
///
/// When pushed via `Navigator.push` it renders its own [AppBar] with a
/// back button (Flutter's default). When rendered in-place as a bottom-nav
/// tab's own branch content (no push involved), there is simply no back
/// button to show — the same widget works both ways unmodified.
class NotAvailablePlaceholderScreen extends StatelessWidget {
  const NotAvailablePlaceholderScreen({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: EmptyStateView(icon: icon, message: message),
    );
  }
}
