import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables/expense_entries_table.dart'
    as expense_table;
import '../../../core/sync/sync_outbox_table.dart';
import '../domain/expense_entry.dart';
import '../domain/expense_repository.dart';

class ExpenseRepositoryImpl implements ExpenseRepository {
  ExpenseRepositoryImpl(this._db, {required String userId}) : _userId = userId;

  final AppDatabase _db;
  final String _userId;
  static const _uuid = Uuid();

  Future<void> _appendOutbox(
    String table,
    String rowId,
    SyncOperation operation,
    Map<String, dynamic> payload,
  ) async {
    await _db
        .into(_db.syncOutbox)
        .insert(
          SyncOutboxCompanion.insert(
            id: _uuid.v4(),
            entityTable: table,
            rowId: rowId,
            operation: operation,
            payload: jsonEncode(payload),
          ),
        );
  }

  ExpenseEntry _toDomain(ExpenseEntryRow row) {
    return ExpenseEntry(
      id: row.id,
      userId: row.userId,
      envelopeId: row.envelopeId,
      amount: row.amount,
      entryDate: row.entryDate,
      note: row.note,
      entryMethod: row.entryMethod == expense_table.ExpenseEntryMethod.scanned
          ? ExpenseMethod.scanned
          : ExpenseMethod.manual,
    );
  }

  @override
  Stream<List<ExpenseEntry>> watchAll() {
    return (_db.select(_db.expenseEntries)
          ..where((row) => row.userId.equals(_userId) & row.deletedAt.isNull()))
        .watch()
        .map((rows) => rows.map(_toDomain).toList());
  }

