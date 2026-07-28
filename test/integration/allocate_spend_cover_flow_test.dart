import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'package:finance/core/database/app_database.dart';
import 'package:finance/features/envelopes/data/allocation_repository_impl.dart';
import 'package:finance/features/envelopes/data/envelope_repository_impl.dart';
import 'package:finance/features/envelopes/domain/allocation_event.dart';
import 'package:finance/features/envelopes/domain/allocation_event_line.dart';
import 'package:finance/features/envelopes/domain/compute_allocation_preview.dart';
import 'package:finance/features/envelopes/domain/envelope.dart';
import 'package:finance/features/expenses/data/expense_repository_impl.dart';
import 'package:finance/features/expenses/domain/compute_overspend.dart';
import 'package:finance/features/expenses/domain/expense_entry.dart';

const _uuid = Uuid();
const _userId = 'test-user';

void main() {
  late AppDatabase db;
  late EnvelopeRepositoryImpl envelopeRepository;
  late AllocationRepositoryImpl allocationRepository;
  late ExpenseRepositoryImpl expenseRepository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    envelopeRepository = EnvelopeRepositoryImpl(db, userId: _userId);
    allocationRepository = AllocationRepositoryImpl(db);
    expenseRepository = ExpenseRepositoryImpl(db, userId: _userId);
  });

  tearDown(() async {
    await db.close();
  });

  /// Confirms an allocation event end to end: runs the real
  /// compute_allocation_preview against the repository's current envelope
  /// snapshot, then persists it via AllocationRepositoryImpl — exactly the
  /// sequence the Plan controller performs in the real app.
  Future<void> confirmAllocation(int incomeAmount) async {
    final envelopes = await envelopeRepository.getAll();
    final preview = computeAllocationPreview(
      incomeAmount: incomeAmount,
      envelopes: envelopes,
    );
    expect(
      preview.canConfirm,
      isTrue,
      reason: 'test setup should not overspend/over-allocate',
    );

    final eventId = _uuid.v4();
    final event = AllocationEvent(
      id: eventId,
      userId: _userId,
      eventDate: DateTime.now(),
      incomeAmount: incomeAmount,
    );
    final lines = [
      for (final line in preview.lines)
        AllocationEventLine(
          id: _uuid.v4(),
          userId: _userId,
          allocationEventId: eventId,
          envelopeId: line.envelope.id,
          amount: line.allocatedAmount,
          isRoundingRemainderLine:
              line.envelope.id == preview.receiverEnvelopeId &&
              preview.leftoverAddedToReceiver > 0,
        ),
    ];
    await allocationRepository.confirmEvent(event: event, lines: lines);
  }

  test(
    'allocate -> spend -> overspend-coverage, full loop against a real Drift database',
    () async {
      // --- Configure envelopes (US3) ---
      final rentId = _uuid.v4();
      final savingsId = _uuid.v4();
      final bufferId = _uuid.v4();
      await envelopeRepository.create(
        Envelope(
          id: rentId,
          userId: _userId,
          name: 'Rent',
          allocationMethod: AllocationMethod.fixed,
          allocationValue: 5000000,
          balance: 0,
          isRoundingReceiver: false,
        ),
      );
      await envelopeRepository.create(
        Envelope(
          id: savingsId,
          userId: _userId,
          name: 'Savings',
          allocationMethod: AllocationMethod.percentage,
          allocationValue: 0.30,
          balance: 0,
          isRoundingReceiver: false,
        ),
      );
      await envelopeRepository.create(
        Envelope(
          id: bufferId,
          userId: _userId,
          name: 'Buffer',
          allocationMethod: AllocationMethod.percentage,
          allocationValue: 0.0,
          balance: 0,
          isRoundingReceiver: true,
        ),
      );

      // --- US1: first allocation event ---
      await confirmAllocation(20000000);

      var envelopes = await envelopeRepository.getAll();
      var rent = envelopes.firstWhere((e) => e.id == rentId);
      var savings = envelopes.firstWhere((e) => e.id == savingsId);
      var buffer = envelopes.firstWhere((e) => e.id == bufferId);
      expect(rent.balance, 5000000);
      expect(savings.balance, 6000000);
      expect(buffer.balance, 9000000); // leftover: 20M - 5M - 6M

      // --- FR-008/FR-009: second allocation event is additive, not a reset ---
      await confirmAllocation(10000000);

      envelopes = await envelopeRepository.getAll();
      rent = envelopes.firstWhere((e) => e.id == rentId);
      savings = envelopes.firstWhere((e) => e.id == savingsId);
      buffer = envelopes.firstWhere((e) => e.id == bufferId);
      expect(
        rent.balance,
        5000000 + 5000000,
      ); // additive, not reset to 5,000,000
      expect(savings.balance, 6000000 + 3000000);
      expect(buffer.balance, 9000000 + 2000000);

      // --- FR-010: each event's breakdown is persisted and retrievable ---
      final allLines = await db.select(db.allocationEventLines).get();
      expect(allLines.length, 6); // 3 envelopes x 2 events
      final totalAllocatedToRent = allLines
          .where((line) => line.envelopeId == rentId)
          .fold<int>(0, (sum, line) => sum + line.amount);
      expect(totalAllocatedToRent, 10000000);

      // --- US2: routine (non-overspending) expense ---
      final groceriesExpenseId = _uuid.v4();
      await expenseRepository.create(
        expense: ExpenseEntry(
          id: groceriesExpenseId,
          userId: _userId,
          envelopeId: rentId,
          amount: 2000000,
          entryDate: DateTime.now(),
        ),
      );
      rent = (await envelopeRepository.getAll()).firstWhere(
        (e) => e.id == rentId,
      );
      expect(rent.balance, 10000000 - 2000000);

      // --- US2: overspending expense with inline coverage (FR-016/FR-017) ---
      final bigExpenseId = _uuid.v4();
      const bigExpenseAmount = 9000000; // exceeds Rent's remaining 8,000,000
      final overspend = computeOverspend(
        expenseAmount: bigExpenseAmount,
        targetEnvelopeBalance: rent.balance,
        otherEnvelopesCount: 2,
      );
      expect(overspend.isOverspend, isTrue);
      expect(overspend.needsCoveringEnvelope, isTrue);
      expect(overspend.shortfall, 1000000);

      await expenseRepository.create(
        expense: ExpenseEntry(
          id: bigExpenseId,
          userId: _userId,
          envelopeId: rentId,
          amount: bigExpenseAmount,
          entryDate: DateTime.now(),
        ),
        coveringEnvelopeId: savingsId,
      );

      envelopes = await envelopeRepository.getAll();
      rent = envelopes.firstWhere((e) => e.id == rentId);
      savings = envelopes.firstWhere((e) => e.id == savingsId);
      expect(rent.balance, 0); // shortfall fully covered, restored to exactly 0
      expect(savings.balance, 9000000 - 1000000);

      final coverages = await db.select(db.envelopeCoverages).get();
      expect(coverages.length, 1);
      expect(coverages.single.sourceEnvelopeId, rentId);
      expect(coverages.single.coveringEnvelopeId, savingsId);
      expect(coverages.single.amount, 1000000);

      // --- FR-018a: deleting the covered expense reverses both sides ---
      await expenseRepository.delete(bigExpenseId);

      envelopes = await envelopeRepository.getAll();
      rent = envelopes.firstWhere((e) => e.id == rentId);
      savings = envelopes.firstWhere((e) => e.id == savingsId);
      // Reversal must undo BOTH target-side adjustments the original apply
      // made (the raw -9,000,000 subtraction AND the +1,000,000 shortfall
      // restoration that had brought it back to 0) — net back to the
      // pre-expense balance of 8,000,000, not merely +9,000,000 from 0.
      expect(rent.balance, 8000000);
      expect(savings.balance, 9000000); // shortfall un-covered, restored

      final coveragesAfterDelete = await (db.select(
        db.envelopeCoverages,
      )..where((row) => row.deletedAt.isNull())).get();
      expect(coveragesAfterDelete, isEmpty);
    },
  );
}
