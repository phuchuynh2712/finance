import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/auth/auth_state_provider.dart';
import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/features/envelopes/domain/envelope.dart';
import 'package:finance/features/envelopes/presentation/envelopes_providers.dart';
import 'package:finance/features/expenses/domain/expense_entry.dart';
import 'package:finance/features/expenses/domain/expense_repository.dart';
import 'package:finance/features/expenses/presentation/expense_form_screen.dart';
import 'package:finance/features/expenses/presentation/expenses_providers.dart';
import 'package:finance/features/expenses/presentation/spending_screen.dart';

class _FakeExpenseRepository implements ExpenseRepository {
  ExpenseEntry? savedExpense;
  String? savedCoveringEnvelopeId;
  bool createCalled = false;
  bool updateCalled = false;

  @override
  Stream<List<ExpenseEntry>> watchAll() => Stream.value(const []);

  @override
  Future<void> create({
    required ExpenseEntry expense,
    String? coveringEnvelopeId,
  }) async {
    createCalled = true;
    savedExpense = expense;
    savedCoveringEnvelopeId = coveringEnvelopeId;
  }

  @override
  Future<void> update({
    required ExpenseEntry expense,
    String? coveringEnvelopeId,
  }) async {
    updateCalled = true;
    savedExpense = expense;
    savedCoveringEnvelopeId = coveringEnvelopeId;
  }

  @override
  Future<void> delete(String id) async {}
}

Envelope _envelope(String id, int balance) => Envelope(
  id: id,
  userId: 'u1',
  name: id,
  allocationMethod: AllocationMethod.fixed,
  allocationValue: 0,
  balance: balance,
  isRoundingReceiver: false,
);

Widget _harness({
  required List<Envelope> envelopes,
  required ExpenseRepository repository,
  ExpenseEntry? existingExpense,
}) {
  return ProviderScope(
    overrides: [
      envelopesStreamProvider.overrideWith((ref) => Stream.value(envelopes)),
      expenseRepositoryProvider.overrideWithValue(repository),
      currentUserIdProvider.overrideWithValue('u1'),
    ],
    child: MaterialApp(
      locale: const Locale('vi'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Consumer(
        builder: (context, ref, _) {
          ref.watch(envelopesStreamProvider);
          return Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        ExpenseFormScreen(existingExpense: existingExpense),
                  ),
                ),
                child: const Text('open form'),
              ),
            ),
          );
        },
      ),
    ),
  );
}

Future<void> _openForm(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.tap(find.text('open form'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('saves a routine (non-overspending) expense directly', (
    tester,
  ) async {
    final repo = _FakeExpenseRepository();
    await tester.pumpWidget(
      _harness(envelopes: [_envelope('Groceries', 2000000)], repository: repo),
    );
    await _openForm(tester);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Groceries').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '500000');
    await tester.pump();

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(repo.createCalled, isTrue);
    expect(repo.savedExpense?.amount, 500000);
    expect(repo.savedCoveringEnvelopeId, isNull);
  });

  testWidgets(
    'an overspending expense triggers the covering-envelope prompt (FR-016)',
    (tester) async {
      final repo = _FakeExpenseRepository();
      await tester.pumpWidget(
        _harness(
          envelopes: [
            _envelope('Groceries', 300000),
            _envelope('Fun', 1000000),
          ],
          repository: repo,
        ),
      );
      await _openForm(tester);

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Groceries').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '500000');
      await tester.pump();

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(repo.createCalled, isFalse);

      await tester.tap(find.text('Fun'));
      await tester.pumpAndSettle();

      expect(repo.createCalled, isTrue);
      expect(repo.savedCoveringEnvelopeId, 'Fun');
    },
  );

  testWidgets(
    'cancelling the covering-envelope prompt saves nothing (FR-018)',
    (tester) async {
      final repo = _FakeExpenseRepository();
      await tester.pumpWidget(
        _harness(
          envelopes: [
            _envelope('Groceries', 300000),
            _envelope('Fun', 1000000),
          ],
          repository: repo,
        ),
      );
      await _openForm(tester);

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Groceries').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '500000');
      await tester.pump();

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();

      expect(repo.createCalled, isFalse);
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  testWidgets('editing a saved expense pre-fills the form and calls update', (
    tester,
  ) async {
    final repo = _FakeExpenseRepository();
    final existing = ExpenseEntry(
      id: 'e1',
      userId: 'u1',
      envelopeId: 'Groceries',
      amount: 500000,
      entryDate: DateTime(2026, 1, 1),
      note: 'weekly shop',
    );
    await tester.pumpWidget(
      _harness(
        envelopes: [_envelope('Groceries', 1500000)],
        repository: repo,
        existingExpense: existing,
      ),
    );
    await _openForm(tester);

    expect(find.text('500000'), findsOneWidget);
    expect(find.text('weekly shop'), findsOneWidget);

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(repo.updateCalled, isTrue);
    expect(repo.savedExpense?.id, 'e1');
  });

  group('SpendingScreen zero-envelope guard (FR-030)', () {
    Widget spendingHarness({required List<Envelope> envelopes}) {
      return ProviderScope(
        overrides: [
          envelopesStreamProvider.overrideWith(
            (ref) => Stream.value(envelopes),
          ),
          expensesStreamProvider.overrideWith((ref) => Stream.value(const [])),
          expenseRepositoryProvider.overrideWithValue(_FakeExpenseRepository()),
          currentUserIdProvider.overrideWithValue('u1'),
        ],
        child: MaterialApp(
          locale: const Locale('vi'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const SpendingScreen(),
        ),
      );
    }

    testWidgets(
      'hides the Add expense action and shows a warning when there are no envelopes',
      (tester) async {
        await tester.pumpWidget(spendingHarness(envelopes: const []));
        await tester.pumpAndSettle();

        expect(find.byType(FloatingActionButton), findsNothing);
        expect(
          find.text(
            'Chưa có khoản nào. Hãy tạo khoản trong tab Kiểm soát trước khi ghi chi tiêu.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('shows the Add expense action when envelopes exist', (
      tester,
    ) async {
      await tester.pumpWidget(
        spendingHarness(envelopes: [_envelope('Groceries', 1000000)]),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsOneWidget);
    });
  });
}