  Future<void> _adjustEnvelopeBalance(String envelopeId, int delta) async {
    final row = await (_db.select(
      _db.envelopes,
    )..where((r) => r.id.equals(envelopeId))).getSingle();
    final newBalance = row.balance + delta;
    await (_db.update(
      _db.envelopes,
    )..where((r) => r.id.equals(envelopeId))).write(
      EnvelopesCompanion(
        balance: Value(newBalance),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _appendOutbox('envelopes', envelopeId, SyncOperation.update, {
      'id': envelopeId,
      'balance': newBalance,
    });
    return;
  }

  /// Applies a new expense's effects: decreases the target envelope, and if
  /// [coveringEnvelopeId] is given, restores the target to exactly 0 and
  /// deducts the shortfall from the coverer, recording an EnvelopeCoverage
  /// (FR-017). The repository derives the shortfall itself from the
  /// target's current balance rather than trusting a caller-supplied
  /// figure, since this is the layer actually performing the mutation.
  Future<void> _applyExpenseEffects(
    ExpenseEntry expense,
    String? coveringEnvelopeId,
  ) async {
    await _adjustEnvelopeBalance(expense.envelopeId, -expense.amount);

    final targetRow = await (_db.select(
      _db.envelopes,
    )..where((r) => r.id.equals(expense.envelopeId))).getSingle();
    final shortfall = targetRow.balance < 0 ? -targetRow.balance : 0;

    if (shortfall > 0 && coveringEnvelopeId != null) {
      await _adjustEnvelopeBalance(expense.envelopeId, shortfall);
      await _adjustEnvelopeBalance(coveringEnvelopeId, -shortfall);

      final coverageId = _uuid.v4();
      final coveredAt = DateTime.now();
      await _db
          .into(_db.envelopeCoverages)
          .insert(
            EnvelopeCoveragesCompanion.insert(
              id: coverageId,
              userId: _userId,
              expenseEntryId: expense.id,
              sourceEnvelopeId: expense.envelopeId,
              coveringEnvelopeId: coveringEnvelopeId,
              amount: shortfall,
              coveredAt: Value(coveredAt),
            ),
          );
      await _appendOutbox(
        'envelope_coverages',
        coverageId,
        SyncOperation.insert,
        {
          'id': coverageId,
          'user_id': _userId,
          'expense_entry_id': expense.id,
          'source_envelope_id': expense.envelopeId,
          'covering_envelope_id': coveringEnvelopeId,
          'amount': shortfall,
          'covered_at': coveredAt.toIso8601String(),
        },
      );
    }
  }

  /// Reverses a saved expense's effects — restores its target envelope's
  /// balance, and if a coverage record is linked, restores the covering
  /// envelope's balance and soft-deletes the coverage row (FR-018a). Used
  /// by both [update] and [delete].
  ///
  /// When a coverage exists, applying the original expense touched the
  /// target envelope TWICE — once subtracting the raw expense amount, then
  /// again adding the shortfall back to restore it to exactly 0 (see
  /// [_applyExpenseEffects]). Both of those target-side adjustments must be
  /// undone here, not just the first: net reversal to the target is
  /// `+expenseRow.amount - coverageRow.amount`, not `+expenseRow.amount`
  /// alone (which would overshoot by the coverage amount).
  Future<void> _reverseExpenseEffects(String expenseId) async {
    final expenseRow = await (_db.select(
      _db.expenseEntries,
    )..where((r) => r.id.equals(expenseId))).getSingle();

    await _adjustEnvelopeBalance(expenseRow.envelopeId, expenseRow.amount);

    final coverageRow =
        await (_db.select(_db.envelopeCoverages)..where(
              (r) => r.expenseEntryId.equals(expenseId) & r.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (coverageRow != null) {
      await _adjustEnvelopeBalance(expenseRow.envelopeId, -coverageRow.amount);
      await _adjustEnvelopeBalance(
        coverageRow.coveringEnvelopeId,
        coverageRow.amount,
      );
      await (_db.update(_db.envelopeCoverages)
            ..where((r) => r.id.equals(coverageRow.id)))
          .write(EnvelopeCoveragesCompanion(deletedAt: Value(DateTime.now())));
      await _appendOutbox(
        'envelope_coverages',
        coverageRow.id,
        SyncOperation.delete,
        {'id': coverageRow.id},
      );
    }
  }

  @override
  Future<void> create({
    required ExpenseEntry expense,
    String? coveringEnvelopeId,
  }) async {
    await _db.transaction(() async {
      await _db
          .into(_db.expenseEntries)
          .insert(
            ExpenseEntriesCompanion.insert(
              id: expense.id,
              userId: expense.userId,
              envelopeId: expense.envelopeId,
              amount: expense.amount,
              entryDate: expense.entryDate,
              note: Value(expense.note),
              entryMethod: Value(
                expense.entryMethod == ExpenseMethod.scanned
                    ? expense_table.ExpenseEntryMethod.scanned
                    : expense_table.ExpenseEntryMethod.manual,
              ),
            ),
          );
      await _appendOutbox('expense_entries', expense.id, SyncOperation.insert, {
        'id': expense.id,
        'user_id': expense.userId,
        'envelope_id': expense.envelopeId,
        'amount': expense.amount,
        'entry_date': expense.entryDate.toIso8601String(),
        'note': expense.note,
        'entry_method': expense.entryMethod.name,
      });

      await _applyExpenseEffects(expense, coveringEnvelopeId);
    });
  }

  @override
  Future<void> update({
    required ExpenseEntry expense,
    String? coveringEnvelopeId,
  }) async {
    await _db.transaction(() async {
      await _reverseExpenseEffects(expense.id);

      await (_db.update(
        _db.expenseEntries,
      )..where((r) => r.id.equals(expense.id))).write(
        ExpenseEntriesCompanion(
          envelopeId: Value(expense.envelopeId),
          amount: Value(expense.amount),
          entryDate: Value(expense.entryDate),
          note: Value(expense.note),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await _appendOutbox('expense_entries', expense.id, SyncOperation.update, {
        'id': expense.id,
        'envelope_id': expense.envelopeId,
        'amount': expense.amount,
        'entry_date': expense.entryDate.toIso8601String(),
        'note': expense.note,
      });

      await _applyExpenseEffects(expense, coveringEnvelopeId);
    });
  }

  @override
  Future<void> delete(String id) async {
    await _db.transaction(() async {
      await _reverseExpenseEffects(id);
      await (_db.update(_db.expenseEntries)..where((r) => r.id.equals(id)))
          .write(ExpenseEntriesCompanion(deletedAt: Value(DateTime.now())));
      await _appendOutbox('expense_entries', id, SyncOperation.delete, {
        'id': id,
      });
    });
  }
}
