// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $EnvelopesTable extends Envelopes
    with TableInfo<$EnvelopesTable, EnvelopeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EnvelopesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<AllocationMethod, String>
  allocationMethod = GeneratedColumn<String>(
    'allocation_method',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<AllocationMethod>($EnvelopesTable.$converterallocationMethod);
  static const VerificationMeta _allocationValueMeta = const VerificationMeta(
    'allocationValue',
  );
  @override
  late final GeneratedColumn<double> allocationValue = GeneratedColumn<double>(
    'allocation_value',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _balanceMeta = const VerificationMeta(
    'balance',
  );
  @override
  late final GeneratedColumn<int> balance = GeneratedColumn<int>(
    'balance',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isRoundingReceiverMeta =
      const VerificationMeta('isRoundingReceiver');
  @override
  late final GeneratedColumn<bool> isRoundingReceiver = GeneratedColumn<bool>(
    'is_rounding_receiver',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_rounding_receiver" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    name,
    allocationMethod,
    allocationValue,
    balance,
    isRoundingReceiver,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'envelopes';
  @override
  VerificationContext validateIntegrity(
    Insertable<EnvelopeRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('allocation_value')) {
      context.handle(
        _allocationValueMeta,
        allocationValue.isAcceptableOrUnknown(
          data['allocation_value']!,
          _allocationValueMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_allocationValueMeta);
    }
    if (data.containsKey('balance')) {
      context.handle(
        _balanceMeta,
        balance.isAcceptableOrUnknown(data['balance']!, _balanceMeta),
      );
    }
    if (data.containsKey('is_rounding_receiver')) {
      context.handle(
        _isRoundingReceiverMeta,
        isRoundingReceiver.isAcceptableOrUnknown(
          data['is_rounding_receiver']!,
          _isRoundingReceiverMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EnvelopeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EnvelopeRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      allocationMethod: $EnvelopesTable.$converterallocationMethod.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}allocation_method'],
        )!,
      ),
      allocationValue: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}allocation_value'],
      )!,
      balance: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}balance'],
      )!,
      isRoundingReceiver: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_rounding_receiver'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $EnvelopesTable createAlias(String alias) {
    return $EnvelopesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<AllocationMethod, String, String>
  $converterallocationMethod = const EnumNameConverter<AllocationMethod>(
    AllocationMethod.values,
  );
}

