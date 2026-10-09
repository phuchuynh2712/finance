import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/database/app_database.dart';
import 'package:finance/core/formatting/currency_formatter.dart';
import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/sync/sync_notice.dart';
import 'package:finance/core/sync/sync_notices_provider.dart';
import 'package:finance/core/sync/sync_outbox_table.dart';
import 'package:finance/core/theme/app_theme.dart';
import 'package:finance/core/widgets/sync_notice_host.dart';

import '../../../support/expense_screen_harness.dart' show useView;
import '../../../support/load_app_fonts.dart';

SyncNotice _mismatch(String id, String item) => SyncNotice(
  id: 'mismatch:$id',
  reason: SyncNoticeReason.balanceMismatch,
  itemName: item,
);

SyncNotice _correctionNotice(String id, SyncNoticeReason reason) => SyncNotice(
  id: id,
  reason: reason,
  itemName: 'Food',
  transactionId: 'transaction',
  amount: 25000,
);

void main() {
  setUpAll(loadAppFonts);

  late AppDatabase db;
  late SyncNotices notices;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    notices = SyncNotices(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpHost(
    WidgetTester tester, {
    double width = 412,
    double height = 800,
    Locale locale = const Locale('vi'),
    double textScale = 1.0,
  }) async {
    useView(tester, width, height);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [syncNoticesProvider.overrideWithValue(notices)],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const SyncNoticeHost(child: Scaffold(body: Text('content'))),
        ),
      ),
    );
    await tester.pump();
  }

  /// Lets the visible snack bar run out: its entry animation, then its
  /// four-second timer, then its exit animation.
  Future<void> letSnackBarExpire(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  Future<String> message(Locale locale, String item) async =>
      (await AppLocalizations.delegate.load(
        locale,
      )).syncBalanceMismatchNotice(item);

  for (final locale in const [Locale('vi'), Locale('en')]) {
    testWidgets('a balance mismatch shows one snack bar naming the item '
        '(${locale.languageCode})', (tester) async {
      await pumpHost(tester, locale: locale);

      notices.report(_mismatch('a', 'Food'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text(await message(locale, 'Food')), findsOneWidget);
    });
  }

  testWidgets('the snack bar is a live region for a screen reader', (
    tester,
  ) async {
    await pumpHost(tester);

    notices.report(_mismatch('a', 'Food'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final live = find.ancestor(
      of: find.text(await message(const Locale('vi'), 'Food')),
      matching: find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.liveRegion == true,
      ),
    );
    expect(live, findsWidgets);
  });

  for (final locale in const [Locale('vi'), Locale('en')]) {
    for (final reason in [
      SyncNoticeReason.deleted,
      SyncNoticeReason.reversed,
      SyncNoticeReason.alreadyReversed,
      SyncNoticeReason.editedElsewhere,
    ]) {
      testWidgets(
        'a ${reason.name} correction notice names the item and amount '
        '(${locale.languageCode})',
        (tester) async {
          await pumpHost(tester, locale: locale);
          notices.report(
            _correctionNotice('correction:${reason.name}', reason),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          final l10n = await AppLocalizations.delegate.load(locale);
          final amount = CurrencyFormatter(locale.toString()).format(25000);
          final message = switch (reason) {
            SyncNoticeReason.deleted => l10n.syncCorrectionDeletedNotice(
              'Food',
              amount,
            ),
            SyncNoticeReason.reversed => l10n.syncCorrectionReversedNotice(
              'Food',
              amount,
            ),
            SyncNoticeReason.alreadyReversed =>
              l10n.syncCorrectionAlreadyReversedNotice('Food', amount),
            SyncNoticeReason.editedElsewhere =>
              l10n.syncCorrectionEditedElsewhereNotice('Food', amount),
            SyncNoticeReason.balanceMismatch => fail('not a correction notice'),
          };
          expect(find.text(message), findsOneWidget);
        },
      );
    }
  }

  testWidgets('a persisted refusal is acknowledged after it is shown', (
    tester,
  ) async {
    await tester.runAsync(
      () => db
          .into(db.syncOutbox)
          .insert(
            SyncOutboxCompanion.insert(
              id: 'rejected',
              entityTable: 'financial_transactions',
              rowId: 'transaction',
              operation: SyncOperation.update,
              payload: jsonEncode({'display_name': 'Food', 'amount': 25000}),
              rejectedAt: Value(DateTime.utc(2026, 1, 1)),
              rejectReason: const Value('already_reversed'),
            ),
          ),
    );
    await tester.runAsync(() => notices.dispose());
    notices = SyncNotices(db);
    await tester.runAsync(() => notices.loaded);
    await pumpHost(tester);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
    final amount = CurrencyFormatter('vi').format(25000);
    expect(
      find.text(l10n.syncCorrectionAlreadyReversedNotice('Food', amount)),
      findsOneWidget,
    );

    tester
        .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
        .hideCurrentSnackBar();
    await tester.pumpAndSettle();
    final remainingRows = await tester.runAsync(
      () => db.select(db.syncOutbox).get(),
    );
    expect(remainingRows, isEmpty);
  });

  testWidgets('a notice is never shown again after it was shown', (
    tester,
  ) async {
    await pumpHost(tester);
    notices.report(_mismatch('a', 'Food'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(SnackBar), findsOneWidget);

    await letSnackBarExpire(tester);
    expect(find.byType(SnackBar), findsNothing);

    // The same screen rebuilding, or a new listener, does not replay it.
    await tester.pumpWidget(const SizedBox());
    await pumpHost(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('several notices are shown one after the other', (tester) async {
    await pumpHost(tester);
    notices.report(_mismatch('a', 'Food'));
    notices.report(_mismatch('b', 'Rent'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final vi = await AppLocalizations.delegate.load(const Locale('vi'));
    expect(find.text(vi.syncBalanceMismatchNotice('Food')), findsOneWidget);
    expect(find.text(vi.syncBalanceMismatchNotice('Rent')), findsNothing);

    await letSnackBarExpire(tester);
    expect(find.text(vi.syncBalanceMismatchNotice('Rent')), findsOneWidget);
  });

  testWidgets('with no notice it adds nothing but its child', (tester) async {
    await pumpHost(tester);
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('content'), findsOneWidget);
  });

  for (final c in const [
    (320.0, 1.0),
    (1440.0, 1.0),
    (320.0, 1.3),
    (1440.0, 1.3),
  ]) {
    testWidgets(
      'fits at ${c.$1.toInt()} dp wide, text ${(c.$2 * 100).toInt()} %',
      (tester) async {
        await pumpHost(tester, width: c.$1, textScale: c.$2);

        notices.report(
          _mismatch(
            'a',
            'Một khoản chi tiêu có tên rất dài để thử việc ngắt dòng',
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(SnackBar), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
