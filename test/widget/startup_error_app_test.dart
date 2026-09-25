import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/main.dart';

void main() {
  testWidgets(
    'supabaseConfig renders the Supabase-configuration copy (FR-014, unchanged behavior)',
    (tester) async {
      await tester.pumpWidget(
        const StartupErrorApp(reason: StartupFailureReason.supabaseConfig),
      );
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
      expect(find.text(l10n.startupConfigurationTitle), findsOneWidget);
      expect(find.text(l10n.startupConfigurationMessage), findsOneWidget);
      expect(find.text(l10n.startupWebStorageTitle), findsNothing);
      expect(find.text(l10n.startupWebStorageMessage), findsNothing);
    },
  );

  testWidgets(
    'webStorage renders distinct, storage-specific copy, not the Supabase text (FR-014)',
    (tester) async {
      await tester.pumpWidget(
        const StartupErrorApp(reason: StartupFailureReason.webStorage),
      );
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
      expect(find.text(l10n.startupWebStorageTitle), findsOneWidget);
      expect(find.text(l10n.startupWebStorageMessage), findsOneWidget);
      expect(find.text(l10n.startupConfigurationTitle), findsNothing);
      expect(find.text(l10n.startupConfigurationMessage), findsNothing);
    },
  );
}
