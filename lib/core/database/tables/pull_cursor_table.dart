import 'package:drift/drift.dart';

@DataClassName('PullCursorRow')
class PullCursor extends Table {
  TextColumn get userId => text()();
  TextColumn get syncTableName => text().named('table_name')();
  DateTimeColumn get lastUpdatedAt => dateTime().nullable()();
  TextColumn get lastId => text().nullable()();
  BoolColumn get initialPullCompleted =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {userId, syncTableName};
}
