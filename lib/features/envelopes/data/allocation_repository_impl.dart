import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_outbox_table.dart';
import '../domain/allocation_event.dart';
import '../domain/allocation_event_line.dart';
import '../domain/allocation_repository.dart';

class AllocationRepositoryImpl implements AllocationRepository {
  AllocationRepositoryImpl(this._db);

  final AppDatabase _db;
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

  @override
  Future<void> confirmEvent({
    required AllocationEvent event,
    required List<AllocationEventLine> lines,
  }) async {
    await _db.transaction(() async {
      await _db
          .into(_db.allocationEvents)
          .insert(
            AllocationEventsCompanion.insert(
              id: event.id,
              userId: event.userId,
              eventDate: Value(event.eventDate),
              incomeAmount: event.incomeAmount,
            ),
          );
      await _appendOutbox('allocation_events', event.id, SyncOperation.insert, {
        'id': event.id,
        'user_id': event.userId,
        'event_date': event.eventDate.toIso8601String(),
        'income_amount': event.incomeAmount,
      });

      for (final line in lines) {
        await _db
            .into(_db.allocationEventLines)
            .insert(
              AllocationEventLinesCompanion.insert(
                id: line.id,
                userId: line.userId,
                allocationEventId: line.allocationEventId,
                envelopeId: line.envelopeId,
                amount: line.amount,
                isRoundingRemainderLine: Value(line.isRoundingRemainderLine),
              ),
            );
        await _appendOutbox(
          'allocation_event_lines',
          line.id,
          SyncOperation.insert,
          {
            'id': line.id,
            'user_id': line.userId,
            'allocation_event_id': line.allocationEventId,
            'envelope_id': line.envelopeId,
            'amount': line.amount,
            'is_rounding_remainder_line': line.isRoundingRemainderLine,
          },
        );

        // Additive balance update (FR-008/FR-009) — read-modify-write inside
        // the same transaction so concurrent writers can't race.
        final envelopeRow = await (_db.select(
          _db.envelopes,
        )..where((row) => row.id.equals(line.envelopeId))).getSingle();
        final newBalance = envelopeRow.balance + line.amount;
        await (_db.update(
          _db.envelopes,
        )..where((row) => row.id.equals(line.envelopeId))).write(
          EnvelopesCompanion(
            balance: Value(newBalance),
            updatedAt: Value(DateTime.now()),
          ),
        );
        await _appendOutbox(
          'envelopes',
          line.envelopeId,
          SyncOperation.update,
          {'id': line.envelopeId, 'balance': newBalance},
        );
      }
    });
  }
}
