import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:finance/core/auth/auth_state_provider.dart';
import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/features/envelopes/domain/envelope.dart';
import 'package:finance/features/envelopes/domain/envelope_repository.dart';
import 'package:finance/features/envelopes/presentation/envelopes_providers.dart';
import 'package:finance/features/envelopes/presentation/envelopes_screen.dart';

class _FakeEnvelopeRepository implements EnvelopeRepository {
  Envelope? created;
  Envelope? updated;
  String? deletedId;
  final List<Envelope> _envelopes;

  _FakeEnvelopeRepository(this._envelopes);

  @override
  Stream<List<Envelope>> watchAll() => Stream.value(_envelopes);

  @override
  Future<List<Envelope>> getAll() async => _envelopes;

  @override
  Future<void> create(Envelope envelope) async {
    created = envelope;
  }

  @override
  Future<void> update(Envelope envelope) async {
    updated = envelope;
  }

  @override
  Future<void> delete(String id) async {
    deletedId = id;
  }
}

Envelope _envelope(
  String id, {
  int balance = 0,
  bool isRoundingReceiver = false,
}) => Envelope(
  id: id,
  userId: 'u1',
  name: id,
  allocationMethod: AllocationMethod.fixed,
  allocationValue: 100000,
  balance: balance,
  isRoundingReceiver: isRoundingReceiver,
);

Widget _harness(_FakeEnvelopeRepository repo) {
  return ProviderScope(
    overrides: [
      envelopeRepositoryProvider.overrideWithValue(repo),
      currentUserIdProvider.overrideWithValue('u1'),
    ],
    child: MaterialApp(
      locale: const Locale('vi'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const EnvelopesScreen(),
    ),
  );
}

void main() {
  testWidgets('creating a new envelope calls repository.create', (
    tester,
  ) async {
    final repo = _FakeEnvelopeRepository([]);
    await tester.pumpWidget(_harness(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Travel');
    await tester.enterText(find.byType(TextField).last, '10');
    await tester.pump();

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(repo.created?.name, 'Travel');
    expect(repo.created?.allocationMethod, AllocationMethod.percentage);
    expect(repo.created?.allocationValue, closeTo(0.10, 0.0001));
  });

  testWidgets('editing an existing envelope calls repository.update', (
    tester,
  ) async {
    final repo = _FakeEnvelopeRepository([_envelope('Rent', balance: 500000)]);
    await tester.pumpWidget(_harness(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rent'));
    await tester.pumpAndSettle();

    expect(find.text('Rent'), findsOneWidget);

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(repo.updated?.id, 'Rent');
  });

  testWidgets(
    'deleting an envelope with a non-zero balance warns first (FR-027)',
    (tester) async {
      final repo = _FakeEnvelopeRepository([
        _envelope('Rent', balance: 500000),
      ]);
      await tester.pumpWidget(_harness(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(LucideIcons.trash2));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(repo.deletedId, isNull);

      await tester.tap(find.text('Xóa'));
      await tester.pumpAndSettle();

      expect(repo.deletedId, 'Rent');
    },
  );

  testWidgets(
    'deleting the rounding-remainder receiver requires reassignment first (FR-028)',
    (tester) async {
      final repo = _FakeEnvelopeRepository([
        _envelope('Buffer', isRoundingReceiver: true),
        _envelope('Savings'),
      ]);
      await tester.pumpWidget(_harness(repo));
      await tester.pumpAndSettle();

      final deleteButtons = find.byIcon(LucideIcons.trash2);
      await tester.tap(deleteButtons.first);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(repo.updated, isNull);
      expect(repo.deletedId, isNull);

      await tester.tap(find.text('Savings').last);
      await tester.pumpAndSettle();

      expect(repo.updated?.id, 'Savings');
      expect(repo.updated?.isRoundingReceiver, isTrue);
      expect(repo.deletedId, 'Buffer');
    },
  );
}
