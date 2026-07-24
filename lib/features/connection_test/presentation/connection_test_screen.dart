import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../domain/connection_status.dart';
import 'connection_test_controller.dart';

class ConnectionTestScreen extends ConsumerWidget {
  const ConnectionTestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final statusAsync = ref.watch(connectionStatusProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.connectionTestTitle)),
      body: Center(
        child: statusAsync.when(
          loading: () => _StatusView(
            icon: Icons.hourglass_top,
            color: Colors.grey,
            message: l10n.connectionStatusChecking,
          ),
          error: (error, _) => _StatusView(
            icon: Icons.error_outline,
            color: Colors.red,
            message: l10n.connectionStatusFailure(error.toString()),
          ),
          data: (status) => switch (status) {
            ConnectionSuccess() => _StatusView(
              icon: Icons.check_circle_outline,
              color: Colors.green,
              message: l10n.connectionStatusSuccess,
            ),
            ConnectionFailure(:final message) => _StatusView(
              icon: Icons.error_outline,
              color: Colors.red,
              message: l10n.connectionStatusFailure(message),
            ),
            ConnectionChecking() => _StatusView(
              icon: Icons.hourglass_top,
              color: Colors.grey,
              message: l10n.connectionStatusChecking,
            ),
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => ref.invalidate(connectionStatusProvider),
        tooltip: 'Retry',
        child: const Icon(Icons.refresh),
      ),
    );
  }
}

class _StatusView extends StatelessWidget {
  const _StatusView({
    required this.icon,
    required this.color,
    required this.message,
  });

  final IconData icon;
  final Color color;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 64),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