class EnvelopeRow extends DataClass implements Insertable<EnvelopeRow> {
  final String id;
  final String userId;
  final String name;
  final AllocationMethod allocationMethod;
  final double allocationValue;
  final int balance;
  final bool isRoundingReceiver;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const EnvelopeRow({
    required this.id,
    required this.userId,
    required this.name,
    required this.allocationMethod,
    required this.allocationValue,
    required this.balance,
    required this.isRoundingReceiver,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['name'] = Variable<String>(name);
    {
      map['allocation_method'] = Variable<String>(
        $EnvelopesTable.$converterallocationMethod.toSql(allocationMethod),
      );
    }
    map['allocation_value'] = Variable<double>(allocationValue);
    map['balance'] = Variable<int>(balance);
    map['is_rounding_receiver'] = Variable<bool>(isRoundingReceiver);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  EnvelopesCompanion toCompanion(bool nullToAbsent) {
    return EnvelopesCompanion(
      id: Value(id),
      userId: Value(userId),
      name: Value(name),
      allocationMethod: Value(allocationMethod),
      allocationValue: Value(allocationValue),
      balance: Value(balance),
      isRoundingReceiver: Value(isRoundingReceiver),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory EnvelopeRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EnvelopeRow(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      name: serializer.fromJson<String>(json['name']),
      allocationMethod: $EnvelopesTable.$converterallocationMethod.fromJson(
        serializer.fromJson<String>(json['allocationMethod']),
      ),
      allocationValue: serializer.fromJson<double>(json['allocationValue']),
      balance: serializer.fromJson<int>(json['balance']),
      isRoundingReceiver: serializer.fromJson<bool>(json['isRoundingReceiver']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'name': serializer.toJson<String>(name),
      'allocationMethod': serializer.toJson<String>(
        $EnvelopesTable.$converterallocationMethod.toJson(allocationMethod),
      ),
      'allocationValue': serializer.toJson<double>(allocationValue),
      'balance': serializer.toJson<int>(balance),
      'isRoundingReceiver': serializer.toJson<bool>(isRoundingReceiver),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  EnvelopeRow copyWith({
    String? id,
    String? userId,
    String? name,
    AllocationMethod? allocationMethod,
    double? allocationValue,
    int? balance,
    bool? isRoundingReceiver,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => EnvelopeRow(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    name: name ?? this.name,
    allocationMethod: allocationMethod ?? this.allocationMethod,
    allocationValue: allocationValue ?? this.allocationValue,
    balance: balance ?? this.balance,
    isRoundingReceiver: isRoundingReceiver ?? this.isRoundingReceiver,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  EnvelopeRow copyWithCompanion(EnvelopesCompanion data) {
    return EnvelopeRow(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      name: data.name.present ? data.name.value : this.name,
      allocationMethod: data.allocationMethod.present
          ? data.allocationMethod.value
          : this.allocationMethod,
      allocationValue: data.allocationValue.present
          ? data.allocationValue.value
          : this.allocationValue,
      balance: data.balance.present ? data.balance.value : this.balance,
      isRoundingReceiver: data.isRoundingReceiver.present
          ? data.isRoundingReceiver.value
          : this.isRoundingReceiver,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EnvelopeRow(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('name: $name, ')
          ..write('allocationMethod: $allocationMethod, ')
          ..write('allocationValue: $allocationValue, ')
          ..write('balance: $balance, ')
          ..write('isRoundingReceiver: $isRoundingReceiver, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    name,
    allocationMethod,
    allocationValue,
    balance,
    isRoundingReceiver,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EnvelopeRow &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.name == this.name &&
          other.allocationMethod == this.allocationMethod &&
          other.allocationValue == this.allocationValue &&
          other.balance == this.balance &&
          other.isRoundingReceiver == this.isRoundingReceiver &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class EnvelopesCompanion extends UpdateCompanion<EnvelopeRow> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String> name;
  final Value<AllocationMethod> allocationMethod;
  final Value<double> allocationValue;
  final Value<int> balance;
  final Value<bool> isRoundingReceiver;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const EnvelopesCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.name = const Value.absent(),
    this.allocationMethod = const Value.absent(),
    this.allocationValue = const Value.absent(),
    this.balance = const Value.absent(),
    this.isRoundingReceiver = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EnvelopesCompanion.insert({
    required String id,
    required String userId,
    required String name,
    required AllocationMethod allocationMethod,
    required double allocationValue,
    this.balance = const Value.absent(),
    this.isRoundingReceiver = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       userId = Value(userId),
       name = Value(name),
       allocationMethod = Value(allocationMethod),
       allocationValue = Value(allocationValue);
  static Insertable<EnvelopeRow> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? name,
    Expression<String>? allocationMethod,
    Expression<double>? allocationValue,
    Expression<int>? balance,
    Expression<bool>? isRoundingReceiver,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (name != null) 'name': name,
      if (allocationMethod != null) 'allocation_method': allocationMethod,
      if (allocationValue != null) 'allocation_value': allocationValue,
      if (balance != null) 'balance': balance,
      if (isRoundingReceiver != null)
        'is_rounding_receiver': isRoundingReceiver,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EnvelopesCompanion copyWith({
    Value<String>? id,
    Value<String>? userId,
    Value<String>? name,
    Value<AllocationMethod>? allocationMethod,
    Value<double>? allocationValue,
    Value<int>? balance,
    Value<bool>? isRoundingReceiver,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return EnvelopesCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      allocationMethod: allocationMethod ?? this.allocationMethod,
      allocationValue: allocationValue ?? this.allocationValue,
      balance: balance ?? this.balance,
      isRoundingReceiver: isRoundingReceiver ?? this.isRoundingReceiver,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (allocationMethod.present) {
      map['allocation_method'] = Variable<String>(
        $EnvelopesTable.$converterallocationMethod.toSql(
          allocationMethod.value,
        ),
      );
    }
    if (allocationValue.present) {
      map['allocation_value'] = Variable<double>(allocationValue.value);
    }
    if (balance.present) {
      map['balance'] = Variable<int>(balance.value);
    }
    if (isRoundingReceiver.present) {
      map['is_rounding_receiver'] = Variable<bool>(isRoundingReceiver.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EnvelopesCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('name: $name, ')
          ..write('allocationMethod: $allocationMethod, ')
          ..write('allocationValue: $allocationValue, ')
          ..write('balance: $balance, ')
          ..write('isRoundingReceiver: $isRoundingReceiver, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AllocationEventsTable extends AllocationEvents
    with TableInfo<$AllocationEventsTable, AllocationEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AllocationEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eventDateMeta = const VerificationMeta(
    'eventDate',
  );
  @override
  late final GeneratedColumn<DateTime> eventDate = GeneratedColumn<DateTime>(
    'event_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _incomeAmountMeta = const VerificationMeta(
    'incomeAmount',
  );
  @override
  late final GeneratedColumn<int> incomeAmount = GeneratedColumn<int>(
    'income_amount',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    eventDate,
    incomeAmount,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'allocation_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<AllocationEventRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('event_date')) {
      context.handle(
        _eventDateMeta,
        eventDate.isAcceptableOrUnknown(data['event_date']!, _eventDateMeta),
      );
    }
    if (data.containsKey('income_amount')) {
      context.handle(
        _incomeAmountMeta,
        incomeAmount.isAcceptableOrUnknown(
          data['income_amount']!,
          _incomeAmountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_incomeAmountMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AllocationEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AllocationEventRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      eventDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}event_date'],
      )!,
      incomeAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}income_amount'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $AllocationEventsTable createAlias(String alias) {
    return $AllocationEventsTable(attachedDatabase, alias);
  }
}

class AllocationEventRow extends DataClass
    implements Insertable<AllocationEventRow> {
  final String id;
  final String userId;
  final DateTime eventDate;
  final int incomeAmount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const AllocationEventRow({
    required this.id,
    required this.userId,
    required this.eventDate,
    required this.incomeAmount,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['event_date'] = Variable<DateTime>(eventDate);
    map['income_amount'] = Variable<int>(incomeAmount);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  AllocationEventsCompanion toCompanion(bool nullToAbsent) {
    return AllocationEventsCompanion(
      id: Value(id),
      userId: Value(userId),
      eventDate: Value(eventDate),
      incomeAmount: Value(incomeAmount),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory AllocationEventRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AllocationEventRow(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      eventDate: serializer.fromJson<DateTime>(json['eventDate']),
      incomeAmount: serializer.fromJson<int>(json['incomeAmount']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'eventDate': serializer.toJson<DateTime>(eventDate),
      'incomeAmount': serializer.toJson<int>(incomeAmount),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  AllocationEventRow copyWith({
    String? id,
    String? userId,
    DateTime? eventDate,
    int? incomeAmount,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => AllocationEventRow(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    eventDate: eventDate ?? this.eventDate,
    incomeAmount: incomeAmount ?? this.incomeAmount,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  AllocationEventRow copyWithCompanion(AllocationEventsCompanion data) {
    return AllocationEventRow(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      eventDate: data.eventDate.present ? data.eventDate.value : this.eventDate,
      incomeAmount: data.incomeAmount.present
          ? data.incomeAmount.value
          : this.incomeAmount,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AllocationEventRow(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('eventDate: $eventDate, ')
          ..write('incomeAmount: $incomeAmount, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    eventDate,
    incomeAmount,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AllocationEventRow &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.eventDate == this.eventDate &&
          other.incomeAmount == this.incomeAmount &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class AllocationEventsCompanion extends UpdateCompanion<AllocationEventRow> {
  final Value<String> id;
  final Value<String> userId;
  final Value<DateTime> eventDate;
  final Value<int> incomeAmount;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const AllocationEventsCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.eventDate = const Value.absent(),
    this.incomeAmount = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AllocationEventsCompanion.insert({
    required String id,
    required String userId,
    this.eventDate = const Value.absent(),
    required int incomeAmount,
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       userId = Value(userId),
       incomeAmount = Value(incomeAmount);
  static Insertable<AllocationEventRow> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<DateTime>? eventDate,
    Expression<int>? incomeAmount,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (eventDate != null) 'event_date': eventDate,
      if (incomeAmount != null) 'income_amount': incomeAmount,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AllocationEventsCompanion copyWith({
    Value<String>? id,
    Value<String>? userId,
    Value<DateTime>? eventDate,
    Value<int>? incomeAmount,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return AllocationEventsCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      eventDate: eventDate ?? this.eventDate,
      incomeAmount: incomeAmount ?? this.incomeAmount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (eventDate.present) {
      map['event_date'] = Variable<DateTime>(eventDate.value);
    }
    if (incomeAmount.present) {
      map['income_amount'] = Variable<int>(incomeAmount.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AllocationEventsCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('eventDate: $eventDate, ')
          ..write('incomeAmount: $incomeAmount, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AllocationEventLinesTable extends AllocationEventLines
    with TableInfo<$AllocationEventLinesTable, AllocationEventLineRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AllocationEventLinesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _allocationEventIdMeta = const VerificationMeta(
    'allocationEventId',
  );
  @override
  late final GeneratedColumn<String> allocationEventId =
      GeneratedColumn<String>(
        'allocation_event_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES allocation_events (id)',
        ),
      );
  static const VerificationMeta _envelopeIdMeta = const VerificationMeta(
    'envelopeId',
  );
  @override
  late final GeneratedColumn<String> envelopeId = GeneratedColumn<String>(
    'envelope_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES envelopes (id)',
    ),
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<int> amount = GeneratedColumn<int>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isRoundingRemainderLineMeta =
      const VerificationMeta('isRoundingRemainderLine');
  @override
  late final GeneratedColumn<bool> isRoundingRemainderLine =
      GeneratedColumn<bool>(
        'is_rounding_remainder_line',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_rounding_remainder_line" IN (0, 1))',
        ),
        defaultValue: const Constant(false),
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    allocationEventId,
    envelopeId,
    amount,
    isRoundingRemainderLine,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'allocation_event_lines';
  @override
  VerificationContext validateIntegrity(
    Insertable<AllocationEventLineRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('allocation_event_id')) {
      context.handle(
        _allocationEventIdMeta,
        allocationEventId.isAcceptableOrUnknown(
          data['allocation_event_id']!,
          _allocationEventIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_allocationEventIdMeta);
    }
    if (data.containsKey('envelope_id')) {
      context.handle(
        _envelopeIdMeta,
        envelopeId.isAcceptableOrUnknown(data['envelope_id']!, _envelopeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_envelopeIdMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('is_rounding_remainder_line')) {
      context.handle(
        _isRoundingRemainderLineMeta,
        isRoundingRemainderLine.isAcceptableOrUnknown(
          data['is_rounding_remainder_line']!,
          _isRoundingRemainderLineMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AllocationEventLineRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AllocationEventLineRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      allocationEventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}allocation_event_id'],
      )!,
      envelopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}envelope_id'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount'],
      )!,
      isRoundingRemainderLine: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_rounding_remainder_line'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $AllocationEventLinesTable createAlias(String alias) {
    return $AllocationEventLinesTable(attachedDatabase, alias);
  }
}

class AllocationEventLineRow extends DataClass
    implements Insertable<AllocationEventLineRow> {
  final String id;
  final String userId;
  final String allocationEventId;
  final String envelopeId;
  final int amount;
  final bool isRoundingRemainderLine;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const AllocationEventLineRow({
    required this.id,
    required this.userId,
    required this.allocationEventId,
    required this.envelopeId,
    required this.amount,
    required this.isRoundingRemainderLine,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['allocation_event_id'] = Variable<String>(allocationEventId);
    map['envelope_id'] = Variable<String>(envelopeId);
    map['amount'] = Variable<int>(amount);
    map['is_rounding_remainder_line'] = Variable<bool>(isRoundingRemainderLine);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  AllocationEventLinesCompanion toCompanion(bool nullToAbsent) {
    return AllocationEventLinesCompanion(
      id: Value(id),
      userId: Value(userId),
      allocationEventId: Value(allocationEventId),
      envelopeId: Value(envelopeId),
      amount: Value(amount),
      isRoundingRemainderLine: Value(isRoundingRemainderLine),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory AllocationEventLineRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AllocationEventLineRow(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      allocationEventId: serializer.fromJson<String>(json['allocationEventId']),
      envelopeId: serializer.fromJson<String>(json['envelopeId']),
      amount: serializer.fromJson<int>(json['amount']),
      isRoundingRemainderLine: serializer.fromJson<bool>(
        json['isRoundingRemainderLine'],
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'allocationEventId': serializer.toJson<String>(allocationEventId),
      'envelopeId': serializer.toJson<String>(envelopeId),
      'amount': serializer.toJson<int>(amount),
      'isRoundingRemainderLine': serializer.toJson<bool>(
        isRoundingRemainderLine,
      ),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  AllocationEventLineRow copyWith({
    String? id,
    String? userId,
    String? allocationEventId,
    String? envelopeId,
    int? amount,
    bool? isRoundingRemainderLine,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => AllocationEventLineRow(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    allocationEventId: allocationEventId ?? this.allocationEventId,
    envelopeId: envelopeId ?? this.envelopeId,
    amount: amount ?? this.amount,
    isRoundingRemainderLine:
        isRoundingRemainderLine ?? this.isRoundingRemainderLine,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  AllocationEventLineRow copyWithCompanion(AllocationEventLinesCompanion data) {
    return AllocationEventLineRow(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      allocationEventId: data.allocationEventId.present
          ? data.allocationEventId.value
          : this.allocationEventId,
      envelopeId: data.envelopeId.present
          ? data.envelopeId.value
          : this.envelopeId,
      amount: data.amount.present ? data.amount.value : this.amount,
      isRoundingRemainderLine: data.isRoundingRemainderLine.present
          ? data.isRoundingRemainderLine.value
          : this.isRoundingRemainderLine,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AllocationEventLineRow(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('allocationEventId: $allocationEventId, ')
          ..write('envelopeId: $envelopeId, ')
          ..write('amount: $amount, ')
          ..write('isRoundingRemainderLine: $isRoundingRemainderLine, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    allocationEventId,
    envelopeId,
    amount,
    isRoundingRemainderLine,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AllocationEventLineRow &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.allocationEventId == this.allocationEventId &&
          other.envelopeId == this.envelopeId &&
          other.amount == this.amount &&
          other.isRoundingRemainderLine == this.isRoundingRemainderLine &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class AllocationEventLinesCompanion
    extends UpdateCompanion<AllocationEventLineRow> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String> allocationEventId;
  final Value<String> envelopeId;
  final Value<int> amount;
  final Value<bool> isRoundingRemainderLine;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const AllocationEventLinesCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.allocationEventId = const Value.absent(),
    this.envelopeId = const Value.absent(),
    this.amount = const Value.absent(),
    this.isRoundingRemainderLine = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AllocationEventLinesCompanion.insert({
    required String id,
    required String userId,
    required String allocationEventId,
    required String envelopeId,
    required int amount,
    this.isRoundingRemainderLine = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       userId = Value(userId),
       allocationEventId = Value(allocationEventId),
       envelopeId = Value(envelopeId),
       amount = Value(amount);
  static Insertable<AllocationEventLineRow> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? allocationEventId,
    Expression<String>? envelopeId,
    Expression<int>? amount,
    Expression<bool>? isRoundingRemainderLine,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (allocationEventId != null) 'allocation_event_id': allocationEventId,
      if (envelopeId != null) 'envelope_id': envelopeId,
      if (amount != null) 'amount': amount,
      if (isRoundingRemainderLine != null)
        'is_rounding_remainder_line': isRoundingRemainderLine,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AllocationEventLinesCompanion copyWith({
    Value<String>? id,
    Value<String>? userId,
    Value<String>? allocationEventId,
    Value<String>? envelopeId,
    Value<int>? amount,
    Value<bool>? isRoundingRemainderLine,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return AllocationEventLinesCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      allocationEventId: allocationEventId ?? this.allocationEventId,
      envelopeId: envelopeId ?? this.envelopeId,
      amount: amount ?? this.amount,
      isRoundingRemainderLine:
          isRoundingRemainderLine ?? this.isRoundingRemainderLine,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (allocationEventId.present) {
      map['allocation_event_id'] = Variable<String>(allocationEventId.value);
    }
    if (envelopeId.present) {
      map['envelope_id'] = Variable<String>(envelopeId.value);
    }
    if (amount.present) {
      map['amount'] = Variable<int>(amount.value);
    }
    if (isRoundingRemainderLine.present) {
      map['is_rounding_remainder_line'] = Variable<bool>(
        isRoundingRemainderLine.value,
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AllocationEventLinesCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('allocationEventId: $allocationEventId, ')
          ..write('envelopeId: $envelopeId, ')
          ..write('amount: $amount, ')
          ..write('isRoundingRemainderLine: $isRoundingRemainderLine, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ExpenseEntriesTable extends ExpenseEntries
    with TableInfo<$ExpenseEntriesTable, ExpenseEntryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExpenseEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _envelopeIdMeta = const VerificationMeta(
    'envelopeId',
  );
  @override
  late final GeneratedColumn<String> envelopeId = GeneratedColumn<String>(
    'envelope_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES envelopes (id)',
    ),
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<int> amount = GeneratedColumn<int>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entryDateMeta = const VerificationMeta(
    'entryDate',
  );
  @override
  late final GeneratedColumn<DateTime> entryDate = GeneratedColumn<DateTime>(
    'entry_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ExpenseEntryMethod, String>
  entryMethod =
      GeneratedColumn<String>(
        'entry_method',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('manual'),
      ).withConverter<ExpenseEntryMethod>(
        $ExpenseEntriesTable.$converterentryMethod,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    envelopeId,
    amount,
    entryDate,
    note,
    entryMethod,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'expense_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<ExpenseEntryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('envelope_id')) {
      context.handle(
        _envelopeIdMeta,
        envelopeId.isAcceptableOrUnknown(data['envelope_id']!, _envelopeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_envelopeIdMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('entry_date')) {
      context.handle(
        _entryDateMeta,
        entryDate.isAcceptableOrUnknown(data['entry_date']!, _entryDateMeta),
      );
    } else if (isInserting) {
      context.missing(_entryDateMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ExpenseEntryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExpenseEntryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      envelopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}envelope_id'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount'],
      )!,
      entryDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}entry_date'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      entryMethod: $ExpenseEntriesTable.$converterentryMethod.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}entry_method'],
        )!,
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $ExpenseEntriesTable createAlias(String alias) {
    return $ExpenseEntriesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ExpenseEntryMethod, String, String>
  $converterentryMethod = const EnumNameConverter<ExpenseEntryMethod>(
    ExpenseEntryMethod.values,
  );
}

class ExpenseEntryRow extends DataClass implements Insertable<ExpenseEntryRow> {
  final String id;
  final String userId;
  final String envelopeId;
  final int amount;
  final DateTime entryDate;
  final String? note;
  final ExpenseEntryMethod entryMethod;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const ExpenseEntryRow({
    required this.id,
    required this.userId,
    required this.envelopeId,
    required this.amount,
    required this.entryDate,
    this.note,
    required this.entryMethod,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['envelope_id'] = Variable<String>(envelopeId);
    map['amount'] = Variable<int>(amount);
    map['entry_date'] = Variable<DateTime>(entryDate);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    {
      map['entry_method'] = Variable<String>(
        $ExpenseEntriesTable.$converterentryMethod.toSql(entryMethod),
      );
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  ExpenseEntriesCompanion toCompanion(bool nullToAbsent) {
    return ExpenseEntriesCompanion(
      id: Value(id),
      userId: Value(userId),
      envelopeId: Value(envelopeId),
      amount: Value(amount),
      entryDate: Value(entryDate),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      entryMethod: Value(entryMethod),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory ExpenseEntryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExpenseEntryRow(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      envelopeId: serializer.fromJson<String>(json['envelopeId']),
      amount: serializer.fromJson<int>(json['amount']),
      entryDate: serializer.fromJson<DateTime>(json['entryDate']),
      note: serializer.fromJson<String?>(json['note']),
      entryMethod: $ExpenseEntriesTable.$converterentryMethod.fromJson(
        serializer.fromJson<String>(json['entryMethod']),
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'envelopeId': serializer.toJson<String>(envelopeId),
      'amount': serializer.toJson<int>(amount),
      'entryDate': serializer.toJson<DateTime>(entryDate),
      'note': serializer.toJson<String?>(note),
      'entryMethod': serializer.toJson<String>(
        $ExpenseEntriesTable.$converterentryMethod.toJson(entryMethod),
      ),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  ExpenseEntryRow copyWith({
    String? id,
    String? userId,
    String? envelopeId,
    int? amount,
    DateTime? entryDate,
    Value<String?> note = const Value.absent(),
    ExpenseEntryMethod? entryMethod,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => ExpenseEntryRow(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    envelopeId: envelopeId ?? this.envelopeId,
    amount: amount ?? this.amount,
    entryDate: entryDate ?? this.entryDate,
    note: note.present ? note.value : this.note,
    entryMethod: entryMethod ?? this.entryMethod,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  ExpenseEntryRow copyWithCompanion(ExpenseEntriesCompanion data) {
    return ExpenseEntryRow(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      envelopeId: data.envelopeId.present
          ? data.envelopeId.value
          : this.envelopeId,
      amount: data.amount.present ? data.amount.value : this.amount,
      entryDate: data.entryDate.present ? data.entryDate.value : this.entryDate,
      note: data.note.present ? data.note.value : this.note,
      entryMethod: data.entryMethod.present
          ? data.entryMethod.value
          : this.entryMethod,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExpenseEntryRow(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('envelopeId: $envelopeId, ')
          ..write('amount: $amount, ')
          ..write('entryDate: $entryDate, ')
          ..write('note: $note, ')
          ..write('entryMethod: $entryMethod, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    envelopeId,
    amount,
    entryDate,
    note,
    entryMethod,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExpenseEntryRow &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.envelopeId == this.envelopeId &&
          other.amount == this.amount &&
          other.entryDate == this.entryDate &&
          other.note == this.note &&
          other.entryMethod == this.entryMethod &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class ExpenseEntriesCompanion extends UpdateCompanion<ExpenseEntryRow> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String> envelopeId;
  final Value<int> amount;
  final Value<DateTime> entryDate;
  final Value<String?> note;
  final Value<ExpenseEntryMethod> entryMethod;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const ExpenseEntriesCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.envelopeId = const Value.absent(),
    this.amount = const Value.absent(),
    this.entryDate = const Value.absent(),
    this.note = const Value.absent(),
    this.entryMethod = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ExpenseEntriesCompanion.insert({
    required String id,
    required String userId,
    required String envelopeId,
    required int amount,
    required DateTime entryDate,
    this.note = const Value.absent(),
    this.entryMethod = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       userId = Value(userId),
       envelopeId = Value(envelopeId),
       amount = Value(amount),
       entryDate = Value(entryDate);
  static Insertable<ExpenseEntryRow> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? envelopeId,
    Expression<int>? amount,
    Expression<DateTime>? entryDate,
    Expression<String>? note,
    Expression<String>? entryMethod,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (envelopeId != null) 'envelope_id': envelopeId,
      if (amount != null) 'amount': amount,
      if (entryDate != null) 'entry_date': entryDate,
      if (note != null) 'note': note,
      if (entryMethod != null) 'entry_method': entryMethod,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ExpenseEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? userId,
    Value<String>? envelopeId,
    Value<int>? amount,
    Value<DateTime>? entryDate,
    Value<String?>? note,
    Value<ExpenseEntryMethod>? entryMethod,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return ExpenseEntriesCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      envelopeId: envelopeId ?? this.envelopeId,
      amount: amount ?? this.amount,
      entryDate: entryDate ?? this.entryDate,
      note: note ?? this.note,
      entryMethod: entryMethod ?? this.entryMethod,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (envelopeId.present) {
      map['envelope_id'] = Variable<String>(envelopeId.value);
    }
    if (amount.present) {
      map['amount'] = Variable<int>(amount.value);
    }
    if (entryDate.present) {
      map['entry_date'] = Variable<DateTime>(entryDate.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (entryMethod.present) {
      map['entry_method'] = Variable<String>(
        $ExpenseEntriesTable.$converterentryMethod.toSql(entryMethod.value),
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExpenseEntriesCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('envelopeId: $envelopeId, ')
          ..write('amount: $amount, ')
          ..write('entryDate: $entryDate, ')
          ..write('note: $note, ')
          ..write('entryMethod: $entryMethod, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EnvelopeCoveragesTable extends EnvelopeCoverages
    with TableInfo<$EnvelopeCoveragesTable, EnvelopeCoverageRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EnvelopeCoveragesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expenseEntryIdMeta = const VerificationMeta(
    'expenseEntryId',
  );
  @override
  late final GeneratedColumn<String> expenseEntryId = GeneratedColumn<String>(
    'expense_entry_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES expense_entries (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _sourceEnvelopeIdMeta = const VerificationMeta(
    'sourceEnvelopeId',
  );
  @override
  late final GeneratedColumn<String> sourceEnvelopeId = GeneratedColumn<String>(
    'source_envelope_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES envelopes (id)',
    ),
  );
  static const VerificationMeta _coveringEnvelopeIdMeta =
      const VerificationMeta('coveringEnvelopeId');
  @override
  late final GeneratedColumn<String> coveringEnvelopeId =
      GeneratedColumn<String>(
        'covering_envelope_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES envelopes (id)',
        ),
      );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<int> amount = GeneratedColumn<int>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _coveredAtMeta = const VerificationMeta(
    'coveredAt',
  );
  @override
  late final GeneratedColumn<DateTime> coveredAt = GeneratedColumn<DateTime>(
    'covered_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    expenseEntryId,
    sourceEnvelopeId,
    coveringEnvelopeId,
    amount,
    coveredAt,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'envelope_coverages';
  @override
  VerificationContext validateIntegrity(
    Insertable<EnvelopeCoverageRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('expense_entry_id')) {
      context.handle(
        _expenseEntryIdMeta,
        expenseEntryId.isAcceptableOrUnknown(
          data['expense_entry_id']!,
          _expenseEntryIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_expenseEntryIdMeta);
    }
    if (data.containsKey('source_envelope_id')) {
      context.handle(
        _sourceEnvelopeIdMeta,
        sourceEnvelopeId.isAcceptableOrUnknown(
          data['source_envelope_id']!,
          _sourceEnvelopeIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceEnvelopeIdMeta);
    }
    if (data.containsKey('covering_envelope_id')) {
      context.handle(
        _coveringEnvelopeIdMeta,
        coveringEnvelopeId.isAcceptableOrUnknown(
          data['covering_envelope_id']!,
          _coveringEnvelopeIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_coveringEnvelopeIdMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('covered_at')) {
      context.handle(
        _coveredAtMeta,
        coveredAt.isAcceptableOrUnknown(data['covered_at']!, _coveredAtMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EnvelopeCoverageRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EnvelopeCoverageRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      expenseEntryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}expense_entry_id'],
      )!,
      sourceEnvelopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_envelope_id'],
      )!,
      coveringEnvelopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}covering_envelope_id'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount'],
      )!,
      coveredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}covered_at'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $EnvelopeCoveragesTable createAlias(String alias) {
    return $EnvelopeCoveragesTable(attachedDatabase, alias);
  }
}

class EnvelopeCoverageRow extends DataClass
    implements Insertable<EnvelopeCoverageRow> {
  final String id;
  final String userId;
  final String expenseEntryId;
  final String sourceEnvelopeId;
  final String coveringEnvelopeId;
  final int amount;
  final DateTime coveredAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const EnvelopeCoverageRow({
    required this.id,
    required this.userId,
    required this.expenseEntryId,
    required this.sourceEnvelopeId,
    required this.coveringEnvelopeId,
    required this.amount,
    required this.coveredAt,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['expense_entry_id'] = Variable<String>(expenseEntryId);
    map['source_envelope_id'] = Variable<String>(sourceEnvelopeId);
    map['covering_envelope_id'] = Variable<String>(coveringEnvelopeId);
    map['amount'] = Variable<int>(amount);
    map['covered_at'] = Variable<DateTime>(coveredAt);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  EnvelopeCoveragesCompanion toCompanion(bool nullToAbsent) {
    return EnvelopeCoveragesCompanion(
      id: Value(id),
      userId: Value(userId),
      expenseEntryId: Value(expenseEntryId),
      sourceEnvelopeId: Value(sourceEnvelopeId),
      coveringEnvelopeId: Value(coveringEnvelopeId),
      amount: Value(amount),
      coveredAt: Value(coveredAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory EnvelopeCoverageRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EnvelopeCoverageRow(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      expenseEntryId: serializer.fromJson<String>(json['expenseEntryId']),
      sourceEnvelopeId: serializer.fromJson<String>(json['sourceEnvelopeId']),
      coveringEnvelopeId: serializer.fromJson<String>(
        json['coveringEnvelopeId'],
      ),
      amount: serializer.fromJson<int>(json['amount']),
      coveredAt: serializer.fromJson<DateTime>(json['coveredAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'expenseEntryId': serializer.toJson<String>(expenseEntryId),
      'sourceEnvelopeId': serializer.toJson<String>(sourceEnvelopeId),
      'coveringEnvelopeId': serializer.toJson<String>(coveringEnvelopeId),
      'amount': serializer.toJson<int>(amount),
      'coveredAt': serializer.toJson<DateTime>(coveredAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  EnvelopeCoverageRow copyWith({
    String? id,
    String? userId,
    String? expenseEntryId,
    String? sourceEnvelopeId,
    String? coveringEnvelopeId,
    int? amount,
    DateTime? coveredAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => EnvelopeCoverageRow(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    expenseEntryId: expenseEntryId ?? this.expenseEntryId,
    sourceEnvelopeId: sourceEnvelopeId ?? this.sourceEnvelopeId,
    coveringEnvelopeId: coveringEnvelopeId ?? this.coveringEnvelopeId,
    amount: amount ?? this.amount,
    coveredAt: coveredAt ?? this.coveredAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  EnvelopeCoverageRow copyWithCompanion(EnvelopeCoveragesCompanion data) {
    return EnvelopeCoverageRow(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      expenseEntryId: data.expenseEntryId.present
          ? data.expenseEntryId.value
          : this.expenseEntryId,
      sourceEnvelopeId: data.sourceEnvelopeId.present
          ? data.sourceEnvelopeId.value
          : this.sourceEnvelopeId,
      coveringEnvelopeId: data.coveringEnvelopeId.present
          ? data.coveringEnvelopeId.value
          : this.coveringEnvelopeId,
      amount: data.amount.present ? data.amount.value : this.amount,
      coveredAt: data.coveredAt.present ? data.coveredAt.value : this.coveredAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EnvelopeCoverageRow(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('expenseEntryId: $expenseEntryId, ')
          ..write('sourceEnvelopeId: $sourceEnvelopeId, ')
          ..write('coveringEnvelopeId: $coveringEnvelopeId, ')
          ..write('amount: $amount, ')
          ..write('coveredAt: $coveredAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    expenseEntryId,
    sourceEnvelopeId,
    coveringEnvelopeId,
    amount,
    coveredAt,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EnvelopeCoverageRow &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.expenseEntryId == this.expenseEntryId &&
          other.sourceEnvelopeId == this.sourceEnvelopeId &&
          other.coveringEnvelopeId == this.coveringEnvelopeId &&
          other.amount == this.amount &&
          other.coveredAt == this.coveredAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class EnvelopeCoveragesCompanion extends UpdateCompanion<EnvelopeCoverageRow> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String> expenseEntryId;
  final Value<String> sourceEnvelopeId;
  final Value<String> coveringEnvelopeId;
  final Value<int> amount;
  final Value<DateTime> coveredAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const EnvelopeCoveragesCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.expenseEntryId = const Value.absent(),
    this.sourceEnvelopeId = const Value.absent(),
    this.coveringEnvelopeId = const Value.absent(),
    this.amount = const Value.absent(),
    this.coveredAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EnvelopeCoveragesCompanion.insert({
    required String id,
    required String userId,
    required String expenseEntryId,
    required String sourceEnvelopeId,
    required String coveringEnvelopeId,
    required int amount,
    this.coveredAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       userId = Value(userId),
       expenseEntryId = Value(expenseEntryId),
       sourceEnvelopeId = Value(sourceEnvelopeId),
       coveringEnvelopeId = Value(coveringEnvelopeId),
       amount = Value(amount);
  static Insertable<EnvelopeCoverageRow> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? expenseEntryId,
    Expression<String>? sourceEnvelopeId,
    Expression<String>? coveringEnvelopeId,
    Expression<int>? amount,
    Expression<DateTime>? coveredAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (expenseEntryId != null) 'expense_entry_id': expenseEntryId,
      if (sourceEnvelopeId != null) 'source_envelope_id': sourceEnvelopeId,
      if (coveringEnvelopeId != null)
        'covering_envelope_id': coveringEnvelopeId,
      if (amount != null) 'amount': amount,
      if (coveredAt != null) 'covered_at': coveredAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EnvelopeCoveragesCompanion copyWith({
    Value<String>? id,
    Value<String>? userId,
    Value<String>? expenseEntryId,
    Value<String>? sourceEnvelopeId,
    Value<String>? coveringEnvelopeId,
    Value<int>? amount,
    Value<DateTime>? coveredAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return EnvelopeCoveragesCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      expenseEntryId: expenseEntryId ?? this.expenseEntryId,
      sourceEnvelopeId: sourceEnvelopeId ?? this.sourceEnvelopeId,
      coveringEnvelopeId: coveringEnvelopeId ?? this.coveringEnvelopeId,
      amount: amount ?? this.amount,
      coveredAt: coveredAt ?? this.coveredAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (expenseEntryId.present) {
      map['expense_entry_id'] = Variable<String>(expenseEntryId.value);
    }
    if (sourceEnvelopeId.present) {
      map['source_envelope_id'] = Variable<String>(sourceEnvelopeId.value);
    }
    if (coveringEnvelopeId.present) {
      map['covering_envelope_id'] = Variable<String>(coveringEnvelopeId.value);
    }
    if (amount.present) {
      map['amount'] = Variable<int>(amount.value);
    }
    if (coveredAt.present) {
      map['covered_at'] = Variable<DateTime>(coveredAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EnvelopeCoveragesCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('expenseEntryId: $expenseEntryId, ')
          ..write('sourceEnvelopeId: $sourceEnvelopeId, ')
          ..write('coveringEnvelopeId: $coveringEnvelopeId, ')
          ..write('amount: $amount, ')
          ..write('coveredAt: $coveredAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ExpenseControlItemsTable extends ExpenseControlItems
    with TableInfo<$ExpenseControlItemsTable, ExpenseControlItemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExpenseControlItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iconKeyMeta = const VerificationMeta(
    'iconKey',
  );
  @override
  late final GeneratedColumn<String> iconKey = GeneratedColumn<String>(
    'icon_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  late final GeneratedColumnWithTypeConverter<ExpenseAllocationMethod?, String>
  allocationMethod =
      GeneratedColumn<String>(
        'allocation_method',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<ExpenseAllocationMethod?>(
        $ExpenseControlItemsTable.$converterallocationMethodn,
      );
  static const VerificationMeta _allocationValueMeta = const VerificationMeta(
    'allocationValue',
  );
  @override
  late final GeneratedColumn<double> allocationValue = GeneratedColumn<double>(
    'allocation_value',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    parentId,
    name,
    iconKey,
    description,
    sortOrder,
    allocationMethod,
    allocationValue,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'expense_control_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<ExpenseControlItemRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('icon_key')) {
      context.handle(
        _iconKeyMeta,
        iconKey.isAcceptableOrUnknown(data['icon_key']!, _iconKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_iconKeyMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('allocation_value')) {
      context.handle(
        _allocationValueMeta,
        allocationValue.isAcceptableOrUnknown(
          data['allocation_value']!,
          _allocationValueMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ExpenseControlItemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExpenseControlItemRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      iconKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon_key'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      allocationMethod: $ExpenseControlItemsTable.$converterallocationMethodn
          .fromSql(
            attachedDatabase.typeMapping.read(
              DriftSqlType.string,
              data['${effectivePrefix}allocation_method'],
            ),
          ),
      allocationValue: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}allocation_value'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $ExpenseControlItemsTable createAlias(String alias) {
    return $ExpenseControlItemsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ExpenseAllocationMethod, String, String>
  $converterallocationMethod = const EnumNameConverter<ExpenseAllocationMethod>(
    ExpenseAllocationMethod.values,
  );
  static JsonTypeConverter2<ExpenseAllocationMethod?, String?, String?>
  $converterallocationMethodn = JsonTypeConverter2.asNullable(
    $converterallocationMethod,
  );
}

class ExpenseControlItemRow extends DataClass
    implements Insertable<ExpenseControlItemRow> {
  final String id;
  final String userId;
  final String? parentId;
  final String name;
  final String iconKey;
  final String? description;
  final int sortOrder;
  final ExpenseAllocationMethod? allocationMethod;
  final double? allocationValue;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const ExpenseControlItemRow({
    required this.id,
    required this.userId,
    this.parentId,
    required this.name,
    required this.iconKey,
    this.description,
    required this.sortOrder,
    this.allocationMethod,
    this.allocationValue,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    map['name'] = Variable<String>(name);
    map['icon_key'] = Variable<String>(iconKey);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    if (!nullToAbsent || allocationMethod != null) {
      map['allocation_method'] = Variable<String>(
        $ExpenseControlItemsTable.$converterallocationMethodn.toSql(
          allocationMethod,
        ),
      );
    }
    if (!nullToAbsent || allocationValue != null) {
      map['allocation_value'] = Variable<double>(allocationValue);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  ExpenseControlItemsCompanion toCompanion(bool nullToAbsent) {
    return ExpenseControlItemsCompanion(
      id: Value(id),
      userId: Value(userId),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      name: Value(name),
      iconKey: Value(iconKey),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      sortOrder: Value(sortOrder),
      allocationMethod: allocationMethod == null && nullToAbsent
          ? const Value.absent()
          : Value(allocationMethod),
      allocationValue: allocationValue == null && nullToAbsent
          ? const Value.absent()
          : Value(allocationValue),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory ExpenseControlItemRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExpenseControlItemRow(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      parentId: serializer.fromJson<String?>(json['parentId']),
      name: serializer.fromJson<String>(json['name']),
      iconKey: serializer.fromJson<String>(json['iconKey']),
      description: serializer.fromJson<String?>(json['description']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      allocationMethod: $ExpenseControlItemsTable.$converterallocationMethodn
          .fromJson(serializer.fromJson<String?>(json['allocationMethod'])),
      allocationValue: serializer.fromJson<double?>(json['allocationValue']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'parentId': serializer.toJson<String?>(parentId),
      'name': serializer.toJson<String>(name),
      'iconKey': serializer.toJson<String>(iconKey),
      'description': serializer.toJson<String?>(description),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'allocationMethod': serializer.toJson<String?>(
        $ExpenseControlItemsTable.$converterallocationMethodn.toJson(
          allocationMethod,
        ),
      ),
      'allocationValue': serializer.toJson<double?>(allocationValue),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  ExpenseControlItemRow copyWith({
    String? id,
    String? userId,
    Value<String?> parentId = const Value.absent(),
    String? name,
    String? iconKey,
    Value<String?> description = const Value.absent(),
    int? sortOrder,
    Value<ExpenseAllocationMethod?> allocationMethod = const Value.absent(),
    Value<double?> allocationValue = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => ExpenseControlItemRow(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    parentId: parentId.present ? parentId.value : this.parentId,
    name: name ?? this.name,
    iconKey: iconKey ?? this.iconKey,
    description: description.present ? description.value : this.description,
    sortOrder: sortOrder ?? this.sortOrder,
    allocationMethod: allocationMethod.present
        ? allocationMethod.value
        : this.allocationMethod,
    allocationValue: allocationValue.present
        ? allocationValue.value
        : this.allocationValue,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  ExpenseControlItemRow copyWithCompanion(ExpenseControlItemsCompanion data) {
    return ExpenseControlItemRow(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      name: data.name.present ? data.name.value : this.name,
      iconKey: data.iconKey.present ? data.iconKey.value : this.iconKey,
      description: data.description.present
          ? data.description.value
          : this.description,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      allocationMethod: data.allocationMethod.present
          ? data.allocationMethod.value
          : this.allocationMethod,
      allocationValue: data.allocationValue.present
          ? data.allocationValue.value
          : this.allocationValue,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExpenseControlItemRow(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('parentId: $parentId, ')
          ..write('name: $name, ')
          ..write('iconKey: $iconKey, ')
          ..write('description: $description, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('allocationMethod: $allocationMethod, ')
          ..write('allocationValue: $allocationValue, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    parentId,
    name,
    iconKey,
    description,
    sortOrder,
    allocationMethod,
    allocationValue,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExpenseControlItemRow &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.parentId == this.parentId &&
          other.name == this.name &&
          other.iconKey == this.iconKey &&
          other.description == this.description &&
          other.sortOrder == this.sortOrder &&
          other.allocationMethod == this.allocationMethod &&
          other.allocationValue == this.allocationValue &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class ExpenseControlItemsCompanion
    extends UpdateCompanion<ExpenseControlItemRow> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String?> parentId;
  final Value<String> name;
  final Value<String> iconKey;
  final Value<String?> description;
  final Value<int> sortOrder;
  final Value<ExpenseAllocationMethod?> allocationMethod;
  final Value<double?> allocationValue;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const ExpenseControlItemsCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.parentId = const Value.absent(),
    this.name = const Value.absent(),
    this.iconKey = const Value.absent(),
    this.description = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.allocationMethod = const Value.absent(),
    this.allocationValue = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ExpenseControlItemsCompanion.insert({
    required String id,
    required String userId,
    this.parentId = const Value.absent(),
    required String name,
    required String iconKey,
    this.description = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.allocationMethod = const Value.absent(),
    this.allocationValue = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       userId = Value(userId),
       name = Value(name),
       iconKey = Value(iconKey);
  static Insertable<ExpenseControlItemRow> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? parentId,
    Expression<String>? name,
    Expression<String>? iconKey,
    Expression<String>? description,
    Expression<int>? sortOrder,
    Expression<String>? allocationMethod,
    Expression<double>? allocationValue,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (parentId != null) 'parent_id': parentId,
      if (name != null) 'name': name,
      if (iconKey != null) 'icon_key': iconKey,
      if (description != null) 'description': description,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (allocationMethod != null) 'allocation_method': allocationMethod,
      if (allocationValue != null) 'allocation_value': allocationValue,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ExpenseControlItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? userId,
    Value<String?>? parentId,
    Value<String>? name,
    Value<String>? iconKey,
    Value<String?>? description,
    Value<int>? sortOrder,
    Value<ExpenseAllocationMethod?>? allocationMethod,
    Value<double?>? allocationValue,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return ExpenseControlItemsCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      parentId: parentId ?? this.parentId,
      name: name ?? this.name,
      iconKey: iconKey ?? this.iconKey,
      description: description ?? this.description,
      sortOrder: sortOrder ?? this.sortOrder,
      allocationMethod: allocationMethod ?? this.allocationMethod,
      allocationValue: allocationValue ?? this.allocationValue,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (iconKey.present) {
      map['icon_key'] = Variable<String>(iconKey.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (allocationMethod.present) {
      map['allocation_method'] = Variable<String>(
        $ExpenseControlItemsTable.$converterallocationMethodn.toSql(
          allocationMethod.value,
        ),
      );
    }
    if (allocationValue.present) {
      map['allocation_value'] = Variable<double>(allocationValue.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExpenseControlItemsCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('parentId: $parentId, ')
          ..write('name: $name, ')
          ..write('iconKey: $iconKey, ')
          ..write('description: $description, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('allocationMethod: $allocationMethod, ')
          ..write('allocationValue: $allocationValue, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncOutboxTable extends SyncOutbox
    with TableInfo<$SyncOutboxTable, SyncOutboxRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncOutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityTableMeta = const VerificationMeta(
    'entityTable',
  );
  @override
  late final GeneratedColumn<String> entityTable = GeneratedColumn<String>(
    'entity_table',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rowIdMeta = const VerificationMeta('rowId');
  @override
  late final GeneratedColumn<String> rowId = GeneratedColumn<String>(
    'row_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<SyncOperation, String> operation =
      GeneratedColumn<String>(
        'operation',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<SyncOperation>($SyncOutboxTable.$converteroperation);
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _retryCountMeta = const VerificationMeta(
    'retryCount',
  );
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
    'retry_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    entityTable,
    rowId,
    operation,
    payload,
    syncedAt,
    retryCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncOutboxRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('entity_table')) {
      context.handle(
        _entityTableMeta,
        entityTable.isAcceptableOrUnknown(
          data['entity_table']!,
          _entityTableMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_entityTableMeta);
    }
    if (data.containsKey('row_id')) {
      context.handle(
        _rowIdMeta,
        rowId.isAcceptableOrUnknown(data['row_id']!, _rowIdMeta),
      );
    } else if (isInserting) {
      context.missing(_rowIdMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    if (data.containsKey('retry_count')) {
      context.handle(
        _retryCountMeta,
        retryCount.isAcceptableOrUnknown(data['retry_count']!, _retryCountMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncOutboxRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncOutboxRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      entityTable: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_table'],
      )!,
      rowId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}row_id'],
      )!,
      operation: $SyncOutboxTable.$converteroperation.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}operation'],
        )!,
      ),
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      ),
      retryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_count'],
      )!,
    );
  }

  @override
  $SyncOutboxTable createAlias(String alias) {
    return $SyncOutboxTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<SyncOperation, String, String> $converteroperation =
      const EnumNameConverter<SyncOperation>(SyncOperation.values);
}

class SyncOutboxRow extends DataClass implements Insertable<SyncOutboxRow> {
  final String id;
  final String entityTable;
  final String rowId;
  final SyncOperation operation;
  final String payload;
  final DateTime? syncedAt;
  final int retryCount;
  const SyncOutboxRow({
    required this.id,
    required this.entityTable,
    required this.rowId,
    required this.operation,
    required this.payload,
    this.syncedAt,
    required this.retryCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['entity_table'] = Variable<String>(entityTable);
    map['row_id'] = Variable<String>(rowId);
    {
      map['operation'] = Variable<String>(
        $SyncOutboxTable.$converteroperation.toSql(operation),
      );
    }
    map['payload'] = Variable<String>(payload);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    map['retry_count'] = Variable<int>(retryCount);
    return map;
  }

  SyncOutboxCompanion toCompanion(bool nullToAbsent) {
    return SyncOutboxCompanion(
      id: Value(id),
      entityTable: Value(entityTable),
      rowId: Value(rowId),
      operation: Value(operation),
      payload: Value(payload),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
      retryCount: Value(retryCount),
    );
  }

  factory SyncOutboxRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncOutboxRow(
      id: serializer.fromJson<String>(json['id']),
      entityTable: serializer.fromJson<String>(json['entityTable']),
      rowId: serializer.fromJson<String>(json['rowId']),
      operation: $SyncOutboxTable.$converteroperation.fromJson(
        serializer.fromJson<String>(json['operation']),
      ),
      payload: serializer.fromJson<String>(json['payload']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'entityTable': serializer.toJson<String>(entityTable),
      'rowId': serializer.toJson<String>(rowId),
      'operation': serializer.toJson<String>(
        $SyncOutboxTable.$converteroperation.toJson(operation),
      ),
      'payload': serializer.toJson<String>(payload),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
      'retryCount': serializer.toJson<int>(retryCount),
    };
  }

  SyncOutboxRow copyWith({
    String? id,
    String? entityTable,
    String? rowId,
    SyncOperation? operation,
    String? payload,
    Value<DateTime?> syncedAt = const Value.absent(),
    int? retryCount,
  }) => SyncOutboxRow(
    id: id ?? this.id,
    entityTable: entityTable ?? this.entityTable,
    rowId: rowId ?? this.rowId,
    operation: operation ?? this.operation,
    payload: payload ?? this.payload,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
    retryCount: retryCount ?? this.retryCount,
  );
  SyncOutboxRow copyWithCompanion(SyncOutboxCompanion data) {
    return SyncOutboxRow(
      id: data.id.present ? data.id.value : this.id,
      entityTable: data.entityTable.present
          ? data.entityTable.value
          : this.entityTable,
      rowId: data.rowId.present ? data.rowId.value : this.rowId,
      operation: data.operation.present ? data.operation.value : this.operation,
      payload: data.payload.present ? data.payload.value : this.payload,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncOutboxRow(')
          ..write('id: $id, ')
          ..write('entityTable: $entityTable, ')
          ..write('rowId: $rowId, ')
          ..write('operation: $operation, ')
          ..write('payload: $payload, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('retryCount: $retryCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    entityTable,
    rowId,
    operation,
    payload,
    syncedAt,
    retryCount,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncOutboxRow &&
          other.id == this.id &&
          other.entityTable == this.entityTable &&
          other.rowId == this.rowId &&
          other.operation == this.operation &&
          other.payload == this.payload &&
          other.syncedAt == this.syncedAt &&
          other.retryCount == this.retryCount);
}

class SyncOutboxCompanion extends UpdateCompanion<SyncOutboxRow> {
  final Value<String> id;
  final Value<String> entityTable;
  final Value<String> rowId;
  final Value<SyncOperation> operation;
  final Value<String> payload;
  final Value<DateTime?> syncedAt;
  final Value<int> retryCount;
  final Value<int> rowid;
  const SyncOutboxCompanion({
    this.id = const Value.absent(),
    this.entityTable = const Value.absent(),
    this.rowId = const Value.absent(),
    this.operation = const Value.absent(),
    this.payload = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncOutboxCompanion.insert({
    required String id,
    required String entityTable,
    required String rowId,
    required SyncOperation operation,
    required String payload,
    this.syncedAt = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       entityTable = Value(entityTable),
       rowId = Value(rowId),
       operation = Value(operation),
       payload = Value(payload);
  static Insertable<SyncOutboxRow> custom({
    Expression<String>? id,
    Expression<String>? entityTable,
    Expression<String>? rowId,
    Expression<String>? operation,
    Expression<String>? payload,
    Expression<DateTime>? syncedAt,
    Expression<int>? retryCount,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entityTable != null) 'entity_table': entityTable,
      if (rowId != null) 'row_id': rowId,
      if (operation != null) 'operation': operation,
      if (payload != null) 'payload': payload,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (retryCount != null) 'retry_count': retryCount,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncOutboxCompanion copyWith({
    Value<String>? id,
    Value<String>? entityTable,
    Value<String>? rowId,
    Value<SyncOperation>? operation,
    Value<String>? payload,
    Value<DateTime?>? syncedAt,
    Value<int>? retryCount,
    Value<int>? rowid,
  }) {
    return SyncOutboxCompanion(
      id: id ?? this.id,
      entityTable: entityTable ?? this.entityTable,
      rowId: rowId ?? this.rowId,
      operation: operation ?? this.operation,
      payload: payload ?? this.payload,
      syncedAt: syncedAt ?? this.syncedAt,
      retryCount: retryCount ?? this.retryCount,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (entityTable.present) {
      map['entity_table'] = Variable<String>(entityTable.value);
    }
    if (rowId.present) {
      map['row_id'] = Variable<String>(rowId.value);
    }
    if (operation.present) {
      map['operation'] = Variable<String>(
        $SyncOutboxTable.$converteroperation.toSql(operation.value),
      );
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncOutboxCompanion(')
          ..write('id: $id, ')
          ..write('entityTable: $entityTable, ')
          ..write('rowId: $rowId, ')
          ..write('operation: $operation, ')
          ..write('payload: $payload, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('retryCount: $retryCount, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $EnvelopesTable envelopes = $EnvelopesTable(this);
  late final $AllocationEventsTable allocationEvents = $AllocationEventsTable(
    this,
  );
  late final $AllocationEventLinesTable allocationEventLines =
      $AllocationEventLinesTable(this);
  late final $ExpenseEntriesTable expenseEntries = $ExpenseEntriesTable(this);
  late final $EnvelopeCoveragesTable envelopeCoverages =
      $EnvelopeCoveragesTable(this);
  late final $ExpenseControlItemsTable expenseControlItems =
      $ExpenseControlItemsTable(this);
  late final $SyncOutboxTable syncOutbox = $SyncOutboxTable(this);
  late final Index envelopesUserIdIdx = Index(
    'envelopes_user_id_idx',
    'CREATE INDEX envelopes_user_id_idx ON envelopes (user_id)',
  );
  late final Index allocationEventsUserIdIdx = Index(
    'allocation_events_user_id_idx',
    'CREATE INDEX allocation_events_user_id_idx ON allocation_events (user_id)',
  );
  late final Index allocationEventLinesUserIdIdx = Index(
    'allocation_event_lines_user_id_idx',
    'CREATE INDEX allocation_event_lines_user_id_idx ON allocation_event_lines (user_id)',
  );
  late final Index allocationEventLinesEnvelopeIdIdx = Index(
    'allocation_event_lines_envelope_id_idx',
    'CREATE INDEX allocation_event_lines_envelope_id_idx ON allocation_event_lines (envelope_id)',
  );
  late final Index expenseEntriesUserIdIdx = Index(
    'expense_entries_user_id_idx',
    'CREATE INDEX expense_entries_user_id_idx ON expense_entries (user_id)',
  );
  late final Index expenseEntriesEnvelopeIdIdx = Index(
    'expense_entries_envelope_id_idx',
    'CREATE INDEX expense_entries_envelope_id_idx ON expense_entries (envelope_id)',
  );
  late final Index envelopeCoveragesUserIdIdx = Index(
    'envelope_coverages_user_id_idx',
    'CREATE INDEX envelope_coverages_user_id_idx ON envelope_coverages (user_id)',
  );
  late final Index envelopeCoveragesSourceEnvelopeIdIdx = Index(
    'envelope_coverages_source_envelope_id_idx',
    'CREATE INDEX envelope_coverages_source_envelope_id_idx ON envelope_coverages (source_envelope_id)',
  );
  late final Index envelopeCoveragesCoveringEnvelopeIdIdx = Index(
    'envelope_coverages_covering_envelope_id_idx',
    'CREATE INDEX envelope_coverages_covering_envelope_id_idx ON envelope_coverages (covering_envelope_id)',
  );
  late final Index expenseControlItemsUserIdIdx = Index(
    'expense_control_items_user_id_idx',
    'CREATE INDEX expense_control_items_user_id_idx ON expense_control_items (user_id)',
  );
  late final Index syncOutboxUnsyncedIdx = Index(
    'sync_outbox_unsynced_idx',
    'CREATE INDEX sync_outbox_unsynced_idx ON sync_outbox (synced_at) WHERE synced_at IS NULL',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    envelopes,
    allocationEvents,
    allocationEventLines,
    expenseEntries,
    envelopeCoverages,
    expenseControlItems,
    syncOutbox,
    envelopesUserIdIdx,
    allocationEventsUserIdIdx,
    allocationEventLinesUserIdIdx,
    allocationEventLinesEnvelopeIdIdx,
    expenseEntriesUserIdIdx,
    expenseEntriesEnvelopeIdIdx,
    envelopeCoveragesUserIdIdx,
    envelopeCoveragesSourceEnvelopeIdIdx,
    envelopeCoveragesCoveringEnvelopeIdIdx,
    expenseControlItemsUserIdIdx,
    syncOutboxUnsyncedIdx,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'expense_entries',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('envelope_coverages', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$EnvelopesTableCreateCompanionBuilder =
    EnvelopesCompanion Function({
      required String id,
      required String userId,
      required String name,
      required AllocationMethod allocationMethod,
      required double allocationValue,
      Value<int> balance,
      Value<bool> isRoundingReceiver,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$EnvelopesTableUpdateCompanionBuilder =
    EnvelopesCompanion Function({
      Value<String> id,
      Value<String> userId,
      Value<String> name,
      Value<AllocationMethod> allocationMethod,
      Value<double> allocationValue,
      Value<int> balance,
      Value<bool> isRoundingReceiver,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

final class $$EnvelopesTableReferences
    extends BaseReferences<_$AppDatabase, $EnvelopesTable, EnvelopeRow> {
  $$EnvelopesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<
    $AllocationEventLinesTable,
    List<AllocationEventLineRow>
  >
  _allocationEventLinesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.allocationEventLines,
        aliasName: $_aliasNameGenerator(
          db.envelopes.id,
          db.allocationEventLines.envelopeId,
        ),
      );

  $$AllocationEventLinesTableProcessedTableManager
  get allocationEventLinesRefs {
    final manager = $$AllocationEventLinesTableTableManager(
      $_db,
      $_db.allocationEventLines,
    ).filter((f) => f.envelopeId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _allocationEventLinesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ExpenseEntriesTable, List<ExpenseEntryRow>>
  _expenseEntriesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.expenseEntries,
    aliasName: $_aliasNameGenerator(
      db.envelopes.id,
      db.expenseEntries.envelopeId,
    ),
  );

  $$ExpenseEntriesTableProcessedTableManager get expenseEntriesRefs {
    final manager = $$ExpenseEntriesTableTableManager(
      $_db,
      $_db.expenseEntries,
    ).filter((f) => f.envelopeId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_expenseEntriesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$EnvelopeCoveragesTable, List<EnvelopeCoverageRow>>
  _coveragesAsSourceTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.envelopeCoverages,
    aliasName: $_aliasNameGenerator(
      db.envelopes.id,
      db.envelopeCoverages.sourceEnvelopeId,
    ),
  );

  $$EnvelopeCoveragesTableProcessedTableManager get coveragesAsSource {
    final manager =
        $$EnvelopeCoveragesTableTableManager(
          $_db,
          $_db.envelopeCoverages,
        ).filter(
          (f) => f.sourceEnvelopeId.id.sqlEquals($_itemColumn<String>('id')!),
        );

    final cache = $_typedResult.readTableOrNull(_coveragesAsSourceTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$EnvelopeCoveragesTable, List<EnvelopeCoverageRow>>
  _coveragesAsCovererTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.envelopeCoverages,
    aliasName: $_aliasNameGenerator(
      db.envelopes.id,
      db.envelopeCoverages.coveringEnvelopeId,
    ),
  );

  $$EnvelopeCoveragesTableProcessedTableManager get coveragesAsCoverer {
    final manager =
        $$EnvelopeCoveragesTableTableManager(
          $_db,
          $_db.envelopeCoverages,
        ).filter(
          (f) => f.coveringEnvelopeId.id.sqlEquals($_itemColumn<String>('id')!),
        );

    final cache = $_typedResult.readTableOrNull(_coveragesAsCovererTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$EnvelopesTableFilterComposer
    extends Composer<_$AppDatabase, $EnvelopesTable> {
  $$EnvelopesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<AllocationMethod, AllocationMethod, String>
  get allocationMethod => $composableBuilder(
    column: $table.allocationMethod,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<double> get allocationValue => $composableBuilder(
    column: $table.allocationValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get balance => $composableBuilder(
    column: $table.balance,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isRoundingReceiver => $composableBuilder(
    column: $table.isRoundingReceiver,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> allocationEventLinesRefs(
    Expression<bool> Function($$AllocationEventLinesTableFilterComposer f) f,
  ) {
    final $$AllocationEventLinesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.allocationEventLines,
      getReferencedColumn: (t) => t.envelopeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AllocationEventLinesTableFilterComposer(
            $db: $db,
            $table: $db.allocationEventLines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> expenseEntriesRefs(
    Expression<bool> Function($$ExpenseEntriesTableFilterComposer f) f,
  ) {
    final $$ExpenseEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.expenseEntries,
      getReferencedColumn: (t) => t.envelopeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExpenseEntriesTableFilterComposer(
            $db: $db,
            $table: $db.expenseEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> coveragesAsSource(
    Expression<bool> Function($$EnvelopeCoveragesTableFilterComposer f) f,
  ) {
    final $$EnvelopeCoveragesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.envelopeCoverages,
      getReferencedColumn: (t) => t.sourceEnvelopeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EnvelopeCoveragesTableFilterComposer(
            $db: $db,
            $table: $db.envelopeCoverages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> coveragesAsCoverer(
    Expression<bool> Function($$EnvelopeCoveragesTableFilterComposer f) f,
  ) {
    final $$EnvelopeCoveragesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.envelopeCoverages,
      getReferencedColumn: (t) => t.coveringEnvelopeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EnvelopeCoveragesTableFilterComposer(
            $db: $db,
            $table: $db.envelopeCoverages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$EnvelopesTableOrderingComposer
    extends Composer<_$AppDatabase, $EnvelopesTable> {
  $$EnvelopesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get allocationMethod => $composableBuilder(
    column: $table.allocationMethod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get allocationValue => $composableBuilder(
    column: $table.allocationValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get balance => $composableBuilder(
    column: $table.balance,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isRoundingReceiver => $composableBuilder(
    column: $table.isRoundingReceiver,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EnvelopesTableAnnotationComposer
    extends Composer<_$AppDatabase, $EnvelopesTable> {
  $$EnvelopesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumnWithTypeConverter<AllocationMethod, String>
  get allocationMethod => $composableBuilder(
    column: $table.allocationMethod,
    builder: (column) => column,
  );

  GeneratedColumn<double> get allocationValue => $composableBuilder(
    column: $table.allocationValue,
    builder: (column) => column,
  );

  GeneratedColumn<int> get balance =>
      $composableBuilder(column: $table.balance, builder: (column) => column);

  GeneratedColumn<bool> get isRoundingReceiver => $composableBuilder(
    column: $table.isRoundingReceiver,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  Expression<T> allocationEventLinesRefs<T extends Object>(
    Expression<T> Function($$AllocationEventLinesTableAnnotationComposer a) f,
  ) {
    final $$AllocationEventLinesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.allocationEventLines,
          getReferencedColumn: (t) => t.envelopeId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$AllocationEventLinesTableAnnotationComposer(
                $db: $db,
                $table: $db.allocationEventLines,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> expenseEntriesRefs<T extends Object>(
    Expression<T> Function($$ExpenseEntriesTableAnnotationComposer a) f,
  ) {
    final $$ExpenseEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.expenseEntries,
      getReferencedColumn: (t) => t.envelopeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExpenseEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.expenseEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> coveragesAsSource<T extends Object>(
    Expression<T> Function($$EnvelopeCoveragesTableAnnotationComposer a) f,
  ) {
    final $$EnvelopeCoveragesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.envelopeCoverages,
          getReferencedColumn: (t) => t.sourceEnvelopeId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$EnvelopeCoveragesTableAnnotationComposer(
                $db: $db,
                $table: $db.envelopeCoverages,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> coveragesAsCoverer<T extends Object>(
    Expression<T> Function($$EnvelopeCoveragesTableAnnotationComposer a) f,
  ) {
    final $$EnvelopeCoveragesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.envelopeCoverages,
          getReferencedColumn: (t) => t.coveringEnvelopeId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$EnvelopeCoveragesTableAnnotationComposer(
                $db: $db,
                $table: $db.envelopeCoverages,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$EnvelopesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EnvelopesTable,
          EnvelopeRow,
          $$EnvelopesTableFilterComposer,
          $$EnvelopesTableOrderingComposer,
          $$EnvelopesTableAnnotationComposer,
          $$EnvelopesTableCreateCompanionBuilder,
          $$EnvelopesTableUpdateCompanionBuilder,
          (EnvelopeRow, $$EnvelopesTableReferences),
          EnvelopeRow,
          PrefetchHooks Function({
            bool allocationEventLinesRefs,
            bool expenseEntriesRefs,
            bool coveragesAsSource,
            bool coveragesAsCoverer,
          })
        > {
  $$EnvelopesTableTableManager(_$AppDatabase db, $EnvelopesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EnvelopesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EnvelopesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EnvelopesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<AllocationMethod> allocationMethod = const Value.absent(),
                Value<double> allocationValue = const Value.absent(),
                Value<int> balance = const Value.absent(),
                Value<bool> isRoundingReceiver = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EnvelopesCompanion(
                id: id,
                userId: userId,
                name: name,
                allocationMethod: allocationMethod,
                allocationValue: allocationValue,
                balance: balance,
                isRoundingReceiver: isRoundingReceiver,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String userId,
                required String name,
                required AllocationMethod allocationMethod,
                required double allocationValue,
                Value<int> balance = const Value.absent(),
                Value<bool> isRoundingReceiver = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EnvelopesCompanion.insert(
                id: id,
                userId: userId,
                name: name,
                allocationMethod: allocationMethod,
                allocationValue: allocationValue,
                balance: balance,
                isRoundingReceiver: isRoundingReceiver,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$EnvelopesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                allocationEventLinesRefs = false,
                expenseEntriesRefs = false,
                coveragesAsSource = false,
                coveragesAsCoverer = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (allocationEventLinesRefs) db.allocationEventLines,
                    if (expenseEntriesRefs) db.expenseEntries,
                    if (coveragesAsSource) db.envelopeCoverages,
                    if (coveragesAsCoverer) db.envelopeCoverages,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (allocationEventLinesRefs)
                        await $_getPrefetchedData<
                          EnvelopeRow,
                          $EnvelopesTable,
                          AllocationEventLineRow
                        >(
                          currentTable: table,
                          referencedTable: $$EnvelopesTableReferences
                              ._allocationEventLinesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$EnvelopesTableReferences(
                                db,
                                table,
                                p0,
                              ).allocationEventLinesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.envelopeId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (expenseEntriesRefs)
                        await $_getPrefetchedData<
                          EnvelopeRow,
                          $EnvelopesTable,
                          ExpenseEntryRow
                        >(
                          currentTable: table,
                          referencedTable: $$EnvelopesTableReferences
                              ._expenseEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$EnvelopesTableReferences(
                                db,
                                table,
                                p0,
                              ).expenseEntriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.envelopeId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (coveragesAsSource)
                        await $_getPrefetchedData<
                          EnvelopeRow,
                          $EnvelopesTable,
                          EnvelopeCoverageRow
                        >(
                          currentTable: table,
                          referencedTable: $$EnvelopesTableReferences
                              ._coveragesAsSourceTable(db),
                          managerFromTypedResult: (p0) =>
                              $$EnvelopesTableReferences(
                                db,
                                table,
                                p0,
                              ).coveragesAsSource,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sourceEnvelopeId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (coveragesAsCoverer)
                        await $_getPrefetchedData<
                          EnvelopeRow,
                          $EnvelopesTable,
                          EnvelopeCoverageRow
                        >(
                          currentTable: table,
                          referencedTable: $$EnvelopesTableReferences
                              ._coveragesAsCovererTable(db),
                          managerFromTypedResult: (p0) =>
                              $$EnvelopesTableReferences(
                                db,
                                table,
                                p0,
                              ).coveragesAsCoverer,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.coveringEnvelopeId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$EnvelopesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EnvelopesTable,
      EnvelopeRow,
      $$EnvelopesTableFilterComposer,
      $$EnvelopesTableOrderingComposer,
      $$EnvelopesTableAnnotationComposer,
      $$EnvelopesTableCreateCompanionBuilder,
      $$EnvelopesTableUpdateCompanionBuilder,
      (EnvelopeRow, $$EnvelopesTableReferences),
      EnvelopeRow,
      PrefetchHooks Function({
        bool allocationEventLinesRefs,
        bool expenseEntriesRefs,
        bool coveragesAsSource,
        bool coveragesAsCoverer,
      })
    >;
typedef $$AllocationEventsTableCreateCompanionBuilder =
    AllocationEventsCompanion Function({
      required String id,
      required String userId,
      Value<DateTime> eventDate,
      required int incomeAmount,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$AllocationEventsTableUpdateCompanionBuilder =
    AllocationEventsCompanion Function({
      Value<String> id,
      Value<String> userId,
      Value<DateTime> eventDate,
      Value<int> incomeAmount,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

final class $$AllocationEventsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $AllocationEventsTable,
          AllocationEventRow
        > {
  $$AllocationEventsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<
    $AllocationEventLinesTable,
    List<AllocationEventLineRow>
  >
  _allocationEventLinesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.allocationEventLines,
        aliasName: $_aliasNameGenerator(
          db.allocationEvents.id,
          db.allocationEventLines.allocationEventId,
        ),
      );

  $$AllocationEventLinesTableProcessedTableManager
  get allocationEventLinesRefs {
    final manager =
        $$AllocationEventLinesTableTableManager(
          $_db,
          $_db.allocationEventLines,
        ).filter(
          (f) => f.allocationEventId.id.sqlEquals($_itemColumn<String>('id')!),
        );

    final cache = $_typedResult.readTableOrNull(
      _allocationEventLinesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$AllocationEventsTableFilterComposer
    extends Composer<_$AppDatabase, $AllocationEventsTable> {
  $$AllocationEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get eventDate => $composableBuilder(
    column: $table.eventDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get incomeAmount => $composableBuilder(
    column: $table.incomeAmount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> allocationEventLinesRefs(
    Expression<bool> Function($$AllocationEventLinesTableFilterComposer f) f,
  ) {
    final $$AllocationEventLinesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.allocationEventLines,
      getReferencedColumn: (t) => t.allocationEventId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AllocationEventLinesTableFilterComposer(
            $db: $db,
            $table: $db.allocationEventLines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AllocationEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $AllocationEventsTable> {
  $$AllocationEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get eventDate => $composableBuilder(
    column: $table.eventDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get incomeAmount => $composableBuilder(
    column: $table.incomeAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AllocationEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AllocationEventsTable> {
  $$AllocationEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<DateTime> get eventDate =>
      $composableBuilder(column: $table.eventDate, builder: (column) => column);

  GeneratedColumn<int> get incomeAmount => $composableBuilder(
    column: $table.incomeAmount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  Expression<T> allocationEventLinesRefs<T extends Object>(
    Expression<T> Function($$AllocationEventLinesTableAnnotationComposer a) f,
  ) {
    final $$AllocationEventLinesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.allocationEventLines,
          getReferencedColumn: (t) => t.allocationEventId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$AllocationEventLinesTableAnnotationComposer(
                $db: $db,
                $table: $db.allocationEventLines,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$AllocationEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AllocationEventsTable,
          AllocationEventRow,
          $$AllocationEventsTableFilterComposer,
          $$AllocationEventsTableOrderingComposer,
          $$AllocationEventsTableAnnotationComposer,
          $$AllocationEventsTableCreateCompanionBuilder,
          $$AllocationEventsTableUpdateCompanionBuilder,
          (AllocationEventRow, $$AllocationEventsTableReferences),
          AllocationEventRow,
          PrefetchHooks Function({bool allocationEventLinesRefs})
        > {
  $$AllocationEventsTableTableManager(
    _$AppDatabase db,
    $AllocationEventsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AllocationEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AllocationEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AllocationEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<DateTime> eventDate = const Value.absent(),
                Value<int> incomeAmount = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AllocationEventsCompanion(
                id: id,
                userId: userId,
                eventDate: eventDate,
                incomeAmount: incomeAmount,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String userId,
                Value<DateTime> eventDate = const Value.absent(),
                required int incomeAmount,
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AllocationEventsCompanion.insert(
                id: id,
                userId: userId,
                eventDate: eventDate,
                incomeAmount: incomeAmount,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AllocationEventsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({allocationEventLinesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (allocationEventLinesRefs) db.allocationEventLines,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (allocationEventLinesRefs)
                    await $_getPrefetchedData<
                      AllocationEventRow,
                      $AllocationEventsTable,
                      AllocationEventLineRow
                    >(
                      currentTable: table,
                      referencedTable: $$AllocationEventsTableReferences
                          ._allocationEventLinesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$AllocationEventsTableReferences(
                            db,
                            table,
                            p0,
                          ).allocationEventLinesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.allocationEventId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$AllocationEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AllocationEventsTable,
      AllocationEventRow,
      $$AllocationEventsTableFilterComposer,
      $$AllocationEventsTableOrderingComposer,
      $$AllocationEventsTableAnnotationComposer,
      $$AllocationEventsTableCreateCompanionBuilder,
      $$AllocationEventsTableUpdateCompanionBuilder,
      (AllocationEventRow, $$AllocationEventsTableReferences),
      AllocationEventRow,
      PrefetchHooks Function({bool allocationEventLinesRefs})
    >;
typedef $$AllocationEventLinesTableCreateCompanionBuilder =
    AllocationEventLinesCompanion Function({
      required String id,
      required String userId,
      required String allocationEventId,
      required String envelopeId,
      required int amount,
      Value<bool> isRoundingRemainderLine,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$AllocationEventLinesTableUpdateCompanionBuilder =
    AllocationEventLinesCompanion Function({
      Value<String> id,
      Value<String> userId,
      Value<String> allocationEventId,
      Value<String> envelopeId,
      Value<int> amount,
      Value<bool> isRoundingRemainderLine,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

final class $$AllocationEventLinesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $AllocationEventLinesTable,
          AllocationEventLineRow
        > {
  $$AllocationEventLinesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $AllocationEventsTable _allocationEventIdTable(_$AppDatabase db) =>
      db.allocationEvents.createAlias(
        $_aliasNameGenerator(
          db.allocationEventLines.allocationEventId,
          db.allocationEvents.id,
        ),
      );

  $$AllocationEventsTableProcessedTableManager get allocationEventId {
    final $_column = $_itemColumn<String>('allocation_event_id')!;

    final manager = $$AllocationEventsTableTableManager(
      $_db,
      $_db.allocationEvents,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_allocationEventIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $EnvelopesTable _envelopeIdTable(_$AppDatabase db) =>
      db.envelopes.createAlias(
        $_aliasNameGenerator(
          db.allocationEventLines.envelopeId,
          db.envelopes.id,
        ),
      );

  $$EnvelopesTableProcessedTableManager get envelopeId {
    final $_column = $_itemColumn<String>('envelope_id')!;

    final manager = $$EnvelopesTableTableManager(
      $_db,
      $_db.envelopes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_envelopeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AllocationEventLinesTableFilterComposer
    extends Composer<_$AppDatabase, $AllocationEventLinesTable> {
  $$AllocationEventLinesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isRoundingRemainderLine => $composableBuilder(
    column: $table.isRoundingRemainderLine,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$AllocationEventsTableFilterComposer get allocationEventId {
    final $$AllocationEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.allocationEventId,
      referencedTable: $db.allocationEvents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AllocationEventsTableFilterComposer(
            $db: $db,
            $table: $db.allocationEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$EnvelopesTableFilterComposer get envelopeId {
    final $$EnvelopesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.envelopeId,
      referencedTable: $db.envelopes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EnvelopesTableFilterComposer(
            $db: $db,
            $table: $db.envelopes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AllocationEventLinesTableOrderingComposer
    extends Composer<_$AppDatabase, $AllocationEventLinesTable> {
  $$AllocationEventLinesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isRoundingRemainderLine => $composableBuilder(
    column: $table.isRoundingRemainderLine,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$AllocationEventsTableOrderingComposer get allocationEventId {
    final $$AllocationEventsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.allocationEventId,
      referencedTable: $db.allocationEvents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AllocationEventsTableOrderingComposer(
            $db: $db,
            $table: $db.allocationEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$EnvelopesTableOrderingComposer get envelopeId {
    final $$EnvelopesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.envelopeId,
      referencedTable: $db.envelopes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EnvelopesTableOrderingComposer(
            $db: $db,
            $table: $db.envelopes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AllocationEventLinesTableAnnotationComposer
    extends Composer<_$AppDatabase, $AllocationEventLinesTable> {
  $$AllocationEventLinesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<int> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<bool> get isRoundingRemainderLine => $composableBuilder(
    column: $table.isRoundingRemainderLine,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  $$AllocationEventsTableAnnotationComposer get allocationEventId {
    final $$AllocationEventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.allocationEventId,
      referencedTable: $db.allocationEvents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AllocationEventsTableAnnotationComposer(
            $db: $db,
            $table: $db.allocationEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$EnvelopesTableAnnotationComposer get envelopeId {
    final $$EnvelopesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.envelopeId,
      referencedTable: $db.envelopes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EnvelopesTableAnnotationComposer(
            $db: $db,
            $table: $db.envelopes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AllocationEventLinesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AllocationEventLinesTable,
          AllocationEventLineRow,
          $$AllocationEventLinesTableFilterComposer,
          $$AllocationEventLinesTableOrderingComposer,
          $$AllocationEventLinesTableAnnotationComposer,
          $$AllocationEventLinesTableCreateCompanionBuilder,
          $$AllocationEventLinesTableUpdateCompanionBuilder,
          (AllocationEventLineRow, $$AllocationEventLinesTableReferences),
          AllocationEventLineRow,
          PrefetchHooks Function({bool allocationEventId, bool envelopeId})
        > {
  $$AllocationEventLinesTableTableManager(
    _$AppDatabase db,
    $AllocationEventLinesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AllocationEventLinesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AllocationEventLinesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$AllocationEventLinesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> allocationEventId = const Value.absent(),
                Value<String> envelopeId = const Value.absent(),
                Value<int> amount = const Value.absent(),
                Value<bool> isRoundingRemainderLine = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AllocationEventLinesCompanion(
                id: id,
                userId: userId,
                allocationEventId: allocationEventId,
                envelopeId: envelopeId,
                amount: amount,
                isRoundingRemainderLine: isRoundingRemainderLine,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String userId,
                required String allocationEventId,
                required String envelopeId,
                required int amount,
                Value<bool> isRoundingRemainderLine = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AllocationEventLinesCompanion.insert(
                id: id,
                userId: userId,
                allocationEventId: allocationEventId,
                envelopeId: envelopeId,
                amount: amount,
                isRoundingRemainderLine: isRoundingRemainderLine,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AllocationEventLinesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({allocationEventId = false, envelopeId = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (allocationEventId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.allocationEventId,
                                    referencedTable:
                                        $$AllocationEventLinesTableReferences
                                            ._allocationEventIdTable(db),
                                    referencedColumn:
                                        $$AllocationEventLinesTableReferences
                                            ._allocationEventIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (envelopeId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.envelopeId,
                                    referencedTable:
                                        $$AllocationEventLinesTableReferences
                                            ._envelopeIdTable(db),
                                    referencedColumn:
                                        $$AllocationEventLinesTableReferences
                                            ._envelopeIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [];
                  },
                );
              },
        ),
      );
}

typedef $$AllocationEventLinesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AllocationEventLinesTable,
      AllocationEventLineRow,
      $$AllocationEventLinesTableFilterComposer,
      $$AllocationEventLinesTableOrderingComposer,
      $$AllocationEventLinesTableAnnotationComposer,
      $$AllocationEventLinesTableCreateCompanionBuilder,
      $$AllocationEventLinesTableUpdateCompanionBuilder,
      (AllocationEventLineRow, $$AllocationEventLinesTableReferences),
      AllocationEventLineRow,
      PrefetchHooks Function({bool allocationEventId, bool envelopeId})
    >;
typedef $$ExpenseEntriesTableCreateCompanionBuilder =
    ExpenseEntriesCompanion Function({
      required String id,
      required String userId,
      required String envelopeId,
      required int amount,
      required DateTime entryDate,
      Value<String?> note,
      Value<ExpenseEntryMethod> entryMethod,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$ExpenseEntriesTableUpdateCompanionBuilder =
    ExpenseEntriesCompanion Function({
      Value<String> id,
      Value<String> userId,
      Value<String> envelopeId,
      Value<int> amount,
      Value<DateTime> entryDate,
      Value<String?> note,
      Value<ExpenseEntryMethod> entryMethod,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

final class $$ExpenseEntriesTableReferences
    extends
        BaseReferences<_$AppDatabase, $ExpenseEntriesTable, ExpenseEntryRow> {
  $$ExpenseEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $EnvelopesTable _envelopeIdTable(_$AppDatabase db) =>
      db.envelopes.createAlias(
        $_aliasNameGenerator(db.expenseEntries.envelopeId, db.envelopes.id),
      );

  $$EnvelopesTableProcessedTableManager get envelopeId {
    final $_column = $_itemColumn<String>('envelope_id')!;

    final manager = $$EnvelopesTableTableManager(
      $_db,
      $_db.envelopes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_envelopeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$EnvelopeCoveragesTable, List<EnvelopeCoverageRow>>
  _envelopeCoveragesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.envelopeCoverages,
        aliasName: $_aliasNameGenerator(
          db.expenseEntries.id,
          db.envelopeCoverages.expenseEntryId,
        ),
      );

  $$EnvelopeCoveragesTableProcessedTableManager get envelopeCoveragesRefs {
    final manager = $$EnvelopeCoveragesTableTableManager(
      $_db,
      $_db.envelopeCoverages,
    ).filter((f) => f.expenseEntryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _envelopeCoveragesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ExpenseEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $ExpenseEntriesTable> {
  $$ExpenseEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get entryDate => $composableBuilder(
    column: $table.entryDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ExpenseEntryMethod, ExpenseEntryMethod, String>
  get entryMethod => $composableBuilder(
    column: $table.entryMethod,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$EnvelopesTableFilterComposer get envelopeId {
    final $$EnvelopesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.envelopeId,
      referencedTable: $db.envelopes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EnvelopesTableFilterComposer(
            $db: $db,
            $table: $db.envelopes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> envelopeCoveragesRefs(
    Expression<bool> Function($$EnvelopeCoveragesTableFilterComposer f) f,
  ) {
    final $$EnvelopeCoveragesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.envelopeCoverages,
      getReferencedColumn: (t) => t.expenseEntryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EnvelopeCoveragesTableFilterComposer(
            $db: $db,
            $table: $db.envelopeCoverages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ExpenseEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $ExpenseEntriesTable> {
  $$ExpenseEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get entryDate => $composableBuilder(
    column: $table.entryDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entryMethod => $composableBuilder(
    column: $table.entryMethod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$EnvelopesTableOrderingComposer get envelopeId {
    final $$EnvelopesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.envelopeId,
      referencedTable: $db.envelopes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EnvelopesTableOrderingComposer(
            $db: $db,
            $table: $db.envelopes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ExpenseEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExpenseEntriesTable> {
  $$ExpenseEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<int> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<DateTime> get entryDate =>
      $composableBuilder(column: $table.entryDate, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ExpenseEntryMethod, String>
  get entryMethod => $composableBuilder(
    column: $table.entryMethod,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  $$EnvelopesTableAnnotationComposer get envelopeId {
    final $$EnvelopesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.envelopeId,
      referencedTable: $db.envelopes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EnvelopesTableAnnotationComposer(
            $db: $db,
            $table: $db.envelopes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> envelopeCoveragesRefs<T extends Object>(
    Expression<T> Function($$EnvelopeCoveragesTableAnnotationComposer a) f,
  ) {
    final $$EnvelopeCoveragesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.envelopeCoverages,
          getReferencedColumn: (t) => t.expenseEntryId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$EnvelopeCoveragesTableAnnotationComposer(
                $db: $db,
                $table: $db.envelopeCoverages,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$ExpenseEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ExpenseEntriesTable,
          ExpenseEntryRow,
          $$ExpenseEntriesTableFilterComposer,
          $$ExpenseEntriesTableOrderingComposer,
          $$ExpenseEntriesTableAnnotationComposer,
          $$ExpenseEntriesTableCreateCompanionBuilder,
          $$ExpenseEntriesTableUpdateCompanionBuilder,
          (ExpenseEntryRow, $$ExpenseEntriesTableReferences),
          ExpenseEntryRow,
          PrefetchHooks Function({bool envelopeId, bool envelopeCoveragesRefs})
        > {
  $$ExpenseEntriesTableTableManager(
    _$AppDatabase db,
    $ExpenseEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExpenseEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExpenseEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExpenseEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> envelopeId = const Value.absent(),
                Value<int> amount = const Value.absent(),
                Value<DateTime> entryDate = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<ExpenseEntryMethod> entryMethod = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExpenseEntriesCompanion(
                id: id,
                userId: userId,
                envelopeId: envelopeId,
                amount: amount,
                entryDate: entryDate,
                note: note,
                entryMethod: entryMethod,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String userId,
                required String envelopeId,
                required int amount,
                required DateTime entryDate,
                Value<String?> note = const Value.absent(),
                Value<ExpenseEntryMethod> entryMethod = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExpenseEntriesCompanion.insert(
                id: id,
                userId: userId,
                envelopeId: envelopeId,
                amount: amount,
                entryDate: entryDate,
                note: note,
                entryMethod: entryMethod,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ExpenseEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({envelopeId = false, envelopeCoveragesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (envelopeCoveragesRefs) db.envelopeCoverages,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (envelopeId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.envelopeId,
                                    referencedTable:
                                        $$ExpenseEntriesTableReferences
                                            ._envelopeIdTable(db),
                                    referencedColumn:
                                        $$ExpenseEntriesTableReferences
                                            ._envelopeIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (envelopeCoveragesRefs)
                        await $_getPrefetchedData<
                          ExpenseEntryRow,
                          $ExpenseEntriesTable,
                          EnvelopeCoverageRow
                        >(
                          currentTable: table,
                          referencedTable: $$ExpenseEntriesTableReferences
                              ._envelopeCoveragesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ExpenseEntriesTableReferences(
                                db,
                                table,
                                p0,
                              ).envelopeCoveragesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.expenseEntryId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ExpenseEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ExpenseEntriesTable,
      ExpenseEntryRow,
      $$ExpenseEntriesTableFilterComposer,
      $$ExpenseEntriesTableOrderingComposer,
      $$ExpenseEntriesTableAnnotationComposer,
      $$ExpenseEntriesTableCreateCompanionBuilder,
      $$ExpenseEntriesTableUpdateCompanionBuilder,
      (ExpenseEntryRow, $$ExpenseEntriesTableReferences),
      ExpenseEntryRow,
      PrefetchHooks Function({bool envelopeId, bool envelopeCoveragesRefs})
    >;
typedef $$EnvelopeCoveragesTableCreateCompanionBuilder =
    EnvelopeCoveragesCompanion Function({
      required String id,
      required String userId,
      required String expenseEntryId,
      required String sourceEnvelopeId,
      required String coveringEnvelopeId,
      required int amount,
      Value<DateTime> coveredAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$EnvelopeCoveragesTableUpdateCompanionBuilder =
    EnvelopeCoveragesCompanion Function({
      Value<String> id,
      Value<String> userId,
      Value<String> expenseEntryId,
      Value<String> sourceEnvelopeId,
      Value<String> coveringEnvelopeId,
      Value<int> amount,
      Value<DateTime> coveredAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

final class $$EnvelopeCoveragesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $EnvelopeCoveragesTable,
          EnvelopeCoverageRow
        > {
  $$EnvelopeCoveragesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ExpenseEntriesTable _expenseEntryIdTable(_$AppDatabase db) =>
      db.expenseEntries.createAlias(
        $_aliasNameGenerator(
          db.envelopeCoverages.expenseEntryId,
          db.expenseEntries.id,
        ),
      );

  $$ExpenseEntriesTableProcessedTableManager get expenseEntryId {
    final $_column = $_itemColumn<String>('expense_entry_id')!;

    final manager = $$ExpenseEntriesTableTableManager(
      $_db,
      $_db.expenseEntries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_expenseEntryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $EnvelopesTable _sourceEnvelopeIdTable(_$AppDatabase db) =>
      db.envelopes.createAlias(
        $_aliasNameGenerator(
          db.envelopeCoverages.sourceEnvelopeId,
          db.envelopes.id,
        ),
      );

  $$EnvelopesTableProcessedTableManager get sourceEnvelopeId {
    final $_column = $_itemColumn<String>('source_envelope_id')!;

    final manager = $$EnvelopesTableTableManager(
      $_db,
      $_db.envelopes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sourceEnvelopeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $EnvelopesTable _coveringEnvelopeIdTable(_$AppDatabase db) =>
      db.envelopes.createAlias(
        $_aliasNameGenerator(
          db.envelopeCoverages.coveringEnvelopeId,
          db.envelopes.id,
        ),
      );

  $$EnvelopesTableProcessedTableManager get coveringEnvelopeId {
    final $_column = $_itemColumn<String>('covering_envelope_id')!;

    final manager = $$EnvelopesTableTableManager(
      $_db,
      $_db.envelopes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_coveringEnvelopeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$EnvelopeCoveragesTableFilterComposer
    extends Composer<_$AppDatabase, $EnvelopeCoveragesTable> {
  $$EnvelopeCoveragesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get coveredAt => $composableBuilder(
    column: $table.coveredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ExpenseEntriesTableFilterComposer get expenseEntryId {
    final $$ExpenseEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.expenseEntryId,
      referencedTable: $db.expenseEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExpenseEntriesTableFilterComposer(
            $db: $db,
            $table: $db.expenseEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$EnvelopesTableFilterComposer get sourceEnvelopeId {
    final $$EnvelopesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceEnvelopeId,
      referencedTable: $db.envelopes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EnvelopesTableFilterComposer(
            $db: $db,
            $table: $db.envelopes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$EnvelopesTableFilterComposer get coveringEnvelopeId {
    final $$EnvelopesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.coveringEnvelopeId,
      referencedTable: $db.envelopes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EnvelopesTableFilterComposer(
            $db: $db,
            $table: $db.envelopes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EnvelopeCoveragesTableOrderingComposer
    extends Composer<_$AppDatabase, $EnvelopeCoveragesTable> {
  $$EnvelopeCoveragesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get coveredAt => $composableBuilder(
    column: $table.coveredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ExpenseEntriesTableOrderingComposer get expenseEntryId {
    final $$ExpenseEntriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.expenseEntryId,
      referencedTable: $db.expenseEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExpenseEntriesTableOrderingComposer(
            $db: $db,
            $table: $db.expenseEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$EnvelopesTableOrderingComposer get sourceEnvelopeId {
    final $$EnvelopesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceEnvelopeId,
      referencedTable: $db.envelopes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EnvelopesTableOrderingComposer(
            $db: $db,
            $table: $db.envelopes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$EnvelopesTableOrderingComposer get coveringEnvelopeId {
    final $$EnvelopesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.coveringEnvelopeId,
      referencedTable: $db.envelopes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EnvelopesTableOrderingComposer(
            $db: $db,
            $table: $db.envelopes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EnvelopeCoveragesTableAnnotationComposer
    extends Composer<_$AppDatabase, $EnvelopeCoveragesTable> {
  $$EnvelopeCoveragesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<int> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<DateTime> get coveredAt =>
      $composableBuilder(column: $table.coveredAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  $$ExpenseEntriesTableAnnotationComposer get expenseEntryId {
    final $$ExpenseEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.expenseEntryId,
      referencedTable: $db.expenseEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExpenseEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.expenseEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$EnvelopesTableAnnotationComposer get sourceEnvelopeId {
    final $$EnvelopesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceEnvelopeId,
      referencedTable: $db.envelopes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EnvelopesTableAnnotationComposer(
            $db: $db,
            $table: $db.envelopes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$EnvelopesTableAnnotationComposer get coveringEnvelopeId {
    final $$EnvelopesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.coveringEnvelopeId,
      referencedTable: $db.envelopes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EnvelopesTableAnnotationComposer(
            $db: $db,
            $table: $db.envelopes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EnvelopeCoveragesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EnvelopeCoveragesTable,
          EnvelopeCoverageRow,
          $$EnvelopeCoveragesTableFilterComposer,
          $$EnvelopeCoveragesTableOrderingComposer,
          $$EnvelopeCoveragesTableAnnotationComposer,
          $$EnvelopeCoveragesTableCreateCompanionBuilder,
          $$EnvelopeCoveragesTableUpdateCompanionBuilder,
          (EnvelopeCoverageRow, $$EnvelopeCoveragesTableReferences),
          EnvelopeCoverageRow,
          PrefetchHooks Function({
            bool expenseEntryId,
            bool sourceEnvelopeId,
            bool coveringEnvelopeId,
          })
        > {
  $$EnvelopeCoveragesTableTableManager(
    _$AppDatabase db,
    $EnvelopeCoveragesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EnvelopeCoveragesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EnvelopeCoveragesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EnvelopeCoveragesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> expenseEntryId = const Value.absent(),
                Value<String> sourceEnvelopeId = const Value.absent(),
                Value<String> coveringEnvelopeId = const Value.absent(),
                Value<int> amount = const Value.absent(),
                Value<DateTime> coveredAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EnvelopeCoveragesCompanion(
                id: id,
                userId: userId,
                expenseEntryId: expenseEntryId,
                sourceEnvelopeId: sourceEnvelopeId,
                coveringEnvelopeId: coveringEnvelopeId,
                amount: amount,
                coveredAt: coveredAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String userId,
                required String expenseEntryId,
                required String sourceEnvelopeId,
                required String coveringEnvelopeId,
                required int amount,
                Value<DateTime> coveredAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EnvelopeCoveragesCompanion.insert(
                id: id,
                userId: userId,
                expenseEntryId: expenseEntryId,
                sourceEnvelopeId: sourceEnvelopeId,
                coveringEnvelopeId: coveringEnvelopeId,
                amount: amount,
                coveredAt: coveredAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$EnvelopeCoveragesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                expenseEntryId = false,
                sourceEnvelopeId = false,
                coveringEnvelopeId = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (expenseEntryId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.expenseEntryId,
                                    referencedTable:
                                        $$EnvelopeCoveragesTableReferences
                                            ._expenseEntryIdTable(db),
                                    referencedColumn:
                                        $$EnvelopeCoveragesTableReferences
                                            ._expenseEntryIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (sourceEnvelopeId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.sourceEnvelopeId,
                                    referencedTable:
                                        $$EnvelopeCoveragesTableReferences
                                            ._sourceEnvelopeIdTable(db),
                                    referencedColumn:
                                        $$EnvelopeCoveragesTableReferences
                                            ._sourceEnvelopeIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (coveringEnvelopeId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.coveringEnvelopeId,
                                    referencedTable:
                                        $$EnvelopeCoveragesTableReferences
                                            ._coveringEnvelopeIdTable(db),
                                    referencedColumn:
                                        $$EnvelopeCoveragesTableReferences
                                            ._coveringEnvelopeIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [];
                  },
                );
              },
        ),
      );
}

typedef $$EnvelopeCoveragesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EnvelopeCoveragesTable,
      EnvelopeCoverageRow,
      $$EnvelopeCoveragesTableFilterComposer,
      $$EnvelopeCoveragesTableOrderingComposer,
      $$EnvelopeCoveragesTableAnnotationComposer,
      $$EnvelopeCoveragesTableCreateCompanionBuilder,
      $$EnvelopeCoveragesTableUpdateCompanionBuilder,
      (EnvelopeCoverageRow, $$EnvelopeCoveragesTableReferences),
      EnvelopeCoverageRow,
      PrefetchHooks Function({
        bool expenseEntryId,
        bool sourceEnvelopeId,
        bool coveringEnvelopeId,
      })
    >;
typedef $$ExpenseControlItemsTableCreateCompanionBuilder =
    ExpenseControlItemsCompanion Function({
      required String id,
      required String userId,
      Value<String?> parentId,
      required String name,
      required String iconKey,
      Value<String?> description,
      Value<int> sortOrder,
      Value<ExpenseAllocationMethod?> allocationMethod,
      Value<double?> allocationValue,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$ExpenseControlItemsTableUpdateCompanionBuilder =
    ExpenseControlItemsCompanion Function({
      Value<String> id,
      Value<String> userId,
      Value<String?> parentId,
      Value<String> name,
      Value<String> iconKey,
      Value<String?> description,
      Value<int> sortOrder,
      Value<ExpenseAllocationMethod?> allocationMethod,
      Value<double?> allocationValue,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

class $$ExpenseControlItemsTableFilterComposer
    extends Composer<_$AppDatabase, $ExpenseControlItemsTable> {
  $$ExpenseControlItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get iconKey => $composableBuilder(
    column: $table.iconKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<
    ExpenseAllocationMethod?,
    ExpenseAllocationMethod,
    String
  >
  get allocationMethod => $composableBuilder(
    column: $table.allocationMethod,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<double> get allocationValue => $composableBuilder(
    column: $table.allocationValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ExpenseControlItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $ExpenseControlItemsTable> {
  $$ExpenseControlItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get iconKey => $composableBuilder(
    column: $table.iconKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get allocationMethod => $composableBuilder(
    column: $table.allocationMethod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get allocationValue => $composableBuilder(
    column: $table.allocationValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ExpenseControlItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExpenseControlItemsTable> {
  $$ExpenseControlItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get iconKey =>
      $composableBuilder(column: $table.iconKey, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ExpenseAllocationMethod?, String>
  get allocationMethod => $composableBuilder(
    column: $table.allocationMethod,
    builder: (column) => column,
  );

  GeneratedColumn<double> get allocationValue => $composableBuilder(
    column: $table.allocationValue,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$ExpenseControlItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ExpenseControlItemsTable,
          ExpenseControlItemRow,
          $$ExpenseControlItemsTableFilterComposer,
          $$ExpenseControlItemsTableOrderingComposer,
          $$ExpenseControlItemsTableAnnotationComposer,
          $$ExpenseControlItemsTableCreateCompanionBuilder,
          $$ExpenseControlItemsTableUpdateCompanionBuilder,
          (
            ExpenseControlItemRow,
            BaseReferences<
              _$AppDatabase,
              $ExpenseControlItemsTable,
              ExpenseControlItemRow
            >,
          ),
          ExpenseControlItemRow,
          PrefetchHooks Function()
        > {
  $$ExpenseControlItemsTableTableManager(
    _$AppDatabase db,
    $ExpenseControlItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExpenseControlItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExpenseControlItemsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ExpenseControlItemsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> iconKey = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<ExpenseAllocationMethod?> allocationMethod =
                    const Value.absent(),
                Value<double?> allocationValue = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExpenseControlItemsCompanion(
                id: id,
                userId: userId,
                parentId: parentId,
                name: name,
                iconKey: iconKey,
                description: description,
                sortOrder: sortOrder,
                allocationMethod: allocationMethod,
                allocationValue: allocationValue,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String userId,
                Value<String?> parentId = const Value.absent(),
                required String name,
                required String iconKey,
                Value<String?> description = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<ExpenseAllocationMethod?> allocationMethod =
                    const Value.absent(),
                Value<double?> allocationValue = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExpenseControlItemsCompanion.insert(
                id: id,
                userId: userId,
                parentId: parentId,
                name: name,
                iconKey: iconKey,
                description: description,
                sortOrder: sortOrder,
                allocationMethod: allocationMethod,
                allocationValue: allocationValue,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ExpenseControlItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ExpenseControlItemsTable,
      ExpenseControlItemRow,
      $$ExpenseControlItemsTableFilterComposer,
      $$ExpenseControlItemsTableOrderingComposer,
      $$ExpenseControlItemsTableAnnotationComposer,
      $$ExpenseControlItemsTableCreateCompanionBuilder,
      $$ExpenseControlItemsTableUpdateCompanionBuilder,
      (
        ExpenseControlItemRow,
        BaseReferences<
          _$AppDatabase,
          $ExpenseControlItemsTable,
          ExpenseControlItemRow
        >,
      ),
      ExpenseControlItemRow,
      PrefetchHooks Function()
    >;
typedef $$SyncOutboxTableCreateCompanionBuilder =
    SyncOutboxCompanion Function({
      required String id,
      required String entityTable,
      required String rowId,
      required SyncOperation operation,
      required String payload,
      Value<DateTime?> syncedAt,
      Value<int> retryCount,
      Value<int> rowid,
    });
typedef $$SyncOutboxTableUpdateCompanionBuilder =
    SyncOutboxCompanion Function({
      Value<String> id,
      Value<String> entityTable,
      Value<String> rowId,
      Value<SyncOperation> operation,
      Value<String> payload,
      Value<DateTime?> syncedAt,
      Value<int> retryCount,
      Value<int> rowid,
    });

class $$SyncOutboxTableFilterComposer
    extends Composer<_$AppDatabase, $SyncOutboxTable> {
  $$SyncOutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityTable => $composableBuilder(
    column: $table.entityTable,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rowId => $composableBuilder(
    column: $table.rowId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<SyncOperation, SyncOperation, String>
  get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncOutboxTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncOutboxTable> {
  $$SyncOutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityTable => $composableBuilder(
    column: $table.entityTable,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rowId => $composableBuilder(
    column: $table.rowId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncOutboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncOutboxTable> {
  $$SyncOutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get entityTable => $composableBuilder(
    column: $table.entityTable,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rowId =>
      $composableBuilder(column: $table.rowId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<SyncOperation, String> get operation =>
      $composableBuilder(column: $table.operation, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );
}

class $$SyncOutboxTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncOutboxTable,
          SyncOutboxRow,
          $$SyncOutboxTableFilterComposer,
          $$SyncOutboxTableOrderingComposer,
          $$SyncOutboxTableAnnotationComposer,
          $$SyncOutboxTableCreateCompanionBuilder,
          $$SyncOutboxTableUpdateCompanionBuilder,
          (
            SyncOutboxRow,
            BaseReferences<_$AppDatabase, $SyncOutboxTable, SyncOutboxRow>,
          ),
          SyncOutboxRow,
          PrefetchHooks Function()
        > {
  $$SyncOutboxTableTableManager(_$AppDatabase db, $SyncOutboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncOutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncOutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncOutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> entityTable = const Value.absent(),
                Value<String> rowId = const Value.absent(),
                Value<SyncOperation> operation = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncOutboxCompanion(
                id: id,
                entityTable: entityTable,
                rowId: rowId,
                operation: operation,
                payload: payload,
                syncedAt: syncedAt,
                retryCount: retryCount,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String entityTable,
                required String rowId,
                required SyncOperation operation,
                required String payload,
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncOutboxCompanion.insert(
                id: id,
                entityTable: entityTable,
                rowId: rowId,
                operation: operation,
                payload: payload,
                syncedAt: syncedAt,
                retryCount: retryCount,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncOutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncOutboxTable,
      SyncOutboxRow,
      $$SyncOutboxTableFilterComposer,
      $$SyncOutboxTableOrderingComposer,
      $$SyncOutboxTableAnnotationComposer,
      $$SyncOutboxTableCreateCompanionBuilder,
      $$SyncOutboxTableUpdateCompanionBuilder,
      (
        SyncOutboxRow,
        BaseReferences<_$AppDatabase, $SyncOutboxTable, SyncOutboxRow>,
      ),
      SyncOutboxRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$EnvelopesTableTableManager get envelopes =>
      $$EnvelopesTableTableManager(_db, _db.envelopes);
  $$AllocationEventsTableTableManager get allocationEvents =>
      $$AllocationEventsTableTableManager(_db, _db.allocationEvents);
  $$AllocationEventLinesTableTableManager get allocationEventLines =>
      $$AllocationEventLinesTableTableManager(_db, _db.allocationEventLines);
  $$ExpenseEntriesTableTableManager get expenseEntries =>
      $$ExpenseEntriesTableTableManager(_db, _db.expenseEntries);
  $$EnvelopeCoveragesTableTableManager get envelopeCoverages =>
      $$EnvelopeCoveragesTableTableManager(_db, _db.envelopeCoverages);
  $$ExpenseControlItemsTableTableManager get expenseControlItems =>
      $$ExpenseControlItemsTableTableManager(_db, _db.expenseControlItems);
  $$SyncOutboxTableTableManager get syncOutbox =>
      $$SyncOutboxTableTableManager(_db, _db.syncOutbox);
}
