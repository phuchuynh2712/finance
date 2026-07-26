import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables/envelopes_table.dart' as tables;
import '../../../core/sync/sync_outbox_table.dart';
import '../domain/envelope.dart';
import '../domain/envelope_repository.dart';

class EnvelopeRepositoryImpl implements EnvelopeRepository {
  EnvelopeRepositoryImpl(this._db, {required String userId}) : _userId = userId;

  final AppDatabase _db;
  final String _userId;
  static const _uuid = Uuid();

  Envelope _toDomain(EnvelopeRow row) {
    return Envelope(
      id: row.id,
      userId: row.userId,
      name: row.name,
      allocationMethod: row.allocationMethod == tables.AllocationMethod.fixed
          ? AllocationMethod.fixed
          : AllocationMethod.percentage,
      allocationValue: row.allocationValue,
      balance: row.balance,
      isRoundingReceiver: row.isRoundingReceiver,
    );
  }

  Future<void> _appendOutbox(
    String rowId,
    SyncOperation operation,
    Map<String, dynamic> payload,
  ) async {
    await _db
        .into(_db.syncOutbox)
        .insert(
          SyncOutboxCompanion.insert(
            id: _uuid.v4(),
            entityTable: 'envelopes',
            rowId: rowId,
            operation: operation,
            payload: jsonEncode(payload),
          ),
        );
  }

  @override
  Stream<List<Envelope>> watchAll() {
    return (_db.select(_db.envelopes)
          ..where((row) => row.userId.equals(_userId) & row.deletedAt.isNull()))
        .watch()
        .map((rows) => rows.map(_toDomain).toList());
  }

  @override
  Future<List<Envelope>> getAll() async {
    final rows =
        await (_db.select(_db.envelopes)..where(
              (row) => row.userId.equals(_userId) & row.deletedAt.isNull(),
            ))
            .get();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<void> create(Envelope envelope) async {
    await _db.transaction(() async {
      if (envelope.isRoundingReceiver) {
        await _clearExistingReceiver();
      }
      final method = envelope.allocationMethod == AllocationMethod.fixed
          ? tables.AllocationMethod.fixed
          : tables.AllocationMethod.percentage;
      final payload = {
        'id': envelope.id,
        'user_id': envelope.userId,
        'name': envelope.name,
        'allocation_method': method.name,
        'allocation_value': envelope.allocationValue,
        'balance': envelope.balance,
        'is_rounding_receiver': envelope.isRoundingReceiver,
      };
      await _db
          .into(_db.envelopes)
          .insert(
            EnvelopesCompanion.insert(
              id: envelope.id,
              userId: envelope.userId,
              name: envelope.name,
              allocationMethod: method,
              allocationValue: envelope.allocationValue,
              balance: Value(envelope.balance),
              isRoundingReceiver: Value(envelope.isRoundingReceiver),
            ),
          );
      await _appendOutbox(envelope.id, SyncOperation.insert, payload);
    });
  }

  @override
  Future<void> update(Envelope envelope) async {
    await _db.transaction(() async {
      if (envelope.isRoundingReceiver) {
        await _clearExistingReceiver(exceptId: envelope.id);
      }
      final method = envelope.allocationMethod == AllocationMethod.fixed
          ? tables.AllocationMethod.fixed
          : tables.AllocationMethod.percentage;
      final payload = {
        'id': envelope.id,
        'user_id': envelope.userId,
        'name': envelope.name,
        'allocation_method': method.name,
        'allocation_value': envelope.allocationValue,
        'balance': envelope.balance,
        'is_rounding_receiver': envelope.isRoundingReceiver,
      };
      await (_db.update(
        _db.envelopes,
      )..where((row) => row.id.equals(envelope.id))).write(
        EnvelopesCompanion(
          name: Value(envelope.name),
          allocationMethod: Value(method),
          allocationValue: Value(envelope.allocationValue),
          balance: Value(envelope.balance),
          isRoundingReceiver: Value(envelope.isRoundingReceiver),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await _appendOutbox(envelope.id, SyncOperation.update, payload);
    });
  }

  @override
  Future<void> delete(String id) async {
    await _db.transaction(() async {
      await (_db.update(_db.envelopes)..where((row) => row.id.equals(id)))
          .write(EnvelopesCompanion(deletedAt: Value(DateTime.now())));
      await _appendOutbox(id, SyncOperation.delete, {'id': id});
    });
  }

  /// FR-002: at most one rounding-remainder receiver per user.
  Future<void> _clearExistingReceiver({String? exceptId}) async {
    final query = _db.update(_db.envelopes)
      ..where(
        (row) =>
            row.userId.equals(_userId) &
            row.isRoundingReceiver.equals(true) &
            row.deletedAt.isNull(),
      );
    if (exceptId != null) {
      await (query..where((row) => row.id.equals(exceptId).not())).write(
        const EnvelopesCompanion(isRoundingReceiver: Value(false)),
      );
    } else {
      await query.write(
        const EnvelopesCompanion(isRoundingReceiver: Value(false)),
      );
    }
  }
}
