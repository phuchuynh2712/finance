import 'package:drift/drift.dart';

enum AllocationMethod { percentage, fixed }

@DataClassName('EnvelopeRow')
@TableIndex(name: 'envelopes_user_id_idx', columns: {#userId})
class Envelopes extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get name => text()();
  TextColumn get allocationMethod => textEnum<AllocationMethod>()();
  RealColumn get allocationValue => real()();
  IntColumn get balance => integer().withDefault(const Constant(0))();
  BoolColumn get isRoundingReceiver =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
