// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $RoisTable extends Rois with TableInfo<$RoisTable, Roi> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RoisTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
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
  static const VerificationMeta _authorIdMeta = const VerificationMeta(
    'authorId',
  );
  @override
  late final GeneratedColumn<String> authorId = GeneratedColumn<String>(
    'author_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isSharedMeta = const VerificationMeta(
    'isShared',
  );
  @override
  late final GeneratedColumn<bool> isShared = GeneratedColumn<bool>(
    'is_shared',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_shared" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isOfflineCachedMeta = const VerificationMeta(
    'isOfflineCached',
  );
  @override
  late final GeneratedColumn<int> isOfflineCached = GeneratedColumn<int>(
    'is_offline_cached',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    clientDefault: () => DateTime.now().millisecondsSinceEpoch,
  );
  static const VerificationMeta _cloudVersionMeta = const VerificationMeta(
    'cloudVersion',
  );
  @override
  late final GeneratedColumn<int> cloudVersion = GeneratedColumn<int>(
    'cloud_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _syncLockExpiresAtMeta = const VerificationMeta(
    'syncLockExpiresAt',
  );
  @override
  late final GeneratedColumn<int> syncLockExpiresAt = GeneratedColumn<int>(
    'sync_lock_expires_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    description,
    authorId,
    isShared,
    isOfflineCached,
    createdAt,
    cloudVersion,
    syncLockExpiresAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rois';
  @override
  VerificationContext validateIntegrity(
    Insertable<Roi> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
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
    if (data.containsKey('author_id')) {
      context.handle(
        _authorIdMeta,
        authorId.isAcceptableOrUnknown(data['author_id']!, _authorIdMeta),
      );
    } else if (isInserting) {
      context.missing(_authorIdMeta);
    }
    if (data.containsKey('is_shared')) {
      context.handle(
        _isSharedMeta,
        isShared.isAcceptableOrUnknown(data['is_shared']!, _isSharedMeta),
      );
    }
    if (data.containsKey('is_offline_cached')) {
      context.handle(
        _isOfflineCachedMeta,
        isOfflineCached.isAcceptableOrUnknown(
          data['is_offline_cached']!,
          _isOfflineCachedMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('cloud_version')) {
      context.handle(
        _cloudVersionMeta,
        cloudVersion.isAcceptableOrUnknown(
          data['cloud_version']!,
          _cloudVersionMeta,
        ),
      );
    }
    if (data.containsKey('sync_lock_expires_at')) {
      context.handle(
        _syncLockExpiresAtMeta,
        syncLockExpiresAt.isAcceptableOrUnknown(
          data['sync_lock_expires_at']!,
          _syncLockExpiresAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Roi map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Roi(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      authorId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author_id'],
      )!,
      isShared: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_shared'],
      )!,
      isOfflineCached: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}is_offline_cached'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      cloudVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cloud_version'],
      )!,
      syncLockExpiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sync_lock_expires_at'],
      ),
    );
  }

  @override
  $RoisTable createAlias(String alias) {
    return $RoisTable(attachedDatabase, alias);
  }
}

class Roi extends DataClass implements Insertable<Roi> {
  final String id;
  final String name;
  final String? description;
  final String authorId;
  final bool isShared;
  final int isOfflineCached;
  final int createdAt;
  final int cloudVersion;
  final int? syncLockExpiresAt;
  const Roi({
    required this.id,
    required this.name,
    this.description,
    required this.authorId,
    required this.isShared,
    required this.isOfflineCached,
    required this.createdAt,
    required this.cloudVersion,
    this.syncLockExpiresAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['author_id'] = Variable<String>(authorId);
    map['is_shared'] = Variable<bool>(isShared);
    map['is_offline_cached'] = Variable<int>(isOfflineCached);
    map['created_at'] = Variable<int>(createdAt);
    map['cloud_version'] = Variable<int>(cloudVersion);
    if (!nullToAbsent || syncLockExpiresAt != null) {
      map['sync_lock_expires_at'] = Variable<int>(syncLockExpiresAt);
    }
    return map;
  }

  RoisCompanion toCompanion(bool nullToAbsent) {
    return RoisCompanion(
      id: Value(id),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      authorId: Value(authorId),
      isShared: Value(isShared),
      isOfflineCached: Value(isOfflineCached),
      createdAt: Value(createdAt),
      cloudVersion: Value(cloudVersion),
      syncLockExpiresAt: syncLockExpiresAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncLockExpiresAt),
    );
  }

  factory Roi.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Roi(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      authorId: serializer.fromJson<String>(json['authorId']),
      isShared: serializer.fromJson<bool>(json['isShared']),
      isOfflineCached: serializer.fromJson<int>(json['isOfflineCached']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      cloudVersion: serializer.fromJson<int>(json['cloudVersion']),
      syncLockExpiresAt: serializer.fromJson<int?>(json['syncLockExpiresAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'authorId': serializer.toJson<String>(authorId),
      'isShared': serializer.toJson<bool>(isShared),
      'isOfflineCached': serializer.toJson<int>(isOfflineCached),
      'createdAt': serializer.toJson<int>(createdAt),
      'cloudVersion': serializer.toJson<int>(cloudVersion),
      'syncLockExpiresAt': serializer.toJson<int?>(syncLockExpiresAt),
    };
  }

  Roi copyWith({
    String? id,
    String? name,
    Value<String?> description = const Value.absent(),
    String? authorId,
    bool? isShared,
    int? isOfflineCached,
    int? createdAt,
    int? cloudVersion,
    Value<int?> syncLockExpiresAt = const Value.absent(),
  }) => Roi(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description.present ? description.value : this.description,
    authorId: authorId ?? this.authorId,
    isShared: isShared ?? this.isShared,
    isOfflineCached: isOfflineCached ?? this.isOfflineCached,
    createdAt: createdAt ?? this.createdAt,
    cloudVersion: cloudVersion ?? this.cloudVersion,
    syncLockExpiresAt: syncLockExpiresAt.present
        ? syncLockExpiresAt.value
        : this.syncLockExpiresAt,
  );
  Roi copyWithCompanion(RoisCompanion data) {
    return Roi(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      authorId: data.authorId.present ? data.authorId.value : this.authorId,
      isShared: data.isShared.present ? data.isShared.value : this.isShared,
      isOfflineCached: data.isOfflineCached.present
          ? data.isOfflineCached.value
          : this.isOfflineCached,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      cloudVersion: data.cloudVersion.present
          ? data.cloudVersion.value
          : this.cloudVersion,
      syncLockExpiresAt: data.syncLockExpiresAt.present
          ? data.syncLockExpiresAt.value
          : this.syncLockExpiresAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Roi(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('authorId: $authorId, ')
          ..write('isShared: $isShared, ')
          ..write('isOfflineCached: $isOfflineCached, ')
          ..write('createdAt: $createdAt, ')
          ..write('cloudVersion: $cloudVersion, ')
          ..write('syncLockExpiresAt: $syncLockExpiresAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    description,
    authorId,
    isShared,
    isOfflineCached,
    createdAt,
    cloudVersion,
    syncLockExpiresAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Roi &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.authorId == this.authorId &&
          other.isShared == this.isShared &&
          other.isOfflineCached == this.isOfflineCached &&
          other.createdAt == this.createdAt &&
          other.cloudVersion == this.cloudVersion &&
          other.syncLockExpiresAt == this.syncLockExpiresAt);
}

class RoisCompanion extends UpdateCompanion<Roi> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> description;
  final Value<String> authorId;
  final Value<bool> isShared;
  final Value<int> isOfflineCached;
  final Value<int> createdAt;
  final Value<int> cloudVersion;
  final Value<int?> syncLockExpiresAt;
  final Value<int> rowid;
  const RoisCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.authorId = const Value.absent(),
    this.isShared = const Value.absent(),
    this.isOfflineCached = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.cloudVersion = const Value.absent(),
    this.syncLockExpiresAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RoisCompanion.insert({
    required String id,
    required String name,
    this.description = const Value.absent(),
    required String authorId,
    this.isShared = const Value.absent(),
    this.isOfflineCached = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.cloudVersion = const Value.absent(),
    this.syncLockExpiresAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       authorId = Value(authorId);
  static Insertable<Roi> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<String>? authorId,
    Expression<bool>? isShared,
    Expression<int>? isOfflineCached,
    Expression<int>? createdAt,
    Expression<int>? cloudVersion,
    Expression<int>? syncLockExpiresAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (authorId != null) 'author_id': authorId,
      if (isShared != null) 'is_shared': isShared,
      if (isOfflineCached != null) 'is_offline_cached': isOfflineCached,
      if (createdAt != null) 'created_at': createdAt,
      if (cloudVersion != null) 'cloud_version': cloudVersion,
      if (syncLockExpiresAt != null) 'sync_lock_expires_at': syncLockExpiresAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RoisCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? description,
    Value<String>? authorId,
    Value<bool>? isShared,
    Value<int>? isOfflineCached,
    Value<int>? createdAt,
    Value<int>? cloudVersion,
    Value<int?>? syncLockExpiresAt,
    Value<int>? rowid,
  }) {
    return RoisCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      authorId: authorId ?? this.authorId,
      isShared: isShared ?? this.isShared,
      isOfflineCached: isOfflineCached ?? this.isOfflineCached,
      createdAt: createdAt ?? this.createdAt,
      cloudVersion: cloudVersion ?? this.cloudVersion,
      syncLockExpiresAt: syncLockExpiresAt ?? this.syncLockExpiresAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (authorId.present) {
      map['author_id'] = Variable<String>(authorId.value);
    }
    if (isShared.present) {
      map['is_shared'] = Variable<bool>(isShared.value);
    }
    if (isOfflineCached.present) {
      map['is_offline_cached'] = Variable<int>(isOfflineCached.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (cloudVersion.present) {
      map['cloud_version'] = Variable<int>(cloudVersion.value);
    }
    if (syncLockExpiresAt.present) {
      map['sync_lock_expires_at'] = Variable<int>(syncLockExpiresAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RoisCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('authorId: $authorId, ')
          ..write('isShared: $isShared, ')
          ..write('isOfflineCached: $isOfflineCached, ')
          ..write('createdAt: $createdAt, ')
          ..write('cloudVersion: $cloudVersion, ')
          ..write('syncLockExpiresAt: $syncLockExpiresAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PoisTable extends Pois with TableInfo<$PoisTable, Poi> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PoisTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roiIdMeta = const VerificationMeta('roiId');
  @override
  late final GeneratedColumn<String> roiId = GeneratedColumn<String>(
    'roi_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES rois (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _authorIdMeta = const VerificationMeta(
    'authorId',
  );
  @override
  late final GeneratedColumn<String> authorId = GeneratedColumn<String>(
    'author_id',
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
  static const VerificationMeta _addressMeta = const VerificationMeta(
    'address',
  );
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
    'address',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _latMeta = const VerificationMeta('lat');
  @override
  late final GeneratedColumn<double> lat = GeneratedColumn<double>(
    'lat',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lngMeta = const VerificationMeta('lng');
  @override
  late final GeneratedColumn<double> lng = GeneratedColumn<double>(
    'lng',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _businessHoursMeta = const VerificationMeta(
    'businessHours',
  );
  @override
  late final GeneratedColumn<String> businessHours = GeneratedColumn<String>(
    'business_hours',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contactInfoMeta = const VerificationMeta(
    'contactInfo',
  );
  @override
  late final GeneratedColumn<String> contactInfo = GeneratedColumn<String>(
    'contact_info',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localCoverImagePathMeta =
      const VerificationMeta('localCoverImagePath');
  @override
  late final GeneratedColumn<String> localCoverImagePath =
      GeneratedColumn<String>(
        'local_cover_image_path',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _remoteCoverImageUrlMeta =
      const VerificationMeta('remoteCoverImageUrl');
  @override
  late final GeneratedColumn<String> remoteCoverImageUrl =
      GeneratedColumn<String>(
        'remote_cover_image_url',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    clientDefault: () => DateTime.now().millisecondsSinceEpoch,
  );
  static const VerificationMeta _isSharedMeta = const VerificationMeta(
    'isShared',
  );
  @override
  late final GeneratedColumn<bool> isShared = GeneratedColumn<bool>(
    'is_shared',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_shared" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<int> syncStatus = GeneratedColumn<int>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _hasEverSyncedMeta = const VerificationMeta(
    'hasEverSynced',
  );
  @override
  late final GeneratedColumn<bool> hasEverSynced = GeneratedColumn<bool>(
    'has_ever_synced',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_ever_synced" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastModifiedAtMeta = const VerificationMeta(
    'lastModifiedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastModifiedAt =
      GeneratedColumn<DateTime>(
        'last_modified_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    roiId,
    authorId,
    name,
    description,
    address,
    lat,
    lng,
    businessHours,
    contactInfo,
    localCoverImagePath,
    remoteCoverImageUrl,
    createdAt,
    isShared,
    sortOrder,
    syncStatus,
    isDeleted,
    hasEverSynced,
    lastModifiedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pois';
  @override
  VerificationContext validateIntegrity(
    Insertable<Poi> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('roi_id')) {
      context.handle(
        _roiIdMeta,
        roiId.isAcceptableOrUnknown(data['roi_id']!, _roiIdMeta),
      );
    }
    if (data.containsKey('author_id')) {
      context.handle(
        _authorIdMeta,
        authorId.isAcceptableOrUnknown(data['author_id']!, _authorIdMeta),
      );
    } else if (isInserting) {
      context.missing(_authorIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
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
    if (data.containsKey('address')) {
      context.handle(
        _addressMeta,
        address.isAcceptableOrUnknown(data['address']!, _addressMeta),
      );
    }
    if (data.containsKey('lat')) {
      context.handle(
        _latMeta,
        lat.isAcceptableOrUnknown(data['lat']!, _latMeta),
      );
    } else if (isInserting) {
      context.missing(_latMeta);
    }
    if (data.containsKey('lng')) {
      context.handle(
        _lngMeta,
        lng.isAcceptableOrUnknown(data['lng']!, _lngMeta),
      );
    } else if (isInserting) {
      context.missing(_lngMeta);
    }
    if (data.containsKey('business_hours')) {
      context.handle(
        _businessHoursMeta,
        businessHours.isAcceptableOrUnknown(
          data['business_hours']!,
          _businessHoursMeta,
        ),
      );
    }
    if (data.containsKey('contact_info')) {
      context.handle(
        _contactInfoMeta,
        contactInfo.isAcceptableOrUnknown(
          data['contact_info']!,
          _contactInfoMeta,
        ),
      );
    }
    if (data.containsKey('local_cover_image_path')) {
      context.handle(
        _localCoverImagePathMeta,
        localCoverImagePath.isAcceptableOrUnknown(
          data['local_cover_image_path']!,
          _localCoverImagePathMeta,
        ),
      );
    }
    if (data.containsKey('remote_cover_image_url')) {
      context.handle(
        _remoteCoverImageUrlMeta,
        remoteCoverImageUrl.isAcceptableOrUnknown(
          data['remote_cover_image_url']!,
          _remoteCoverImageUrlMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('is_shared')) {
      context.handle(
        _isSharedMeta,
        isShared.isAcceptableOrUnknown(data['is_shared']!, _isSharedMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('has_ever_synced')) {
      context.handle(
        _hasEverSyncedMeta,
        hasEverSynced.isAcceptableOrUnknown(
          data['has_ever_synced']!,
          _hasEverSyncedMeta,
        ),
      );
    }
    if (data.containsKey('last_modified_at')) {
      context.handle(
        _lastModifiedAtMeta,
        lastModifiedAt.isAcceptableOrUnknown(
          data['last_modified_at']!,
          _lastModifiedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Poi map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Poi(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      roiId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}roi_id'],
      ),
      authorId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      address: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address'],
      ),
      lat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lat'],
      )!,
      lng: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lng'],
      )!,
      businessHours: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}business_hours'],
      ),
      contactInfo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}contact_info'],
      ),
      localCoverImagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_cover_image_path'],
      ),
      remoteCoverImageUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_cover_image_url'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      isShared: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_shared'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sync_status'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      hasEverSynced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_ever_synced'],
      )!,
      lastModifiedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_modified_at'],
      ),
    );
  }

  @override
  $PoisTable createAlias(String alias) {
    return $PoisTable(attachedDatabase, alias);
  }
}

class Poi extends DataClass implements Insertable<Poi> {
  final String id;
  final String? roiId;
  final String authorId;
  final String name;
  final String? description;
  final String? address;
  final double lat;
  final double lng;
  final String? businessHours;
  final String? contactInfo;
  final String? localCoverImagePath;
  final String? remoteCoverImageUrl;
  final int createdAt;
  final bool isShared;
  final int sortOrder;
  final int syncStatus;
  final bool isDeleted;
  final bool hasEverSynced;
  final DateTime? lastModifiedAt;
  const Poi({
    required this.id,
    this.roiId,
    required this.authorId,
    required this.name,
    this.description,
    this.address,
    required this.lat,
    required this.lng,
    this.businessHours,
    this.contactInfo,
    this.localCoverImagePath,
    this.remoteCoverImageUrl,
    required this.createdAt,
    required this.isShared,
    required this.sortOrder,
    required this.syncStatus,
    required this.isDeleted,
    required this.hasEverSynced,
    this.lastModifiedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || roiId != null) {
      map['roi_id'] = Variable<String>(roiId);
    }
    map['author_id'] = Variable<String>(authorId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || address != null) {
      map['address'] = Variable<String>(address);
    }
    map['lat'] = Variable<double>(lat);
    map['lng'] = Variable<double>(lng);
    if (!nullToAbsent || businessHours != null) {
      map['business_hours'] = Variable<String>(businessHours);
    }
    if (!nullToAbsent || contactInfo != null) {
      map['contact_info'] = Variable<String>(contactInfo);
    }
    if (!nullToAbsent || localCoverImagePath != null) {
      map['local_cover_image_path'] = Variable<String>(localCoverImagePath);
    }
    if (!nullToAbsent || remoteCoverImageUrl != null) {
      map['remote_cover_image_url'] = Variable<String>(remoteCoverImageUrl);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['is_shared'] = Variable<bool>(isShared);
    map['sort_order'] = Variable<int>(sortOrder);
    map['sync_status'] = Variable<int>(syncStatus);
    map['is_deleted'] = Variable<bool>(isDeleted);
    map['has_ever_synced'] = Variable<bool>(hasEverSynced);
    if (!nullToAbsent || lastModifiedAt != null) {
      map['last_modified_at'] = Variable<DateTime>(lastModifiedAt);
    }
    return map;
  }

  PoisCompanion toCompanion(bool nullToAbsent) {
    return PoisCompanion(
      id: Value(id),
      roiId: roiId == null && nullToAbsent
          ? const Value.absent()
          : Value(roiId),
      authorId: Value(authorId),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      address: address == null && nullToAbsent
          ? const Value.absent()
          : Value(address),
      lat: Value(lat),
      lng: Value(lng),
      businessHours: businessHours == null && nullToAbsent
          ? const Value.absent()
          : Value(businessHours),
      contactInfo: contactInfo == null && nullToAbsent
          ? const Value.absent()
          : Value(contactInfo),
      localCoverImagePath: localCoverImagePath == null && nullToAbsent
          ? const Value.absent()
          : Value(localCoverImagePath),
      remoteCoverImageUrl: remoteCoverImageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteCoverImageUrl),
      createdAt: Value(createdAt),
      isShared: Value(isShared),
      sortOrder: Value(sortOrder),
      syncStatus: Value(syncStatus),
      isDeleted: Value(isDeleted),
      hasEverSynced: Value(hasEverSynced),
      lastModifiedAt: lastModifiedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastModifiedAt),
    );
  }

  factory Poi.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Poi(
      id: serializer.fromJson<String>(json['id']),
      roiId: serializer.fromJson<String?>(json['roiId']),
      authorId: serializer.fromJson<String>(json['authorId']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      address: serializer.fromJson<String?>(json['address']),
      lat: serializer.fromJson<double>(json['lat']),
      lng: serializer.fromJson<double>(json['lng']),
      businessHours: serializer.fromJson<String?>(json['businessHours']),
      contactInfo: serializer.fromJson<String?>(json['contactInfo']),
      localCoverImagePath: serializer.fromJson<String?>(
        json['localCoverImagePath'],
      ),
      remoteCoverImageUrl: serializer.fromJson<String?>(
        json['remoteCoverImageUrl'],
      ),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      isShared: serializer.fromJson<bool>(json['isShared']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      syncStatus: serializer.fromJson<int>(json['syncStatus']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      hasEverSynced: serializer.fromJson<bool>(json['hasEverSynced']),
      lastModifiedAt: serializer.fromJson<DateTime?>(json['lastModifiedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'roiId': serializer.toJson<String?>(roiId),
      'authorId': serializer.toJson<String>(authorId),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'address': serializer.toJson<String?>(address),
      'lat': serializer.toJson<double>(lat),
      'lng': serializer.toJson<double>(lng),
      'businessHours': serializer.toJson<String?>(businessHours),
      'contactInfo': serializer.toJson<String?>(contactInfo),
      'localCoverImagePath': serializer.toJson<String?>(localCoverImagePath),
      'remoteCoverImageUrl': serializer.toJson<String?>(remoteCoverImageUrl),
      'createdAt': serializer.toJson<int>(createdAt),
      'isShared': serializer.toJson<bool>(isShared),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'syncStatus': serializer.toJson<int>(syncStatus),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'hasEverSynced': serializer.toJson<bool>(hasEverSynced),
      'lastModifiedAt': serializer.toJson<DateTime?>(lastModifiedAt),
    };
  }

  Poi copyWith({
    String? id,
    Value<String?> roiId = const Value.absent(),
    String? authorId,
    String? name,
    Value<String?> description = const Value.absent(),
    Value<String?> address = const Value.absent(),
    double? lat,
    double? lng,
    Value<String?> businessHours = const Value.absent(),
    Value<String?> contactInfo = const Value.absent(),
    Value<String?> localCoverImagePath = const Value.absent(),
    Value<String?> remoteCoverImageUrl = const Value.absent(),
    int? createdAt,
    bool? isShared,
    int? sortOrder,
    int? syncStatus,
    bool? isDeleted,
    bool? hasEverSynced,
    Value<DateTime?> lastModifiedAt = const Value.absent(),
  }) => Poi(
    id: id ?? this.id,
    roiId: roiId.present ? roiId.value : this.roiId,
    authorId: authorId ?? this.authorId,
    name: name ?? this.name,
    description: description.present ? description.value : this.description,
    address: address.present ? address.value : this.address,
    lat: lat ?? this.lat,
    lng: lng ?? this.lng,
    businessHours: businessHours.present
        ? businessHours.value
        : this.businessHours,
    contactInfo: contactInfo.present ? contactInfo.value : this.contactInfo,
    localCoverImagePath: localCoverImagePath.present
        ? localCoverImagePath.value
        : this.localCoverImagePath,
    remoteCoverImageUrl: remoteCoverImageUrl.present
        ? remoteCoverImageUrl.value
        : this.remoteCoverImageUrl,
    createdAt: createdAt ?? this.createdAt,
    isShared: isShared ?? this.isShared,
    sortOrder: sortOrder ?? this.sortOrder,
    syncStatus: syncStatus ?? this.syncStatus,
    isDeleted: isDeleted ?? this.isDeleted,
    hasEverSynced: hasEverSynced ?? this.hasEverSynced,
    lastModifiedAt: lastModifiedAt.present
        ? lastModifiedAt.value
        : this.lastModifiedAt,
  );
  Poi copyWithCompanion(PoisCompanion data) {
    return Poi(
      id: data.id.present ? data.id.value : this.id,
      roiId: data.roiId.present ? data.roiId.value : this.roiId,
      authorId: data.authorId.present ? data.authorId.value : this.authorId,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      address: data.address.present ? data.address.value : this.address,
      lat: data.lat.present ? data.lat.value : this.lat,
      lng: data.lng.present ? data.lng.value : this.lng,
      businessHours: data.businessHours.present
          ? data.businessHours.value
          : this.businessHours,
      contactInfo: data.contactInfo.present
          ? data.contactInfo.value
          : this.contactInfo,
      localCoverImagePath: data.localCoverImagePath.present
          ? data.localCoverImagePath.value
          : this.localCoverImagePath,
      remoteCoverImageUrl: data.remoteCoverImageUrl.present
          ? data.remoteCoverImageUrl.value
          : this.remoteCoverImageUrl,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      isShared: data.isShared.present ? data.isShared.value : this.isShared,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      hasEverSynced: data.hasEverSynced.present
          ? data.hasEverSynced.value
          : this.hasEverSynced,
      lastModifiedAt: data.lastModifiedAt.present
          ? data.lastModifiedAt.value
          : this.lastModifiedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Poi(')
          ..write('id: $id, ')
          ..write('roiId: $roiId, ')
          ..write('authorId: $authorId, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('address: $address, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('businessHours: $businessHours, ')
          ..write('contactInfo: $contactInfo, ')
          ..write('localCoverImagePath: $localCoverImagePath, ')
          ..write('remoteCoverImageUrl: $remoteCoverImageUrl, ')
          ..write('createdAt: $createdAt, ')
          ..write('isShared: $isShared, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('hasEverSynced: $hasEverSynced, ')
          ..write('lastModifiedAt: $lastModifiedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    roiId,
    authorId,
    name,
    description,
    address,
    lat,
    lng,
    businessHours,
    contactInfo,
    localCoverImagePath,
    remoteCoverImageUrl,
    createdAt,
    isShared,
    sortOrder,
    syncStatus,
    isDeleted,
    hasEverSynced,
    lastModifiedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Poi &&
          other.id == this.id &&
          other.roiId == this.roiId &&
          other.authorId == this.authorId &&
          other.name == this.name &&
          other.description == this.description &&
          other.address == this.address &&
          other.lat == this.lat &&
          other.lng == this.lng &&
          other.businessHours == this.businessHours &&
          other.contactInfo == this.contactInfo &&
          other.localCoverImagePath == this.localCoverImagePath &&
          other.remoteCoverImageUrl == this.remoteCoverImageUrl &&
          other.createdAt == this.createdAt &&
          other.isShared == this.isShared &&
          other.sortOrder == this.sortOrder &&
          other.syncStatus == this.syncStatus &&
          other.isDeleted == this.isDeleted &&
          other.hasEverSynced == this.hasEverSynced &&
          other.lastModifiedAt == this.lastModifiedAt);
}

class PoisCompanion extends UpdateCompanion<Poi> {
  final Value<String> id;
  final Value<String?> roiId;
  final Value<String> authorId;
  final Value<String> name;
  final Value<String?> description;
  final Value<String?> address;
  final Value<double> lat;
  final Value<double> lng;
  final Value<String?> businessHours;
  final Value<String?> contactInfo;
  final Value<String?> localCoverImagePath;
  final Value<String?> remoteCoverImageUrl;
  final Value<int> createdAt;
  final Value<bool> isShared;
  final Value<int> sortOrder;
  final Value<int> syncStatus;
  final Value<bool> isDeleted;
  final Value<bool> hasEverSynced;
  final Value<DateTime?> lastModifiedAt;
  final Value<int> rowid;
  const PoisCompanion({
    this.id = const Value.absent(),
    this.roiId = const Value.absent(),
    this.authorId = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.address = const Value.absent(),
    this.lat = const Value.absent(),
    this.lng = const Value.absent(),
    this.businessHours = const Value.absent(),
    this.contactInfo = const Value.absent(),
    this.localCoverImagePath = const Value.absent(),
    this.remoteCoverImageUrl = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.isShared = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.hasEverSynced = const Value.absent(),
    this.lastModifiedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PoisCompanion.insert({
    required String id,
    this.roiId = const Value.absent(),
    required String authorId,
    required String name,
    this.description = const Value.absent(),
    this.address = const Value.absent(),
    required double lat,
    required double lng,
    this.businessHours = const Value.absent(),
    this.contactInfo = const Value.absent(),
    this.localCoverImagePath = const Value.absent(),
    this.remoteCoverImageUrl = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.isShared = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.hasEverSynced = const Value.absent(),
    this.lastModifiedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       authorId = Value(authorId),
       name = Value(name),
       lat = Value(lat),
       lng = Value(lng);
  static Insertable<Poi> custom({
    Expression<String>? id,
    Expression<String>? roiId,
    Expression<String>? authorId,
    Expression<String>? name,
    Expression<String>? description,
    Expression<String>? address,
    Expression<double>? lat,
    Expression<double>? lng,
    Expression<String>? businessHours,
    Expression<String>? contactInfo,
    Expression<String>? localCoverImagePath,
    Expression<String>? remoteCoverImageUrl,
    Expression<int>? createdAt,
    Expression<bool>? isShared,
    Expression<int>? sortOrder,
    Expression<int>? syncStatus,
    Expression<bool>? isDeleted,
    Expression<bool>? hasEverSynced,
    Expression<DateTime>? lastModifiedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (roiId != null) 'roi_id': roiId,
      if (authorId != null) 'author_id': authorId,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (address != null) 'address': address,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (businessHours != null) 'business_hours': businessHours,
      if (contactInfo != null) 'contact_info': contactInfo,
      if (localCoverImagePath != null)
        'local_cover_image_path': localCoverImagePath,
      if (remoteCoverImageUrl != null)
        'remote_cover_image_url': remoteCoverImageUrl,
      if (createdAt != null) 'created_at': createdAt,
      if (isShared != null) 'is_shared': isShared,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (hasEverSynced != null) 'has_ever_synced': hasEverSynced,
      if (lastModifiedAt != null) 'last_modified_at': lastModifiedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PoisCompanion copyWith({
    Value<String>? id,
    Value<String?>? roiId,
    Value<String>? authorId,
    Value<String>? name,
    Value<String?>? description,
    Value<String?>? address,
    Value<double>? lat,
    Value<double>? lng,
    Value<String?>? businessHours,
    Value<String?>? contactInfo,
    Value<String?>? localCoverImagePath,
    Value<String?>? remoteCoverImageUrl,
    Value<int>? createdAt,
    Value<bool>? isShared,
    Value<int>? sortOrder,
    Value<int>? syncStatus,
    Value<bool>? isDeleted,
    Value<bool>? hasEverSynced,
    Value<DateTime?>? lastModifiedAt,
    Value<int>? rowid,
  }) {
    return PoisCompanion(
      id: id ?? this.id,
      roiId: roiId ?? this.roiId,
      authorId: authorId ?? this.authorId,
      name: name ?? this.name,
      description: description ?? this.description,
      address: address ?? this.address,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      businessHours: businessHours ?? this.businessHours,
      contactInfo: contactInfo ?? this.contactInfo,
      localCoverImagePath: localCoverImagePath ?? this.localCoverImagePath,
      remoteCoverImageUrl: remoteCoverImageUrl ?? this.remoteCoverImageUrl,
      createdAt: createdAt ?? this.createdAt,
      isShared: isShared ?? this.isShared,
      sortOrder: sortOrder ?? this.sortOrder,
      syncStatus: syncStatus ?? this.syncStatus,
      isDeleted: isDeleted ?? this.isDeleted,
      hasEverSynced: hasEverSynced ?? this.hasEverSynced,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (roiId.present) {
      map['roi_id'] = Variable<String>(roiId.value);
    }
    if (authorId.present) {
      map['author_id'] = Variable<String>(authorId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (lat.present) {
      map['lat'] = Variable<double>(lat.value);
    }
    if (lng.present) {
      map['lng'] = Variable<double>(lng.value);
    }
    if (businessHours.present) {
      map['business_hours'] = Variable<String>(businessHours.value);
    }
    if (contactInfo.present) {
      map['contact_info'] = Variable<String>(contactInfo.value);
    }
    if (localCoverImagePath.present) {
      map['local_cover_image_path'] = Variable<String>(
        localCoverImagePath.value,
      );
    }
    if (remoteCoverImageUrl.present) {
      map['remote_cover_image_url'] = Variable<String>(
        remoteCoverImageUrl.value,
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (isShared.present) {
      map['is_shared'] = Variable<bool>(isShared.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<int>(syncStatus.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (hasEverSynced.present) {
      map['has_ever_synced'] = Variable<bool>(hasEverSynced.value);
    }
    if (lastModifiedAt.present) {
      map['last_modified_at'] = Variable<DateTime>(lastModifiedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PoisCompanion(')
          ..write('id: $id, ')
          ..write('roiId: $roiId, ')
          ..write('authorId: $authorId, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('address: $address, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('businessHours: $businessHours, ')
          ..write('contactInfo: $contactInfo, ')
          ..write('localCoverImagePath: $localCoverImagePath, ')
          ..write('remoteCoverImageUrl: $remoteCoverImageUrl, ')
          ..write('createdAt: $createdAt, ')
          ..write('isShared: $isShared, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('hasEverSynced: $hasEverSynced, ')
          ..write('lastModifiedAt: $lastModifiedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AnimesTable extends Animes with TableInfo<$AnimesTable, Anime> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AnimesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
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
  static const VerificationMeta _bangumiIdMeta = const VerificationMeta(
    'bangumiId',
  );
  @override
  late final GeneratedColumn<String> bangumiId = GeneratedColumn<String>(
    'bangumi_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _authorIdMeta = const VerificationMeta(
    'authorId',
  );
  @override
  late final GeneratedColumn<String> authorId = GeneratedColumn<String>(
    'author_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isSharedMeta = const VerificationMeta(
    'isShared',
  );
  @override
  late final GeneratedColumn<bool> isShared = GeneratedColumn<bool>(
    'is_shared',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_shared" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    clientDefault: () => DateTime.now().millisecondsSinceEpoch,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    description,
    bangumiId,
    authorId,
    isShared,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'animes';
  @override
  VerificationContext validateIntegrity(
    Insertable<Anime> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
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
    if (data.containsKey('bangumi_id')) {
      context.handle(
        _bangumiIdMeta,
        bangumiId.isAcceptableOrUnknown(data['bangumi_id']!, _bangumiIdMeta),
      );
    }
    if (data.containsKey('author_id')) {
      context.handle(
        _authorIdMeta,
        authorId.isAcceptableOrUnknown(data['author_id']!, _authorIdMeta),
      );
    } else if (isInserting) {
      context.missing(_authorIdMeta);
    }
    if (data.containsKey('is_shared')) {
      context.handle(
        _isSharedMeta,
        isShared.isAcceptableOrUnknown(data['is_shared']!, _isSharedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Anime map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Anime(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      bangumiId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bangumi_id'],
      ),
      authorId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author_id'],
      )!,
      isShared: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_shared'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $AnimesTable createAlias(String alias) {
    return $AnimesTable(attachedDatabase, alias);
  }
}

class Anime extends DataClass implements Insertable<Anime> {
  final String id;
  final String name;
  final String? description;
  final String? bangumiId;
  final String authorId;
  final bool isShared;
  final int createdAt;
  const Anime({
    required this.id,
    required this.name,
    this.description,
    this.bangumiId,
    required this.authorId,
    required this.isShared,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || bangumiId != null) {
      map['bangumi_id'] = Variable<String>(bangumiId);
    }
    map['author_id'] = Variable<String>(authorId);
    map['is_shared'] = Variable<bool>(isShared);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  AnimesCompanion toCompanion(bool nullToAbsent) {
    return AnimesCompanion(
      id: Value(id),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      bangumiId: bangumiId == null && nullToAbsent
          ? const Value.absent()
          : Value(bangumiId),
      authorId: Value(authorId),
      isShared: Value(isShared),
      createdAt: Value(createdAt),
    );
  }

  factory Anime.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Anime(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      bangumiId: serializer.fromJson<String?>(json['bangumiId']),
      authorId: serializer.fromJson<String>(json['authorId']),
      isShared: serializer.fromJson<bool>(json['isShared']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'bangumiId': serializer.toJson<String?>(bangumiId),
      'authorId': serializer.toJson<String>(authorId),
      'isShared': serializer.toJson<bool>(isShared),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  Anime copyWith({
    String? id,
    String? name,
    Value<String?> description = const Value.absent(),
    Value<String?> bangumiId = const Value.absent(),
    String? authorId,
    bool? isShared,
    int? createdAt,
  }) => Anime(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description.present ? description.value : this.description,
    bangumiId: bangumiId.present ? bangumiId.value : this.bangumiId,
    authorId: authorId ?? this.authorId,
    isShared: isShared ?? this.isShared,
    createdAt: createdAt ?? this.createdAt,
  );
  Anime copyWithCompanion(AnimesCompanion data) {
    return Anime(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      bangumiId: data.bangumiId.present ? data.bangumiId.value : this.bangumiId,
      authorId: data.authorId.present ? data.authorId.value : this.authorId,
      isShared: data.isShared.present ? data.isShared.value : this.isShared,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Anime(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('bangumiId: $bangumiId, ')
          ..write('authorId: $authorId, ')
          ..write('isShared: $isShared, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    description,
    bangumiId,
    authorId,
    isShared,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Anime &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.bangumiId == this.bangumiId &&
          other.authorId == this.authorId &&
          other.isShared == this.isShared &&
          other.createdAt == this.createdAt);
}

class AnimesCompanion extends UpdateCompanion<Anime> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> description;
  final Value<String?> bangumiId;
  final Value<String> authorId;
  final Value<bool> isShared;
  final Value<int> createdAt;
  final Value<int> rowid;
  const AnimesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.bangumiId = const Value.absent(),
    this.authorId = const Value.absent(),
    this.isShared = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AnimesCompanion.insert({
    required String id,
    required String name,
    this.description = const Value.absent(),
    this.bangumiId = const Value.absent(),
    required String authorId,
    this.isShared = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       authorId = Value(authorId);
  static Insertable<Anime> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<String>? bangumiId,
    Expression<String>? authorId,
    Expression<bool>? isShared,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (bangumiId != null) 'bangumi_id': bangumiId,
      if (authorId != null) 'author_id': authorId,
      if (isShared != null) 'is_shared': isShared,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AnimesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? description,
    Value<String?>? bangumiId,
    Value<String>? authorId,
    Value<bool>? isShared,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return AnimesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      bangumiId: bangumiId ?? this.bangumiId,
      authorId: authorId ?? this.authorId,
      isShared: isShared ?? this.isShared,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (bangumiId.present) {
      map['bangumi_id'] = Variable<String>(bangumiId.value);
    }
    if (authorId.present) {
      map['author_id'] = Variable<String>(authorId.value);
    }
    if (isShared.present) {
      map['is_shared'] = Variable<bool>(isShared.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AnimesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('bangumiId: $bangumiId, ')
          ..write('authorId: $authorId, ')
          ..write('isShared: $isShared, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TagsTable extends Tags with TableInfo<$TagsTable, Tag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
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
  static const VerificationMeta _authorIdMeta = const VerificationMeta(
    'authorId',
  );
  @override
  late final GeneratedColumn<String> authorId = GeneratedColumn<String>(
    'author_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isSharedMeta = const VerificationMeta(
    'isShared',
  );
  @override
  late final GeneratedColumn<bool> isShared = GeneratedColumn<bool>(
    'is_shared',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_shared" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    clientDefault: () => DateTime.now().millisecondsSinceEpoch,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    description,
    authorId,
    isShared,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<Tag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
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
    if (data.containsKey('author_id')) {
      context.handle(
        _authorIdMeta,
        authorId.isAcceptableOrUnknown(data['author_id']!, _authorIdMeta),
      );
    } else if (isInserting) {
      context.missing(_authorIdMeta);
    }
    if (data.containsKey('is_shared')) {
      context.handle(
        _isSharedMeta,
        isShared.isAcceptableOrUnknown(data['is_shared']!, _isSharedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Tag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Tag(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      authorId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author_id'],
      )!,
      isShared: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_shared'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $TagsTable createAlias(String alias) {
    return $TagsTable(attachedDatabase, alias);
  }
}

class Tag extends DataClass implements Insertable<Tag> {
  final String id;
  final String name;
  final String? description;
  final String authorId;
  final bool isShared;
  final int createdAt;
  const Tag({
    required this.id,
    required this.name,
    this.description,
    required this.authorId,
    required this.isShared,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['author_id'] = Variable<String>(authorId);
    map['is_shared'] = Variable<bool>(isShared);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  TagsCompanion toCompanion(bool nullToAbsent) {
    return TagsCompanion(
      id: Value(id),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      authorId: Value(authorId),
      isShared: Value(isShared),
      createdAt: Value(createdAt),
    );
  }

  factory Tag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Tag(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      authorId: serializer.fromJson<String>(json['authorId']),
      isShared: serializer.fromJson<bool>(json['isShared']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'authorId': serializer.toJson<String>(authorId),
      'isShared': serializer.toJson<bool>(isShared),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  Tag copyWith({
    String? id,
    String? name,
    Value<String?> description = const Value.absent(),
    String? authorId,
    bool? isShared,
    int? createdAt,
  }) => Tag(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description.present ? description.value : this.description,
    authorId: authorId ?? this.authorId,
    isShared: isShared ?? this.isShared,
    createdAt: createdAt ?? this.createdAt,
  );
  Tag copyWithCompanion(TagsCompanion data) {
    return Tag(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      authorId: data.authorId.present ? data.authorId.value : this.authorId,
      isShared: data.isShared.present ? data.isShared.value : this.isShared,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Tag(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('authorId: $authorId, ')
          ..write('isShared: $isShared, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, description, authorId, isShared, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Tag &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.authorId == this.authorId &&
          other.isShared == this.isShared &&
          other.createdAt == this.createdAt);
}

class TagsCompanion extends UpdateCompanion<Tag> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> description;
  final Value<String> authorId;
  final Value<bool> isShared;
  final Value<int> createdAt;
  final Value<int> rowid;
  const TagsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.authorId = const Value.absent(),
    this.isShared = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TagsCompanion.insert({
    required String id,
    required String name,
    this.description = const Value.absent(),
    required String authorId,
    this.isShared = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       authorId = Value(authorId);
  static Insertable<Tag> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<String>? authorId,
    Expression<bool>? isShared,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (authorId != null) 'author_id': authorId,
      if (isShared != null) 'is_shared': isShared,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TagsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? description,
    Value<String>? authorId,
    Value<bool>? isShared,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return TagsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      authorId: authorId ?? this.authorId,
      isShared: isShared ?? this.isShared,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (authorId.present) {
      map['author_id'] = Variable<String>(authorId.value);
    }
    if (isShared.present) {
      map['is_shared'] = Variable<bool>(isShared.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TagsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('authorId: $authorId, ')
          ..write('isShared: $isShared, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PoiAnimesTable extends PoiAnimes
    with TableInfo<$PoiAnimesTable, PoiAnime> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PoiAnimesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _poiIdMeta = const VerificationMeta('poiId');
  @override
  late final GeneratedColumn<String> poiId = GeneratedColumn<String>(
    'poi_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES pois (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _animeIdMeta = const VerificationMeta(
    'animeId',
  );
  @override
  late final GeneratedColumn<String> animeId = GeneratedColumn<String>(
    'anime_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES animes (id) ON DELETE CASCADE',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [poiId, animeId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'poi_animes';
  @override
  VerificationContext validateIntegrity(
    Insertable<PoiAnime> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('poi_id')) {
      context.handle(
        _poiIdMeta,
        poiId.isAcceptableOrUnknown(data['poi_id']!, _poiIdMeta),
      );
    } else if (isInserting) {
      context.missing(_poiIdMeta);
    }
    if (data.containsKey('anime_id')) {
      context.handle(
        _animeIdMeta,
        animeId.isAcceptableOrUnknown(data['anime_id']!, _animeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_animeIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {poiId, animeId};
  @override
  PoiAnime map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PoiAnime(
      poiId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}poi_id'],
      )!,
      animeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}anime_id'],
      )!,
    );
  }

  @override
  $PoiAnimesTable createAlias(String alias) {
    return $PoiAnimesTable(attachedDatabase, alias);
  }
}

class PoiAnime extends DataClass implements Insertable<PoiAnime> {
  final String poiId;
  final String animeId;
  const PoiAnime({required this.poiId, required this.animeId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['poi_id'] = Variable<String>(poiId);
    map['anime_id'] = Variable<String>(animeId);
    return map;
  }

  PoiAnimesCompanion toCompanion(bool nullToAbsent) {
    return PoiAnimesCompanion(poiId: Value(poiId), animeId: Value(animeId));
  }

  factory PoiAnime.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PoiAnime(
      poiId: serializer.fromJson<String>(json['poiId']),
      animeId: serializer.fromJson<String>(json['animeId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'poiId': serializer.toJson<String>(poiId),
      'animeId': serializer.toJson<String>(animeId),
    };
  }

  PoiAnime copyWith({String? poiId, String? animeId}) =>
      PoiAnime(poiId: poiId ?? this.poiId, animeId: animeId ?? this.animeId);
  PoiAnime copyWithCompanion(PoiAnimesCompanion data) {
    return PoiAnime(
      poiId: data.poiId.present ? data.poiId.value : this.poiId,
      animeId: data.animeId.present ? data.animeId.value : this.animeId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PoiAnime(')
          ..write('poiId: $poiId, ')
          ..write('animeId: $animeId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(poiId, animeId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PoiAnime &&
          other.poiId == this.poiId &&
          other.animeId == this.animeId);
}

class PoiAnimesCompanion extends UpdateCompanion<PoiAnime> {
  final Value<String> poiId;
  final Value<String> animeId;
  final Value<int> rowid;
  const PoiAnimesCompanion({
    this.poiId = const Value.absent(),
    this.animeId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PoiAnimesCompanion.insert({
    required String poiId,
    required String animeId,
    this.rowid = const Value.absent(),
  }) : poiId = Value(poiId),
       animeId = Value(animeId);
  static Insertable<PoiAnime> custom({
    Expression<String>? poiId,
    Expression<String>? animeId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (poiId != null) 'poi_id': poiId,
      if (animeId != null) 'anime_id': animeId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PoiAnimesCompanion copyWith({
    Value<String>? poiId,
    Value<String>? animeId,
    Value<int>? rowid,
  }) {
    return PoiAnimesCompanion(
      poiId: poiId ?? this.poiId,
      animeId: animeId ?? this.animeId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (poiId.present) {
      map['poi_id'] = Variable<String>(poiId.value);
    }
    if (animeId.present) {
      map['anime_id'] = Variable<String>(animeId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PoiAnimesCompanion(')
          ..write('poiId: $poiId, ')
          ..write('animeId: $animeId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PoiTagsTable extends PoiTags with TableInfo<$PoiTagsTable, PoiTag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PoiTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _poiIdMeta = const VerificationMeta('poiId');
  @override
  late final GeneratedColumn<String> poiId = GeneratedColumn<String>(
    'poi_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES pois (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  @override
  late final GeneratedColumn<String> tagId = GeneratedColumn<String>(
    'tag_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tags (id) ON DELETE CASCADE',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [poiId, tagId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'poi_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<PoiTag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('poi_id')) {
      context.handle(
        _poiIdMeta,
        poiId.isAcceptableOrUnknown(data['poi_id']!, _poiIdMeta),
      );
    } else if (isInserting) {
      context.missing(_poiIdMeta);
    }
    if (data.containsKey('tag_id')) {
      context.handle(
        _tagIdMeta,
        tagId.isAcceptableOrUnknown(data['tag_id']!, _tagIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tagIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {poiId, tagId};
  @override
  PoiTag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PoiTag(
      poiId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}poi_id'],
      )!,
      tagId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag_id'],
      )!,
    );
  }

  @override
  $PoiTagsTable createAlias(String alias) {
    return $PoiTagsTable(attachedDatabase, alias);
  }
}

class PoiTag extends DataClass implements Insertable<PoiTag> {
  final String poiId;
  final String tagId;
  const PoiTag({required this.poiId, required this.tagId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['poi_id'] = Variable<String>(poiId);
    map['tag_id'] = Variable<String>(tagId);
    return map;
  }

  PoiTagsCompanion toCompanion(bool nullToAbsent) {
    return PoiTagsCompanion(poiId: Value(poiId), tagId: Value(tagId));
  }

  factory PoiTag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PoiTag(
      poiId: serializer.fromJson<String>(json['poiId']),
      tagId: serializer.fromJson<String>(json['tagId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'poiId': serializer.toJson<String>(poiId),
      'tagId': serializer.toJson<String>(tagId),
    };
  }

  PoiTag copyWith({String? poiId, String? tagId}) =>
      PoiTag(poiId: poiId ?? this.poiId, tagId: tagId ?? this.tagId);
  PoiTag copyWithCompanion(PoiTagsCompanion data) {
    return PoiTag(
      poiId: data.poiId.present ? data.poiId.value : this.poiId,
      tagId: data.tagId.present ? data.tagId.value : this.tagId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PoiTag(')
          ..write('poiId: $poiId, ')
          ..write('tagId: $tagId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(poiId, tagId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PoiTag &&
          other.poiId == this.poiId &&
          other.tagId == this.tagId);
}

class PoiTagsCompanion extends UpdateCompanion<PoiTag> {
  final Value<String> poiId;
  final Value<String> tagId;
  final Value<int> rowid;
  const PoiTagsCompanion({
    this.poiId = const Value.absent(),
    this.tagId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PoiTagsCompanion.insert({
    required String poiId,
    required String tagId,
    this.rowid = const Value.absent(),
  }) : poiId = Value(poiId),
       tagId = Value(tagId);
  static Insertable<PoiTag> custom({
    Expression<String>? poiId,
    Expression<String>? tagId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (poiId != null) 'poi_id': poiId,
      if (tagId != null) 'tag_id': tagId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PoiTagsCompanion copyWith({
    Value<String>? poiId,
    Value<String>? tagId,
    Value<int>? rowid,
  }) {
    return PoiTagsCompanion(
      poiId: poiId ?? this.poiId,
      tagId: tagId ?? this.tagId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (poiId.present) {
      map['poi_id'] = Variable<String>(poiId.value);
    }
    if (tagId.present) {
      map['tag_id'] = Variable<String>(tagId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PoiTagsCompanion(')
          ..write('poiId: $poiId, ')
          ..write('tagId: $tagId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TimeChunksTable extends TimeChunks
    with TableInfo<$TimeChunksTable, TimeChunk> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TimeChunksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _poiIdMeta = const VerificationMeta('poiId');
  @override
  late final GeneratedColumn<String> poiId = GeneratedColumn<String>(
    'poi_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES pois (id)',
    ),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startTimeMeta = const VerificationMeta(
    'startTime',
  );
  @override
  late final GeneratedColumn<String> startTime = GeneratedColumn<String>(
    'start_time',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endTimeMeta = const VerificationMeta(
    'endTime',
  );
  @override
  late final GeneratedColumn<String> endTime = GeneratedColumn<String>(
    'end_time',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('backlog'),
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
  static const VerificationMeta _durationMeta = const VerificationMeta(
    'duration',
  );
  @override
  late final GeneratedColumn<int> duration = GeneratedColumn<int>(
    'duration',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(60),
  );
  static const VerificationMeta _transitDurationMeta = const VerificationMeta(
    'transitDuration',
  );
  @override
  late final GeneratedColumn<int> transitDuration = GeneratedColumn<int>(
    'transit_duration',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isFixedTimeMeta = const VerificationMeta(
    'isFixedTime',
  );
  @override
  late final GeneratedColumn<bool> isFixedTime = GeneratedColumn<bool>(
    'is_fixed_time',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_fixed_time" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _authorIdMeta = const VerificationMeta(
    'authorId',
  );
  @override
  late final GeneratedColumn<String> authorId = GeneratedColumn<String>(
    'author_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isSharedMeta = const VerificationMeta(
    'isShared',
  );
  @override
  late final GeneratedColumn<bool> isShared = GeneratedColumn<bool>(
    'is_shared',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_shared" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    clientDefault: () => DateTime.now().millisecondsSinceEpoch,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<int> syncStatus = GeneratedColumn<int>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _hasEverSyncedMeta = const VerificationMeta(
    'hasEverSynced',
  );
  @override
  late final GeneratedColumn<bool> hasEverSynced = GeneratedColumn<bool>(
    'has_ever_synced',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_ever_synced" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _originalStartTimeMeta = const VerificationMeta(
    'originalStartTime',
  );
  @override
  late final GeneratedColumn<String> originalStartTime =
      GeneratedColumn<String>(
        'original_start_time',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _originalEndTimeMeta = const VerificationMeta(
    'originalEndTime',
  );
  @override
  late final GeneratedColumn<String> originalEndTime = GeneratedColumn<String>(
    'original_end_time',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastModifiedAtMeta = const VerificationMeta(
    'lastModifiedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastModifiedAt =
      GeneratedColumn<DateTime>(
        'last_modified_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    poiId,
    date,
    startTime,
    endTime,
    status,
    sortOrder,
    duration,
    transitDuration,
    isFixedTime,
    authorId,
    isShared,
    createdAt,
    syncStatus,
    isDeleted,
    hasEverSynced,
    originalStartTime,
    originalEndTime,
    lastModifiedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'time_chunks';
  @override
  VerificationContext validateIntegrity(
    Insertable<TimeChunk> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('poi_id')) {
      context.handle(
        _poiIdMeta,
        poiId.isAcceptableOrUnknown(data['poi_id']!, _poiIdMeta),
      );
    } else if (isInserting) {
      context.missing(_poiIdMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    }
    if (data.containsKey('start_time')) {
      context.handle(
        _startTimeMeta,
        startTime.isAcceptableOrUnknown(data['start_time']!, _startTimeMeta),
      );
    }
    if (data.containsKey('end_time')) {
      context.handle(
        _endTimeMeta,
        endTime.isAcceptableOrUnknown(data['end_time']!, _endTimeMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('duration')) {
      context.handle(
        _durationMeta,
        duration.isAcceptableOrUnknown(data['duration']!, _durationMeta),
      );
    }
    if (data.containsKey('transit_duration')) {
      context.handle(
        _transitDurationMeta,
        transitDuration.isAcceptableOrUnknown(
          data['transit_duration']!,
          _transitDurationMeta,
        ),
      );
    }
    if (data.containsKey('is_fixed_time')) {
      context.handle(
        _isFixedTimeMeta,
        isFixedTime.isAcceptableOrUnknown(
          data['is_fixed_time']!,
          _isFixedTimeMeta,
        ),
      );
    }
    if (data.containsKey('author_id')) {
      context.handle(
        _authorIdMeta,
        authorId.isAcceptableOrUnknown(data['author_id']!, _authorIdMeta),
      );
    } else if (isInserting) {
      context.missing(_authorIdMeta);
    }
    if (data.containsKey('is_shared')) {
      context.handle(
        _isSharedMeta,
        isShared.isAcceptableOrUnknown(data['is_shared']!, _isSharedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('has_ever_synced')) {
      context.handle(
        _hasEverSyncedMeta,
        hasEverSynced.isAcceptableOrUnknown(
          data['has_ever_synced']!,
          _hasEverSyncedMeta,
        ),
      );
    }
    if (data.containsKey('original_start_time')) {
      context.handle(
        _originalStartTimeMeta,
        originalStartTime.isAcceptableOrUnknown(
          data['original_start_time']!,
          _originalStartTimeMeta,
        ),
      );
    }
    if (data.containsKey('original_end_time')) {
      context.handle(
        _originalEndTimeMeta,
        originalEndTime.isAcceptableOrUnknown(
          data['original_end_time']!,
          _originalEndTimeMeta,
        ),
      );
    }
    if (data.containsKey('last_modified_at')) {
      context.handle(
        _lastModifiedAtMeta,
        lastModifiedAt.isAcceptableOrUnknown(
          data['last_modified_at']!,
          _lastModifiedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TimeChunk map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TimeChunk(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      poiId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}poi_id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      ),
      startTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}start_time'],
      ),
      endTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}end_time'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      duration: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration'],
      )!,
      transitDuration: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}transit_duration'],
      )!,
      isFixedTime: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_fixed_time'],
      )!,
      authorId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author_id'],
      )!,
      isShared: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_shared'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sync_status'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      hasEverSynced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_ever_synced'],
      )!,
      originalStartTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}original_start_time'],
      ),
      originalEndTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}original_end_time'],
      ),
      lastModifiedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_modified_at'],
      ),
    );
  }

  @override
  $TimeChunksTable createAlias(String alias) {
    return $TimeChunksTable(attachedDatabase, alias);
  }
}

class TimeChunk extends DataClass implements Insertable<TimeChunk> {
  final String id;
  final String poiId;
  final String? date;
  final String? startTime;
  final String? endTime;
  final String status;
  final int sortOrder;
  final int duration;
  final int transitDuration;
  final bool isFixedTime;
  final String authorId;
  final bool isShared;
  final int createdAt;
  final int syncStatus;
  final bool isDeleted;
  final bool hasEverSynced;
  final String? originalStartTime;
  final String? originalEndTime;
  final DateTime? lastModifiedAt;
  const TimeChunk({
    required this.id,
    required this.poiId,
    this.date,
    this.startTime,
    this.endTime,
    required this.status,
    required this.sortOrder,
    required this.duration,
    required this.transitDuration,
    required this.isFixedTime,
    required this.authorId,
    required this.isShared,
    required this.createdAt,
    required this.syncStatus,
    required this.isDeleted,
    required this.hasEverSynced,
    this.originalStartTime,
    this.originalEndTime,
    this.lastModifiedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['poi_id'] = Variable<String>(poiId);
    if (!nullToAbsent || date != null) {
      map['date'] = Variable<String>(date);
    }
    if (!nullToAbsent || startTime != null) {
      map['start_time'] = Variable<String>(startTime);
    }
    if (!nullToAbsent || endTime != null) {
      map['end_time'] = Variable<String>(endTime);
    }
    map['status'] = Variable<String>(status);
    map['sort_order'] = Variable<int>(sortOrder);
    map['duration'] = Variable<int>(duration);
    map['transit_duration'] = Variable<int>(transitDuration);
    map['is_fixed_time'] = Variable<bool>(isFixedTime);
    map['author_id'] = Variable<String>(authorId);
    map['is_shared'] = Variable<bool>(isShared);
    map['created_at'] = Variable<int>(createdAt);
    map['sync_status'] = Variable<int>(syncStatus);
    map['is_deleted'] = Variable<bool>(isDeleted);
    map['has_ever_synced'] = Variable<bool>(hasEverSynced);
    if (!nullToAbsent || originalStartTime != null) {
      map['original_start_time'] = Variable<String>(originalStartTime);
    }
    if (!nullToAbsent || originalEndTime != null) {
      map['original_end_time'] = Variable<String>(originalEndTime);
    }
    if (!nullToAbsent || lastModifiedAt != null) {
      map['last_modified_at'] = Variable<DateTime>(lastModifiedAt);
    }
    return map;
  }

  TimeChunksCompanion toCompanion(bool nullToAbsent) {
    return TimeChunksCompanion(
      id: Value(id),
      poiId: Value(poiId),
      date: date == null && nullToAbsent ? const Value.absent() : Value(date),
      startTime: startTime == null && nullToAbsent
          ? const Value.absent()
          : Value(startTime),
      endTime: endTime == null && nullToAbsent
          ? const Value.absent()
          : Value(endTime),
      status: Value(status),
      sortOrder: Value(sortOrder),
      duration: Value(duration),
      transitDuration: Value(transitDuration),
      isFixedTime: Value(isFixedTime),
      authorId: Value(authorId),
      isShared: Value(isShared),
      createdAt: Value(createdAt),
      syncStatus: Value(syncStatus),
      isDeleted: Value(isDeleted),
      hasEverSynced: Value(hasEverSynced),
      originalStartTime: originalStartTime == null && nullToAbsent
          ? const Value.absent()
          : Value(originalStartTime),
      originalEndTime: originalEndTime == null && nullToAbsent
          ? const Value.absent()
          : Value(originalEndTime),
      lastModifiedAt: lastModifiedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastModifiedAt),
    );
  }

  factory TimeChunk.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TimeChunk(
      id: serializer.fromJson<String>(json['id']),
      poiId: serializer.fromJson<String>(json['poiId']),
      date: serializer.fromJson<String?>(json['date']),
      startTime: serializer.fromJson<String?>(json['startTime']),
      endTime: serializer.fromJson<String?>(json['endTime']),
      status: serializer.fromJson<String>(json['status']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      duration: serializer.fromJson<int>(json['duration']),
      transitDuration: serializer.fromJson<int>(json['transitDuration']),
      isFixedTime: serializer.fromJson<bool>(json['isFixedTime']),
      authorId: serializer.fromJson<String>(json['authorId']),
      isShared: serializer.fromJson<bool>(json['isShared']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      syncStatus: serializer.fromJson<int>(json['syncStatus']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      hasEverSynced: serializer.fromJson<bool>(json['hasEverSynced']),
      originalStartTime: serializer.fromJson<String?>(
        json['originalStartTime'],
      ),
      originalEndTime: serializer.fromJson<String?>(json['originalEndTime']),
      lastModifiedAt: serializer.fromJson<DateTime?>(json['lastModifiedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'poiId': serializer.toJson<String>(poiId),
      'date': serializer.toJson<String?>(date),
      'startTime': serializer.toJson<String?>(startTime),
      'endTime': serializer.toJson<String?>(endTime),
      'status': serializer.toJson<String>(status),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'duration': serializer.toJson<int>(duration),
      'transitDuration': serializer.toJson<int>(transitDuration),
      'isFixedTime': serializer.toJson<bool>(isFixedTime),
      'authorId': serializer.toJson<String>(authorId),
      'isShared': serializer.toJson<bool>(isShared),
      'createdAt': serializer.toJson<int>(createdAt),
      'syncStatus': serializer.toJson<int>(syncStatus),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'hasEverSynced': serializer.toJson<bool>(hasEverSynced),
      'originalStartTime': serializer.toJson<String?>(originalStartTime),
      'originalEndTime': serializer.toJson<String?>(originalEndTime),
      'lastModifiedAt': serializer.toJson<DateTime?>(lastModifiedAt),
    };
  }

  TimeChunk copyWith({
    String? id,
    String? poiId,
    Value<String?> date = const Value.absent(),
    Value<String?> startTime = const Value.absent(),
    Value<String?> endTime = const Value.absent(),
    String? status,
    int? sortOrder,
    int? duration,
    int? transitDuration,
    bool? isFixedTime,
    String? authorId,
    bool? isShared,
    int? createdAt,
    int? syncStatus,
    bool? isDeleted,
    bool? hasEverSynced,
    Value<String?> originalStartTime = const Value.absent(),
    Value<String?> originalEndTime = const Value.absent(),
    Value<DateTime?> lastModifiedAt = const Value.absent(),
  }) => TimeChunk(
    id: id ?? this.id,
    poiId: poiId ?? this.poiId,
    date: date.present ? date.value : this.date,
    startTime: startTime.present ? startTime.value : this.startTime,
    endTime: endTime.present ? endTime.value : this.endTime,
    status: status ?? this.status,
    sortOrder: sortOrder ?? this.sortOrder,
    duration: duration ?? this.duration,
    transitDuration: transitDuration ?? this.transitDuration,
    isFixedTime: isFixedTime ?? this.isFixedTime,
    authorId: authorId ?? this.authorId,
    isShared: isShared ?? this.isShared,
    createdAt: createdAt ?? this.createdAt,
    syncStatus: syncStatus ?? this.syncStatus,
    isDeleted: isDeleted ?? this.isDeleted,
    hasEverSynced: hasEverSynced ?? this.hasEverSynced,
    originalStartTime: originalStartTime.present
        ? originalStartTime.value
        : this.originalStartTime,
    originalEndTime: originalEndTime.present
        ? originalEndTime.value
        : this.originalEndTime,
    lastModifiedAt: lastModifiedAt.present
        ? lastModifiedAt.value
        : this.lastModifiedAt,
  );
  TimeChunk copyWithCompanion(TimeChunksCompanion data) {
    return TimeChunk(
      id: data.id.present ? data.id.value : this.id,
      poiId: data.poiId.present ? data.poiId.value : this.poiId,
      date: data.date.present ? data.date.value : this.date,
      startTime: data.startTime.present ? data.startTime.value : this.startTime,
      endTime: data.endTime.present ? data.endTime.value : this.endTime,
      status: data.status.present ? data.status.value : this.status,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      duration: data.duration.present ? data.duration.value : this.duration,
      transitDuration: data.transitDuration.present
          ? data.transitDuration.value
          : this.transitDuration,
      isFixedTime: data.isFixedTime.present
          ? data.isFixedTime.value
          : this.isFixedTime,
      authorId: data.authorId.present ? data.authorId.value : this.authorId,
      isShared: data.isShared.present ? data.isShared.value : this.isShared,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      hasEverSynced: data.hasEverSynced.present
          ? data.hasEverSynced.value
          : this.hasEverSynced,
      originalStartTime: data.originalStartTime.present
          ? data.originalStartTime.value
          : this.originalStartTime,
      originalEndTime: data.originalEndTime.present
          ? data.originalEndTime.value
          : this.originalEndTime,
      lastModifiedAt: data.lastModifiedAt.present
          ? data.lastModifiedAt.value
          : this.lastModifiedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TimeChunk(')
          ..write('id: $id, ')
          ..write('poiId: $poiId, ')
          ..write('date: $date, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('status: $status, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('duration: $duration, ')
          ..write('transitDuration: $transitDuration, ')
          ..write('isFixedTime: $isFixedTime, ')
          ..write('authorId: $authorId, ')
          ..write('isShared: $isShared, ')
          ..write('createdAt: $createdAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('hasEverSynced: $hasEverSynced, ')
          ..write('originalStartTime: $originalStartTime, ')
          ..write('originalEndTime: $originalEndTime, ')
          ..write('lastModifiedAt: $lastModifiedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    poiId,
    date,
    startTime,
    endTime,
    status,
    sortOrder,
    duration,
    transitDuration,
    isFixedTime,
    authorId,
    isShared,
    createdAt,
    syncStatus,
    isDeleted,
    hasEverSynced,
    originalStartTime,
    originalEndTime,
    lastModifiedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TimeChunk &&
          other.id == this.id &&
          other.poiId == this.poiId &&
          other.date == this.date &&
          other.startTime == this.startTime &&
          other.endTime == this.endTime &&
          other.status == this.status &&
          other.sortOrder == this.sortOrder &&
          other.duration == this.duration &&
          other.transitDuration == this.transitDuration &&
          other.isFixedTime == this.isFixedTime &&
          other.authorId == this.authorId &&
          other.isShared == this.isShared &&
          other.createdAt == this.createdAt &&
          other.syncStatus == this.syncStatus &&
          other.isDeleted == this.isDeleted &&
          other.hasEverSynced == this.hasEverSynced &&
          other.originalStartTime == this.originalStartTime &&
          other.originalEndTime == this.originalEndTime &&
          other.lastModifiedAt == this.lastModifiedAt);
}

class TimeChunksCompanion extends UpdateCompanion<TimeChunk> {
  final Value<String> id;
  final Value<String> poiId;
  final Value<String?> date;
  final Value<String?> startTime;
  final Value<String?> endTime;
  final Value<String> status;
  final Value<int> sortOrder;
  final Value<int> duration;
  final Value<int> transitDuration;
  final Value<bool> isFixedTime;
  final Value<String> authorId;
  final Value<bool> isShared;
  final Value<int> createdAt;
  final Value<int> syncStatus;
  final Value<bool> isDeleted;
  final Value<bool> hasEverSynced;
  final Value<String?> originalStartTime;
  final Value<String?> originalEndTime;
  final Value<DateTime?> lastModifiedAt;
  final Value<int> rowid;
  const TimeChunksCompanion({
    this.id = const Value.absent(),
    this.poiId = const Value.absent(),
    this.date = const Value.absent(),
    this.startTime = const Value.absent(),
    this.endTime = const Value.absent(),
    this.status = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.duration = const Value.absent(),
    this.transitDuration = const Value.absent(),
    this.isFixedTime = const Value.absent(),
    this.authorId = const Value.absent(),
    this.isShared = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.hasEverSynced = const Value.absent(),
    this.originalStartTime = const Value.absent(),
    this.originalEndTime = const Value.absent(),
    this.lastModifiedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TimeChunksCompanion.insert({
    required String id,
    required String poiId,
    this.date = const Value.absent(),
    this.startTime = const Value.absent(),
    this.endTime = const Value.absent(),
    this.status = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.duration = const Value.absent(),
    this.transitDuration = const Value.absent(),
    this.isFixedTime = const Value.absent(),
    required String authorId,
    this.isShared = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.hasEverSynced = const Value.absent(),
    this.originalStartTime = const Value.absent(),
    this.originalEndTime = const Value.absent(),
    this.lastModifiedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       poiId = Value(poiId),
       authorId = Value(authorId);
  static Insertable<TimeChunk> custom({
    Expression<String>? id,
    Expression<String>? poiId,
    Expression<String>? date,
    Expression<String>? startTime,
    Expression<String>? endTime,
    Expression<String>? status,
    Expression<int>? sortOrder,
    Expression<int>? duration,
    Expression<int>? transitDuration,
    Expression<bool>? isFixedTime,
    Expression<String>? authorId,
    Expression<bool>? isShared,
    Expression<int>? createdAt,
    Expression<int>? syncStatus,
    Expression<bool>? isDeleted,
    Expression<bool>? hasEverSynced,
    Expression<String>? originalStartTime,
    Expression<String>? originalEndTime,
    Expression<DateTime>? lastModifiedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (poiId != null) 'poi_id': poiId,
      if (date != null) 'date': date,
      if (startTime != null) 'start_time': startTime,
      if (endTime != null) 'end_time': endTime,
      if (status != null) 'status': status,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (duration != null) 'duration': duration,
      if (transitDuration != null) 'transit_duration': transitDuration,
      if (isFixedTime != null) 'is_fixed_time': isFixedTime,
      if (authorId != null) 'author_id': authorId,
      if (isShared != null) 'is_shared': isShared,
      if (createdAt != null) 'created_at': createdAt,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (hasEverSynced != null) 'has_ever_synced': hasEverSynced,
      if (originalStartTime != null) 'original_start_time': originalStartTime,
      if (originalEndTime != null) 'original_end_time': originalEndTime,
      if (lastModifiedAt != null) 'last_modified_at': lastModifiedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TimeChunksCompanion copyWith({
    Value<String>? id,
    Value<String>? poiId,
    Value<String?>? date,
    Value<String?>? startTime,
    Value<String?>? endTime,
    Value<String>? status,
    Value<int>? sortOrder,
    Value<int>? duration,
    Value<int>? transitDuration,
    Value<bool>? isFixedTime,
    Value<String>? authorId,
    Value<bool>? isShared,
    Value<int>? createdAt,
    Value<int>? syncStatus,
    Value<bool>? isDeleted,
    Value<bool>? hasEverSynced,
    Value<String?>? originalStartTime,
    Value<String?>? originalEndTime,
    Value<DateTime?>? lastModifiedAt,
    Value<int>? rowid,
  }) {
    return TimeChunksCompanion(
      id: id ?? this.id,
      poiId: poiId ?? this.poiId,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      sortOrder: sortOrder ?? this.sortOrder,
      duration: duration ?? this.duration,
      transitDuration: transitDuration ?? this.transitDuration,
      isFixedTime: isFixedTime ?? this.isFixedTime,
      authorId: authorId ?? this.authorId,
      isShared: isShared ?? this.isShared,
      createdAt: createdAt ?? this.createdAt,
      syncStatus: syncStatus ?? this.syncStatus,
      isDeleted: isDeleted ?? this.isDeleted,
      hasEverSynced: hasEverSynced ?? this.hasEverSynced,
      originalStartTime: originalStartTime ?? this.originalStartTime,
      originalEndTime: originalEndTime ?? this.originalEndTime,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (poiId.present) {
      map['poi_id'] = Variable<String>(poiId.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (startTime.present) {
      map['start_time'] = Variable<String>(startTime.value);
    }
    if (endTime.present) {
      map['end_time'] = Variable<String>(endTime.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (duration.present) {
      map['duration'] = Variable<int>(duration.value);
    }
    if (transitDuration.present) {
      map['transit_duration'] = Variable<int>(transitDuration.value);
    }
    if (isFixedTime.present) {
      map['is_fixed_time'] = Variable<bool>(isFixedTime.value);
    }
    if (authorId.present) {
      map['author_id'] = Variable<String>(authorId.value);
    }
    if (isShared.present) {
      map['is_shared'] = Variable<bool>(isShared.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<int>(syncStatus.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (hasEverSynced.present) {
      map['has_ever_synced'] = Variable<bool>(hasEverSynced.value);
    }
    if (originalStartTime.present) {
      map['original_start_time'] = Variable<String>(originalStartTime.value);
    }
    if (originalEndTime.present) {
      map['original_end_time'] = Variable<String>(originalEndTime.value);
    }
    if (lastModifiedAt.present) {
      map['last_modified_at'] = Variable<DateTime>(lastModifiedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TimeChunksCompanion(')
          ..write('id: $id, ')
          ..write('poiId: $poiId, ')
          ..write('date: $date, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('status: $status, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('duration: $duration, ')
          ..write('transitDuration: $transitDuration, ')
          ..write('isFixedTime: $isFixedTime, ')
          ..write('authorId: $authorId, ')
          ..write('isShared: $isShared, ')
          ..write('createdAt: $createdAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('hasEverSynced: $hasEverSynced, ')
          ..write('originalStartTime: $originalStartTime, ')
          ..write('originalEndTime: $originalEndTime, ')
          ..write('lastModifiedAt: $lastModifiedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReferenceImagesTable extends ReferenceImages
    with TableInfo<$ReferenceImagesTable, ReferenceImage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReferenceImagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _poiIdMeta = const VerificationMeta('poiId');
  @override
  late final GeneratedColumn<String> poiId = GeneratedColumn<String>(
    'poi_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES pois (id)',
    ),
  );
  static const VerificationMeta _authorIdMeta = const VerificationMeta(
    'authorId',
  );
  @override
  late final GeneratedColumn<String> authorId = GeneratedColumn<String>(
    'author_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localPathMeta = const VerificationMeta(
    'localPath',
  );
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
    'local_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _remoteUrlMeta = const VerificationMeta(
    'remoteUrl',
  );
  @override
  late final GeneratedColumn<String> remoteUrl = GeneratedColumn<String>(
    'remote_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _metadataMeta = const VerificationMeta(
    'metadata',
  );
  @override
  late final GeneratedColumn<String> metadata = GeneratedColumn<String>(
    'metadata',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    clientDefault: () => DateTime.now().millisecondsSinceEpoch,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    poiId,
    authorId,
    localPath,
    remoteUrl,
    metadata,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reference_images';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReferenceImage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('poi_id')) {
      context.handle(
        _poiIdMeta,
        poiId.isAcceptableOrUnknown(data['poi_id']!, _poiIdMeta),
      );
    } else if (isInserting) {
      context.missing(_poiIdMeta);
    }
    if (data.containsKey('author_id')) {
      context.handle(
        _authorIdMeta,
        authorId.isAcceptableOrUnknown(data['author_id']!, _authorIdMeta),
      );
    } else if (isInserting) {
      context.missing(_authorIdMeta);
    }
    if (data.containsKey('local_path')) {
      context.handle(
        _localPathMeta,
        localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta),
      );
    }
    if (data.containsKey('remote_url')) {
      context.handle(
        _remoteUrlMeta,
        remoteUrl.isAcceptableOrUnknown(data['remote_url']!, _remoteUrlMeta),
      );
    }
    if (data.containsKey('metadata')) {
      context.handle(
        _metadataMeta,
        metadata.isAcceptableOrUnknown(data['metadata']!, _metadataMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReferenceImage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReferenceImage(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      poiId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}poi_id'],
      )!,
      authorId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author_id'],
      )!,
      localPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_path'],
      ),
      remoteUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_url'],
      ),
      metadata: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metadata'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ReferenceImagesTable createAlias(String alias) {
    return $ReferenceImagesTable(attachedDatabase, alias);
  }
}

class ReferenceImage extends DataClass implements Insertable<ReferenceImage> {
  final String id;
  final String poiId;
  final String authorId;
  final String? localPath;
  final String? remoteUrl;
  final String? metadata;
  final int createdAt;
  const ReferenceImage({
    required this.id,
    required this.poiId,
    required this.authorId,
    this.localPath,
    this.remoteUrl,
    this.metadata,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['poi_id'] = Variable<String>(poiId);
    map['author_id'] = Variable<String>(authorId);
    if (!nullToAbsent || localPath != null) {
      map['local_path'] = Variable<String>(localPath);
    }
    if (!nullToAbsent || remoteUrl != null) {
      map['remote_url'] = Variable<String>(remoteUrl);
    }
    if (!nullToAbsent || metadata != null) {
      map['metadata'] = Variable<String>(metadata);
    }
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  ReferenceImagesCompanion toCompanion(bool nullToAbsent) {
    return ReferenceImagesCompanion(
      id: Value(id),
      poiId: Value(poiId),
      authorId: Value(authorId),
      localPath: localPath == null && nullToAbsent
          ? const Value.absent()
          : Value(localPath),
      remoteUrl: remoteUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteUrl),
      metadata: metadata == null && nullToAbsent
          ? const Value.absent()
          : Value(metadata),
      createdAt: Value(createdAt),
    );
  }

  factory ReferenceImage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReferenceImage(
      id: serializer.fromJson<String>(json['id']),
      poiId: serializer.fromJson<String>(json['poiId']),
      authorId: serializer.fromJson<String>(json['authorId']),
      localPath: serializer.fromJson<String?>(json['localPath']),
      remoteUrl: serializer.fromJson<String?>(json['remoteUrl']),
      metadata: serializer.fromJson<String?>(json['metadata']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'poiId': serializer.toJson<String>(poiId),
      'authorId': serializer.toJson<String>(authorId),
      'localPath': serializer.toJson<String?>(localPath),
      'remoteUrl': serializer.toJson<String?>(remoteUrl),
      'metadata': serializer.toJson<String?>(metadata),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  ReferenceImage copyWith({
    String? id,
    String? poiId,
    String? authorId,
    Value<String?> localPath = const Value.absent(),
    Value<String?> remoteUrl = const Value.absent(),
    Value<String?> metadata = const Value.absent(),
    int? createdAt,
  }) => ReferenceImage(
    id: id ?? this.id,
    poiId: poiId ?? this.poiId,
    authorId: authorId ?? this.authorId,
    localPath: localPath.present ? localPath.value : this.localPath,
    remoteUrl: remoteUrl.present ? remoteUrl.value : this.remoteUrl,
    metadata: metadata.present ? metadata.value : this.metadata,
    createdAt: createdAt ?? this.createdAt,
  );
  ReferenceImage copyWithCompanion(ReferenceImagesCompanion data) {
    return ReferenceImage(
      id: data.id.present ? data.id.value : this.id,
      poiId: data.poiId.present ? data.poiId.value : this.poiId,
      authorId: data.authorId.present ? data.authorId.value : this.authorId,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      remoteUrl: data.remoteUrl.present ? data.remoteUrl.value : this.remoteUrl,
      metadata: data.metadata.present ? data.metadata.value : this.metadata,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReferenceImage(')
          ..write('id: $id, ')
          ..write('poiId: $poiId, ')
          ..write('authorId: $authorId, ')
          ..write('localPath: $localPath, ')
          ..write('remoteUrl: $remoteUrl, ')
          ..write('metadata: $metadata, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    poiId,
    authorId,
    localPath,
    remoteUrl,
    metadata,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReferenceImage &&
          other.id == this.id &&
          other.poiId == this.poiId &&
          other.authorId == this.authorId &&
          other.localPath == this.localPath &&
          other.remoteUrl == this.remoteUrl &&
          other.metadata == this.metadata &&
          other.createdAt == this.createdAt);
}

class ReferenceImagesCompanion extends UpdateCompanion<ReferenceImage> {
  final Value<String> id;
  final Value<String> poiId;
  final Value<String> authorId;
  final Value<String?> localPath;
  final Value<String?> remoteUrl;
  final Value<String?> metadata;
  final Value<int> createdAt;
  final Value<int> rowid;
  const ReferenceImagesCompanion({
    this.id = const Value.absent(),
    this.poiId = const Value.absent(),
    this.authorId = const Value.absent(),
    this.localPath = const Value.absent(),
    this.remoteUrl = const Value.absent(),
    this.metadata = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReferenceImagesCompanion.insert({
    required String id,
    required String poiId,
    required String authorId,
    this.localPath = const Value.absent(),
    this.remoteUrl = const Value.absent(),
    this.metadata = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       poiId = Value(poiId),
       authorId = Value(authorId);
  static Insertable<ReferenceImage> custom({
    Expression<String>? id,
    Expression<String>? poiId,
    Expression<String>? authorId,
    Expression<String>? localPath,
    Expression<String>? remoteUrl,
    Expression<String>? metadata,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (poiId != null) 'poi_id': poiId,
      if (authorId != null) 'author_id': authorId,
      if (localPath != null) 'local_path': localPath,
      if (remoteUrl != null) 'remote_url': remoteUrl,
      if (metadata != null) 'metadata': metadata,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReferenceImagesCompanion copyWith({
    Value<String>? id,
    Value<String>? poiId,
    Value<String>? authorId,
    Value<String?>? localPath,
    Value<String?>? remoteUrl,
    Value<String?>? metadata,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return ReferenceImagesCompanion(
      id: id ?? this.id,
      poiId: poiId ?? this.poiId,
      authorId: authorId ?? this.authorId,
      localPath: localPath ?? this.localPath,
      remoteUrl: remoteUrl ?? this.remoteUrl,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (poiId.present) {
      map['poi_id'] = Variable<String>(poiId.value);
    }
    if (authorId.present) {
      map['author_id'] = Variable<String>(authorId.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (remoteUrl.present) {
      map['remote_url'] = Variable<String>(remoteUrl.value);
    }
    if (metadata.present) {
      map['metadata'] = Variable<String>(metadata.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReferenceImagesCompanion(')
          ..write('id: $id, ')
          ..write('poiId: $poiId, ')
          ..write('authorId: $authorId, ')
          ..write('localPath: $localPath, ')
          ..write('remoteUrl: $remoteUrl, ')
          ..write('metadata: $metadata, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MediaAssetsTable extends MediaAssets
    with TableInfo<$MediaAssetsTable, MediaAsset> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MediaAssetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _poiIdMeta = const VerificationMeta('poiId');
  @override
  late final GeneratedColumn<String> poiId = GeneratedColumn<String>(
    'poi_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES pois (id)',
    ),
  );
  static const VerificationMeta _authorIdMeta = const VerificationMeta(
    'authorId',
  );
  @override
  late final GeneratedColumn<String> authorId = GeneratedColumn<String>(
    'author_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localPathMeta = const VerificationMeta(
    'localPath',
  );
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
    'local_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _remoteUrlMeta = const VerificationMeta(
    'remoteUrl',
  );
  @override
  late final GeneratedColumn<String> remoteUrl = GeneratedColumn<String>(
    'remote_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _metadataMeta = const VerificationMeta(
    'metadata',
  );
  @override
  late final GeneratedColumn<String> metadata = GeneratedColumn<String>(
    'metadata',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _referenceImageIdMeta = const VerificationMeta(
    'referenceImageId',
  );
  @override
  late final GeneratedColumn<String> referenceImageId = GeneratedColumn<String>(
    'reference_image_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES reference_images (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    clientDefault: () => DateTime.now().millisecondsSinceEpoch,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    poiId,
    authorId,
    type,
    localPath,
    remoteUrl,
    metadata,
    referenceImageId,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'media_assets';
  @override
  VerificationContext validateIntegrity(
    Insertable<MediaAsset> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('poi_id')) {
      context.handle(
        _poiIdMeta,
        poiId.isAcceptableOrUnknown(data['poi_id']!, _poiIdMeta),
      );
    } else if (isInserting) {
      context.missing(_poiIdMeta);
    }
    if (data.containsKey('author_id')) {
      context.handle(
        _authorIdMeta,
        authorId.isAcceptableOrUnknown(data['author_id']!, _authorIdMeta),
      );
    } else if (isInserting) {
      context.missing(_authorIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('local_path')) {
      context.handle(
        _localPathMeta,
        localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta),
      );
    }
    if (data.containsKey('remote_url')) {
      context.handle(
        _remoteUrlMeta,
        remoteUrl.isAcceptableOrUnknown(data['remote_url']!, _remoteUrlMeta),
      );
    }
    if (data.containsKey('metadata')) {
      context.handle(
        _metadataMeta,
        metadata.isAcceptableOrUnknown(data['metadata']!, _metadataMeta),
      );
    }
    if (data.containsKey('reference_image_id')) {
      context.handle(
        _referenceImageIdMeta,
        referenceImageId.isAcceptableOrUnknown(
          data['reference_image_id']!,
          _referenceImageIdMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MediaAsset map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MediaAsset(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      poiId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}poi_id'],
      )!,
      authorId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      localPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_path'],
      ),
      remoteUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_url'],
      ),
      metadata: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metadata'],
      ),
      referenceImageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reference_image_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $MediaAssetsTable createAlias(String alias) {
    return $MediaAssetsTable(attachedDatabase, alias);
  }
}

class MediaAsset extends DataClass implements Insertable<MediaAsset> {
  final String id;
  final String poiId;
  final String authorId;
  final String type;
  final String? localPath;
  final String? remoteUrl;
  final String? metadata;
  final String? referenceImageId;
  final int createdAt;
  const MediaAsset({
    required this.id,
    required this.poiId,
    required this.authorId,
    required this.type,
    this.localPath,
    this.remoteUrl,
    this.metadata,
    this.referenceImageId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['poi_id'] = Variable<String>(poiId);
    map['author_id'] = Variable<String>(authorId);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || localPath != null) {
      map['local_path'] = Variable<String>(localPath);
    }
    if (!nullToAbsent || remoteUrl != null) {
      map['remote_url'] = Variable<String>(remoteUrl);
    }
    if (!nullToAbsent || metadata != null) {
      map['metadata'] = Variable<String>(metadata);
    }
    if (!nullToAbsent || referenceImageId != null) {
      map['reference_image_id'] = Variable<String>(referenceImageId);
    }
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  MediaAssetsCompanion toCompanion(bool nullToAbsent) {
    return MediaAssetsCompanion(
      id: Value(id),
      poiId: Value(poiId),
      authorId: Value(authorId),
      type: Value(type),
      localPath: localPath == null && nullToAbsent
          ? const Value.absent()
          : Value(localPath),
      remoteUrl: remoteUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteUrl),
      metadata: metadata == null && nullToAbsent
          ? const Value.absent()
          : Value(metadata),
      referenceImageId: referenceImageId == null && nullToAbsent
          ? const Value.absent()
          : Value(referenceImageId),
      createdAt: Value(createdAt),
    );
  }

  factory MediaAsset.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MediaAsset(
      id: serializer.fromJson<String>(json['id']),
      poiId: serializer.fromJson<String>(json['poiId']),
      authorId: serializer.fromJson<String>(json['authorId']),
      type: serializer.fromJson<String>(json['type']),
      localPath: serializer.fromJson<String?>(json['localPath']),
      remoteUrl: serializer.fromJson<String?>(json['remoteUrl']),
      metadata: serializer.fromJson<String?>(json['metadata']),
      referenceImageId: serializer.fromJson<String?>(json['referenceImageId']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'poiId': serializer.toJson<String>(poiId),
      'authorId': serializer.toJson<String>(authorId),
      'type': serializer.toJson<String>(type),
      'localPath': serializer.toJson<String?>(localPath),
      'remoteUrl': serializer.toJson<String?>(remoteUrl),
      'metadata': serializer.toJson<String?>(metadata),
      'referenceImageId': serializer.toJson<String?>(referenceImageId),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  MediaAsset copyWith({
    String? id,
    String? poiId,
    String? authorId,
    String? type,
    Value<String?> localPath = const Value.absent(),
    Value<String?> remoteUrl = const Value.absent(),
    Value<String?> metadata = const Value.absent(),
    Value<String?> referenceImageId = const Value.absent(),
    int? createdAt,
  }) => MediaAsset(
    id: id ?? this.id,
    poiId: poiId ?? this.poiId,
    authorId: authorId ?? this.authorId,
    type: type ?? this.type,
    localPath: localPath.present ? localPath.value : this.localPath,
    remoteUrl: remoteUrl.present ? remoteUrl.value : this.remoteUrl,
    metadata: metadata.present ? metadata.value : this.metadata,
    referenceImageId: referenceImageId.present
        ? referenceImageId.value
        : this.referenceImageId,
    createdAt: createdAt ?? this.createdAt,
  );
  MediaAsset copyWithCompanion(MediaAssetsCompanion data) {
    return MediaAsset(
      id: data.id.present ? data.id.value : this.id,
      poiId: data.poiId.present ? data.poiId.value : this.poiId,
      authorId: data.authorId.present ? data.authorId.value : this.authorId,
      type: data.type.present ? data.type.value : this.type,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      remoteUrl: data.remoteUrl.present ? data.remoteUrl.value : this.remoteUrl,
      metadata: data.metadata.present ? data.metadata.value : this.metadata,
      referenceImageId: data.referenceImageId.present
          ? data.referenceImageId.value
          : this.referenceImageId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MediaAsset(')
          ..write('id: $id, ')
          ..write('poiId: $poiId, ')
          ..write('authorId: $authorId, ')
          ..write('type: $type, ')
          ..write('localPath: $localPath, ')
          ..write('remoteUrl: $remoteUrl, ')
          ..write('metadata: $metadata, ')
          ..write('referenceImageId: $referenceImageId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    poiId,
    authorId,
    type,
    localPath,
    remoteUrl,
    metadata,
    referenceImageId,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MediaAsset &&
          other.id == this.id &&
          other.poiId == this.poiId &&
          other.authorId == this.authorId &&
          other.type == this.type &&
          other.localPath == this.localPath &&
          other.remoteUrl == this.remoteUrl &&
          other.metadata == this.metadata &&
          other.referenceImageId == this.referenceImageId &&
          other.createdAt == this.createdAt);
}

class MediaAssetsCompanion extends UpdateCompanion<MediaAsset> {
  final Value<String> id;
  final Value<String> poiId;
  final Value<String> authorId;
  final Value<String> type;
  final Value<String?> localPath;
  final Value<String?> remoteUrl;
  final Value<String?> metadata;
  final Value<String?> referenceImageId;
  final Value<int> createdAt;
  final Value<int> rowid;
  const MediaAssetsCompanion({
    this.id = const Value.absent(),
    this.poiId = const Value.absent(),
    this.authorId = const Value.absent(),
    this.type = const Value.absent(),
    this.localPath = const Value.absent(),
    this.remoteUrl = const Value.absent(),
    this.metadata = const Value.absent(),
    this.referenceImageId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MediaAssetsCompanion.insert({
    required String id,
    required String poiId,
    required String authorId,
    required String type,
    this.localPath = const Value.absent(),
    this.remoteUrl = const Value.absent(),
    this.metadata = const Value.absent(),
    this.referenceImageId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       poiId = Value(poiId),
       authorId = Value(authorId),
       type = Value(type);
  static Insertable<MediaAsset> custom({
    Expression<String>? id,
    Expression<String>? poiId,
    Expression<String>? authorId,
    Expression<String>? type,
    Expression<String>? localPath,
    Expression<String>? remoteUrl,
    Expression<String>? metadata,
    Expression<String>? referenceImageId,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (poiId != null) 'poi_id': poiId,
      if (authorId != null) 'author_id': authorId,
      if (type != null) 'type': type,
      if (localPath != null) 'local_path': localPath,
      if (remoteUrl != null) 'remote_url': remoteUrl,
      if (metadata != null) 'metadata': metadata,
      if (referenceImageId != null) 'reference_image_id': referenceImageId,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MediaAssetsCompanion copyWith({
    Value<String>? id,
    Value<String>? poiId,
    Value<String>? authorId,
    Value<String>? type,
    Value<String?>? localPath,
    Value<String?>? remoteUrl,
    Value<String?>? metadata,
    Value<String?>? referenceImageId,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return MediaAssetsCompanion(
      id: id ?? this.id,
      poiId: poiId ?? this.poiId,
      authorId: authorId ?? this.authorId,
      type: type ?? this.type,
      localPath: localPath ?? this.localPath,
      remoteUrl: remoteUrl ?? this.remoteUrl,
      metadata: metadata ?? this.metadata,
      referenceImageId: referenceImageId ?? this.referenceImageId,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (poiId.present) {
      map['poi_id'] = Variable<String>(poiId.value);
    }
    if (authorId.present) {
      map['author_id'] = Variable<String>(authorId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (remoteUrl.present) {
      map['remote_url'] = Variable<String>(remoteUrl.value);
    }
    if (metadata.present) {
      map['metadata'] = Variable<String>(metadata.value);
    }
    if (referenceImageId.present) {
      map['reference_image_id'] = Variable<String>(referenceImageId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MediaAssetsCompanion(')
          ..write('id: $id, ')
          ..write('poiId: $poiId, ')
          ..write('authorId: $authorId, ')
          ..write('type: $type, ')
          ..write('localPath: $localPath, ')
          ..write('remoteUrl: $remoteUrl, ')
          ..write('metadata: $metadata, ')
          ..write('referenceImageId: $referenceImageId, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlacesTable extends Places with TableInfo<$PlacesTable, Place> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlacesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _placeKeyMeta = const VerificationMeta(
    'placeKey',
  );
  @override
  late final GeneratedColumn<String> placeKey = GeneratedColumn<String>(
    'place_key',
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
  static const VerificationMeta _latMeta = const VerificationMeta('lat');
  @override
  late final GeneratedColumn<double> lat = GeneratedColumn<double>(
    'lat',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lngMeta = const VerificationMeta('lng');
  @override
  late final GeneratedColumn<double> lng = GeneratedColumn<double>(
    'lng',
    aliasedName,
    false,
    type: DriftSqlType.double,
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
  static const VerificationMeta _addressMeta = const VerificationMeta(
    'address',
  );
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
    'address',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _businessHoursMeta = const VerificationMeta(
    'businessHours',
  );
  @override
  late final GeneratedColumn<String> businessHours = GeneratedColumn<String>(
    'business_hours',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contactInfoMeta = const VerificationMeta(
    'contactInfo',
  );
  @override
  late final GeneratedColumn<String> contactInfo = GeneratedColumn<String>(
    'contact_info',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _accessTipsMeta = const VerificationMeta(
    'accessTips',
  );
  @override
  late final GeneratedColumn<String> accessTips = GeneratedColumn<String>(
    'access_tips',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _linksMeta = const VerificationMeta('links');
  @override
  late final GeneratedColumn<String> links = GeneratedColumn<String>(
    'links',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverLocalPathMeta = const VerificationMeta(
    'coverLocalPath',
  );
  @override
  late final GeneratedColumn<String> coverLocalPath = GeneratedColumn<String>(
    'cover_local_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverRemoteUrlMeta = const VerificationMeta(
    'coverRemoteUrl',
  );
  @override
  late final GeneratedColumn<String> coverRemoteUrl = GeneratedColumn<String>(
    'cover_remote_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceUrlMeta = const VerificationMeta(
    'sourceUrl',
  );
  @override
  late final GeneratedColumn<String> sourceUrl = GeneratedColumn<String>(
    'source_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _privateNoteMeta = const VerificationMeta(
    'privateNote',
  );
  @override
  late final GeneratedColumn<String> privateNote = GeneratedColumn<String>(
    'private_note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _visibilityMeta = const VerificationMeta(
    'visibility',
  );
  @override
  late final GeneratedColumn<String> visibility = GeneratedColumn<String>(
    'visibility',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('saved'),
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
    clientDefault: () => DateTime.now(),
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> updatedAt =
      GeneratedColumn<int>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        clientDefault: () => DateTime.now().millisecondsSinceEpoch,
      ).withConverter<DateTime>($PlacesTable.$converterupdatedAt);
  @override
  List<GeneratedColumn> get $columns => [
    placeKey,
    name,
    lat,
    lng,
    description,
    address,
    businessHours,
    contactInfo,
    accessTips,
    links,
    coverLocalPath,
    coverRemoteUrl,
    source,
    sourceUrl,
    privateNote,
    visibility,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'places';
  @override
  VerificationContext validateIntegrity(
    Insertable<Place> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('place_key')) {
      context.handle(
        _placeKeyMeta,
        placeKey.isAcceptableOrUnknown(data['place_key']!, _placeKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_placeKeyMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('lat')) {
      context.handle(
        _latMeta,
        lat.isAcceptableOrUnknown(data['lat']!, _latMeta),
      );
    } else if (isInserting) {
      context.missing(_latMeta);
    }
    if (data.containsKey('lng')) {
      context.handle(
        _lngMeta,
        lng.isAcceptableOrUnknown(data['lng']!, _lngMeta),
      );
    } else if (isInserting) {
      context.missing(_lngMeta);
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
    if (data.containsKey('address')) {
      context.handle(
        _addressMeta,
        address.isAcceptableOrUnknown(data['address']!, _addressMeta),
      );
    }
    if (data.containsKey('business_hours')) {
      context.handle(
        _businessHoursMeta,
        businessHours.isAcceptableOrUnknown(
          data['business_hours']!,
          _businessHoursMeta,
        ),
      );
    }
    if (data.containsKey('contact_info')) {
      context.handle(
        _contactInfoMeta,
        contactInfo.isAcceptableOrUnknown(
          data['contact_info']!,
          _contactInfoMeta,
        ),
      );
    }
    if (data.containsKey('access_tips')) {
      context.handle(
        _accessTipsMeta,
        accessTips.isAcceptableOrUnknown(data['access_tips']!, _accessTipsMeta),
      );
    }
    if (data.containsKey('links')) {
      context.handle(
        _linksMeta,
        links.isAcceptableOrUnknown(data['links']!, _linksMeta),
      );
    }
    if (data.containsKey('cover_local_path')) {
      context.handle(
        _coverLocalPathMeta,
        coverLocalPath.isAcceptableOrUnknown(
          data['cover_local_path']!,
          _coverLocalPathMeta,
        ),
      );
    }
    if (data.containsKey('cover_remote_url')) {
      context.handle(
        _coverRemoteUrlMeta,
        coverRemoteUrl.isAcceptableOrUnknown(
          data['cover_remote_url']!,
          _coverRemoteUrlMeta,
        ),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('source_url')) {
      context.handle(
        _sourceUrlMeta,
        sourceUrl.isAcceptableOrUnknown(data['source_url']!, _sourceUrlMeta),
      );
    }
    if (data.containsKey('private_note')) {
      context.handle(
        _privateNoteMeta,
        privateNote.isAcceptableOrUnknown(
          data['private_note']!,
          _privateNoteMeta,
        ),
      );
    }
    if (data.containsKey('visibility')) {
      context.handle(
        _visibilityMeta,
        visibility.isAcceptableOrUnknown(data['visibility']!, _visibilityMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {placeKey};
  @override
  Place map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Place(
      placeKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}place_key'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      lat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lat'],
      )!,
      lng: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lng'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      address: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address'],
      ),
      businessHours: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}business_hours'],
      ),
      contactInfo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}contact_info'],
      ),
      accessTips: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}access_tips'],
      ),
      links: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}links'],
      ),
      coverLocalPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_local_path'],
      ),
      coverRemoteUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_remote_url'],
      ),
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      ),
      sourceUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_url'],
      ),
      privateNote: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}private_note'],
      ),
      visibility: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}visibility'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: $PlacesTable.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
    );
  }

  @override
  $PlacesTable createAlias(String alias) {
    return $PlacesTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converterupdatedAt =
      const MillisecondDateTimeConverter();
}

class Place extends DataClass implements Insertable<Place> {
  /// The spot's global identity: `anitabi:<pointId>` for Anitabi imports, UUID for user-created.
  final String placeKey;
  final String name;
  final double lat;
  final double lng;
  final String? description;
  final String? address;
  final String? businessHours;
  final String? contactInfo;

  /// Tips on how to get there and optimal lighting/angles for photos.
  final String? accessTips;

  /// External links (Google Maps, Anitabi web page, etc.).
  final String? links;
  final String? coverLocalPath;
  final String? coverRemoteUrl;

  /// Attribution data (e.g. "Anitabi", origin URL for CC BY-NC-SA 4.0).
  final String? source;
  final String? sourceUrl;

  /// Personal private notes (visible only to the device owner).
  final String? privateNote;

  /// Visibility: 'saved' (shown in library) or 'trip_only' (hidden library entry created for a trip).
  final String visibility;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Place({
    required this.placeKey,
    required this.name,
    required this.lat,
    required this.lng,
    this.description,
    this.address,
    this.businessHours,
    this.contactInfo,
    this.accessTips,
    this.links,
    this.coverLocalPath,
    this.coverRemoteUrl,
    this.source,
    this.sourceUrl,
    this.privateNote,
    required this.visibility,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['place_key'] = Variable<String>(placeKey);
    map['name'] = Variable<String>(name);
    map['lat'] = Variable<double>(lat);
    map['lng'] = Variable<double>(lng);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || address != null) {
      map['address'] = Variable<String>(address);
    }
    if (!nullToAbsent || businessHours != null) {
      map['business_hours'] = Variable<String>(businessHours);
    }
    if (!nullToAbsent || contactInfo != null) {
      map['contact_info'] = Variable<String>(contactInfo);
    }
    if (!nullToAbsent || accessTips != null) {
      map['access_tips'] = Variable<String>(accessTips);
    }
    if (!nullToAbsent || links != null) {
      map['links'] = Variable<String>(links);
    }
    if (!nullToAbsent || coverLocalPath != null) {
      map['cover_local_path'] = Variable<String>(coverLocalPath);
    }
    if (!nullToAbsent || coverRemoteUrl != null) {
      map['cover_remote_url'] = Variable<String>(coverRemoteUrl);
    }
    if (!nullToAbsent || source != null) {
      map['source'] = Variable<String>(source);
    }
    if (!nullToAbsent || sourceUrl != null) {
      map['source_url'] = Variable<String>(sourceUrl);
    }
    if (!nullToAbsent || privateNote != null) {
      map['private_note'] = Variable<String>(privateNote);
    }
    map['visibility'] = Variable<String>(visibility);
    map['created_at'] = Variable<DateTime>(createdAt);
    {
      map['updated_at'] = Variable<int>(
        $PlacesTable.$converterupdatedAt.toSql(updatedAt),
      );
    }
    return map;
  }

  PlacesCompanion toCompanion(bool nullToAbsent) {
    return PlacesCompanion(
      placeKey: Value(placeKey),
      name: Value(name),
      lat: Value(lat),
      lng: Value(lng),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      address: address == null && nullToAbsent
          ? const Value.absent()
          : Value(address),
      businessHours: businessHours == null && nullToAbsent
          ? const Value.absent()
          : Value(businessHours),
      contactInfo: contactInfo == null && nullToAbsent
          ? const Value.absent()
          : Value(contactInfo),
      accessTips: accessTips == null && nullToAbsent
          ? const Value.absent()
          : Value(accessTips),
      links: links == null && nullToAbsent
          ? const Value.absent()
          : Value(links),
      coverLocalPath: coverLocalPath == null && nullToAbsent
          ? const Value.absent()
          : Value(coverLocalPath),
      coverRemoteUrl: coverRemoteUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(coverRemoteUrl),
      source: source == null && nullToAbsent
          ? const Value.absent()
          : Value(source),
      sourceUrl: sourceUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceUrl),
      privateNote: privateNote == null && nullToAbsent
          ? const Value.absent()
          : Value(privateNote),
      visibility: Value(visibility),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Place.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Place(
      placeKey: serializer.fromJson<String>(json['placeKey']),
      name: serializer.fromJson<String>(json['name']),
      lat: serializer.fromJson<double>(json['lat']),
      lng: serializer.fromJson<double>(json['lng']),
      description: serializer.fromJson<String?>(json['description']),
      address: serializer.fromJson<String?>(json['address']),
      businessHours: serializer.fromJson<String?>(json['businessHours']),
      contactInfo: serializer.fromJson<String?>(json['contactInfo']),
      accessTips: serializer.fromJson<String?>(json['accessTips']),
      links: serializer.fromJson<String?>(json['links']),
      coverLocalPath: serializer.fromJson<String?>(json['coverLocalPath']),
      coverRemoteUrl: serializer.fromJson<String?>(json['coverRemoteUrl']),
      source: serializer.fromJson<String?>(json['source']),
      sourceUrl: serializer.fromJson<String?>(json['sourceUrl']),
      privateNote: serializer.fromJson<String?>(json['privateNote']),
      visibility: serializer.fromJson<String>(json['visibility']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'placeKey': serializer.toJson<String>(placeKey),
      'name': serializer.toJson<String>(name),
      'lat': serializer.toJson<double>(lat),
      'lng': serializer.toJson<double>(lng),
      'description': serializer.toJson<String?>(description),
      'address': serializer.toJson<String?>(address),
      'businessHours': serializer.toJson<String?>(businessHours),
      'contactInfo': serializer.toJson<String?>(contactInfo),
      'accessTips': serializer.toJson<String?>(accessTips),
      'links': serializer.toJson<String?>(links),
      'coverLocalPath': serializer.toJson<String?>(coverLocalPath),
      'coverRemoteUrl': serializer.toJson<String?>(coverRemoteUrl),
      'source': serializer.toJson<String?>(source),
      'sourceUrl': serializer.toJson<String?>(sourceUrl),
      'privateNote': serializer.toJson<String?>(privateNote),
      'visibility': serializer.toJson<String>(visibility),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Place copyWith({
    String? placeKey,
    String? name,
    double? lat,
    double? lng,
    Value<String?> description = const Value.absent(),
    Value<String?> address = const Value.absent(),
    Value<String?> businessHours = const Value.absent(),
    Value<String?> contactInfo = const Value.absent(),
    Value<String?> accessTips = const Value.absent(),
    Value<String?> links = const Value.absent(),
    Value<String?> coverLocalPath = const Value.absent(),
    Value<String?> coverRemoteUrl = const Value.absent(),
    Value<String?> source = const Value.absent(),
    Value<String?> sourceUrl = const Value.absent(),
    Value<String?> privateNote = const Value.absent(),
    String? visibility,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Place(
    placeKey: placeKey ?? this.placeKey,
    name: name ?? this.name,
    lat: lat ?? this.lat,
    lng: lng ?? this.lng,
    description: description.present ? description.value : this.description,
    address: address.present ? address.value : this.address,
    businessHours: businessHours.present
        ? businessHours.value
        : this.businessHours,
    contactInfo: contactInfo.present ? contactInfo.value : this.contactInfo,
    accessTips: accessTips.present ? accessTips.value : this.accessTips,
    links: links.present ? links.value : this.links,
    coverLocalPath: coverLocalPath.present
        ? coverLocalPath.value
        : this.coverLocalPath,
    coverRemoteUrl: coverRemoteUrl.present
        ? coverRemoteUrl.value
        : this.coverRemoteUrl,
    source: source.present ? source.value : this.source,
    sourceUrl: sourceUrl.present ? sourceUrl.value : this.sourceUrl,
    privateNote: privateNote.present ? privateNote.value : this.privateNote,
    visibility: visibility ?? this.visibility,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Place copyWithCompanion(PlacesCompanion data) {
    return Place(
      placeKey: data.placeKey.present ? data.placeKey.value : this.placeKey,
      name: data.name.present ? data.name.value : this.name,
      lat: data.lat.present ? data.lat.value : this.lat,
      lng: data.lng.present ? data.lng.value : this.lng,
      description: data.description.present
          ? data.description.value
          : this.description,
      address: data.address.present ? data.address.value : this.address,
      businessHours: data.businessHours.present
          ? data.businessHours.value
          : this.businessHours,
      contactInfo: data.contactInfo.present
          ? data.contactInfo.value
          : this.contactInfo,
      accessTips: data.accessTips.present
          ? data.accessTips.value
          : this.accessTips,
      links: data.links.present ? data.links.value : this.links,
      coverLocalPath: data.coverLocalPath.present
          ? data.coverLocalPath.value
          : this.coverLocalPath,
      coverRemoteUrl: data.coverRemoteUrl.present
          ? data.coverRemoteUrl.value
          : this.coverRemoteUrl,
      source: data.source.present ? data.source.value : this.source,
      sourceUrl: data.sourceUrl.present ? data.sourceUrl.value : this.sourceUrl,
      privateNote: data.privateNote.present
          ? data.privateNote.value
          : this.privateNote,
      visibility: data.visibility.present
          ? data.visibility.value
          : this.visibility,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Place(')
          ..write('placeKey: $placeKey, ')
          ..write('name: $name, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('description: $description, ')
          ..write('address: $address, ')
          ..write('businessHours: $businessHours, ')
          ..write('contactInfo: $contactInfo, ')
          ..write('accessTips: $accessTips, ')
          ..write('links: $links, ')
          ..write('coverLocalPath: $coverLocalPath, ')
          ..write('coverRemoteUrl: $coverRemoteUrl, ')
          ..write('source: $source, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('privateNote: $privateNote, ')
          ..write('visibility: $visibility, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    placeKey,
    name,
    lat,
    lng,
    description,
    address,
    businessHours,
    contactInfo,
    accessTips,
    links,
    coverLocalPath,
    coverRemoteUrl,
    source,
    sourceUrl,
    privateNote,
    visibility,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Place &&
          other.placeKey == this.placeKey &&
          other.name == this.name &&
          other.lat == this.lat &&
          other.lng == this.lng &&
          other.description == this.description &&
          other.address == this.address &&
          other.businessHours == this.businessHours &&
          other.contactInfo == this.contactInfo &&
          other.accessTips == this.accessTips &&
          other.links == this.links &&
          other.coverLocalPath == this.coverLocalPath &&
          other.coverRemoteUrl == this.coverRemoteUrl &&
          other.source == this.source &&
          other.sourceUrl == this.sourceUrl &&
          other.privateNote == this.privateNote &&
          other.visibility == this.visibility &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class PlacesCompanion extends UpdateCompanion<Place> {
  final Value<String> placeKey;
  final Value<String> name;
  final Value<double> lat;
  final Value<double> lng;
  final Value<String?> description;
  final Value<String?> address;
  final Value<String?> businessHours;
  final Value<String?> contactInfo;
  final Value<String?> accessTips;
  final Value<String?> links;
  final Value<String?> coverLocalPath;
  final Value<String?> coverRemoteUrl;
  final Value<String?> source;
  final Value<String?> sourceUrl;
  final Value<String?> privateNote;
  final Value<String> visibility;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const PlacesCompanion({
    this.placeKey = const Value.absent(),
    this.name = const Value.absent(),
    this.lat = const Value.absent(),
    this.lng = const Value.absent(),
    this.description = const Value.absent(),
    this.address = const Value.absent(),
    this.businessHours = const Value.absent(),
    this.contactInfo = const Value.absent(),
    this.accessTips = const Value.absent(),
    this.links = const Value.absent(),
    this.coverLocalPath = const Value.absent(),
    this.coverRemoteUrl = const Value.absent(),
    this.source = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.privateNote = const Value.absent(),
    this.visibility = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlacesCompanion.insert({
    required String placeKey,
    required String name,
    required double lat,
    required double lng,
    this.description = const Value.absent(),
    this.address = const Value.absent(),
    this.businessHours = const Value.absent(),
    this.contactInfo = const Value.absent(),
    this.accessTips = const Value.absent(),
    this.links = const Value.absent(),
    this.coverLocalPath = const Value.absent(),
    this.coverRemoteUrl = const Value.absent(),
    this.source = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.privateNote = const Value.absent(),
    this.visibility = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : placeKey = Value(placeKey),
       name = Value(name),
       lat = Value(lat),
       lng = Value(lng);
  static Insertable<Place> custom({
    Expression<String>? placeKey,
    Expression<String>? name,
    Expression<double>? lat,
    Expression<double>? lng,
    Expression<String>? description,
    Expression<String>? address,
    Expression<String>? businessHours,
    Expression<String>? contactInfo,
    Expression<String>? accessTips,
    Expression<String>? links,
    Expression<String>? coverLocalPath,
    Expression<String>? coverRemoteUrl,
    Expression<String>? source,
    Expression<String>? sourceUrl,
    Expression<String>? privateNote,
    Expression<String>? visibility,
    Expression<DateTime>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (placeKey != null) 'place_key': placeKey,
      if (name != null) 'name': name,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (description != null) 'description': description,
      if (address != null) 'address': address,
      if (businessHours != null) 'business_hours': businessHours,
      if (contactInfo != null) 'contact_info': contactInfo,
      if (accessTips != null) 'access_tips': accessTips,
      if (links != null) 'links': links,
      if (coverLocalPath != null) 'cover_local_path': coverLocalPath,
      if (coverRemoteUrl != null) 'cover_remote_url': coverRemoteUrl,
      if (source != null) 'source': source,
      if (sourceUrl != null) 'source_url': sourceUrl,
      if (privateNote != null) 'private_note': privateNote,
      if (visibility != null) 'visibility': visibility,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlacesCompanion copyWith({
    Value<String>? placeKey,
    Value<String>? name,
    Value<double>? lat,
    Value<double>? lng,
    Value<String?>? description,
    Value<String?>? address,
    Value<String?>? businessHours,
    Value<String?>? contactInfo,
    Value<String?>? accessTips,
    Value<String?>? links,
    Value<String?>? coverLocalPath,
    Value<String?>? coverRemoteUrl,
    Value<String?>? source,
    Value<String?>? sourceUrl,
    Value<String?>? privateNote,
    Value<String>? visibility,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return PlacesCompanion(
      placeKey: placeKey ?? this.placeKey,
      name: name ?? this.name,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      description: description ?? this.description,
      address: address ?? this.address,
      businessHours: businessHours ?? this.businessHours,
      contactInfo: contactInfo ?? this.contactInfo,
      accessTips: accessTips ?? this.accessTips,
      links: links ?? this.links,
      coverLocalPath: coverLocalPath ?? this.coverLocalPath,
      coverRemoteUrl: coverRemoteUrl ?? this.coverRemoteUrl,
      source: source ?? this.source,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      privateNote: privateNote ?? this.privateNote,
      visibility: visibility ?? this.visibility,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (placeKey.present) {
      map['place_key'] = Variable<String>(placeKey.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (lat.present) {
      map['lat'] = Variable<double>(lat.value);
    }
    if (lng.present) {
      map['lng'] = Variable<double>(lng.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (businessHours.present) {
      map['business_hours'] = Variable<String>(businessHours.value);
    }
    if (contactInfo.present) {
      map['contact_info'] = Variable<String>(contactInfo.value);
    }
    if (accessTips.present) {
      map['access_tips'] = Variable<String>(accessTips.value);
    }
    if (links.present) {
      map['links'] = Variable<String>(links.value);
    }
    if (coverLocalPath.present) {
      map['cover_local_path'] = Variable<String>(coverLocalPath.value);
    }
    if (coverRemoteUrl.present) {
      map['cover_remote_url'] = Variable<String>(coverRemoteUrl.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (sourceUrl.present) {
      map['source_url'] = Variable<String>(sourceUrl.value);
    }
    if (privateNote.present) {
      map['private_note'] = Variable<String>(privateNote.value);
    }
    if (visibility.present) {
      map['visibility'] = Variable<String>(visibility.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(
        $PlacesTable.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlacesCompanion(')
          ..write('placeKey: $placeKey, ')
          ..write('name: $name, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('description: $description, ')
          ..write('address: $address, ')
          ..write('businessHours: $businessHours, ')
          ..write('contactInfo: $contactInfo, ')
          ..write('accessTips: $accessTips, ')
          ..write('links: $links, ')
          ..write('coverLocalPath: $coverLocalPath, ')
          ..write('coverRemoteUrl: $coverRemoteUrl, ')
          ..write('source: $source, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('privateNote: $privateNote, ')
          ..write('visibility: $visibility, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LabelsTable extends Labels with TableInfo<$LabelsTable, Label> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LabelsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
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
  static const VerificationMeta _bangumiIdMeta = const VerificationMeta(
    'bangumiId',
  );
  @override
  late final GeneratedColumn<String> bangumiId = GeneratedColumn<String>(
    'bangumi_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
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
    clientDefault: () => DateTime.now(),
  );
  @override
  List<GeneratedColumn> get $columns => [id, kind, name, bangumiId, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'labels';
  @override
  VerificationContext validateIntegrity(
    Insertable<Label> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('bangumi_id')) {
      context.handle(
        _bangumiIdMeta,
        bangumiId.isAcceptableOrUnknown(data['bangumi_id']!, _bangumiIdMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Label map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Label(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      bangumiId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bangumi_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $LabelsTable createAlias(String alias) {
    return $LabelsTable(attachedDatabase, alias);
  }
}

class Label extends DataClass implements Insertable<Label> {
  final String id;
  final String kind;
  final String name;
  final String? bangumiId;
  final DateTime createdAt;
  const Label({
    required this.id,
    required this.kind,
    required this.name,
    this.bangumiId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || bangumiId != null) {
      map['bangumi_id'] = Variable<String>(bangumiId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  LabelsCompanion toCompanion(bool nullToAbsent) {
    return LabelsCompanion(
      id: Value(id),
      kind: Value(kind),
      name: Value(name),
      bangumiId: bangumiId == null && nullToAbsent
          ? const Value.absent()
          : Value(bangumiId),
      createdAt: Value(createdAt),
    );
  }

  factory Label.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Label(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      name: serializer.fromJson<String>(json['name']),
      bangumiId: serializer.fromJson<String?>(json['bangumiId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(kind),
      'name': serializer.toJson<String>(name),
      'bangumiId': serializer.toJson<String?>(bangumiId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Label copyWith({
    String? id,
    String? kind,
    String? name,
    Value<String?> bangumiId = const Value.absent(),
    DateTime? createdAt,
  }) => Label(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    name: name ?? this.name,
    bangumiId: bangumiId.present ? bangumiId.value : this.bangumiId,
    createdAt: createdAt ?? this.createdAt,
  );
  Label copyWithCompanion(LabelsCompanion data) {
    return Label(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      name: data.name.present ? data.name.value : this.name,
      bangumiId: data.bangumiId.present ? data.bangumiId.value : this.bangumiId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Label(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('bangumiId: $bangumiId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, kind, name, bangumiId, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Label &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.name == this.name &&
          other.bangumiId == this.bangumiId &&
          other.createdAt == this.createdAt);
}

class LabelsCompanion extends UpdateCompanion<Label> {
  final Value<String> id;
  final Value<String> kind;
  final Value<String> name;
  final Value<String?> bangumiId;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const LabelsCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.name = const Value.absent(),
    this.bangumiId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LabelsCompanion.insert({
    required String id,
    required String kind,
    required String name,
    this.bangumiId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       name = Value(name);
  static Insertable<Label> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? name,
    Expression<String>? bangumiId,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (name != null) 'name': name,
      if (bangumiId != null) 'bangumi_id': bangumiId,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LabelsCompanion copyWith({
    Value<String>? id,
    Value<String>? kind,
    Value<String>? name,
    Value<String?>? bangumiId,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return LabelsCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      name: name ?? this.name,
      bangumiId: bangumiId ?? this.bangumiId,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (bangumiId.present) {
      map['bangumi_id'] = Variable<String>(bangumiId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LabelsCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('bangumiId: $bangumiId, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlaceLabelsTable extends PlaceLabels
    with TableInfo<$PlaceLabelsTable, PlaceLabel> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaceLabelsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _placeKeyMeta = const VerificationMeta(
    'placeKey',
  );
  @override
  late final GeneratedColumn<String> placeKey = GeneratedColumn<String>(
    'place_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES places (place_key) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _labelIdMeta = const VerificationMeta(
    'labelId',
  );
  @override
  late final GeneratedColumn<String> labelId = GeneratedColumn<String>(
    'label_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES labels (id) ON DELETE CASCADE',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [placeKey, labelId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'place_labels';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlaceLabel> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('place_key')) {
      context.handle(
        _placeKeyMeta,
        placeKey.isAcceptableOrUnknown(data['place_key']!, _placeKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_placeKeyMeta);
    }
    if (data.containsKey('label_id')) {
      context.handle(
        _labelIdMeta,
        labelId.isAcceptableOrUnknown(data['label_id']!, _labelIdMeta),
      );
    } else if (isInserting) {
      context.missing(_labelIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {placeKey, labelId};
  @override
  PlaceLabel map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaceLabel(
      placeKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}place_key'],
      )!,
      labelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label_id'],
      )!,
    );
  }

  @override
  $PlaceLabelsTable createAlias(String alias) {
    return $PlaceLabelsTable(attachedDatabase, alias);
  }
}

class PlaceLabel extends DataClass implements Insertable<PlaceLabel> {
  final String placeKey;
  final String labelId;
  const PlaceLabel({required this.placeKey, required this.labelId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['place_key'] = Variable<String>(placeKey);
    map['label_id'] = Variable<String>(labelId);
    return map;
  }

  PlaceLabelsCompanion toCompanion(bool nullToAbsent) {
    return PlaceLabelsCompanion(
      placeKey: Value(placeKey),
      labelId: Value(labelId),
    );
  }

  factory PlaceLabel.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaceLabel(
      placeKey: serializer.fromJson<String>(json['placeKey']),
      labelId: serializer.fromJson<String>(json['labelId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'placeKey': serializer.toJson<String>(placeKey),
      'labelId': serializer.toJson<String>(labelId),
    };
  }

  PlaceLabel copyWith({String? placeKey, String? labelId}) => PlaceLabel(
    placeKey: placeKey ?? this.placeKey,
    labelId: labelId ?? this.labelId,
  );
  PlaceLabel copyWithCompanion(PlaceLabelsCompanion data) {
    return PlaceLabel(
      placeKey: data.placeKey.present ? data.placeKey.value : this.placeKey,
      labelId: data.labelId.present ? data.labelId.value : this.labelId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaceLabel(')
          ..write('placeKey: $placeKey, ')
          ..write('labelId: $labelId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(placeKey, labelId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaceLabel &&
          other.placeKey == this.placeKey &&
          other.labelId == this.labelId);
}

class PlaceLabelsCompanion extends UpdateCompanion<PlaceLabel> {
  final Value<String> placeKey;
  final Value<String> labelId;
  final Value<int> rowid;
  const PlaceLabelsCompanion({
    this.placeKey = const Value.absent(),
    this.labelId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlaceLabelsCompanion.insert({
    required String placeKey,
    required String labelId,
    this.rowid = const Value.absent(),
  }) : placeKey = Value(placeKey),
       labelId = Value(labelId);
  static Insertable<PlaceLabel> custom({
    Expression<String>? placeKey,
    Expression<String>? labelId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (placeKey != null) 'place_key': placeKey,
      if (labelId != null) 'label_id': labelId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlaceLabelsCompanion copyWith({
    Value<String>? placeKey,
    Value<String>? labelId,
    Value<int>? rowid,
  }) {
    return PlaceLabelsCompanion(
      placeKey: placeKey ?? this.placeKey,
      labelId: labelId ?? this.labelId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (placeKey.present) {
      map['place_key'] = Variable<String>(placeKey.value);
    }
    if (labelId.present) {
      map['label_id'] = Variable<String>(labelId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaceLabelsCompanion(')
          ..write('placeKey: $placeKey, ')
          ..write('labelId: $labelId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PhotosTable extends Photos with TableInfo<$PhotosTable, Photo> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PhotosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _placeKeyMeta = const VerificationMeta(
    'placeKey',
  );
  @override
  late final GeneratedColumn<String> placeKey = GeneratedColumn<String>(
    'place_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES places (place_key) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _tripIdMeta = const VerificationMeta('tripId');
  @override
  late final GeneratedColumn<String> tripId = GeneratedColumn<String>(
    'trip_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('original'),
  );
  static const VerificationMeta _derivedFromIdMeta = const VerificationMeta(
    'derivedFromId',
  );
  @override
  late final GeneratedColumn<String> derivedFromId = GeneratedColumn<String>(
    'derived_from_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _referenceImageIdMeta = const VerificationMeta(
    'referenceImageId',
  );
  @override
  late final GeneratedColumn<String> referenceImageId = GeneratedColumn<String>(
    'reference_image_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localPathMeta = const VerificationMeta(
    'localPath',
  );
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
    'local_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remoteUrlMeta = const VerificationMeta(
    'remoteUrl',
  );
  @override
  late final GeneratedColumn<String> remoteUrl = GeneratedColumn<String>(
    'remote_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isSharedMeta = const VerificationMeta(
    'isShared',
  );
  @override
  late final GeneratedColumn<bool> isShared = GeneratedColumn<bool>(
    'is_shared',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_shared" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _takenAtMeta = const VerificationMeta(
    'takenAt',
  );
  @override
  late final GeneratedColumn<DateTime> takenAt = GeneratedColumn<DateTime>(
    'taken_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
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
    clientDefault: () => DateTime.now(),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    placeKey,
    tripId,
    kind,
    derivedFromId,
    referenceImageId,
    localPath,
    remoteUrl,
    isShared,
    takenAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'photos';
  @override
  VerificationContext validateIntegrity(
    Insertable<Photo> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('place_key')) {
      context.handle(
        _placeKeyMeta,
        placeKey.isAcceptableOrUnknown(data['place_key']!, _placeKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_placeKeyMeta);
    }
    if (data.containsKey('trip_id')) {
      context.handle(
        _tripIdMeta,
        tripId.isAcceptableOrUnknown(data['trip_id']!, _tripIdMeta),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    }
    if (data.containsKey('derived_from_id')) {
      context.handle(
        _derivedFromIdMeta,
        derivedFromId.isAcceptableOrUnknown(
          data['derived_from_id']!,
          _derivedFromIdMeta,
        ),
      );
    }
    if (data.containsKey('reference_image_id')) {
      context.handle(
        _referenceImageIdMeta,
        referenceImageId.isAcceptableOrUnknown(
          data['reference_image_id']!,
          _referenceImageIdMeta,
        ),
      );
    }
    if (data.containsKey('local_path')) {
      context.handle(
        _localPathMeta,
        localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta),
      );
    } else if (isInserting) {
      context.missing(_localPathMeta);
    }
    if (data.containsKey('remote_url')) {
      context.handle(
        _remoteUrlMeta,
        remoteUrl.isAcceptableOrUnknown(data['remote_url']!, _remoteUrlMeta),
      );
    }
    if (data.containsKey('is_shared')) {
      context.handle(
        _isSharedMeta,
        isShared.isAcceptableOrUnknown(data['is_shared']!, _isSharedMeta),
      );
    }
    if (data.containsKey('taken_at')) {
      context.handle(
        _takenAtMeta,
        takenAt.isAcceptableOrUnknown(data['taken_at']!, _takenAtMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Photo map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Photo(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      placeKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}place_key'],
      )!,
      tripId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trip_id'],
      ),
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      derivedFromId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}derived_from_id'],
      ),
      referenceImageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reference_image_id'],
      ),
      localPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_path'],
      )!,
      remoteUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_url'],
      ),
      isShared: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_shared'],
      )!,
      takenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}taken_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $PhotosTable createAlias(String alias) {
    return $PhotosTable(attachedDatabase, alias);
  }
}

class Photo extends DataClass implements Insertable<Photo> {
  final String id;
  final String placeKey;
  final String? tripId;

  /// Photo type: 'original' | 'edited' | 'comparison' | 'composite'.
  final String kind;
  final String? derivedFromId;
  final String? referenceImageId;
  final String localPath;
  final String? remoteUrl;

  /// Whether the user opted in to publish this photo to the shared trip.
  final bool isShared;
  final DateTime? takenAt;
  final DateTime createdAt;
  const Photo({
    required this.id,
    required this.placeKey,
    this.tripId,
    required this.kind,
    this.derivedFromId,
    this.referenceImageId,
    required this.localPath,
    this.remoteUrl,
    required this.isShared,
    this.takenAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['place_key'] = Variable<String>(placeKey);
    if (!nullToAbsent || tripId != null) {
      map['trip_id'] = Variable<String>(tripId);
    }
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || derivedFromId != null) {
      map['derived_from_id'] = Variable<String>(derivedFromId);
    }
    if (!nullToAbsent || referenceImageId != null) {
      map['reference_image_id'] = Variable<String>(referenceImageId);
    }
    map['local_path'] = Variable<String>(localPath);
    if (!nullToAbsent || remoteUrl != null) {
      map['remote_url'] = Variable<String>(remoteUrl);
    }
    map['is_shared'] = Variable<bool>(isShared);
    if (!nullToAbsent || takenAt != null) {
      map['taken_at'] = Variable<DateTime>(takenAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PhotosCompanion toCompanion(bool nullToAbsent) {
    return PhotosCompanion(
      id: Value(id),
      placeKey: Value(placeKey),
      tripId: tripId == null && nullToAbsent
          ? const Value.absent()
          : Value(tripId),
      kind: Value(kind),
      derivedFromId: derivedFromId == null && nullToAbsent
          ? const Value.absent()
          : Value(derivedFromId),
      referenceImageId: referenceImageId == null && nullToAbsent
          ? const Value.absent()
          : Value(referenceImageId),
      localPath: Value(localPath),
      remoteUrl: remoteUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteUrl),
      isShared: Value(isShared),
      takenAt: takenAt == null && nullToAbsent
          ? const Value.absent()
          : Value(takenAt),
      createdAt: Value(createdAt),
    );
  }

  factory Photo.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Photo(
      id: serializer.fromJson<String>(json['id']),
      placeKey: serializer.fromJson<String>(json['placeKey']),
      tripId: serializer.fromJson<String?>(json['tripId']),
      kind: serializer.fromJson<String>(json['kind']),
      derivedFromId: serializer.fromJson<String?>(json['derivedFromId']),
      referenceImageId: serializer.fromJson<String?>(json['referenceImageId']),
      localPath: serializer.fromJson<String>(json['localPath']),
      remoteUrl: serializer.fromJson<String?>(json['remoteUrl']),
      isShared: serializer.fromJson<bool>(json['isShared']),
      takenAt: serializer.fromJson<DateTime?>(json['takenAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'placeKey': serializer.toJson<String>(placeKey),
      'tripId': serializer.toJson<String?>(tripId),
      'kind': serializer.toJson<String>(kind),
      'derivedFromId': serializer.toJson<String?>(derivedFromId),
      'referenceImageId': serializer.toJson<String?>(referenceImageId),
      'localPath': serializer.toJson<String>(localPath),
      'remoteUrl': serializer.toJson<String?>(remoteUrl),
      'isShared': serializer.toJson<bool>(isShared),
      'takenAt': serializer.toJson<DateTime?>(takenAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Photo copyWith({
    String? id,
    String? placeKey,
    Value<String?> tripId = const Value.absent(),
    String? kind,
    Value<String?> derivedFromId = const Value.absent(),
    Value<String?> referenceImageId = const Value.absent(),
    String? localPath,
    Value<String?> remoteUrl = const Value.absent(),
    bool? isShared,
    Value<DateTime?> takenAt = const Value.absent(),
    DateTime? createdAt,
  }) => Photo(
    id: id ?? this.id,
    placeKey: placeKey ?? this.placeKey,
    tripId: tripId.present ? tripId.value : this.tripId,
    kind: kind ?? this.kind,
    derivedFromId: derivedFromId.present
        ? derivedFromId.value
        : this.derivedFromId,
    referenceImageId: referenceImageId.present
        ? referenceImageId.value
        : this.referenceImageId,
    localPath: localPath ?? this.localPath,
    remoteUrl: remoteUrl.present ? remoteUrl.value : this.remoteUrl,
    isShared: isShared ?? this.isShared,
    takenAt: takenAt.present ? takenAt.value : this.takenAt,
    createdAt: createdAt ?? this.createdAt,
  );
  Photo copyWithCompanion(PhotosCompanion data) {
    return Photo(
      id: data.id.present ? data.id.value : this.id,
      placeKey: data.placeKey.present ? data.placeKey.value : this.placeKey,
      tripId: data.tripId.present ? data.tripId.value : this.tripId,
      kind: data.kind.present ? data.kind.value : this.kind,
      derivedFromId: data.derivedFromId.present
          ? data.derivedFromId.value
          : this.derivedFromId,
      referenceImageId: data.referenceImageId.present
          ? data.referenceImageId.value
          : this.referenceImageId,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      remoteUrl: data.remoteUrl.present ? data.remoteUrl.value : this.remoteUrl,
      isShared: data.isShared.present ? data.isShared.value : this.isShared,
      takenAt: data.takenAt.present ? data.takenAt.value : this.takenAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Photo(')
          ..write('id: $id, ')
          ..write('placeKey: $placeKey, ')
          ..write('tripId: $tripId, ')
          ..write('kind: $kind, ')
          ..write('derivedFromId: $derivedFromId, ')
          ..write('referenceImageId: $referenceImageId, ')
          ..write('localPath: $localPath, ')
          ..write('remoteUrl: $remoteUrl, ')
          ..write('isShared: $isShared, ')
          ..write('takenAt: $takenAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    placeKey,
    tripId,
    kind,
    derivedFromId,
    referenceImageId,
    localPath,
    remoteUrl,
    isShared,
    takenAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Photo &&
          other.id == this.id &&
          other.placeKey == this.placeKey &&
          other.tripId == this.tripId &&
          other.kind == this.kind &&
          other.derivedFromId == this.derivedFromId &&
          other.referenceImageId == this.referenceImageId &&
          other.localPath == this.localPath &&
          other.remoteUrl == this.remoteUrl &&
          other.isShared == this.isShared &&
          other.takenAt == this.takenAt &&
          other.createdAt == this.createdAt);
}

class PhotosCompanion extends UpdateCompanion<Photo> {
  final Value<String> id;
  final Value<String> placeKey;
  final Value<String?> tripId;
  final Value<String> kind;
  final Value<String?> derivedFromId;
  final Value<String?> referenceImageId;
  final Value<String> localPath;
  final Value<String?> remoteUrl;
  final Value<bool> isShared;
  final Value<DateTime?> takenAt;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const PhotosCompanion({
    this.id = const Value.absent(),
    this.placeKey = const Value.absent(),
    this.tripId = const Value.absent(),
    this.kind = const Value.absent(),
    this.derivedFromId = const Value.absent(),
    this.referenceImageId = const Value.absent(),
    this.localPath = const Value.absent(),
    this.remoteUrl = const Value.absent(),
    this.isShared = const Value.absent(),
    this.takenAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PhotosCompanion.insert({
    required String id,
    required String placeKey,
    this.tripId = const Value.absent(),
    this.kind = const Value.absent(),
    this.derivedFromId = const Value.absent(),
    this.referenceImageId = const Value.absent(),
    required String localPath,
    this.remoteUrl = const Value.absent(),
    this.isShared = const Value.absent(),
    this.takenAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       placeKey = Value(placeKey),
       localPath = Value(localPath);
  static Insertable<Photo> custom({
    Expression<String>? id,
    Expression<String>? placeKey,
    Expression<String>? tripId,
    Expression<String>? kind,
    Expression<String>? derivedFromId,
    Expression<String>? referenceImageId,
    Expression<String>? localPath,
    Expression<String>? remoteUrl,
    Expression<bool>? isShared,
    Expression<DateTime>? takenAt,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (placeKey != null) 'place_key': placeKey,
      if (tripId != null) 'trip_id': tripId,
      if (kind != null) 'kind': kind,
      if (derivedFromId != null) 'derived_from_id': derivedFromId,
      if (referenceImageId != null) 'reference_image_id': referenceImageId,
      if (localPath != null) 'local_path': localPath,
      if (remoteUrl != null) 'remote_url': remoteUrl,
      if (isShared != null) 'is_shared': isShared,
      if (takenAt != null) 'taken_at': takenAt,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PhotosCompanion copyWith({
    Value<String>? id,
    Value<String>? placeKey,
    Value<String?>? tripId,
    Value<String>? kind,
    Value<String?>? derivedFromId,
    Value<String?>? referenceImageId,
    Value<String>? localPath,
    Value<String?>? remoteUrl,
    Value<bool>? isShared,
    Value<DateTime?>? takenAt,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return PhotosCompanion(
      id: id ?? this.id,
      placeKey: placeKey ?? this.placeKey,
      tripId: tripId ?? this.tripId,
      kind: kind ?? this.kind,
      derivedFromId: derivedFromId ?? this.derivedFromId,
      referenceImageId: referenceImageId ?? this.referenceImageId,
      localPath: localPath ?? this.localPath,
      remoteUrl: remoteUrl ?? this.remoteUrl,
      isShared: isShared ?? this.isShared,
      takenAt: takenAt ?? this.takenAt,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (placeKey.present) {
      map['place_key'] = Variable<String>(placeKey.value);
    }
    if (tripId.present) {
      map['trip_id'] = Variable<String>(tripId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (derivedFromId.present) {
      map['derived_from_id'] = Variable<String>(derivedFromId.value);
    }
    if (referenceImageId.present) {
      map['reference_image_id'] = Variable<String>(referenceImageId.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (remoteUrl.present) {
      map['remote_url'] = Variable<String>(remoteUrl.value);
    }
    if (isShared.present) {
      map['is_shared'] = Variable<bool>(isShared.value);
    }
    if (takenAt.present) {
      map['taken_at'] = Variable<DateTime>(takenAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PhotosCompanion(')
          ..write('id: $id, ')
          ..write('placeKey: $placeKey, ')
          ..write('tripId: $tripId, ')
          ..write('kind: $kind, ')
          ..write('derivedFromId: $derivedFromId, ')
          ..write('referenceImageId: $referenceImageId, ')
          ..write('localPath: $localPath, ')
          ..write('remoteUrl: $remoteUrl, ')
          ..write('isShared: $isShared, ')
          ..write('takenAt: $takenAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlaceVisitsTable extends PlaceVisits
    with TableInfo<$PlaceVisitsTable, PlaceVisit> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaceVisitsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _placeKeyMeta = const VerificationMeta(
    'placeKey',
  );
  @override
  late final GeneratedColumn<String> placeKey = GeneratedColumn<String>(
    'place_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES places (place_key) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tripIdMeta = const VerificationMeta('tripId');
  @override
  late final GeneratedColumn<String> tripId = GeneratedColumn<String>(
    'trip_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
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
    clientDefault: () => DateTime.now(),
  );
  @override
  List<GeneratedColumn> get $columns => [id, placeKey, date, tripId, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'place_visits';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlaceVisit> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('place_key')) {
      context.handle(
        _placeKeyMeta,
        placeKey.isAcceptableOrUnknown(data['place_key']!, _placeKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_placeKeyMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('trip_id')) {
      context.handle(
        _tripIdMeta,
        tripId.isAcceptableOrUnknown(data['trip_id']!, _tripIdMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlaceVisit map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaceVisit(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      placeKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}place_key'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      tripId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trip_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $PlaceVisitsTable createAlias(String alias) {
    return $PlaceVisitsTable(attachedDatabase, alias);
  }
}

class PlaceVisit extends DataClass implements Insertable<PlaceVisit> {
  final String id;
  final String placeKey;
  final String date;
  final String? tripId;
  final DateTime createdAt;
  const PlaceVisit({
    required this.id,
    required this.placeKey,
    required this.date,
    this.tripId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['place_key'] = Variable<String>(placeKey);
    map['date'] = Variable<String>(date);
    if (!nullToAbsent || tripId != null) {
      map['trip_id'] = Variable<String>(tripId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PlaceVisitsCompanion toCompanion(bool nullToAbsent) {
    return PlaceVisitsCompanion(
      id: Value(id),
      placeKey: Value(placeKey),
      date: Value(date),
      tripId: tripId == null && nullToAbsent
          ? const Value.absent()
          : Value(tripId),
      createdAt: Value(createdAt),
    );
  }

  factory PlaceVisit.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaceVisit(
      id: serializer.fromJson<String>(json['id']),
      placeKey: serializer.fromJson<String>(json['placeKey']),
      date: serializer.fromJson<String>(json['date']),
      tripId: serializer.fromJson<String?>(json['tripId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'placeKey': serializer.toJson<String>(placeKey),
      'date': serializer.toJson<String>(date),
      'tripId': serializer.toJson<String?>(tripId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  PlaceVisit copyWith({
    String? id,
    String? placeKey,
    String? date,
    Value<String?> tripId = const Value.absent(),
    DateTime? createdAt,
  }) => PlaceVisit(
    id: id ?? this.id,
    placeKey: placeKey ?? this.placeKey,
    date: date ?? this.date,
    tripId: tripId.present ? tripId.value : this.tripId,
    createdAt: createdAt ?? this.createdAt,
  );
  PlaceVisit copyWithCompanion(PlaceVisitsCompanion data) {
    return PlaceVisit(
      id: data.id.present ? data.id.value : this.id,
      placeKey: data.placeKey.present ? data.placeKey.value : this.placeKey,
      date: data.date.present ? data.date.value : this.date,
      tripId: data.tripId.present ? data.tripId.value : this.tripId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaceVisit(')
          ..write('id: $id, ')
          ..write('placeKey: $placeKey, ')
          ..write('date: $date, ')
          ..write('tripId: $tripId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, placeKey, date, tripId, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaceVisit &&
          other.id == this.id &&
          other.placeKey == this.placeKey &&
          other.date == this.date &&
          other.tripId == this.tripId &&
          other.createdAt == this.createdAt);
}

class PlaceVisitsCompanion extends UpdateCompanion<PlaceVisit> {
  final Value<String> id;
  final Value<String> placeKey;
  final Value<String> date;
  final Value<String?> tripId;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const PlaceVisitsCompanion({
    this.id = const Value.absent(),
    this.placeKey = const Value.absent(),
    this.date = const Value.absent(),
    this.tripId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlaceVisitsCompanion.insert({
    required String id,
    required String placeKey,
    required String date,
    this.tripId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       placeKey = Value(placeKey),
       date = Value(date);
  static Insertable<PlaceVisit> custom({
    Expression<String>? id,
    Expression<String>? placeKey,
    Expression<String>? date,
    Expression<String>? tripId,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (placeKey != null) 'place_key': placeKey,
      if (date != null) 'date': date,
      if (tripId != null) 'trip_id': tripId,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlaceVisitsCompanion copyWith({
    Value<String>? id,
    Value<String>? placeKey,
    Value<String>? date,
    Value<String?>? tripId,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return PlaceVisitsCompanion(
      id: id ?? this.id,
      placeKey: placeKey ?? this.placeKey,
      date: date ?? this.date,
      tripId: tripId ?? this.tripId,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (placeKey.present) {
      map['place_key'] = Variable<String>(placeKey.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (tripId.present) {
      map['trip_id'] = Variable<String>(tripId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaceVisitsCompanion(')
          ..write('id: $id, ')
          ..write('placeKey: $placeKey, ')
          ..write('date: $date, ')
          ..write('tripId: $tripId, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NewReferenceImagesTable extends NewReferenceImages
    with TableInfo<$NewReferenceImagesTable, NewReferenceImage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NewReferenceImagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _placeKeyMeta = const VerificationMeta(
    'placeKey',
  );
  @override
  late final GeneratedColumn<String> placeKey = GeneratedColumn<String>(
    'place_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES places (place_key) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _stopIdMeta = const VerificationMeta('stopId');
  @override
  late final GeneratedColumn<String> stopId = GeneratedColumn<String>(
    'stop_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localPathMeta = const VerificationMeta(
    'localPath',
  );
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
    'local_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _remoteUrlMeta = const VerificationMeta(
    'remoteUrl',
  );
  @override
  late final GeneratedColumn<String> remoteUrl = GeneratedColumn<String>(
    'remote_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _animeLabelIdMeta = const VerificationMeta(
    'animeLabelId',
  );
  @override
  late final GeneratedColumn<String> animeLabelId = GeneratedColumn<String>(
    'anime_label_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _episodeMeta = const VerificationMeta(
    'episode',
  );
  @override
  late final GeneratedColumn<String> episode = GeneratedColumn<String>(
    'episode',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _timestampSMeta = const VerificationMeta(
    'timestampS',
  );
  @override
  late final GeneratedColumn<int> timestampS = GeneratedColumn<int>(
    'timestamp_s',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceUrlMeta = const VerificationMeta(
    'sourceUrl',
  );
  @override
  late final GeneratedColumn<String> sourceUrl = GeneratedColumn<String>(
    'source_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
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
    clientDefault: () => DateTime.now(),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    placeKey,
    stopId,
    localPath,
    remoteUrl,
    animeLabelId,
    episode,
    timestampS,
    source,
    sourceUrl,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'v10_reference_images';
  @override
  VerificationContext validateIntegrity(
    Insertable<NewReferenceImage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('place_key')) {
      context.handle(
        _placeKeyMeta,
        placeKey.isAcceptableOrUnknown(data['place_key']!, _placeKeyMeta),
      );
    }
    if (data.containsKey('stop_id')) {
      context.handle(
        _stopIdMeta,
        stopId.isAcceptableOrUnknown(data['stop_id']!, _stopIdMeta),
      );
    }
    if (data.containsKey('local_path')) {
      context.handle(
        _localPathMeta,
        localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta),
      );
    }
    if (data.containsKey('remote_url')) {
      context.handle(
        _remoteUrlMeta,
        remoteUrl.isAcceptableOrUnknown(data['remote_url']!, _remoteUrlMeta),
      );
    }
    if (data.containsKey('anime_label_id')) {
      context.handle(
        _animeLabelIdMeta,
        animeLabelId.isAcceptableOrUnknown(
          data['anime_label_id']!,
          _animeLabelIdMeta,
        ),
      );
    }
    if (data.containsKey('episode')) {
      context.handle(
        _episodeMeta,
        episode.isAcceptableOrUnknown(data['episode']!, _episodeMeta),
      );
    }
    if (data.containsKey('timestamp_s')) {
      context.handle(
        _timestampSMeta,
        timestampS.isAcceptableOrUnknown(data['timestamp_s']!, _timestampSMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('source_url')) {
      context.handle(
        _sourceUrlMeta,
        sourceUrl.isAcceptableOrUnknown(data['source_url']!, _sourceUrlMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NewReferenceImage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NewReferenceImage(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      placeKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}place_key'],
      ),
      stopId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stop_id'],
      ),
      localPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_path'],
      ),
      remoteUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_url'],
      ),
      animeLabelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}anime_label_id'],
      ),
      episode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}episode'],
      ),
      timestampS: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}timestamp_s'],
      ),
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      ),
      sourceUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_url'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $NewReferenceImagesTable createAlias(String alias) {
    return $NewReferenceImagesTable(attachedDatabase, alias);
  }
}

class NewReferenceImage extends DataClass
    implements Insertable<NewReferenceImage> {
  final String id;
  final String? placeKey;
  final String? stopId;
  final String? localPath;
  final String? remoteUrl;
  final String? animeLabelId;
  final String? episode;
  final int? timestampS;
  final String? source;
  final String? sourceUrl;
  final DateTime createdAt;
  const NewReferenceImage({
    required this.id,
    this.placeKey,
    this.stopId,
    this.localPath,
    this.remoteUrl,
    this.animeLabelId,
    this.episode,
    this.timestampS,
    this.source,
    this.sourceUrl,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || placeKey != null) {
      map['place_key'] = Variable<String>(placeKey);
    }
    if (!nullToAbsent || stopId != null) {
      map['stop_id'] = Variable<String>(stopId);
    }
    if (!nullToAbsent || localPath != null) {
      map['local_path'] = Variable<String>(localPath);
    }
    if (!nullToAbsent || remoteUrl != null) {
      map['remote_url'] = Variable<String>(remoteUrl);
    }
    if (!nullToAbsent || animeLabelId != null) {
      map['anime_label_id'] = Variable<String>(animeLabelId);
    }
    if (!nullToAbsent || episode != null) {
      map['episode'] = Variable<String>(episode);
    }
    if (!nullToAbsent || timestampS != null) {
      map['timestamp_s'] = Variable<int>(timestampS);
    }
    if (!nullToAbsent || source != null) {
      map['source'] = Variable<String>(source);
    }
    if (!nullToAbsent || sourceUrl != null) {
      map['source_url'] = Variable<String>(sourceUrl);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  NewReferenceImagesCompanion toCompanion(bool nullToAbsent) {
    return NewReferenceImagesCompanion(
      id: Value(id),
      placeKey: placeKey == null && nullToAbsent
          ? const Value.absent()
          : Value(placeKey),
      stopId: stopId == null && nullToAbsent
          ? const Value.absent()
          : Value(stopId),
      localPath: localPath == null && nullToAbsent
          ? const Value.absent()
          : Value(localPath),
      remoteUrl: remoteUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteUrl),
      animeLabelId: animeLabelId == null && nullToAbsent
          ? const Value.absent()
          : Value(animeLabelId),
      episode: episode == null && nullToAbsent
          ? const Value.absent()
          : Value(episode),
      timestampS: timestampS == null && nullToAbsent
          ? const Value.absent()
          : Value(timestampS),
      source: source == null && nullToAbsent
          ? const Value.absent()
          : Value(source),
      sourceUrl: sourceUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceUrl),
      createdAt: Value(createdAt),
    );
  }

  factory NewReferenceImage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NewReferenceImage(
      id: serializer.fromJson<String>(json['id']),
      placeKey: serializer.fromJson<String?>(json['placeKey']),
      stopId: serializer.fromJson<String?>(json['stopId']),
      localPath: serializer.fromJson<String?>(json['localPath']),
      remoteUrl: serializer.fromJson<String?>(json['remoteUrl']),
      animeLabelId: serializer.fromJson<String?>(json['animeLabelId']),
      episode: serializer.fromJson<String?>(json['episode']),
      timestampS: serializer.fromJson<int?>(json['timestampS']),
      source: serializer.fromJson<String?>(json['source']),
      sourceUrl: serializer.fromJson<String?>(json['sourceUrl']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'placeKey': serializer.toJson<String?>(placeKey),
      'stopId': serializer.toJson<String?>(stopId),
      'localPath': serializer.toJson<String?>(localPath),
      'remoteUrl': serializer.toJson<String?>(remoteUrl),
      'animeLabelId': serializer.toJson<String?>(animeLabelId),
      'episode': serializer.toJson<String?>(episode),
      'timestampS': serializer.toJson<int?>(timestampS),
      'source': serializer.toJson<String?>(source),
      'sourceUrl': serializer.toJson<String?>(sourceUrl),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  NewReferenceImage copyWith({
    String? id,
    Value<String?> placeKey = const Value.absent(),
    Value<String?> stopId = const Value.absent(),
    Value<String?> localPath = const Value.absent(),
    Value<String?> remoteUrl = const Value.absent(),
    Value<String?> animeLabelId = const Value.absent(),
    Value<String?> episode = const Value.absent(),
    Value<int?> timestampS = const Value.absent(),
    Value<String?> source = const Value.absent(),
    Value<String?> sourceUrl = const Value.absent(),
    DateTime? createdAt,
  }) => NewReferenceImage(
    id: id ?? this.id,
    placeKey: placeKey.present ? placeKey.value : this.placeKey,
    stopId: stopId.present ? stopId.value : this.stopId,
    localPath: localPath.present ? localPath.value : this.localPath,
    remoteUrl: remoteUrl.present ? remoteUrl.value : this.remoteUrl,
    animeLabelId: animeLabelId.present ? animeLabelId.value : this.animeLabelId,
    episode: episode.present ? episode.value : this.episode,
    timestampS: timestampS.present ? timestampS.value : this.timestampS,
    source: source.present ? source.value : this.source,
    sourceUrl: sourceUrl.present ? sourceUrl.value : this.sourceUrl,
    createdAt: createdAt ?? this.createdAt,
  );
  NewReferenceImage copyWithCompanion(NewReferenceImagesCompanion data) {
    return NewReferenceImage(
      id: data.id.present ? data.id.value : this.id,
      placeKey: data.placeKey.present ? data.placeKey.value : this.placeKey,
      stopId: data.stopId.present ? data.stopId.value : this.stopId,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      remoteUrl: data.remoteUrl.present ? data.remoteUrl.value : this.remoteUrl,
      animeLabelId: data.animeLabelId.present
          ? data.animeLabelId.value
          : this.animeLabelId,
      episode: data.episode.present ? data.episode.value : this.episode,
      timestampS: data.timestampS.present
          ? data.timestampS.value
          : this.timestampS,
      source: data.source.present ? data.source.value : this.source,
      sourceUrl: data.sourceUrl.present ? data.sourceUrl.value : this.sourceUrl,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NewReferenceImage(')
          ..write('id: $id, ')
          ..write('placeKey: $placeKey, ')
          ..write('stopId: $stopId, ')
          ..write('localPath: $localPath, ')
          ..write('remoteUrl: $remoteUrl, ')
          ..write('animeLabelId: $animeLabelId, ')
          ..write('episode: $episode, ')
          ..write('timestampS: $timestampS, ')
          ..write('source: $source, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    placeKey,
    stopId,
    localPath,
    remoteUrl,
    animeLabelId,
    episode,
    timestampS,
    source,
    sourceUrl,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NewReferenceImage &&
          other.id == this.id &&
          other.placeKey == this.placeKey &&
          other.stopId == this.stopId &&
          other.localPath == this.localPath &&
          other.remoteUrl == this.remoteUrl &&
          other.animeLabelId == this.animeLabelId &&
          other.episode == this.episode &&
          other.timestampS == this.timestampS &&
          other.source == this.source &&
          other.sourceUrl == this.sourceUrl &&
          other.createdAt == this.createdAt);
}

class NewReferenceImagesCompanion extends UpdateCompanion<NewReferenceImage> {
  final Value<String> id;
  final Value<String?> placeKey;
  final Value<String?> stopId;
  final Value<String?> localPath;
  final Value<String?> remoteUrl;
  final Value<String?> animeLabelId;
  final Value<String?> episode;
  final Value<int?> timestampS;
  final Value<String?> source;
  final Value<String?> sourceUrl;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const NewReferenceImagesCompanion({
    this.id = const Value.absent(),
    this.placeKey = const Value.absent(),
    this.stopId = const Value.absent(),
    this.localPath = const Value.absent(),
    this.remoteUrl = const Value.absent(),
    this.animeLabelId = const Value.absent(),
    this.episode = const Value.absent(),
    this.timestampS = const Value.absent(),
    this.source = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NewReferenceImagesCompanion.insert({
    required String id,
    this.placeKey = const Value.absent(),
    this.stopId = const Value.absent(),
    this.localPath = const Value.absent(),
    this.remoteUrl = const Value.absent(),
    this.animeLabelId = const Value.absent(),
    this.episode = const Value.absent(),
    this.timestampS = const Value.absent(),
    this.source = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id);
  static Insertable<NewReferenceImage> custom({
    Expression<String>? id,
    Expression<String>? placeKey,
    Expression<String>? stopId,
    Expression<String>? localPath,
    Expression<String>? remoteUrl,
    Expression<String>? animeLabelId,
    Expression<String>? episode,
    Expression<int>? timestampS,
    Expression<String>? source,
    Expression<String>? sourceUrl,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (placeKey != null) 'place_key': placeKey,
      if (stopId != null) 'stop_id': stopId,
      if (localPath != null) 'local_path': localPath,
      if (remoteUrl != null) 'remote_url': remoteUrl,
      if (animeLabelId != null) 'anime_label_id': animeLabelId,
      if (episode != null) 'episode': episode,
      if (timestampS != null) 'timestamp_s': timestampS,
      if (source != null) 'source': source,
      if (sourceUrl != null) 'source_url': sourceUrl,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NewReferenceImagesCompanion copyWith({
    Value<String>? id,
    Value<String?>? placeKey,
    Value<String?>? stopId,
    Value<String?>? localPath,
    Value<String?>? remoteUrl,
    Value<String?>? animeLabelId,
    Value<String?>? episode,
    Value<int?>? timestampS,
    Value<String?>? source,
    Value<String?>? sourceUrl,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return NewReferenceImagesCompanion(
      id: id ?? this.id,
      placeKey: placeKey ?? this.placeKey,
      stopId: stopId ?? this.stopId,
      localPath: localPath ?? this.localPath,
      remoteUrl: remoteUrl ?? this.remoteUrl,
      animeLabelId: animeLabelId ?? this.animeLabelId,
      episode: episode ?? this.episode,
      timestampS: timestampS ?? this.timestampS,
      source: source ?? this.source,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (placeKey.present) {
      map['place_key'] = Variable<String>(placeKey.value);
    }
    if (stopId.present) {
      map['stop_id'] = Variable<String>(stopId.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (remoteUrl.present) {
      map['remote_url'] = Variable<String>(remoteUrl.value);
    }
    if (animeLabelId.present) {
      map['anime_label_id'] = Variable<String>(animeLabelId.value);
    }
    if (episode.present) {
      map['episode'] = Variable<String>(episode.value);
    }
    if (timestampS.present) {
      map['timestamp_s'] = Variable<int>(timestampS.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (sourceUrl.present) {
      map['source_url'] = Variable<String>(sourceUrl.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NewReferenceImagesCompanion(')
          ..write('id: $id, ')
          ..write('placeKey: $placeKey, ')
          ..write('stopId: $stopId, ')
          ..write('localPath: $localPath, ')
          ..write('remoteUrl: $remoteUrl, ')
          ..write('animeLabelId: $animeLabelId, ')
          ..write('episode: $episode, ')
          ..write('timestampS: $timestampS, ')
          ..write('source: $source, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TripsTable extends Trips with TableInfo<$TripsTable, Trip> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TripsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
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
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sharingMeta = const VerificationMeta(
    'sharing',
  );
  @override
  late final GeneratedColumn<String> sharing = GeneratedColumn<String>(
    'sharing',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('private'),
  );
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<String> startDate = GeneratedColumn<String>(
    'start_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dayCountMeta = const VerificationMeta(
    'dayCount',
  );
  @override
  late final GeneratedColumn<int> dayCount = GeneratedColumn<int>(
    'day_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
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
    clientDefault: () => DateTime.now(),
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> updatedAt =
      GeneratedColumn<int>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        clientDefault: () => DateTime.now().millisecondsSinceEpoch,
      ).withConverter<DateTime>($TripsTable.$converterupdatedAt);
  static const VerificationMeta _updatedByMeta = const VerificationMeta(
    'updatedBy',
  );
  @override
  late final GeneratedColumn<String> updatedBy = GeneratedColumn<String>(
    'updated_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, int> deletedAt =
      GeneratedColumn<int>(
        'deleted_at',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($TripsTable.$converterdeletedAtn);
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<int> syncStatus = GeneratedColumn<int>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    description,
    ownerId,
    sharing,
    startDate,
    dayCount,
    createdAt,
    updatedAt,
    updatedBy,
    deletedAt,
    syncStatus,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'trips';
  @override
  VerificationContext validateIntegrity(
    Insertable<Trip> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
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
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('sharing')) {
      context.handle(
        _sharingMeta,
        sharing.isAcceptableOrUnknown(data['sharing']!, _sharingMeta),
      );
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    }
    if (data.containsKey('day_count')) {
      context.handle(
        _dayCountMeta,
        dayCount.isAcceptableOrUnknown(data['day_count']!, _dayCountMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_by')) {
      context.handle(
        _updatedByMeta,
        updatedBy.isAcceptableOrUnknown(data['updated_by']!, _updatedByMeta),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Trip map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Trip(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      sharing: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sharing'],
      )!,
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}start_date'],
      ),
      dayCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}day_count'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: $TripsTable.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
      updatedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_by'],
      ),
      deletedAt: $TripsTable.$converterdeletedAtn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}deleted_at'],
        ),
      ),
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sync_status'],
      )!,
    );
  }

  @override
  $TripsTable createAlias(String alias) {
    return $TripsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converterupdatedAt =
      const MillisecondDateTimeConverter();
  static TypeConverter<DateTime, int> $converterdeletedAt =
      const MillisecondDateTimeConverter();
  static TypeConverter<DateTime?, int?> $converterdeletedAtn =
      NullAwareTypeConverter.wrap($converterdeletedAt);
}

class Trip extends DataClass implements Insertable<Trip> {
  final String id;
  final String title;
  final String? description;
  final String ownerId;
  final String sharing;
  final String? startDate;
  final int dayCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? updatedBy;
  final DateTime? deletedAt;
  final int syncStatus;
  const Trip({
    required this.id,
    required this.title,
    this.description,
    required this.ownerId,
    required this.sharing,
    this.startDate,
    required this.dayCount,
    required this.createdAt,
    required this.updatedAt,
    this.updatedBy,
    this.deletedAt,
    required this.syncStatus,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['owner_id'] = Variable<String>(ownerId);
    map['sharing'] = Variable<String>(sharing);
    if (!nullToAbsent || startDate != null) {
      map['start_date'] = Variable<String>(startDate);
    }
    map['day_count'] = Variable<int>(dayCount);
    map['created_at'] = Variable<DateTime>(createdAt);
    {
      map['updated_at'] = Variable<int>(
        $TripsTable.$converterupdatedAt.toSql(updatedAt),
      );
    }
    if (!nullToAbsent || updatedBy != null) {
      map['updated_by'] = Variable<String>(updatedBy);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(
        $TripsTable.$converterdeletedAtn.toSql(deletedAt),
      );
    }
    map['sync_status'] = Variable<int>(syncStatus);
    return map;
  }

  TripsCompanion toCompanion(bool nullToAbsent) {
    return TripsCompanion(
      id: Value(id),
      title: Value(title),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      ownerId: Value(ownerId),
      sharing: Value(sharing),
      startDate: startDate == null && nullToAbsent
          ? const Value.absent()
          : Value(startDate),
      dayCount: Value(dayCount),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      updatedBy: updatedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedBy),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      syncStatus: Value(syncStatus),
    );
  }

  factory Trip.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Trip(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String?>(json['description']),
      ownerId: serializer.fromJson<String>(json['ownerId']),
      sharing: serializer.fromJson<String>(json['sharing']),
      startDate: serializer.fromJson<String?>(json['startDate']),
      dayCount: serializer.fromJson<int>(json['dayCount']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      updatedBy: serializer.fromJson<String?>(json['updatedBy']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      syncStatus: serializer.fromJson<int>(json['syncStatus']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String?>(description),
      'ownerId': serializer.toJson<String>(ownerId),
      'sharing': serializer.toJson<String>(sharing),
      'startDate': serializer.toJson<String?>(startDate),
      'dayCount': serializer.toJson<int>(dayCount),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'updatedBy': serializer.toJson<String?>(updatedBy),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'syncStatus': serializer.toJson<int>(syncStatus),
    };
  }

  Trip copyWith({
    String? id,
    String? title,
    Value<String?> description = const Value.absent(),
    String? ownerId,
    String? sharing,
    Value<String?> startDate = const Value.absent(),
    int? dayCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<String?> updatedBy = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
    int? syncStatus,
  }) => Trip(
    id: id ?? this.id,
    title: title ?? this.title,
    description: description.present ? description.value : this.description,
    ownerId: ownerId ?? this.ownerId,
    sharing: sharing ?? this.sharing,
    startDate: startDate.present ? startDate.value : this.startDate,
    dayCount: dayCount ?? this.dayCount,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    updatedBy: updatedBy.present ? updatedBy.value : this.updatedBy,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    syncStatus: syncStatus ?? this.syncStatus,
  );
  Trip copyWithCompanion(TripsCompanion data) {
    return Trip(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      sharing: data.sharing.present ? data.sharing.value : this.sharing,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      dayCount: data.dayCount.present ? data.dayCount.value : this.dayCount,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      updatedBy: data.updatedBy.present ? data.updatedBy.value : this.updatedBy,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Trip(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('ownerId: $ownerId, ')
          ..write('sharing: $sharing, ')
          ..write('startDate: $startDate, ')
          ..write('dayCount: $dayCount, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    description,
    ownerId,
    sharing,
    startDate,
    dayCount,
    createdAt,
    updatedAt,
    updatedBy,
    deletedAt,
    syncStatus,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Trip &&
          other.id == this.id &&
          other.title == this.title &&
          other.description == this.description &&
          other.ownerId == this.ownerId &&
          other.sharing == this.sharing &&
          other.startDate == this.startDate &&
          other.dayCount == this.dayCount &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.updatedBy == this.updatedBy &&
          other.deletedAt == this.deletedAt &&
          other.syncStatus == this.syncStatus);
}

class TripsCompanion extends UpdateCompanion<Trip> {
  final Value<String> id;
  final Value<String> title;
  final Value<String?> description;
  final Value<String> ownerId;
  final Value<String> sharing;
  final Value<String?> startDate;
  final Value<int> dayCount;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String?> updatedBy;
  final Value<DateTime?> deletedAt;
  final Value<int> syncStatus;
  final Value<int> rowid;
  const TripsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.sharing = const Value.absent(),
    this.startDate = const Value.absent(),
    this.dayCount = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.updatedBy = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TripsCompanion.insert({
    required String id,
    required String title,
    this.description = const Value.absent(),
    required String ownerId,
    this.sharing = const Value.absent(),
    this.startDate = const Value.absent(),
    this.dayCount = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.updatedBy = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       ownerId = Value(ownerId);
  static Insertable<Trip> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? description,
    Expression<String>? ownerId,
    Expression<String>? sharing,
    Expression<String>? startDate,
    Expression<int>? dayCount,
    Expression<DateTime>? createdAt,
    Expression<int>? updatedAt,
    Expression<String>? updatedBy,
    Expression<int>? deletedAt,
    Expression<int>? syncStatus,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (ownerId != null) 'owner_id': ownerId,
      if (sharing != null) 'sharing': sharing,
      if (startDate != null) 'start_date': startDate,
      if (dayCount != null) 'day_count': dayCount,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (updatedBy != null) 'updated_by': updatedBy,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TripsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String?>? description,
    Value<String>? ownerId,
    Value<String>? sharing,
    Value<String?>? startDate,
    Value<int>? dayCount,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<String?>? updatedBy,
    Value<DateTime?>? deletedAt,
    Value<int>? syncStatus,
    Value<int>? rowid,
  }) {
    return TripsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      ownerId: ownerId ?? this.ownerId,
      sharing: sharing ?? this.sharing,
      startDate: startDate ?? this.startDate,
      dayCount: dayCount ?? this.dayCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
      deletedAt: deletedAt ?? this.deletedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (sharing.present) {
      map['sharing'] = Variable<String>(sharing.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<String>(startDate.value);
    }
    if (dayCount.present) {
      map['day_count'] = Variable<int>(dayCount.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(
        $TripsTable.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    if (updatedBy.present) {
      map['updated_by'] = Variable<String>(updatedBy.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(
        $TripsTable.$converterdeletedAtn.toSql(deletedAt.value),
      );
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<int>(syncStatus.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TripsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('ownerId: $ownerId, ')
          ..write('sharing: $sharing, ')
          ..write('startDate: $startDate, ')
          ..write('dayCount: $dayCount, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TripDaysTable extends TripDays with TableInfo<$TripDaysTable, TripDay> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TripDaysTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tripIdMeta = const VerificationMeta('tripId');
  @override
  late final GeneratedColumn<String> tripId = GeneratedColumn<String>(
    'trip_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES trips (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _sortKeyMeta = const VerificationMeta(
    'sortKey',
  );
  @override
  late final GeneratedColumn<String> sortKey = GeneratedColumn<String>(
    'sort_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pinnedDateMeta = const VerificationMeta(
    'pinnedDate',
  );
  @override
  late final GeneratedColumn<String> pinnedDate = GeneratedColumn<String>(
    'pinned_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> updatedAt =
      GeneratedColumn<int>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        clientDefault: () => DateTime.now().millisecondsSinceEpoch,
      ).withConverter<DateTime>($TripDaysTable.$converterupdatedAt);
  static const VerificationMeta _updatedByMeta = const VerificationMeta(
    'updatedBy',
  );
  @override
  late final GeneratedColumn<String> updatedBy = GeneratedColumn<String>(
    'updated_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, int> deletedAt =
      GeneratedColumn<int>(
        'deleted_at',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($TripDaysTable.$converterdeletedAtn);
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<int> syncStatus = GeneratedColumn<int>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tripId,
    sortKey,
    title,
    pinnedDate,
    updatedAt,
    updatedBy,
    deletedAt,
    syncStatus,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'trip_days';
  @override
  VerificationContext validateIntegrity(
    Insertable<TripDay> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('trip_id')) {
      context.handle(
        _tripIdMeta,
        tripId.isAcceptableOrUnknown(data['trip_id']!, _tripIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tripIdMeta);
    }
    if (data.containsKey('sort_key')) {
      context.handle(
        _sortKeyMeta,
        sortKey.isAcceptableOrUnknown(data['sort_key']!, _sortKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_sortKeyMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('pinned_date')) {
      context.handle(
        _pinnedDateMeta,
        pinnedDate.isAcceptableOrUnknown(data['pinned_date']!, _pinnedDateMeta),
      );
    }
    if (data.containsKey('updated_by')) {
      context.handle(
        _updatedByMeta,
        updatedBy.isAcceptableOrUnknown(data['updated_by']!, _updatedByMeta),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TripDay map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TripDay(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tripId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trip_id'],
      )!,
      sortKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sort_key'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      pinnedDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pinned_date'],
      ),
      updatedAt: $TripDaysTable.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
      updatedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_by'],
      ),
      deletedAt: $TripDaysTable.$converterdeletedAtn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}deleted_at'],
        ),
      ),
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sync_status'],
      )!,
    );
  }

  @override
  $TripDaysTable createAlias(String alias) {
    return $TripDaysTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converterupdatedAt =
      const MillisecondDateTimeConverter();
  static TypeConverter<DateTime, int> $converterdeletedAt =
      const MillisecondDateTimeConverter();
  static TypeConverter<DateTime?, int?> $converterdeletedAtn =
      NullAwareTypeConverter.wrap($converterdeletedAt);
}

class TripDay extends DataClass implements Insertable<TripDay> {
  final String id;
  final String tripId;
  final String sortKey;
  final String? title;
  final String? pinnedDate;
  final DateTime updatedAt;
  final String? updatedBy;
  final DateTime? deletedAt;
  final int syncStatus;
  const TripDay({
    required this.id,
    required this.tripId,
    required this.sortKey,
    this.title,
    this.pinnedDate,
    required this.updatedAt,
    this.updatedBy,
    this.deletedAt,
    required this.syncStatus,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['trip_id'] = Variable<String>(tripId);
    map['sort_key'] = Variable<String>(sortKey);
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || pinnedDate != null) {
      map['pinned_date'] = Variable<String>(pinnedDate);
    }
    {
      map['updated_at'] = Variable<int>(
        $TripDaysTable.$converterupdatedAt.toSql(updatedAt),
      );
    }
    if (!nullToAbsent || updatedBy != null) {
      map['updated_by'] = Variable<String>(updatedBy);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(
        $TripDaysTable.$converterdeletedAtn.toSql(deletedAt),
      );
    }
    map['sync_status'] = Variable<int>(syncStatus);
    return map;
  }

  TripDaysCompanion toCompanion(bool nullToAbsent) {
    return TripDaysCompanion(
      id: Value(id),
      tripId: Value(tripId),
      sortKey: Value(sortKey),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      pinnedDate: pinnedDate == null && nullToAbsent
          ? const Value.absent()
          : Value(pinnedDate),
      updatedAt: Value(updatedAt),
      updatedBy: updatedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedBy),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      syncStatus: Value(syncStatus),
    );
  }

  factory TripDay.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TripDay(
      id: serializer.fromJson<String>(json['id']),
      tripId: serializer.fromJson<String>(json['tripId']),
      sortKey: serializer.fromJson<String>(json['sortKey']),
      title: serializer.fromJson<String?>(json['title']),
      pinnedDate: serializer.fromJson<String?>(json['pinnedDate']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      updatedBy: serializer.fromJson<String?>(json['updatedBy']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      syncStatus: serializer.fromJson<int>(json['syncStatus']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tripId': serializer.toJson<String>(tripId),
      'sortKey': serializer.toJson<String>(sortKey),
      'title': serializer.toJson<String?>(title),
      'pinnedDate': serializer.toJson<String?>(pinnedDate),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'updatedBy': serializer.toJson<String?>(updatedBy),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'syncStatus': serializer.toJson<int>(syncStatus),
    };
  }

  TripDay copyWith({
    String? id,
    String? tripId,
    String? sortKey,
    Value<String?> title = const Value.absent(),
    Value<String?> pinnedDate = const Value.absent(),
    DateTime? updatedAt,
    Value<String?> updatedBy = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
    int? syncStatus,
  }) => TripDay(
    id: id ?? this.id,
    tripId: tripId ?? this.tripId,
    sortKey: sortKey ?? this.sortKey,
    title: title.present ? title.value : this.title,
    pinnedDate: pinnedDate.present ? pinnedDate.value : this.pinnedDate,
    updatedAt: updatedAt ?? this.updatedAt,
    updatedBy: updatedBy.present ? updatedBy.value : this.updatedBy,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    syncStatus: syncStatus ?? this.syncStatus,
  );
  TripDay copyWithCompanion(TripDaysCompanion data) {
    return TripDay(
      id: data.id.present ? data.id.value : this.id,
      tripId: data.tripId.present ? data.tripId.value : this.tripId,
      sortKey: data.sortKey.present ? data.sortKey.value : this.sortKey,
      title: data.title.present ? data.title.value : this.title,
      pinnedDate: data.pinnedDate.present
          ? data.pinnedDate.value
          : this.pinnedDate,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      updatedBy: data.updatedBy.present ? data.updatedBy.value : this.updatedBy,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TripDay(')
          ..write('id: $id, ')
          ..write('tripId: $tripId, ')
          ..write('sortKey: $sortKey, ')
          ..write('title: $title, ')
          ..write('pinnedDate: $pinnedDate, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tripId,
    sortKey,
    title,
    pinnedDate,
    updatedAt,
    updatedBy,
    deletedAt,
    syncStatus,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TripDay &&
          other.id == this.id &&
          other.tripId == this.tripId &&
          other.sortKey == this.sortKey &&
          other.title == this.title &&
          other.pinnedDate == this.pinnedDate &&
          other.updatedAt == this.updatedAt &&
          other.updatedBy == this.updatedBy &&
          other.deletedAt == this.deletedAt &&
          other.syncStatus == this.syncStatus);
}

class TripDaysCompanion extends UpdateCompanion<TripDay> {
  final Value<String> id;
  final Value<String> tripId;
  final Value<String> sortKey;
  final Value<String?> title;
  final Value<String?> pinnedDate;
  final Value<DateTime> updatedAt;
  final Value<String?> updatedBy;
  final Value<DateTime?> deletedAt;
  final Value<int> syncStatus;
  final Value<int> rowid;
  const TripDaysCompanion({
    this.id = const Value.absent(),
    this.tripId = const Value.absent(),
    this.sortKey = const Value.absent(),
    this.title = const Value.absent(),
    this.pinnedDate = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.updatedBy = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TripDaysCompanion.insert({
    required String id,
    required String tripId,
    required String sortKey,
    this.title = const Value.absent(),
    this.pinnedDate = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.updatedBy = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tripId = Value(tripId),
       sortKey = Value(sortKey);
  static Insertable<TripDay> custom({
    Expression<String>? id,
    Expression<String>? tripId,
    Expression<String>? sortKey,
    Expression<String>? title,
    Expression<String>? pinnedDate,
    Expression<int>? updatedAt,
    Expression<String>? updatedBy,
    Expression<int>? deletedAt,
    Expression<int>? syncStatus,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tripId != null) 'trip_id': tripId,
      if (sortKey != null) 'sort_key': sortKey,
      if (title != null) 'title': title,
      if (pinnedDate != null) 'pinned_date': pinnedDate,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (updatedBy != null) 'updated_by': updatedBy,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TripDaysCompanion copyWith({
    Value<String>? id,
    Value<String>? tripId,
    Value<String>? sortKey,
    Value<String?>? title,
    Value<String?>? pinnedDate,
    Value<DateTime>? updatedAt,
    Value<String?>? updatedBy,
    Value<DateTime?>? deletedAt,
    Value<int>? syncStatus,
    Value<int>? rowid,
  }) {
    return TripDaysCompanion(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      sortKey: sortKey ?? this.sortKey,
      title: title ?? this.title,
      pinnedDate: pinnedDate ?? this.pinnedDate,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
      deletedAt: deletedAt ?? this.deletedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tripId.present) {
      map['trip_id'] = Variable<String>(tripId.value);
    }
    if (sortKey.present) {
      map['sort_key'] = Variable<String>(sortKey.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (pinnedDate.present) {
      map['pinned_date'] = Variable<String>(pinnedDate.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(
        $TripDaysTable.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    if (updatedBy.present) {
      map['updated_by'] = Variable<String>(updatedBy.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(
        $TripDaysTable.$converterdeletedAtn.toSql(deletedAt.value),
      );
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<int>(syncStatus.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TripDaysCompanion(')
          ..write('id: $id, ')
          ..write('tripId: $tripId, ')
          ..write('sortKey: $sortKey, ')
          ..write('title: $title, ')
          ..write('pinnedDate: $pinnedDate, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StopsTable extends Stops with TableInfo<$StopsTable, Stop> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StopsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tripIdMeta = const VerificationMeta('tripId');
  @override
  late final GeneratedColumn<String> tripId = GeneratedColumn<String>(
    'trip_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES trips (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _placeKeyMeta = const VerificationMeta(
    'placeKey',
  );
  @override
  late final GeneratedColumn<String> placeKey = GeneratedColumn<String>(
    'place_key',
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
  static const VerificationMeta _latMeta = const VerificationMeta('lat');
  @override
  late final GeneratedColumn<double> lat = GeneratedColumn<double>(
    'lat',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lngMeta = const VerificationMeta('lng');
  @override
  late final GeneratedColumn<double> lng = GeneratedColumn<double>(
    'lng',
    aliasedName,
    false,
    type: DriftSqlType.double,
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
  static const VerificationMeta _addressMeta = const VerificationMeta(
    'address',
  );
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
    'address',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _businessHoursMeta = const VerificationMeta(
    'businessHours',
  );
  @override
  late final GeneratedColumn<String> businessHours = GeneratedColumn<String>(
    'business_hours',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contactInfoMeta = const VerificationMeta(
    'contactInfo',
  );
  @override
  late final GeneratedColumn<String> contactInfo = GeneratedColumn<String>(
    'contact_info',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _accessTipsMeta = const VerificationMeta(
    'accessTips',
  );
  @override
  late final GeneratedColumn<String> accessTips = GeneratedColumn<String>(
    'access_tips',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _linksMeta = const VerificationMeta('links');
  @override
  late final GeneratedColumn<String> links = GeneratedColumn<String>(
    'links',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverLocalPathMeta = const VerificationMeta(
    'coverLocalPath',
  );
  @override
  late final GeneratedColumn<String> coverLocalPath = GeneratedColumn<String>(
    'cover_local_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverRemoteUrlMeta = const VerificationMeta(
    'coverRemoteUrl',
  );
  @override
  late final GeneratedColumn<String> coverRemoteUrl = GeneratedColumn<String>(
    'cover_remote_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceUrlMeta = const VerificationMeta(
    'sourceUrl',
  );
  @override
  late final GeneratedColumn<String> sourceUrl = GeneratedColumn<String>(
    'source_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _areaMeta = const VerificationMeta('area');
  @override
  late final GeneratedColumn<String> area = GeneratedColumn<String>(
    'area',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _addedByMeta = const VerificationMeta(
    'addedBy',
  );
  @override
  late final GeneratedColumn<String> addedBy = GeneratedColumn<String>(
    'added_by',
    aliasedName,
    false,
    type: DriftSqlType.string,
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
    clientDefault: () => DateTime.now(),
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> updatedAt =
      GeneratedColumn<int>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        clientDefault: () => DateTime.now().millisecondsSinceEpoch,
      ).withConverter<DateTime>($StopsTable.$converterupdatedAt);
  static const VerificationMeta _updatedByMeta = const VerificationMeta(
    'updatedBy',
  );
  @override
  late final GeneratedColumn<String> updatedBy = GeneratedColumn<String>(
    'updated_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, int> deletedAt =
      GeneratedColumn<int>(
        'deleted_at',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($StopsTable.$converterdeletedAtn);
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<int> syncStatus = GeneratedColumn<int>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tripId,
    placeKey,
    name,
    lat,
    lng,
    description,
    address,
    businessHours,
    contactInfo,
    accessTips,
    links,
    coverLocalPath,
    coverRemoteUrl,
    source,
    sourceUrl,
    area,
    note,
    addedBy,
    createdAt,
    updatedAt,
    updatedBy,
    deletedAt,
    syncStatus,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stops';
  @override
  VerificationContext validateIntegrity(
    Insertable<Stop> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('trip_id')) {
      context.handle(
        _tripIdMeta,
        tripId.isAcceptableOrUnknown(data['trip_id']!, _tripIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tripIdMeta);
    }
    if (data.containsKey('place_key')) {
      context.handle(
        _placeKeyMeta,
        placeKey.isAcceptableOrUnknown(data['place_key']!, _placeKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_placeKeyMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('lat')) {
      context.handle(
        _latMeta,
        lat.isAcceptableOrUnknown(data['lat']!, _latMeta),
      );
    } else if (isInserting) {
      context.missing(_latMeta);
    }
    if (data.containsKey('lng')) {
      context.handle(
        _lngMeta,
        lng.isAcceptableOrUnknown(data['lng']!, _lngMeta),
      );
    } else if (isInserting) {
      context.missing(_lngMeta);
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
    if (data.containsKey('address')) {
      context.handle(
        _addressMeta,
        address.isAcceptableOrUnknown(data['address']!, _addressMeta),
      );
    }
    if (data.containsKey('business_hours')) {
      context.handle(
        _businessHoursMeta,
        businessHours.isAcceptableOrUnknown(
          data['business_hours']!,
          _businessHoursMeta,
        ),
      );
    }
    if (data.containsKey('contact_info')) {
      context.handle(
        _contactInfoMeta,
        contactInfo.isAcceptableOrUnknown(
          data['contact_info']!,
          _contactInfoMeta,
        ),
      );
    }
    if (data.containsKey('access_tips')) {
      context.handle(
        _accessTipsMeta,
        accessTips.isAcceptableOrUnknown(data['access_tips']!, _accessTipsMeta),
      );
    }
    if (data.containsKey('links')) {
      context.handle(
        _linksMeta,
        links.isAcceptableOrUnknown(data['links']!, _linksMeta),
      );
    }
    if (data.containsKey('cover_local_path')) {
      context.handle(
        _coverLocalPathMeta,
        coverLocalPath.isAcceptableOrUnknown(
          data['cover_local_path']!,
          _coverLocalPathMeta,
        ),
      );
    }
    if (data.containsKey('cover_remote_url')) {
      context.handle(
        _coverRemoteUrlMeta,
        coverRemoteUrl.isAcceptableOrUnknown(
          data['cover_remote_url']!,
          _coverRemoteUrlMeta,
        ),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('source_url')) {
      context.handle(
        _sourceUrlMeta,
        sourceUrl.isAcceptableOrUnknown(data['source_url']!, _sourceUrlMeta),
      );
    }
    if (data.containsKey('area')) {
      context.handle(
        _areaMeta,
        area.isAcceptableOrUnknown(data['area']!, _areaMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('added_by')) {
      context.handle(
        _addedByMeta,
        addedBy.isAcceptableOrUnknown(data['added_by']!, _addedByMeta),
      );
    } else if (isInserting) {
      context.missing(_addedByMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_by')) {
      context.handle(
        _updatedByMeta,
        updatedBy.isAcceptableOrUnknown(data['updated_by']!, _updatedByMeta),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Stop map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Stop(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tripId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trip_id'],
      )!,
      placeKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}place_key'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      lat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lat'],
      )!,
      lng: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lng'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      address: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address'],
      ),
      businessHours: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}business_hours'],
      ),
      contactInfo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}contact_info'],
      ),
      accessTips: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}access_tips'],
      ),
      links: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}links'],
      ),
      coverLocalPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_local_path'],
      ),
      coverRemoteUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_remote_url'],
      ),
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      ),
      sourceUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_url'],
      ),
      area: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}area'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      addedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}added_by'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: $StopsTable.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
      updatedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_by'],
      ),
      deletedAt: $StopsTable.$converterdeletedAtn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}deleted_at'],
        ),
      ),
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sync_status'],
      )!,
    );
  }

  @override
  $StopsTable createAlias(String alias) {
    return $StopsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converterupdatedAt =
      const MillisecondDateTimeConverter();
  static TypeConverter<DateTime, int> $converterdeletedAt =
      const MillisecondDateTimeConverter();
  static TypeConverter<DateTime?, int?> $converterdeletedAtn =
      NullAwareTypeConverter.wrap($converterdeletedAt);
}

class Stop extends DataClass implements Insertable<Stop> {
  final String id;
  final String tripId;
  final String placeKey;
  final String name;
  final double lat;
  final double lng;
  final String? description;
  final String? address;
  final String? businessHours;
  final String? contactInfo;
  final String? accessTips;
  final String? links;
  final String? coverLocalPath;
  final String? coverRemoteUrl;
  final String? source;
  final String? sourceUrl;
  final String? area;
  final String? note;
  final String addedBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? updatedBy;
  final DateTime? deletedAt;
  final int syncStatus;
  const Stop({
    required this.id,
    required this.tripId,
    required this.placeKey,
    required this.name,
    required this.lat,
    required this.lng,
    this.description,
    this.address,
    this.businessHours,
    this.contactInfo,
    this.accessTips,
    this.links,
    this.coverLocalPath,
    this.coverRemoteUrl,
    this.source,
    this.sourceUrl,
    this.area,
    this.note,
    required this.addedBy,
    required this.createdAt,
    required this.updatedAt,
    this.updatedBy,
    this.deletedAt,
    required this.syncStatus,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['trip_id'] = Variable<String>(tripId);
    map['place_key'] = Variable<String>(placeKey);
    map['name'] = Variable<String>(name);
    map['lat'] = Variable<double>(lat);
    map['lng'] = Variable<double>(lng);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || address != null) {
      map['address'] = Variable<String>(address);
    }
    if (!nullToAbsent || businessHours != null) {
      map['business_hours'] = Variable<String>(businessHours);
    }
    if (!nullToAbsent || contactInfo != null) {
      map['contact_info'] = Variable<String>(contactInfo);
    }
    if (!nullToAbsent || accessTips != null) {
      map['access_tips'] = Variable<String>(accessTips);
    }
    if (!nullToAbsent || links != null) {
      map['links'] = Variable<String>(links);
    }
    if (!nullToAbsent || coverLocalPath != null) {
      map['cover_local_path'] = Variable<String>(coverLocalPath);
    }
    if (!nullToAbsent || coverRemoteUrl != null) {
      map['cover_remote_url'] = Variable<String>(coverRemoteUrl);
    }
    if (!nullToAbsent || source != null) {
      map['source'] = Variable<String>(source);
    }
    if (!nullToAbsent || sourceUrl != null) {
      map['source_url'] = Variable<String>(sourceUrl);
    }
    if (!nullToAbsent || area != null) {
      map['area'] = Variable<String>(area);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['added_by'] = Variable<String>(addedBy);
    map['created_at'] = Variable<DateTime>(createdAt);
    {
      map['updated_at'] = Variable<int>(
        $StopsTable.$converterupdatedAt.toSql(updatedAt),
      );
    }
    if (!nullToAbsent || updatedBy != null) {
      map['updated_by'] = Variable<String>(updatedBy);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(
        $StopsTable.$converterdeletedAtn.toSql(deletedAt),
      );
    }
    map['sync_status'] = Variable<int>(syncStatus);
    return map;
  }

  StopsCompanion toCompanion(bool nullToAbsent) {
    return StopsCompanion(
      id: Value(id),
      tripId: Value(tripId),
      placeKey: Value(placeKey),
      name: Value(name),
      lat: Value(lat),
      lng: Value(lng),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      address: address == null && nullToAbsent
          ? const Value.absent()
          : Value(address),
      businessHours: businessHours == null && nullToAbsent
          ? const Value.absent()
          : Value(businessHours),
      contactInfo: contactInfo == null && nullToAbsent
          ? const Value.absent()
          : Value(contactInfo),
      accessTips: accessTips == null && nullToAbsent
          ? const Value.absent()
          : Value(accessTips),
      links: links == null && nullToAbsent
          ? const Value.absent()
          : Value(links),
      coverLocalPath: coverLocalPath == null && nullToAbsent
          ? const Value.absent()
          : Value(coverLocalPath),
      coverRemoteUrl: coverRemoteUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(coverRemoteUrl),
      source: source == null && nullToAbsent
          ? const Value.absent()
          : Value(source),
      sourceUrl: sourceUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceUrl),
      area: area == null && nullToAbsent ? const Value.absent() : Value(area),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      addedBy: Value(addedBy),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      updatedBy: updatedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedBy),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      syncStatus: Value(syncStatus),
    );
  }

  factory Stop.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Stop(
      id: serializer.fromJson<String>(json['id']),
      tripId: serializer.fromJson<String>(json['tripId']),
      placeKey: serializer.fromJson<String>(json['placeKey']),
      name: serializer.fromJson<String>(json['name']),
      lat: serializer.fromJson<double>(json['lat']),
      lng: serializer.fromJson<double>(json['lng']),
      description: serializer.fromJson<String?>(json['description']),
      address: serializer.fromJson<String?>(json['address']),
      businessHours: serializer.fromJson<String?>(json['businessHours']),
      contactInfo: serializer.fromJson<String?>(json['contactInfo']),
      accessTips: serializer.fromJson<String?>(json['accessTips']),
      links: serializer.fromJson<String?>(json['links']),
      coverLocalPath: serializer.fromJson<String?>(json['coverLocalPath']),
      coverRemoteUrl: serializer.fromJson<String?>(json['coverRemoteUrl']),
      source: serializer.fromJson<String?>(json['source']),
      sourceUrl: serializer.fromJson<String?>(json['sourceUrl']),
      area: serializer.fromJson<String?>(json['area']),
      note: serializer.fromJson<String?>(json['note']),
      addedBy: serializer.fromJson<String>(json['addedBy']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      updatedBy: serializer.fromJson<String?>(json['updatedBy']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      syncStatus: serializer.fromJson<int>(json['syncStatus']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tripId': serializer.toJson<String>(tripId),
      'placeKey': serializer.toJson<String>(placeKey),
      'name': serializer.toJson<String>(name),
      'lat': serializer.toJson<double>(lat),
      'lng': serializer.toJson<double>(lng),
      'description': serializer.toJson<String?>(description),
      'address': serializer.toJson<String?>(address),
      'businessHours': serializer.toJson<String?>(businessHours),
      'contactInfo': serializer.toJson<String?>(contactInfo),
      'accessTips': serializer.toJson<String?>(accessTips),
      'links': serializer.toJson<String?>(links),
      'coverLocalPath': serializer.toJson<String?>(coverLocalPath),
      'coverRemoteUrl': serializer.toJson<String?>(coverRemoteUrl),
      'source': serializer.toJson<String?>(source),
      'sourceUrl': serializer.toJson<String?>(sourceUrl),
      'area': serializer.toJson<String?>(area),
      'note': serializer.toJson<String?>(note),
      'addedBy': serializer.toJson<String>(addedBy),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'updatedBy': serializer.toJson<String?>(updatedBy),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'syncStatus': serializer.toJson<int>(syncStatus),
    };
  }

  Stop copyWith({
    String? id,
    String? tripId,
    String? placeKey,
    String? name,
    double? lat,
    double? lng,
    Value<String?> description = const Value.absent(),
    Value<String?> address = const Value.absent(),
    Value<String?> businessHours = const Value.absent(),
    Value<String?> contactInfo = const Value.absent(),
    Value<String?> accessTips = const Value.absent(),
    Value<String?> links = const Value.absent(),
    Value<String?> coverLocalPath = const Value.absent(),
    Value<String?> coverRemoteUrl = const Value.absent(),
    Value<String?> source = const Value.absent(),
    Value<String?> sourceUrl = const Value.absent(),
    Value<String?> area = const Value.absent(),
    Value<String?> note = const Value.absent(),
    String? addedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<String?> updatedBy = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
    int? syncStatus,
  }) => Stop(
    id: id ?? this.id,
    tripId: tripId ?? this.tripId,
    placeKey: placeKey ?? this.placeKey,
    name: name ?? this.name,
    lat: lat ?? this.lat,
    lng: lng ?? this.lng,
    description: description.present ? description.value : this.description,
    address: address.present ? address.value : this.address,
    businessHours: businessHours.present
        ? businessHours.value
        : this.businessHours,
    contactInfo: contactInfo.present ? contactInfo.value : this.contactInfo,
    accessTips: accessTips.present ? accessTips.value : this.accessTips,
    links: links.present ? links.value : this.links,
    coverLocalPath: coverLocalPath.present
        ? coverLocalPath.value
        : this.coverLocalPath,
    coverRemoteUrl: coverRemoteUrl.present
        ? coverRemoteUrl.value
        : this.coverRemoteUrl,
    source: source.present ? source.value : this.source,
    sourceUrl: sourceUrl.present ? sourceUrl.value : this.sourceUrl,
    area: area.present ? area.value : this.area,
    note: note.present ? note.value : this.note,
    addedBy: addedBy ?? this.addedBy,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    updatedBy: updatedBy.present ? updatedBy.value : this.updatedBy,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    syncStatus: syncStatus ?? this.syncStatus,
  );
  Stop copyWithCompanion(StopsCompanion data) {
    return Stop(
      id: data.id.present ? data.id.value : this.id,
      tripId: data.tripId.present ? data.tripId.value : this.tripId,
      placeKey: data.placeKey.present ? data.placeKey.value : this.placeKey,
      name: data.name.present ? data.name.value : this.name,
      lat: data.lat.present ? data.lat.value : this.lat,
      lng: data.lng.present ? data.lng.value : this.lng,
      description: data.description.present
          ? data.description.value
          : this.description,
      address: data.address.present ? data.address.value : this.address,
      businessHours: data.businessHours.present
          ? data.businessHours.value
          : this.businessHours,
      contactInfo: data.contactInfo.present
          ? data.contactInfo.value
          : this.contactInfo,
      accessTips: data.accessTips.present
          ? data.accessTips.value
          : this.accessTips,
      links: data.links.present ? data.links.value : this.links,
      coverLocalPath: data.coverLocalPath.present
          ? data.coverLocalPath.value
          : this.coverLocalPath,
      coverRemoteUrl: data.coverRemoteUrl.present
          ? data.coverRemoteUrl.value
          : this.coverRemoteUrl,
      source: data.source.present ? data.source.value : this.source,
      sourceUrl: data.sourceUrl.present ? data.sourceUrl.value : this.sourceUrl,
      area: data.area.present ? data.area.value : this.area,
      note: data.note.present ? data.note.value : this.note,
      addedBy: data.addedBy.present ? data.addedBy.value : this.addedBy,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      updatedBy: data.updatedBy.present ? data.updatedBy.value : this.updatedBy,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Stop(')
          ..write('id: $id, ')
          ..write('tripId: $tripId, ')
          ..write('placeKey: $placeKey, ')
          ..write('name: $name, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('description: $description, ')
          ..write('address: $address, ')
          ..write('businessHours: $businessHours, ')
          ..write('contactInfo: $contactInfo, ')
          ..write('accessTips: $accessTips, ')
          ..write('links: $links, ')
          ..write('coverLocalPath: $coverLocalPath, ')
          ..write('coverRemoteUrl: $coverRemoteUrl, ')
          ..write('source: $source, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('area: $area, ')
          ..write('note: $note, ')
          ..write('addedBy: $addedBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    tripId,
    placeKey,
    name,
    lat,
    lng,
    description,
    address,
    businessHours,
    contactInfo,
    accessTips,
    links,
    coverLocalPath,
    coverRemoteUrl,
    source,
    sourceUrl,
    area,
    note,
    addedBy,
    createdAt,
    updatedAt,
    updatedBy,
    deletedAt,
    syncStatus,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Stop &&
          other.id == this.id &&
          other.tripId == this.tripId &&
          other.placeKey == this.placeKey &&
          other.name == this.name &&
          other.lat == this.lat &&
          other.lng == this.lng &&
          other.description == this.description &&
          other.address == this.address &&
          other.businessHours == this.businessHours &&
          other.contactInfo == this.contactInfo &&
          other.accessTips == this.accessTips &&
          other.links == this.links &&
          other.coverLocalPath == this.coverLocalPath &&
          other.coverRemoteUrl == this.coverRemoteUrl &&
          other.source == this.source &&
          other.sourceUrl == this.sourceUrl &&
          other.area == this.area &&
          other.note == this.note &&
          other.addedBy == this.addedBy &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.updatedBy == this.updatedBy &&
          other.deletedAt == this.deletedAt &&
          other.syncStatus == this.syncStatus);
}

class StopsCompanion extends UpdateCompanion<Stop> {
  final Value<String> id;
  final Value<String> tripId;
  final Value<String> placeKey;
  final Value<String> name;
  final Value<double> lat;
  final Value<double> lng;
  final Value<String?> description;
  final Value<String?> address;
  final Value<String?> businessHours;
  final Value<String?> contactInfo;
  final Value<String?> accessTips;
  final Value<String?> links;
  final Value<String?> coverLocalPath;
  final Value<String?> coverRemoteUrl;
  final Value<String?> source;
  final Value<String?> sourceUrl;
  final Value<String?> area;
  final Value<String?> note;
  final Value<String> addedBy;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String?> updatedBy;
  final Value<DateTime?> deletedAt;
  final Value<int> syncStatus;
  final Value<int> rowid;
  const StopsCompanion({
    this.id = const Value.absent(),
    this.tripId = const Value.absent(),
    this.placeKey = const Value.absent(),
    this.name = const Value.absent(),
    this.lat = const Value.absent(),
    this.lng = const Value.absent(),
    this.description = const Value.absent(),
    this.address = const Value.absent(),
    this.businessHours = const Value.absent(),
    this.contactInfo = const Value.absent(),
    this.accessTips = const Value.absent(),
    this.links = const Value.absent(),
    this.coverLocalPath = const Value.absent(),
    this.coverRemoteUrl = const Value.absent(),
    this.source = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.area = const Value.absent(),
    this.note = const Value.absent(),
    this.addedBy = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.updatedBy = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StopsCompanion.insert({
    required String id,
    required String tripId,
    required String placeKey,
    required String name,
    required double lat,
    required double lng,
    this.description = const Value.absent(),
    this.address = const Value.absent(),
    this.businessHours = const Value.absent(),
    this.contactInfo = const Value.absent(),
    this.accessTips = const Value.absent(),
    this.links = const Value.absent(),
    this.coverLocalPath = const Value.absent(),
    this.coverRemoteUrl = const Value.absent(),
    this.source = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.area = const Value.absent(),
    this.note = const Value.absent(),
    required String addedBy,
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.updatedBy = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tripId = Value(tripId),
       placeKey = Value(placeKey),
       name = Value(name),
       lat = Value(lat),
       lng = Value(lng),
       addedBy = Value(addedBy);
  static Insertable<Stop> custom({
    Expression<String>? id,
    Expression<String>? tripId,
    Expression<String>? placeKey,
    Expression<String>? name,
    Expression<double>? lat,
    Expression<double>? lng,
    Expression<String>? description,
    Expression<String>? address,
    Expression<String>? businessHours,
    Expression<String>? contactInfo,
    Expression<String>? accessTips,
    Expression<String>? links,
    Expression<String>? coverLocalPath,
    Expression<String>? coverRemoteUrl,
    Expression<String>? source,
    Expression<String>? sourceUrl,
    Expression<String>? area,
    Expression<String>? note,
    Expression<String>? addedBy,
    Expression<DateTime>? createdAt,
    Expression<int>? updatedAt,
    Expression<String>? updatedBy,
    Expression<int>? deletedAt,
    Expression<int>? syncStatus,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tripId != null) 'trip_id': tripId,
      if (placeKey != null) 'place_key': placeKey,
      if (name != null) 'name': name,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (description != null) 'description': description,
      if (address != null) 'address': address,
      if (businessHours != null) 'business_hours': businessHours,
      if (contactInfo != null) 'contact_info': contactInfo,
      if (accessTips != null) 'access_tips': accessTips,
      if (links != null) 'links': links,
      if (coverLocalPath != null) 'cover_local_path': coverLocalPath,
      if (coverRemoteUrl != null) 'cover_remote_url': coverRemoteUrl,
      if (source != null) 'source': source,
      if (sourceUrl != null) 'source_url': sourceUrl,
      if (area != null) 'area': area,
      if (note != null) 'note': note,
      if (addedBy != null) 'added_by': addedBy,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (updatedBy != null) 'updated_by': updatedBy,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StopsCompanion copyWith({
    Value<String>? id,
    Value<String>? tripId,
    Value<String>? placeKey,
    Value<String>? name,
    Value<double>? lat,
    Value<double>? lng,
    Value<String?>? description,
    Value<String?>? address,
    Value<String?>? businessHours,
    Value<String?>? contactInfo,
    Value<String?>? accessTips,
    Value<String?>? links,
    Value<String?>? coverLocalPath,
    Value<String?>? coverRemoteUrl,
    Value<String?>? source,
    Value<String?>? sourceUrl,
    Value<String?>? area,
    Value<String?>? note,
    Value<String>? addedBy,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<String?>? updatedBy,
    Value<DateTime?>? deletedAt,
    Value<int>? syncStatus,
    Value<int>? rowid,
  }) {
    return StopsCompanion(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      placeKey: placeKey ?? this.placeKey,
      name: name ?? this.name,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      description: description ?? this.description,
      address: address ?? this.address,
      businessHours: businessHours ?? this.businessHours,
      contactInfo: contactInfo ?? this.contactInfo,
      accessTips: accessTips ?? this.accessTips,
      links: links ?? this.links,
      coverLocalPath: coverLocalPath ?? this.coverLocalPath,
      coverRemoteUrl: coverRemoteUrl ?? this.coverRemoteUrl,
      source: source ?? this.source,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      area: area ?? this.area,
      note: note ?? this.note,
      addedBy: addedBy ?? this.addedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
      deletedAt: deletedAt ?? this.deletedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tripId.present) {
      map['trip_id'] = Variable<String>(tripId.value);
    }
    if (placeKey.present) {
      map['place_key'] = Variable<String>(placeKey.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (lat.present) {
      map['lat'] = Variable<double>(lat.value);
    }
    if (lng.present) {
      map['lng'] = Variable<double>(lng.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (businessHours.present) {
      map['business_hours'] = Variable<String>(businessHours.value);
    }
    if (contactInfo.present) {
      map['contact_info'] = Variable<String>(contactInfo.value);
    }
    if (accessTips.present) {
      map['access_tips'] = Variable<String>(accessTips.value);
    }
    if (links.present) {
      map['links'] = Variable<String>(links.value);
    }
    if (coverLocalPath.present) {
      map['cover_local_path'] = Variable<String>(coverLocalPath.value);
    }
    if (coverRemoteUrl.present) {
      map['cover_remote_url'] = Variable<String>(coverRemoteUrl.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (sourceUrl.present) {
      map['source_url'] = Variable<String>(sourceUrl.value);
    }
    if (area.present) {
      map['area'] = Variable<String>(area.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (addedBy.present) {
      map['added_by'] = Variable<String>(addedBy.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(
        $StopsTable.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    if (updatedBy.present) {
      map['updated_by'] = Variable<String>(updatedBy.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(
        $StopsTable.$converterdeletedAtn.toSql(deletedAt.value),
      );
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<int>(syncStatus.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StopsCompanion(')
          ..write('id: $id, ')
          ..write('tripId: $tripId, ')
          ..write('placeKey: $placeKey, ')
          ..write('name: $name, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('description: $description, ')
          ..write('address: $address, ')
          ..write('businessHours: $businessHours, ')
          ..write('contactInfo: $contactInfo, ')
          ..write('accessTips: $accessTips, ')
          ..write('links: $links, ')
          ..write('coverLocalPath: $coverLocalPath, ')
          ..write('coverRemoteUrl: $coverRemoteUrl, ')
          ..write('source: $source, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('area: $area, ')
          ..write('note: $note, ')
          ..write('addedBy: $addedBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StopLabelsTable extends StopLabels
    with TableInfo<$StopLabelsTable, StopLabel> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StopLabelsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _stopIdMeta = const VerificationMeta('stopId');
  @override
  late final GeneratedColumn<String> stopId = GeneratedColumn<String>(
    'stop_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES stops (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _labelIdMeta = const VerificationMeta(
    'labelId',
  );
  @override
  late final GeneratedColumn<String> labelId = GeneratedColumn<String>(
    'label_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES labels (id) ON DELETE CASCADE',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [stopId, labelId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stop_labels';
  @override
  VerificationContext validateIntegrity(
    Insertable<StopLabel> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('stop_id')) {
      context.handle(
        _stopIdMeta,
        stopId.isAcceptableOrUnknown(data['stop_id']!, _stopIdMeta),
      );
    } else if (isInserting) {
      context.missing(_stopIdMeta);
    }
    if (data.containsKey('label_id')) {
      context.handle(
        _labelIdMeta,
        labelId.isAcceptableOrUnknown(data['label_id']!, _labelIdMeta),
      );
    } else if (isInserting) {
      context.missing(_labelIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {stopId, labelId};
  @override
  StopLabel map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StopLabel(
      stopId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stop_id'],
      )!,
      labelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label_id'],
      )!,
    );
  }

  @override
  $StopLabelsTable createAlias(String alias) {
    return $StopLabelsTable(attachedDatabase, alias);
  }
}

class StopLabel extends DataClass implements Insertable<StopLabel> {
  final String stopId;
  final String labelId;
  const StopLabel({required this.stopId, required this.labelId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['stop_id'] = Variable<String>(stopId);
    map['label_id'] = Variable<String>(labelId);
    return map;
  }

  StopLabelsCompanion toCompanion(bool nullToAbsent) {
    return StopLabelsCompanion(stopId: Value(stopId), labelId: Value(labelId));
  }

  factory StopLabel.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StopLabel(
      stopId: serializer.fromJson<String>(json['stopId']),
      labelId: serializer.fromJson<String>(json['labelId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'stopId': serializer.toJson<String>(stopId),
      'labelId': serializer.toJson<String>(labelId),
    };
  }

  StopLabel copyWith({String? stopId, String? labelId}) => StopLabel(
    stopId: stopId ?? this.stopId,
    labelId: labelId ?? this.labelId,
  );
  StopLabel copyWithCompanion(StopLabelsCompanion data) {
    return StopLabel(
      stopId: data.stopId.present ? data.stopId.value : this.stopId,
      labelId: data.labelId.present ? data.labelId.value : this.labelId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StopLabel(')
          ..write('stopId: $stopId, ')
          ..write('labelId: $labelId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(stopId, labelId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StopLabel &&
          other.stopId == this.stopId &&
          other.labelId == this.labelId);
}

class StopLabelsCompanion extends UpdateCompanion<StopLabel> {
  final Value<String> stopId;
  final Value<String> labelId;
  final Value<int> rowid;
  const StopLabelsCompanion({
    this.stopId = const Value.absent(),
    this.labelId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StopLabelsCompanion.insert({
    required String stopId,
    required String labelId,
    this.rowid = const Value.absent(),
  }) : stopId = Value(stopId),
       labelId = Value(labelId);
  static Insertable<StopLabel> custom({
    Expression<String>? stopId,
    Expression<String>? labelId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (stopId != null) 'stop_id': stopId,
      if (labelId != null) 'label_id': labelId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StopLabelsCompanion copyWith({
    Value<String>? stopId,
    Value<String>? labelId,
    Value<int>? rowid,
  }) {
    return StopLabelsCompanion(
      stopId: stopId ?? this.stopId,
      labelId: labelId ?? this.labelId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (stopId.present) {
      map['stop_id'] = Variable<String>(stopId.value);
    }
    if (labelId.present) {
      map['label_id'] = Variable<String>(labelId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StopLabelsCompanion(')
          ..write('stopId: $stopId, ')
          ..write('labelId: $labelId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ScheduleItemsTable extends ScheduleItems
    with TableInfo<$ScheduleItemsTable, ScheduleItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScheduleItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tripIdMeta = const VerificationMeta('tripId');
  @override
  late final GeneratedColumn<String> tripId = GeneratedColumn<String>(
    'trip_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES trips (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _stopIdMeta = const VerificationMeta('stopId');
  @override
  late final GeneratedColumn<String> stopId = GeneratedColumn<String>(
    'stop_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES stops (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _dayIdMeta = const VerificationMeta('dayId');
  @override
  late final GeneratedColumn<String> dayId = GeneratedColumn<String>(
    'day_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES trip_days (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _sortKeyMeta = const VerificationMeta(
    'sortKey',
  );
  @override
  late final GeneratedColumn<String> sortKey = GeneratedColumn<String>(
    'sort_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stayMinutesMeta = const VerificationMeta(
    'stayMinutes',
  );
  @override
  late final GeneratedColumn<int> stayMinutes = GeneratedColumn<int>(
    'stay_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(60),
  );
  static const VerificationMeta _transitMinutesMeta = const VerificationMeta(
    'transitMinutes',
  );
  @override
  late final GeneratedColumn<int> transitMinutes = GeneratedColumn<int>(
    'transit_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _fixedTimeMeta = const VerificationMeta(
    'fixedTime',
  );
  @override
  late final GeneratedColumn<int> fixedTime = GeneratedColumn<int>(
    'fixed_time',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('planned'),
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> updatedAt =
      GeneratedColumn<int>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        clientDefault: () => DateTime.now().millisecondsSinceEpoch,
      ).withConverter<DateTime>($ScheduleItemsTable.$converterupdatedAt);
  static const VerificationMeta _updatedByMeta = const VerificationMeta(
    'updatedBy',
  );
  @override
  late final GeneratedColumn<String> updatedBy = GeneratedColumn<String>(
    'updated_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, int> deletedAt =
      GeneratedColumn<int>(
        'deleted_at',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($ScheduleItemsTable.$converterdeletedAtn);
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<int> syncStatus = GeneratedColumn<int>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tripId,
    stopId,
    dayId,
    sortKey,
    stayMinutes,
    transitMinutes,
    fixedTime,
    status,
    updatedAt,
    updatedBy,
    deletedAt,
    syncStatus,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'schedule_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<ScheduleItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('trip_id')) {
      context.handle(
        _tripIdMeta,
        tripId.isAcceptableOrUnknown(data['trip_id']!, _tripIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tripIdMeta);
    }
    if (data.containsKey('stop_id')) {
      context.handle(
        _stopIdMeta,
        stopId.isAcceptableOrUnknown(data['stop_id']!, _stopIdMeta),
      );
    } else if (isInserting) {
      context.missing(_stopIdMeta);
    }
    if (data.containsKey('day_id')) {
      context.handle(
        _dayIdMeta,
        dayId.isAcceptableOrUnknown(data['day_id']!, _dayIdMeta),
      );
    } else if (isInserting) {
      context.missing(_dayIdMeta);
    }
    if (data.containsKey('sort_key')) {
      context.handle(
        _sortKeyMeta,
        sortKey.isAcceptableOrUnknown(data['sort_key']!, _sortKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_sortKeyMeta);
    }
    if (data.containsKey('stay_minutes')) {
      context.handle(
        _stayMinutesMeta,
        stayMinutes.isAcceptableOrUnknown(
          data['stay_minutes']!,
          _stayMinutesMeta,
        ),
      );
    }
    if (data.containsKey('transit_minutes')) {
      context.handle(
        _transitMinutesMeta,
        transitMinutes.isAcceptableOrUnknown(
          data['transit_minutes']!,
          _transitMinutesMeta,
        ),
      );
    }
    if (data.containsKey('fixed_time')) {
      context.handle(
        _fixedTimeMeta,
        fixedTime.isAcceptableOrUnknown(data['fixed_time']!, _fixedTimeMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('updated_by')) {
      context.handle(
        _updatedByMeta,
        updatedBy.isAcceptableOrUnknown(data['updated_by']!, _updatedByMeta),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ScheduleItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ScheduleItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tripId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trip_id'],
      )!,
      stopId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stop_id'],
      )!,
      dayId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}day_id'],
      )!,
      sortKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sort_key'],
      )!,
      stayMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stay_minutes'],
      )!,
      transitMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}transit_minutes'],
      )!,
      fixedTime: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fixed_time'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      updatedAt: $ScheduleItemsTable.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
      updatedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_by'],
      ),
      deletedAt: $ScheduleItemsTable.$converterdeletedAtn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}deleted_at'],
        ),
      ),
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sync_status'],
      )!,
    );
  }

  @override
  $ScheduleItemsTable createAlias(String alias) {
    return $ScheduleItemsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converterupdatedAt =
      const MillisecondDateTimeConverter();
  static TypeConverter<DateTime, int> $converterdeletedAt =
      const MillisecondDateTimeConverter();
  static TypeConverter<DateTime?, int?> $converterdeletedAtn =
      NullAwareTypeConverter.wrap($converterdeletedAt);
}

class ScheduleItem extends DataClass implements Insertable<ScheduleItem> {
  final String id;
  final String tripId;
  final String stopId;
  final String dayId;
  final String sortKey;
  final int stayMinutes;
  final int transitMinutes;
  final int? fixedTime;
  final String status;
  final DateTime updatedAt;
  final String? updatedBy;
  final DateTime? deletedAt;
  final int syncStatus;
  const ScheduleItem({
    required this.id,
    required this.tripId,
    required this.stopId,
    required this.dayId,
    required this.sortKey,
    required this.stayMinutes,
    required this.transitMinutes,
    this.fixedTime,
    required this.status,
    required this.updatedAt,
    this.updatedBy,
    this.deletedAt,
    required this.syncStatus,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['trip_id'] = Variable<String>(tripId);
    map['stop_id'] = Variable<String>(stopId);
    map['day_id'] = Variable<String>(dayId);
    map['sort_key'] = Variable<String>(sortKey);
    map['stay_minutes'] = Variable<int>(stayMinutes);
    map['transit_minutes'] = Variable<int>(transitMinutes);
    if (!nullToAbsent || fixedTime != null) {
      map['fixed_time'] = Variable<int>(fixedTime);
    }
    map['status'] = Variable<String>(status);
    {
      map['updated_at'] = Variable<int>(
        $ScheduleItemsTable.$converterupdatedAt.toSql(updatedAt),
      );
    }
    if (!nullToAbsent || updatedBy != null) {
      map['updated_by'] = Variable<String>(updatedBy);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(
        $ScheduleItemsTable.$converterdeletedAtn.toSql(deletedAt),
      );
    }
    map['sync_status'] = Variable<int>(syncStatus);
    return map;
  }

  ScheduleItemsCompanion toCompanion(bool nullToAbsent) {
    return ScheduleItemsCompanion(
      id: Value(id),
      tripId: Value(tripId),
      stopId: Value(stopId),
      dayId: Value(dayId),
      sortKey: Value(sortKey),
      stayMinutes: Value(stayMinutes),
      transitMinutes: Value(transitMinutes),
      fixedTime: fixedTime == null && nullToAbsent
          ? const Value.absent()
          : Value(fixedTime),
      status: Value(status),
      updatedAt: Value(updatedAt),
      updatedBy: updatedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedBy),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      syncStatus: Value(syncStatus),
    );
  }

  factory ScheduleItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ScheduleItem(
      id: serializer.fromJson<String>(json['id']),
      tripId: serializer.fromJson<String>(json['tripId']),
      stopId: serializer.fromJson<String>(json['stopId']),
      dayId: serializer.fromJson<String>(json['dayId']),
      sortKey: serializer.fromJson<String>(json['sortKey']),
      stayMinutes: serializer.fromJson<int>(json['stayMinutes']),
      transitMinutes: serializer.fromJson<int>(json['transitMinutes']),
      fixedTime: serializer.fromJson<int?>(json['fixedTime']),
      status: serializer.fromJson<String>(json['status']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      updatedBy: serializer.fromJson<String?>(json['updatedBy']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      syncStatus: serializer.fromJson<int>(json['syncStatus']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tripId': serializer.toJson<String>(tripId),
      'stopId': serializer.toJson<String>(stopId),
      'dayId': serializer.toJson<String>(dayId),
      'sortKey': serializer.toJson<String>(sortKey),
      'stayMinutes': serializer.toJson<int>(stayMinutes),
      'transitMinutes': serializer.toJson<int>(transitMinutes),
      'fixedTime': serializer.toJson<int?>(fixedTime),
      'status': serializer.toJson<String>(status),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'updatedBy': serializer.toJson<String?>(updatedBy),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'syncStatus': serializer.toJson<int>(syncStatus),
    };
  }

  ScheduleItem copyWith({
    String? id,
    String? tripId,
    String? stopId,
    String? dayId,
    String? sortKey,
    int? stayMinutes,
    int? transitMinutes,
    Value<int?> fixedTime = const Value.absent(),
    String? status,
    DateTime? updatedAt,
    Value<String?> updatedBy = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
    int? syncStatus,
  }) => ScheduleItem(
    id: id ?? this.id,
    tripId: tripId ?? this.tripId,
    stopId: stopId ?? this.stopId,
    dayId: dayId ?? this.dayId,
    sortKey: sortKey ?? this.sortKey,
    stayMinutes: stayMinutes ?? this.stayMinutes,
    transitMinutes: transitMinutes ?? this.transitMinutes,
    fixedTime: fixedTime.present ? fixedTime.value : this.fixedTime,
    status: status ?? this.status,
    updatedAt: updatedAt ?? this.updatedAt,
    updatedBy: updatedBy.present ? updatedBy.value : this.updatedBy,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    syncStatus: syncStatus ?? this.syncStatus,
  );
  ScheduleItem copyWithCompanion(ScheduleItemsCompanion data) {
    return ScheduleItem(
      id: data.id.present ? data.id.value : this.id,
      tripId: data.tripId.present ? data.tripId.value : this.tripId,
      stopId: data.stopId.present ? data.stopId.value : this.stopId,
      dayId: data.dayId.present ? data.dayId.value : this.dayId,
      sortKey: data.sortKey.present ? data.sortKey.value : this.sortKey,
      stayMinutes: data.stayMinutes.present
          ? data.stayMinutes.value
          : this.stayMinutes,
      transitMinutes: data.transitMinutes.present
          ? data.transitMinutes.value
          : this.transitMinutes,
      fixedTime: data.fixedTime.present ? data.fixedTime.value : this.fixedTime,
      status: data.status.present ? data.status.value : this.status,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      updatedBy: data.updatedBy.present ? data.updatedBy.value : this.updatedBy,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ScheduleItem(')
          ..write('id: $id, ')
          ..write('tripId: $tripId, ')
          ..write('stopId: $stopId, ')
          ..write('dayId: $dayId, ')
          ..write('sortKey: $sortKey, ')
          ..write('stayMinutes: $stayMinutes, ')
          ..write('transitMinutes: $transitMinutes, ')
          ..write('fixedTime: $fixedTime, ')
          ..write('status: $status, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tripId,
    stopId,
    dayId,
    sortKey,
    stayMinutes,
    transitMinutes,
    fixedTime,
    status,
    updatedAt,
    updatedBy,
    deletedAt,
    syncStatus,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScheduleItem &&
          other.id == this.id &&
          other.tripId == this.tripId &&
          other.stopId == this.stopId &&
          other.dayId == this.dayId &&
          other.sortKey == this.sortKey &&
          other.stayMinutes == this.stayMinutes &&
          other.transitMinutes == this.transitMinutes &&
          other.fixedTime == this.fixedTime &&
          other.status == this.status &&
          other.updatedAt == this.updatedAt &&
          other.updatedBy == this.updatedBy &&
          other.deletedAt == this.deletedAt &&
          other.syncStatus == this.syncStatus);
}

class ScheduleItemsCompanion extends UpdateCompanion<ScheduleItem> {
  final Value<String> id;
  final Value<String> tripId;
  final Value<String> stopId;
  final Value<String> dayId;
  final Value<String> sortKey;
  final Value<int> stayMinutes;
  final Value<int> transitMinutes;
  final Value<int?> fixedTime;
  final Value<String> status;
  final Value<DateTime> updatedAt;
  final Value<String?> updatedBy;
  final Value<DateTime?> deletedAt;
  final Value<int> syncStatus;
  final Value<int> rowid;
  const ScheduleItemsCompanion({
    this.id = const Value.absent(),
    this.tripId = const Value.absent(),
    this.stopId = const Value.absent(),
    this.dayId = const Value.absent(),
    this.sortKey = const Value.absent(),
    this.stayMinutes = const Value.absent(),
    this.transitMinutes = const Value.absent(),
    this.fixedTime = const Value.absent(),
    this.status = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.updatedBy = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ScheduleItemsCompanion.insert({
    required String id,
    required String tripId,
    required String stopId,
    required String dayId,
    required String sortKey,
    this.stayMinutes = const Value.absent(),
    this.transitMinutes = const Value.absent(),
    this.fixedTime = const Value.absent(),
    this.status = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.updatedBy = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tripId = Value(tripId),
       stopId = Value(stopId),
       dayId = Value(dayId),
       sortKey = Value(sortKey);
  static Insertable<ScheduleItem> custom({
    Expression<String>? id,
    Expression<String>? tripId,
    Expression<String>? stopId,
    Expression<String>? dayId,
    Expression<String>? sortKey,
    Expression<int>? stayMinutes,
    Expression<int>? transitMinutes,
    Expression<int>? fixedTime,
    Expression<String>? status,
    Expression<int>? updatedAt,
    Expression<String>? updatedBy,
    Expression<int>? deletedAt,
    Expression<int>? syncStatus,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tripId != null) 'trip_id': tripId,
      if (stopId != null) 'stop_id': stopId,
      if (dayId != null) 'day_id': dayId,
      if (sortKey != null) 'sort_key': sortKey,
      if (stayMinutes != null) 'stay_minutes': stayMinutes,
      if (transitMinutes != null) 'transit_minutes': transitMinutes,
      if (fixedTime != null) 'fixed_time': fixedTime,
      if (status != null) 'status': status,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (updatedBy != null) 'updated_by': updatedBy,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ScheduleItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? tripId,
    Value<String>? stopId,
    Value<String>? dayId,
    Value<String>? sortKey,
    Value<int>? stayMinutes,
    Value<int>? transitMinutes,
    Value<int?>? fixedTime,
    Value<String>? status,
    Value<DateTime>? updatedAt,
    Value<String?>? updatedBy,
    Value<DateTime?>? deletedAt,
    Value<int>? syncStatus,
    Value<int>? rowid,
  }) {
    return ScheduleItemsCompanion(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      stopId: stopId ?? this.stopId,
      dayId: dayId ?? this.dayId,
      sortKey: sortKey ?? this.sortKey,
      stayMinutes: stayMinutes ?? this.stayMinutes,
      transitMinutes: transitMinutes ?? this.transitMinutes,
      fixedTime: fixedTime ?? this.fixedTime,
      status: status ?? this.status,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
      deletedAt: deletedAt ?? this.deletedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tripId.present) {
      map['trip_id'] = Variable<String>(tripId.value);
    }
    if (stopId.present) {
      map['stop_id'] = Variable<String>(stopId.value);
    }
    if (dayId.present) {
      map['day_id'] = Variable<String>(dayId.value);
    }
    if (sortKey.present) {
      map['sort_key'] = Variable<String>(sortKey.value);
    }
    if (stayMinutes.present) {
      map['stay_minutes'] = Variable<int>(stayMinutes.value);
    }
    if (transitMinutes.present) {
      map['transit_minutes'] = Variable<int>(transitMinutes.value);
    }
    if (fixedTime.present) {
      map['fixed_time'] = Variable<int>(fixedTime.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(
        $ScheduleItemsTable.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    if (updatedBy.present) {
      map['updated_by'] = Variable<String>(updatedBy.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(
        $ScheduleItemsTable.$converterdeletedAtn.toSql(deletedAt.value),
      );
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<int>(syncStatus.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScheduleItemsCompanion(')
          ..write('id: $id, ')
          ..write('tripId: $tripId, ')
          ..write('stopId: $stopId, ')
          ..write('dayId: $dayId, ')
          ..write('sortKey: $sortKey, ')
          ..write('stayMinutes: $stayMinutes, ')
          ..write('transitMinutes: $transitMinutes, ')
          ..write('fixedTime: $fixedTime, ')
          ..write('status: $status, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $RoisTable rois = $RoisTable(this);
  late final $PoisTable pois = $PoisTable(this);
  late final $AnimesTable animes = $AnimesTable(this);
  late final $TagsTable tags = $TagsTable(this);
  late final $PoiAnimesTable poiAnimes = $PoiAnimesTable(this);
  late final $PoiTagsTable poiTags = $PoiTagsTable(this);
  late final $TimeChunksTable timeChunks = $TimeChunksTable(this);
  late final $ReferenceImagesTable referenceImages = $ReferenceImagesTable(
    this,
  );
  late final $MediaAssetsTable mediaAssets = $MediaAssetsTable(this);
  late final $PlacesTable places = $PlacesTable(this);
  late final $LabelsTable labels = $LabelsTable(this);
  late final $PlaceLabelsTable placeLabels = $PlaceLabelsTable(this);
  late final $PhotosTable photos = $PhotosTable(this);
  late final $PlaceVisitsTable placeVisits = $PlaceVisitsTable(this);
  late final $NewReferenceImagesTable newReferenceImages =
      $NewReferenceImagesTable(this);
  late final $TripsTable trips = $TripsTable(this);
  late final $TripDaysTable tripDays = $TripDaysTable(this);
  late final $StopsTable stops = $StopsTable(this);
  late final $StopLabelsTable stopLabels = $StopLabelsTable(this);
  late final $ScheduleItemsTable scheduleItems = $ScheduleItemsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    rois,
    pois,
    animes,
    tags,
    poiAnimes,
    poiTags,
    timeChunks,
    referenceImages,
    mediaAssets,
    places,
    labels,
    placeLabels,
    photos,
    placeVisits,
    newReferenceImages,
    trips,
    tripDays,
    stops,
    stopLabels,
    scheduleItems,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'rois',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('pois', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'pois',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('poi_animes', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'animes',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('poi_animes', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'pois',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('poi_tags', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tags',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('poi_tags', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'reference_images',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('media_assets', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'places',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('place_labels', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'labels',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('place_labels', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'places',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('photos', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'places',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('place_visits', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'places',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('v10_reference_images', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'trips',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('trip_days', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'trips',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('stops', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'stops',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('stop_labels', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'labels',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('stop_labels', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'trips',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('schedule_items', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'stops',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('schedule_items', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'trip_days',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('schedule_items', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$RoisTableCreateCompanionBuilder =
    RoisCompanion Function({
      required String id,
      required String name,
      Value<String?> description,
      required String authorId,
      Value<bool> isShared,
      Value<int> isOfflineCached,
      Value<int> createdAt,
      Value<int> cloudVersion,
      Value<int?> syncLockExpiresAt,
      Value<int> rowid,
    });
typedef $$RoisTableUpdateCompanionBuilder =
    RoisCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> description,
      Value<String> authorId,
      Value<bool> isShared,
      Value<int> isOfflineCached,
      Value<int> createdAt,
      Value<int> cloudVersion,
      Value<int?> syncLockExpiresAt,
      Value<int> rowid,
    });

final class $$RoisTableReferences
    extends BaseReferences<_$AppDatabase, $RoisTable, Roi> {
  $$RoisTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PoisTable, List<Poi>> _poisRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.pois,
    aliasName: $_aliasNameGenerator(db.rois.id, db.pois.roiId),
  );

  $$PoisTableProcessedTableManager get poisRefs {
    final manager = $$PoisTableTableManager(
      $_db,
      $_db.pois,
    ).filter((f) => f.roiId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_poisRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$RoisTableFilterComposer extends Composer<_$AppDatabase, $RoisTable> {
  $$RoisTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get authorId => $composableBuilder(
    column: $table.authorId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isShared => $composableBuilder(
    column: $table.isShared,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get isOfflineCached => $composableBuilder(
    column: $table.isOfflineCached,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cloudVersion => $composableBuilder(
    column: $table.cloudVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncLockExpiresAt => $composableBuilder(
    column: $table.syncLockExpiresAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> poisRefs(
    Expression<bool> Function($$PoisTableFilterComposer f) f,
  ) {
    final $$PoisTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.pois,
      getReferencedColumn: (t) => t.roiId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PoisTableFilterComposer(
            $db: $db,
            $table: $db.pois,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RoisTableOrderingComposer extends Composer<_$AppDatabase, $RoisTable> {
  $$RoisTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get authorId => $composableBuilder(
    column: $table.authorId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isShared => $composableBuilder(
    column: $table.isShared,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get isOfflineCached => $composableBuilder(
    column: $table.isOfflineCached,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cloudVersion => $composableBuilder(
    column: $table.cloudVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncLockExpiresAt => $composableBuilder(
    column: $table.syncLockExpiresAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RoisTableAnnotationComposer
    extends Composer<_$AppDatabase, $RoisTable> {
  $$RoisTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get authorId =>
      $composableBuilder(column: $table.authorId, builder: (column) => column);

  GeneratedColumn<bool> get isShared =>
      $composableBuilder(column: $table.isShared, builder: (column) => column);

  GeneratedColumn<int> get isOfflineCached => $composableBuilder(
    column: $table.isOfflineCached,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get cloudVersion => $composableBuilder(
    column: $table.cloudVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get syncLockExpiresAt => $composableBuilder(
    column: $table.syncLockExpiresAt,
    builder: (column) => column,
  );

  Expression<T> poisRefs<T extends Object>(
    Expression<T> Function($$PoisTableAnnotationComposer a) f,
  ) {
    final $$PoisTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.pois,
      getReferencedColumn: (t) => t.roiId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PoisTableAnnotationComposer(
            $db: $db,
            $table: $db.pois,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RoisTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RoisTable,
          Roi,
          $$RoisTableFilterComposer,
          $$RoisTableOrderingComposer,
          $$RoisTableAnnotationComposer,
          $$RoisTableCreateCompanionBuilder,
          $$RoisTableUpdateCompanionBuilder,
          (Roi, $$RoisTableReferences),
          Roi,
          PrefetchHooks Function({bool poisRefs})
        > {
  $$RoisTableTableManager(_$AppDatabase db, $RoisTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RoisTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RoisTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RoisTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String> authorId = const Value.absent(),
                Value<bool> isShared = const Value.absent(),
                Value<int> isOfflineCached = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> cloudVersion = const Value.absent(),
                Value<int?> syncLockExpiresAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RoisCompanion(
                id: id,
                name: name,
                description: description,
                authorId: authorId,
                isShared: isShared,
                isOfflineCached: isOfflineCached,
                createdAt: createdAt,
                cloudVersion: cloudVersion,
                syncLockExpiresAt: syncLockExpiresAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> description = const Value.absent(),
                required String authorId,
                Value<bool> isShared = const Value.absent(),
                Value<int> isOfflineCached = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> cloudVersion = const Value.absent(),
                Value<int?> syncLockExpiresAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RoisCompanion.insert(
                id: id,
                name: name,
                description: description,
                authorId: authorId,
                isShared: isShared,
                isOfflineCached: isOfflineCached,
                createdAt: createdAt,
                cloudVersion: cloudVersion,
                syncLockExpiresAt: syncLockExpiresAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$RoisTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({poisRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (poisRefs) db.pois],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (poisRefs)
                    await $_getPrefetchedData<Roi, $RoisTable, Poi>(
                      currentTable: table,
                      referencedTable: $$RoisTableReferences._poisRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$RoisTableReferences(db, table, p0).poisRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.roiId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$RoisTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RoisTable,
      Roi,
      $$RoisTableFilterComposer,
      $$RoisTableOrderingComposer,
      $$RoisTableAnnotationComposer,
      $$RoisTableCreateCompanionBuilder,
      $$RoisTableUpdateCompanionBuilder,
      (Roi, $$RoisTableReferences),
      Roi,
      PrefetchHooks Function({bool poisRefs})
    >;
typedef $$PoisTableCreateCompanionBuilder =
    PoisCompanion Function({
      required String id,
      Value<String?> roiId,
      required String authorId,
      required String name,
      Value<String?> description,
      Value<String?> address,
      required double lat,
      required double lng,
      Value<String?> businessHours,
      Value<String?> contactInfo,
      Value<String?> localCoverImagePath,
      Value<String?> remoteCoverImageUrl,
      Value<int> createdAt,
      Value<bool> isShared,
      Value<int> sortOrder,
      Value<int> syncStatus,
      Value<bool> isDeleted,
      Value<bool> hasEverSynced,
      Value<DateTime?> lastModifiedAt,
      Value<int> rowid,
    });
typedef $$PoisTableUpdateCompanionBuilder =
    PoisCompanion Function({
      Value<String> id,
      Value<String?> roiId,
      Value<String> authorId,
      Value<String> name,
      Value<String?> description,
      Value<String?> address,
      Value<double> lat,
      Value<double> lng,
      Value<String?> businessHours,
      Value<String?> contactInfo,
      Value<String?> localCoverImagePath,
      Value<String?> remoteCoverImageUrl,
      Value<int> createdAt,
      Value<bool> isShared,
      Value<int> sortOrder,
      Value<int> syncStatus,
      Value<bool> isDeleted,
      Value<bool> hasEverSynced,
      Value<DateTime?> lastModifiedAt,
      Value<int> rowid,
    });

final class $$PoisTableReferences
    extends BaseReferences<_$AppDatabase, $PoisTable, Poi> {
  $$PoisTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $RoisTable _roiIdTable(_$AppDatabase db) =>
      db.rois.createAlias($_aliasNameGenerator(db.pois.roiId, db.rois.id));

  $$RoisTableProcessedTableManager? get roiId {
    final $_column = $_itemColumn<String>('roi_id');
    if ($_column == null) return null;
    final manager = $$RoisTableTableManager(
      $_db,
      $_db.rois,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_roiIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$PoiAnimesTable, List<PoiAnime>>
  _poiAnimesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.poiAnimes,
    aliasName: $_aliasNameGenerator(db.pois.id, db.poiAnimes.poiId),
  );

  $$PoiAnimesTableProcessedTableManager get poiAnimesRefs {
    final manager = $$PoiAnimesTableTableManager(
      $_db,
      $_db.poiAnimes,
    ).filter((f) => f.poiId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_poiAnimesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PoiTagsTable, List<PoiTag>> _poiTagsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.poiTags,
    aliasName: $_aliasNameGenerator(db.pois.id, db.poiTags.poiId),
  );

  $$PoiTagsTableProcessedTableManager get poiTagsRefs {
    final manager = $$PoiTagsTableTableManager(
      $_db,
      $_db.poiTags,
    ).filter((f) => f.poiId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_poiTagsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TimeChunksTable, List<TimeChunk>>
  _timeChunksRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.timeChunks,
    aliasName: $_aliasNameGenerator(db.pois.id, db.timeChunks.poiId),
  );

  $$TimeChunksTableProcessedTableManager get timeChunksRefs {
    final manager = $$TimeChunksTableTableManager(
      $_db,
      $_db.timeChunks,
    ).filter((f) => f.poiId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_timeChunksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ReferenceImagesTable, List<ReferenceImage>>
  _referenceImagesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.referenceImages,
    aliasName: $_aliasNameGenerator(db.pois.id, db.referenceImages.poiId),
  );

  $$ReferenceImagesTableProcessedTableManager get referenceImagesRefs {
    final manager = $$ReferenceImagesTableTableManager(
      $_db,
      $_db.referenceImages,
    ).filter((f) => f.poiId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _referenceImagesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$MediaAssetsTable, List<MediaAsset>>
  _mediaAssetsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.mediaAssets,
    aliasName: $_aliasNameGenerator(db.pois.id, db.mediaAssets.poiId),
  );

  $$MediaAssetsTableProcessedTableManager get mediaAssetsRefs {
    final manager = $$MediaAssetsTableTableManager(
      $_db,
      $_db.mediaAssets,
    ).filter((f) => f.poiId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_mediaAssetsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PoisTableFilterComposer extends Composer<_$AppDatabase, $PoisTable> {
  $$PoisTableFilterComposer({
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

  ColumnFilters<String> get authorId => $composableBuilder(
    column: $table.authorId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lng => $composableBuilder(
    column: $table.lng,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get businessHours => $composableBuilder(
    column: $table.businessHours,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contactInfo => $composableBuilder(
    column: $table.contactInfo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localCoverImagePath => $composableBuilder(
    column: $table.localCoverImagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteCoverImageUrl => $composableBuilder(
    column: $table.remoteCoverImageUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isShared => $composableBuilder(
    column: $table.isShared,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasEverSynced => $composableBuilder(
    column: $table.hasEverSynced,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastModifiedAt => $composableBuilder(
    column: $table.lastModifiedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$RoisTableFilterComposer get roiId {
    final $$RoisTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.roiId,
      referencedTable: $db.rois,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RoisTableFilterComposer(
            $db: $db,
            $table: $db.rois,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> poiAnimesRefs(
    Expression<bool> Function($$PoiAnimesTableFilterComposer f) f,
  ) {
    final $$PoiAnimesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.poiAnimes,
      getReferencedColumn: (t) => t.poiId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PoiAnimesTableFilterComposer(
            $db: $db,
            $table: $db.poiAnimes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> poiTagsRefs(
    Expression<bool> Function($$PoiTagsTableFilterComposer f) f,
  ) {
    final $$PoiTagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.poiTags,
      getReferencedColumn: (t) => t.poiId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PoiTagsTableFilterComposer(
            $db: $db,
            $table: $db.poiTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> timeChunksRefs(
    Expression<bool> Function($$TimeChunksTableFilterComposer f) f,
  ) {
    final $$TimeChunksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.timeChunks,
      getReferencedColumn: (t) => t.poiId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TimeChunksTableFilterComposer(
            $db: $db,
            $table: $db.timeChunks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> referenceImagesRefs(
    Expression<bool> Function($$ReferenceImagesTableFilterComposer f) f,
  ) {
    final $$ReferenceImagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.referenceImages,
      getReferencedColumn: (t) => t.poiId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReferenceImagesTableFilterComposer(
            $db: $db,
            $table: $db.referenceImages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> mediaAssetsRefs(
    Expression<bool> Function($$MediaAssetsTableFilterComposer f) f,
  ) {
    final $$MediaAssetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mediaAssets,
      getReferencedColumn: (t) => t.poiId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MediaAssetsTableFilterComposer(
            $db: $db,
            $table: $db.mediaAssets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PoisTableOrderingComposer extends Composer<_$AppDatabase, $PoisTable> {
  $$PoisTableOrderingComposer({
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

  ColumnOrderings<String> get authorId => $composableBuilder(
    column: $table.authorId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lng => $composableBuilder(
    column: $table.lng,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get businessHours => $composableBuilder(
    column: $table.businessHours,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contactInfo => $composableBuilder(
    column: $table.contactInfo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localCoverImagePath => $composableBuilder(
    column: $table.localCoverImagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteCoverImageUrl => $composableBuilder(
    column: $table.remoteCoverImageUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isShared => $composableBuilder(
    column: $table.isShared,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasEverSynced => $composableBuilder(
    column: $table.hasEverSynced,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastModifiedAt => $composableBuilder(
    column: $table.lastModifiedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$RoisTableOrderingComposer get roiId {
    final $$RoisTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.roiId,
      referencedTable: $db.rois,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RoisTableOrderingComposer(
            $db: $db,
            $table: $db.rois,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PoisTableAnnotationComposer
    extends Composer<_$AppDatabase, $PoisTable> {
  $$PoisTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get authorId =>
      $composableBuilder(column: $table.authorId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<double> get lat =>
      $composableBuilder(column: $table.lat, builder: (column) => column);

  GeneratedColumn<double> get lng =>
      $composableBuilder(column: $table.lng, builder: (column) => column);

  GeneratedColumn<String> get businessHours => $composableBuilder(
    column: $table.businessHours,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contactInfo => $composableBuilder(
    column: $table.contactInfo,
    builder: (column) => column,
  );

  GeneratedColumn<String> get localCoverImagePath => $composableBuilder(
    column: $table.localCoverImagePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get remoteCoverImageUrl => $composableBuilder(
    column: $table.remoteCoverImageUrl,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<bool> get isShared =>
      $composableBuilder(column: $table.isShared, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<bool> get hasEverSynced => $composableBuilder(
    column: $table.hasEverSynced,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastModifiedAt => $composableBuilder(
    column: $table.lastModifiedAt,
    builder: (column) => column,
  );

  $$RoisTableAnnotationComposer get roiId {
    final $$RoisTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.roiId,
      referencedTable: $db.rois,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RoisTableAnnotationComposer(
            $db: $db,
            $table: $db.rois,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> poiAnimesRefs<T extends Object>(
    Expression<T> Function($$PoiAnimesTableAnnotationComposer a) f,
  ) {
    final $$PoiAnimesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.poiAnimes,
      getReferencedColumn: (t) => t.poiId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PoiAnimesTableAnnotationComposer(
            $db: $db,
            $table: $db.poiAnimes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> poiTagsRefs<T extends Object>(
    Expression<T> Function($$PoiTagsTableAnnotationComposer a) f,
  ) {
    final $$PoiTagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.poiTags,
      getReferencedColumn: (t) => t.poiId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PoiTagsTableAnnotationComposer(
            $db: $db,
            $table: $db.poiTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> timeChunksRefs<T extends Object>(
    Expression<T> Function($$TimeChunksTableAnnotationComposer a) f,
  ) {
    final $$TimeChunksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.timeChunks,
      getReferencedColumn: (t) => t.poiId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TimeChunksTableAnnotationComposer(
            $db: $db,
            $table: $db.timeChunks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> referenceImagesRefs<T extends Object>(
    Expression<T> Function($$ReferenceImagesTableAnnotationComposer a) f,
  ) {
    final $$ReferenceImagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.referenceImages,
      getReferencedColumn: (t) => t.poiId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReferenceImagesTableAnnotationComposer(
            $db: $db,
            $table: $db.referenceImages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> mediaAssetsRefs<T extends Object>(
    Expression<T> Function($$MediaAssetsTableAnnotationComposer a) f,
  ) {
    final $$MediaAssetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mediaAssets,
      getReferencedColumn: (t) => t.poiId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MediaAssetsTableAnnotationComposer(
            $db: $db,
            $table: $db.mediaAssets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PoisTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PoisTable,
          Poi,
          $$PoisTableFilterComposer,
          $$PoisTableOrderingComposer,
          $$PoisTableAnnotationComposer,
          $$PoisTableCreateCompanionBuilder,
          $$PoisTableUpdateCompanionBuilder,
          (Poi, $$PoisTableReferences),
          Poi,
          PrefetchHooks Function({
            bool roiId,
            bool poiAnimesRefs,
            bool poiTagsRefs,
            bool timeChunksRefs,
            bool referenceImagesRefs,
            bool mediaAssetsRefs,
          })
        > {
  $$PoisTableTableManager(_$AppDatabase db, $PoisTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PoisTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PoisTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PoisTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> roiId = const Value.absent(),
                Value<String> authorId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> address = const Value.absent(),
                Value<double> lat = const Value.absent(),
                Value<double> lng = const Value.absent(),
                Value<String?> businessHours = const Value.absent(),
                Value<String?> contactInfo = const Value.absent(),
                Value<String?> localCoverImagePath = const Value.absent(),
                Value<String?> remoteCoverImageUrl = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<bool> isShared = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<bool> hasEverSynced = const Value.absent(),
                Value<DateTime?> lastModifiedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PoisCompanion(
                id: id,
                roiId: roiId,
                authorId: authorId,
                name: name,
                description: description,
                address: address,
                lat: lat,
                lng: lng,
                businessHours: businessHours,
                contactInfo: contactInfo,
                localCoverImagePath: localCoverImagePath,
                remoteCoverImageUrl: remoteCoverImageUrl,
                createdAt: createdAt,
                isShared: isShared,
                sortOrder: sortOrder,
                syncStatus: syncStatus,
                isDeleted: isDeleted,
                hasEverSynced: hasEverSynced,
                lastModifiedAt: lastModifiedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> roiId = const Value.absent(),
                required String authorId,
                required String name,
                Value<String?> description = const Value.absent(),
                Value<String?> address = const Value.absent(),
                required double lat,
                required double lng,
                Value<String?> businessHours = const Value.absent(),
                Value<String?> contactInfo = const Value.absent(),
                Value<String?> localCoverImagePath = const Value.absent(),
                Value<String?> remoteCoverImageUrl = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<bool> isShared = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<bool> hasEverSynced = const Value.absent(),
                Value<DateTime?> lastModifiedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PoisCompanion.insert(
                id: id,
                roiId: roiId,
                authorId: authorId,
                name: name,
                description: description,
                address: address,
                lat: lat,
                lng: lng,
                businessHours: businessHours,
                contactInfo: contactInfo,
                localCoverImagePath: localCoverImagePath,
                remoteCoverImageUrl: remoteCoverImageUrl,
                createdAt: createdAt,
                isShared: isShared,
                sortOrder: sortOrder,
                syncStatus: syncStatus,
                isDeleted: isDeleted,
                hasEverSynced: hasEverSynced,
                lastModifiedAt: lastModifiedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$PoisTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                roiId = false,
                poiAnimesRefs = false,
                poiTagsRefs = false,
                timeChunksRefs = false,
                referenceImagesRefs = false,
                mediaAssetsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (poiAnimesRefs) db.poiAnimes,
                    if (poiTagsRefs) db.poiTags,
                    if (timeChunksRefs) db.timeChunks,
                    if (referenceImagesRefs) db.referenceImages,
                    if (mediaAssetsRefs) db.mediaAssets,
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
                        if (roiId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.roiId,
                                    referencedTable: $$PoisTableReferences
                                        ._roiIdTable(db),
                                    referencedColumn: $$PoisTableReferences
                                        ._roiIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (poiAnimesRefs)
                        await $_getPrefetchedData<Poi, $PoisTable, PoiAnime>(
                          currentTable: table,
                          referencedTable: $$PoisTableReferences
                              ._poiAnimesRefsTable(db),
                          managerFromTypedResult: (p0) => $$PoisTableReferences(
                            db,
                            table,
                            p0,
                          ).poiAnimesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.poiId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (poiTagsRefs)
                        await $_getPrefetchedData<Poi, $PoisTable, PoiTag>(
                          currentTable: table,
                          referencedTable: $$PoisTableReferences
                              ._poiTagsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PoisTableReferences(db, table, p0).poiTagsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.poiId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (timeChunksRefs)
                        await $_getPrefetchedData<Poi, $PoisTable, TimeChunk>(
                          currentTable: table,
                          referencedTable: $$PoisTableReferences
                              ._timeChunksRefsTable(db),
                          managerFromTypedResult: (p0) => $$PoisTableReferences(
                            db,
                            table,
                            p0,
                          ).timeChunksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.poiId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (referenceImagesRefs)
                        await $_getPrefetchedData<
                          Poi,
                          $PoisTable,
                          ReferenceImage
                        >(
                          currentTable: table,
                          referencedTable: $$PoisTableReferences
                              ._referenceImagesRefsTable(db),
                          managerFromTypedResult: (p0) => $$PoisTableReferences(
                            db,
                            table,
                            p0,
                          ).referenceImagesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.poiId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (mediaAssetsRefs)
                        await $_getPrefetchedData<Poi, $PoisTable, MediaAsset>(
                          currentTable: table,
                          referencedTable: $$PoisTableReferences
                              ._mediaAssetsRefsTable(db),
                          managerFromTypedResult: (p0) => $$PoisTableReferences(
                            db,
                            table,
                            p0,
                          ).mediaAssetsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.poiId == item.id,
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

typedef $$PoisTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PoisTable,
      Poi,
      $$PoisTableFilterComposer,
      $$PoisTableOrderingComposer,
      $$PoisTableAnnotationComposer,
      $$PoisTableCreateCompanionBuilder,
      $$PoisTableUpdateCompanionBuilder,
      (Poi, $$PoisTableReferences),
      Poi,
      PrefetchHooks Function({
        bool roiId,
        bool poiAnimesRefs,
        bool poiTagsRefs,
        bool timeChunksRefs,
        bool referenceImagesRefs,
        bool mediaAssetsRefs,
      })
    >;
typedef $$AnimesTableCreateCompanionBuilder =
    AnimesCompanion Function({
      required String id,
      required String name,
      Value<String?> description,
      Value<String?> bangumiId,
      required String authorId,
      Value<bool> isShared,
      Value<int> createdAt,
      Value<int> rowid,
    });
typedef $$AnimesTableUpdateCompanionBuilder =
    AnimesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> description,
      Value<String?> bangumiId,
      Value<String> authorId,
      Value<bool> isShared,
      Value<int> createdAt,
      Value<int> rowid,
    });

final class $$AnimesTableReferences
    extends BaseReferences<_$AppDatabase, $AnimesTable, Anime> {
  $$AnimesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PoiAnimesTable, List<PoiAnime>>
  _poiAnimesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.poiAnimes,
    aliasName: $_aliasNameGenerator(db.animes.id, db.poiAnimes.animeId),
  );

  $$PoiAnimesTableProcessedTableManager get poiAnimesRefs {
    final manager = $$PoiAnimesTableTableManager(
      $_db,
      $_db.poiAnimes,
    ).filter((f) => f.animeId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_poiAnimesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$AnimesTableFilterComposer
    extends Composer<_$AppDatabase, $AnimesTable> {
  $$AnimesTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bangumiId => $composableBuilder(
    column: $table.bangumiId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get authorId => $composableBuilder(
    column: $table.authorId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isShared => $composableBuilder(
    column: $table.isShared,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> poiAnimesRefs(
    Expression<bool> Function($$PoiAnimesTableFilterComposer f) f,
  ) {
    final $$PoiAnimesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.poiAnimes,
      getReferencedColumn: (t) => t.animeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PoiAnimesTableFilterComposer(
            $db: $db,
            $table: $db.poiAnimes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AnimesTableOrderingComposer
    extends Composer<_$AppDatabase, $AnimesTable> {
  $$AnimesTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bangumiId => $composableBuilder(
    column: $table.bangumiId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get authorId => $composableBuilder(
    column: $table.authorId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isShared => $composableBuilder(
    column: $table.isShared,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AnimesTableAnnotationComposer
    extends Composer<_$AppDatabase, $AnimesTable> {
  $$AnimesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bangumiId =>
      $composableBuilder(column: $table.bangumiId, builder: (column) => column);

  GeneratedColumn<String> get authorId =>
      $composableBuilder(column: $table.authorId, builder: (column) => column);

  GeneratedColumn<bool> get isShared =>
      $composableBuilder(column: $table.isShared, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> poiAnimesRefs<T extends Object>(
    Expression<T> Function($$PoiAnimesTableAnnotationComposer a) f,
  ) {
    final $$PoiAnimesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.poiAnimes,
      getReferencedColumn: (t) => t.animeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PoiAnimesTableAnnotationComposer(
            $db: $db,
            $table: $db.poiAnimes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AnimesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AnimesTable,
          Anime,
          $$AnimesTableFilterComposer,
          $$AnimesTableOrderingComposer,
          $$AnimesTableAnnotationComposer,
          $$AnimesTableCreateCompanionBuilder,
          $$AnimesTableUpdateCompanionBuilder,
          (Anime, $$AnimesTableReferences),
          Anime,
          PrefetchHooks Function({bool poiAnimesRefs})
        > {
  $$AnimesTableTableManager(_$AppDatabase db, $AnimesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AnimesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AnimesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AnimesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> bangumiId = const Value.absent(),
                Value<String> authorId = const Value.absent(),
                Value<bool> isShared = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AnimesCompanion(
                id: id,
                name: name,
                description: description,
                bangumiId: bangumiId,
                authorId: authorId,
                isShared: isShared,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> description = const Value.absent(),
                Value<String?> bangumiId = const Value.absent(),
                required String authorId,
                Value<bool> isShared = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AnimesCompanion.insert(
                id: id,
                name: name,
                description: description,
                bangumiId: bangumiId,
                authorId: authorId,
                isShared: isShared,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$AnimesTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({poiAnimesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (poiAnimesRefs) db.poiAnimes],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (poiAnimesRefs)
                    await $_getPrefetchedData<Anime, $AnimesTable, PoiAnime>(
                      currentTable: table,
                      referencedTable: $$AnimesTableReferences
                          ._poiAnimesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$AnimesTableReferences(db, table, p0).poiAnimesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.animeId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$AnimesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AnimesTable,
      Anime,
      $$AnimesTableFilterComposer,
      $$AnimesTableOrderingComposer,
      $$AnimesTableAnnotationComposer,
      $$AnimesTableCreateCompanionBuilder,
      $$AnimesTableUpdateCompanionBuilder,
      (Anime, $$AnimesTableReferences),
      Anime,
      PrefetchHooks Function({bool poiAnimesRefs})
    >;
typedef $$TagsTableCreateCompanionBuilder =
    TagsCompanion Function({
      required String id,
      required String name,
      Value<String?> description,
      required String authorId,
      Value<bool> isShared,
      Value<int> createdAt,
      Value<int> rowid,
    });
typedef $$TagsTableUpdateCompanionBuilder =
    TagsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> description,
      Value<String> authorId,
      Value<bool> isShared,
      Value<int> createdAt,
      Value<int> rowid,
    });

final class $$TagsTableReferences
    extends BaseReferences<_$AppDatabase, $TagsTable, Tag> {
  $$TagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PoiTagsTable, List<PoiTag>> _poiTagsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.poiTags,
    aliasName: $_aliasNameGenerator(db.tags.id, db.poiTags.tagId),
  );

  $$PoiTagsTableProcessedTableManager get poiTagsRefs {
    final manager = $$PoiTagsTableTableManager(
      $_db,
      $_db.poiTags,
    ).filter((f) => f.tagId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_poiTagsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TagsTableFilterComposer extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get authorId => $composableBuilder(
    column: $table.authorId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isShared => $composableBuilder(
    column: $table.isShared,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> poiTagsRefs(
    Expression<bool> Function($$PoiTagsTableFilterComposer f) f,
  ) {
    final $$PoiTagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.poiTags,
      getReferencedColumn: (t) => t.tagId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PoiTagsTableFilterComposer(
            $db: $db,
            $table: $db.poiTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TagsTableOrderingComposer extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get authorId => $composableBuilder(
    column: $table.authorId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isShared => $composableBuilder(
    column: $table.isShared,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get authorId =>
      $composableBuilder(column: $table.authorId, builder: (column) => column);

  GeneratedColumn<bool> get isShared =>
      $composableBuilder(column: $table.isShared, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> poiTagsRefs<T extends Object>(
    Expression<T> Function($$PoiTagsTableAnnotationComposer a) f,
  ) {
    final $$PoiTagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.poiTags,
      getReferencedColumn: (t) => t.tagId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PoiTagsTableAnnotationComposer(
            $db: $db,
            $table: $db.poiTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TagsTable,
          Tag,
          $$TagsTableFilterComposer,
          $$TagsTableOrderingComposer,
          $$TagsTableAnnotationComposer,
          $$TagsTableCreateCompanionBuilder,
          $$TagsTableUpdateCompanionBuilder,
          (Tag, $$TagsTableReferences),
          Tag,
          PrefetchHooks Function({bool poiTagsRefs})
        > {
  $$TagsTableTableManager(_$AppDatabase db, $TagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String> authorId = const Value.absent(),
                Value<bool> isShared = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TagsCompanion(
                id: id,
                name: name,
                description: description,
                authorId: authorId,
                isShared: isShared,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> description = const Value.absent(),
                required String authorId,
                Value<bool> isShared = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TagsCompanion.insert(
                id: id,
                name: name,
                description: description,
                authorId: authorId,
                isShared: isShared,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$TagsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({poiTagsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (poiTagsRefs) db.poiTags],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (poiTagsRefs)
                    await $_getPrefetchedData<Tag, $TagsTable, PoiTag>(
                      currentTable: table,
                      referencedTable: $$TagsTableReferences._poiTagsRefsTable(
                        db,
                      ),
                      managerFromTypedResult: (p0) =>
                          $$TagsTableReferences(db, table, p0).poiTagsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.tagId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$TagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TagsTable,
      Tag,
      $$TagsTableFilterComposer,
      $$TagsTableOrderingComposer,
      $$TagsTableAnnotationComposer,
      $$TagsTableCreateCompanionBuilder,
      $$TagsTableUpdateCompanionBuilder,
      (Tag, $$TagsTableReferences),
      Tag,
      PrefetchHooks Function({bool poiTagsRefs})
    >;
typedef $$PoiAnimesTableCreateCompanionBuilder =
    PoiAnimesCompanion Function({
      required String poiId,
      required String animeId,
      Value<int> rowid,
    });
typedef $$PoiAnimesTableUpdateCompanionBuilder =
    PoiAnimesCompanion Function({
      Value<String> poiId,
      Value<String> animeId,
      Value<int> rowid,
    });

final class $$PoiAnimesTableReferences
    extends BaseReferences<_$AppDatabase, $PoiAnimesTable, PoiAnime> {
  $$PoiAnimesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PoisTable _poiIdTable(_$AppDatabase db) =>
      db.pois.createAlias($_aliasNameGenerator(db.poiAnimes.poiId, db.pois.id));

  $$PoisTableProcessedTableManager get poiId {
    final $_column = $_itemColumn<String>('poi_id')!;

    final manager = $$PoisTableTableManager(
      $_db,
      $_db.pois,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_poiIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $AnimesTable _animeIdTable(_$AppDatabase db) => db.animes.createAlias(
    $_aliasNameGenerator(db.poiAnimes.animeId, db.animes.id),
  );

  $$AnimesTableProcessedTableManager get animeId {
    final $_column = $_itemColumn<String>('anime_id')!;

    final manager = $$AnimesTableTableManager(
      $_db,
      $_db.animes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_animeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PoiAnimesTableFilterComposer
    extends Composer<_$AppDatabase, $PoiAnimesTable> {
  $$PoiAnimesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$PoisTableFilterComposer get poiId {
    final $$PoisTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.poiId,
      referencedTable: $db.pois,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PoisTableFilterComposer(
            $db: $db,
            $table: $db.pois,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AnimesTableFilterComposer get animeId {
    final $$AnimesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.animeId,
      referencedTable: $db.animes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AnimesTableFilterComposer(
            $db: $db,
            $table: $db.animes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PoiAnimesTableOrderingComposer
    extends Composer<_$AppDatabase, $PoiAnimesTable> {
  $$PoiAnimesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$PoisTableOrderingComposer get poiId {
    final $$PoisTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.poiId,
      referencedTable: $db.pois,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PoisTableOrderingComposer(
            $db: $db,
            $table: $db.pois,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AnimesTableOrderingComposer get animeId {
    final $$AnimesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.animeId,
      referencedTable: $db.animes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AnimesTableOrderingComposer(
            $db: $db,
            $table: $db.animes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PoiAnimesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PoiAnimesTable> {
  $$PoiAnimesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$PoisTableAnnotationComposer get poiId {
    final $$PoisTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.poiId,
      referencedTable: $db.pois,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PoisTableAnnotationComposer(
            $db: $db,
            $table: $db.pois,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AnimesTableAnnotationComposer get animeId {
    final $$AnimesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.animeId,
      referencedTable: $db.animes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AnimesTableAnnotationComposer(
            $db: $db,
            $table: $db.animes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PoiAnimesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PoiAnimesTable,
          PoiAnime,
          $$PoiAnimesTableFilterComposer,
          $$PoiAnimesTableOrderingComposer,
          $$PoiAnimesTableAnnotationComposer,
          $$PoiAnimesTableCreateCompanionBuilder,
          $$PoiAnimesTableUpdateCompanionBuilder,
          (PoiAnime, $$PoiAnimesTableReferences),
          PoiAnime,
          PrefetchHooks Function({bool poiId, bool animeId})
        > {
  $$PoiAnimesTableTableManager(_$AppDatabase db, $PoiAnimesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PoiAnimesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PoiAnimesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PoiAnimesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> poiId = const Value.absent(),
                Value<String> animeId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PoiAnimesCompanion(
                poiId: poiId,
                animeId: animeId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String poiId,
                required String animeId,
                Value<int> rowid = const Value.absent(),
              }) => PoiAnimesCompanion.insert(
                poiId: poiId,
                animeId: animeId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PoiAnimesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({poiId = false, animeId = false}) {
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
                    if (poiId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.poiId,
                                referencedTable: $$PoiAnimesTableReferences
                                    ._poiIdTable(db),
                                referencedColumn: $$PoiAnimesTableReferences
                                    ._poiIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (animeId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.animeId,
                                referencedTable: $$PoiAnimesTableReferences
                                    ._animeIdTable(db),
                                referencedColumn: $$PoiAnimesTableReferences
                                    ._animeIdTable(db)
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

typedef $$PoiAnimesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PoiAnimesTable,
      PoiAnime,
      $$PoiAnimesTableFilterComposer,
      $$PoiAnimesTableOrderingComposer,
      $$PoiAnimesTableAnnotationComposer,
      $$PoiAnimesTableCreateCompanionBuilder,
      $$PoiAnimesTableUpdateCompanionBuilder,
      (PoiAnime, $$PoiAnimesTableReferences),
      PoiAnime,
      PrefetchHooks Function({bool poiId, bool animeId})
    >;
typedef $$PoiTagsTableCreateCompanionBuilder =
    PoiTagsCompanion Function({
      required String poiId,
      required String tagId,
      Value<int> rowid,
    });
typedef $$PoiTagsTableUpdateCompanionBuilder =
    PoiTagsCompanion Function({
      Value<String> poiId,
      Value<String> tagId,
      Value<int> rowid,
    });

final class $$PoiTagsTableReferences
    extends BaseReferences<_$AppDatabase, $PoiTagsTable, PoiTag> {
  $$PoiTagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PoisTable _poiIdTable(_$AppDatabase db) =>
      db.pois.createAlias($_aliasNameGenerator(db.poiTags.poiId, db.pois.id));

  $$PoisTableProcessedTableManager get poiId {
    final $_column = $_itemColumn<String>('poi_id')!;

    final manager = $$PoisTableTableManager(
      $_db,
      $_db.pois,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_poiIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TagsTable _tagIdTable(_$AppDatabase db) =>
      db.tags.createAlias($_aliasNameGenerator(db.poiTags.tagId, db.tags.id));

  $$TagsTableProcessedTableManager get tagId {
    final $_column = $_itemColumn<String>('tag_id')!;

    final manager = $$TagsTableTableManager(
      $_db,
      $_db.tags,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tagIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PoiTagsTableFilterComposer
    extends Composer<_$AppDatabase, $PoiTagsTable> {
  $$PoiTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$PoisTableFilterComposer get poiId {
    final $$PoisTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.poiId,
      referencedTable: $db.pois,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PoisTableFilterComposer(
            $db: $db,
            $table: $db.pois,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagsTableFilterComposer get tagId {
    final $$TagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableFilterComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PoiTagsTableOrderingComposer
    extends Composer<_$AppDatabase, $PoiTagsTable> {
  $$PoiTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$PoisTableOrderingComposer get poiId {
    final $$PoisTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.poiId,
      referencedTable: $db.pois,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PoisTableOrderingComposer(
            $db: $db,
            $table: $db.pois,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagsTableOrderingComposer get tagId {
    final $$TagsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableOrderingComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PoiTagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PoiTagsTable> {
  $$PoiTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$PoisTableAnnotationComposer get poiId {
    final $$PoisTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.poiId,
      referencedTable: $db.pois,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PoisTableAnnotationComposer(
            $db: $db,
            $table: $db.pois,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagsTableAnnotationComposer get tagId {
    final $$TagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableAnnotationComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PoiTagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PoiTagsTable,
          PoiTag,
          $$PoiTagsTableFilterComposer,
          $$PoiTagsTableOrderingComposer,
          $$PoiTagsTableAnnotationComposer,
          $$PoiTagsTableCreateCompanionBuilder,
          $$PoiTagsTableUpdateCompanionBuilder,
          (PoiTag, $$PoiTagsTableReferences),
          PoiTag,
          PrefetchHooks Function({bool poiId, bool tagId})
        > {
  $$PoiTagsTableTableManager(_$AppDatabase db, $PoiTagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PoiTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PoiTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PoiTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> poiId = const Value.absent(),
                Value<String> tagId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PoiTagsCompanion(poiId: poiId, tagId: tagId, rowid: rowid),
          createCompanionCallback:
              ({
                required String poiId,
                required String tagId,
                Value<int> rowid = const Value.absent(),
              }) => PoiTagsCompanion.insert(
                poiId: poiId,
                tagId: tagId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PoiTagsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({poiId = false, tagId = false}) {
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
                    if (poiId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.poiId,
                                referencedTable: $$PoiTagsTableReferences
                                    ._poiIdTable(db),
                                referencedColumn: $$PoiTagsTableReferences
                                    ._poiIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (tagId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.tagId,
                                referencedTable: $$PoiTagsTableReferences
                                    ._tagIdTable(db),
                                referencedColumn: $$PoiTagsTableReferences
                                    ._tagIdTable(db)
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

typedef $$PoiTagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PoiTagsTable,
      PoiTag,
      $$PoiTagsTableFilterComposer,
      $$PoiTagsTableOrderingComposer,
      $$PoiTagsTableAnnotationComposer,
      $$PoiTagsTableCreateCompanionBuilder,
      $$PoiTagsTableUpdateCompanionBuilder,
      (PoiTag, $$PoiTagsTableReferences),
      PoiTag,
      PrefetchHooks Function({bool poiId, bool tagId})
    >;
typedef $$TimeChunksTableCreateCompanionBuilder =
    TimeChunksCompanion Function({
      required String id,
      required String poiId,
      Value<String?> date,
      Value<String?> startTime,
      Value<String?> endTime,
      Value<String> status,
      Value<int> sortOrder,
      Value<int> duration,
      Value<int> transitDuration,
      Value<bool> isFixedTime,
      required String authorId,
      Value<bool> isShared,
      Value<int> createdAt,
      Value<int> syncStatus,
      Value<bool> isDeleted,
      Value<bool> hasEverSynced,
      Value<String?> originalStartTime,
      Value<String?> originalEndTime,
      Value<DateTime?> lastModifiedAt,
      Value<int> rowid,
    });
typedef $$TimeChunksTableUpdateCompanionBuilder =
    TimeChunksCompanion Function({
      Value<String> id,
      Value<String> poiId,
      Value<String?> date,
      Value<String?> startTime,
      Value<String?> endTime,
      Value<String> status,
      Value<int> sortOrder,
      Value<int> duration,
      Value<int> transitDuration,
      Value<bool> isFixedTime,
      Value<String> authorId,
      Value<bool> isShared,
      Value<int> createdAt,
      Value<int> syncStatus,
      Value<bool> isDeleted,
      Value<bool> hasEverSynced,
      Value<String?> originalStartTime,
      Value<String?> originalEndTime,
      Value<DateTime?> lastModifiedAt,
      Value<int> rowid,
    });

final class $$TimeChunksTableReferences
    extends BaseReferences<_$AppDatabase, $TimeChunksTable, TimeChunk> {
  $$TimeChunksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PoisTable _poiIdTable(_$AppDatabase db) => db.pois.createAlias(
    $_aliasNameGenerator(db.timeChunks.poiId, db.pois.id),
  );

  $$PoisTableProcessedTableManager get poiId {
    final $_column = $_itemColumn<String>('poi_id')!;

    final manager = $$PoisTableTableManager(
      $_db,
      $_db.pois,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_poiIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TimeChunksTableFilterComposer
    extends Composer<_$AppDatabase, $TimeChunksTable> {
  $$TimeChunksTableFilterComposer({
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

  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startTime => $composableBuilder(
    column: $table.startTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get endTime => $composableBuilder(
    column: $table.endTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get duration => $composableBuilder(
    column: $table.duration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get transitDuration => $composableBuilder(
    column: $table.transitDuration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFixedTime => $composableBuilder(
    column: $table.isFixedTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get authorId => $composableBuilder(
    column: $table.authorId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isShared => $composableBuilder(
    column: $table.isShared,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasEverSynced => $composableBuilder(
    column: $table.hasEverSynced,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originalStartTime => $composableBuilder(
    column: $table.originalStartTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originalEndTime => $composableBuilder(
    column: $table.originalEndTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastModifiedAt => $composableBuilder(
    column: $table.lastModifiedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$PoisTableFilterComposer get poiId {
    final $$PoisTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.poiId,
      referencedTable: $db.pois,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PoisTableFilterComposer(
            $db: $db,
            $table: $db.pois,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TimeChunksTableOrderingComposer
    extends Composer<_$AppDatabase, $TimeChunksTable> {
  $$TimeChunksTableOrderingComposer({
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

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startTime => $composableBuilder(
    column: $table.startTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get endTime => $composableBuilder(
    column: $table.endTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get duration => $composableBuilder(
    column: $table.duration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get transitDuration => $composableBuilder(
    column: $table.transitDuration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFixedTime => $composableBuilder(
    column: $table.isFixedTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get authorId => $composableBuilder(
    column: $table.authorId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isShared => $composableBuilder(
    column: $table.isShared,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasEverSynced => $composableBuilder(
    column: $table.hasEverSynced,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originalStartTime => $composableBuilder(
    column: $table.originalStartTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originalEndTime => $composableBuilder(
    column: $table.originalEndTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastModifiedAt => $composableBuilder(
    column: $table.lastModifiedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$PoisTableOrderingComposer get poiId {
    final $$PoisTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.poiId,
      referencedTable: $db.pois,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PoisTableOrderingComposer(
            $db: $db,
            $table: $db.pois,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TimeChunksTableAnnotationComposer
    extends Composer<_$AppDatabase, $TimeChunksTable> {
  $$TimeChunksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get startTime =>
      $composableBuilder(column: $table.startTime, builder: (column) => column);

  GeneratedColumn<String> get endTime =>
      $composableBuilder(column: $table.endTime, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<int> get duration =>
      $composableBuilder(column: $table.duration, builder: (column) => column);

  GeneratedColumn<int> get transitDuration => $composableBuilder(
    column: $table.transitDuration,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isFixedTime => $composableBuilder(
    column: $table.isFixedTime,
    builder: (column) => column,
  );

  GeneratedColumn<String> get authorId =>
      $composableBuilder(column: $table.authorId, builder: (column) => column);

  GeneratedColumn<bool> get isShared =>
      $composableBuilder(column: $table.isShared, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<bool> get hasEverSynced => $composableBuilder(
    column: $table.hasEverSynced,
    builder: (column) => column,
  );

  GeneratedColumn<String> get originalStartTime => $composableBuilder(
    column: $table.originalStartTime,
    builder: (column) => column,
  );

  GeneratedColumn<String> get originalEndTime => $composableBuilder(
    column: $table.originalEndTime,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastModifiedAt => $composableBuilder(
    column: $table.lastModifiedAt,
    builder: (column) => column,
  );

  $$PoisTableAnnotationComposer get poiId {
    final $$PoisTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.poiId,
      referencedTable: $db.pois,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PoisTableAnnotationComposer(
            $db: $db,
            $table: $db.pois,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TimeChunksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TimeChunksTable,
          TimeChunk,
          $$TimeChunksTableFilterComposer,
          $$TimeChunksTableOrderingComposer,
          $$TimeChunksTableAnnotationComposer,
          $$TimeChunksTableCreateCompanionBuilder,
          $$TimeChunksTableUpdateCompanionBuilder,
          (TimeChunk, $$TimeChunksTableReferences),
          TimeChunk,
          PrefetchHooks Function({bool poiId})
        > {
  $$TimeChunksTableTableManager(_$AppDatabase db, $TimeChunksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TimeChunksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TimeChunksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TimeChunksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> poiId = const Value.absent(),
                Value<String?> date = const Value.absent(),
                Value<String?> startTime = const Value.absent(),
                Value<String?> endTime = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> duration = const Value.absent(),
                Value<int> transitDuration = const Value.absent(),
                Value<bool> isFixedTime = const Value.absent(),
                Value<String> authorId = const Value.absent(),
                Value<bool> isShared = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<bool> hasEverSynced = const Value.absent(),
                Value<String?> originalStartTime = const Value.absent(),
                Value<String?> originalEndTime = const Value.absent(),
                Value<DateTime?> lastModifiedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TimeChunksCompanion(
                id: id,
                poiId: poiId,
                date: date,
                startTime: startTime,
                endTime: endTime,
                status: status,
                sortOrder: sortOrder,
                duration: duration,
                transitDuration: transitDuration,
                isFixedTime: isFixedTime,
                authorId: authorId,
                isShared: isShared,
                createdAt: createdAt,
                syncStatus: syncStatus,
                isDeleted: isDeleted,
                hasEverSynced: hasEverSynced,
                originalStartTime: originalStartTime,
                originalEndTime: originalEndTime,
                lastModifiedAt: lastModifiedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String poiId,
                Value<String?> date = const Value.absent(),
                Value<String?> startTime = const Value.absent(),
                Value<String?> endTime = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> duration = const Value.absent(),
                Value<int> transitDuration = const Value.absent(),
                Value<bool> isFixedTime = const Value.absent(),
                required String authorId,
                Value<bool> isShared = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<bool> hasEverSynced = const Value.absent(),
                Value<String?> originalStartTime = const Value.absent(),
                Value<String?> originalEndTime = const Value.absent(),
                Value<DateTime?> lastModifiedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TimeChunksCompanion.insert(
                id: id,
                poiId: poiId,
                date: date,
                startTime: startTime,
                endTime: endTime,
                status: status,
                sortOrder: sortOrder,
                duration: duration,
                transitDuration: transitDuration,
                isFixedTime: isFixedTime,
                authorId: authorId,
                isShared: isShared,
                createdAt: createdAt,
                syncStatus: syncStatus,
                isDeleted: isDeleted,
                hasEverSynced: hasEverSynced,
                originalStartTime: originalStartTime,
                originalEndTime: originalEndTime,
                lastModifiedAt: lastModifiedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TimeChunksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({poiId = false}) {
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
                    if (poiId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.poiId,
                                referencedTable: $$TimeChunksTableReferences
                                    ._poiIdTable(db),
                                referencedColumn: $$TimeChunksTableReferences
                                    ._poiIdTable(db)
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

typedef $$TimeChunksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TimeChunksTable,
      TimeChunk,
      $$TimeChunksTableFilterComposer,
      $$TimeChunksTableOrderingComposer,
      $$TimeChunksTableAnnotationComposer,
      $$TimeChunksTableCreateCompanionBuilder,
      $$TimeChunksTableUpdateCompanionBuilder,
      (TimeChunk, $$TimeChunksTableReferences),
      TimeChunk,
      PrefetchHooks Function({bool poiId})
    >;
typedef $$ReferenceImagesTableCreateCompanionBuilder =
    ReferenceImagesCompanion Function({
      required String id,
      required String poiId,
      required String authorId,
      Value<String?> localPath,
      Value<String?> remoteUrl,
      Value<String?> metadata,
      Value<int> createdAt,
      Value<int> rowid,
    });
typedef $$ReferenceImagesTableUpdateCompanionBuilder =
    ReferenceImagesCompanion Function({
      Value<String> id,
      Value<String> poiId,
      Value<String> authorId,
      Value<String?> localPath,
      Value<String?> remoteUrl,
      Value<String?> metadata,
      Value<int> createdAt,
      Value<int> rowid,
    });

final class $$ReferenceImagesTableReferences
    extends
        BaseReferences<_$AppDatabase, $ReferenceImagesTable, ReferenceImage> {
  $$ReferenceImagesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PoisTable _poiIdTable(_$AppDatabase db) => db.pois.createAlias(
    $_aliasNameGenerator(db.referenceImages.poiId, db.pois.id),
  );

  $$PoisTableProcessedTableManager get poiId {
    final $_column = $_itemColumn<String>('poi_id')!;

    final manager = $$PoisTableTableManager(
      $_db,
      $_db.pois,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_poiIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$MediaAssetsTable, List<MediaAsset>>
  _mediaAssetsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.mediaAssets,
    aliasName: $_aliasNameGenerator(
      db.referenceImages.id,
      db.mediaAssets.referenceImageId,
    ),
  );

  $$MediaAssetsTableProcessedTableManager get mediaAssetsRefs {
    final manager = $$MediaAssetsTableTableManager($_db, $_db.mediaAssets)
        .filter(
          (f) => f.referenceImageId.id.sqlEquals($_itemColumn<String>('id')!),
        );

    final cache = $_typedResult.readTableOrNull(_mediaAssetsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ReferenceImagesTableFilterComposer
    extends Composer<_$AppDatabase, $ReferenceImagesTable> {
  $$ReferenceImagesTableFilterComposer({
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

  ColumnFilters<String> get authorId => $composableBuilder(
    column: $table.authorId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteUrl => $composableBuilder(
    column: $table.remoteUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metadata => $composableBuilder(
    column: $table.metadata,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$PoisTableFilterComposer get poiId {
    final $$PoisTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.poiId,
      referencedTable: $db.pois,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PoisTableFilterComposer(
            $db: $db,
            $table: $db.pois,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> mediaAssetsRefs(
    Expression<bool> Function($$MediaAssetsTableFilterComposer f) f,
  ) {
    final $$MediaAssetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mediaAssets,
      getReferencedColumn: (t) => t.referenceImageId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MediaAssetsTableFilterComposer(
            $db: $db,
            $table: $db.mediaAssets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ReferenceImagesTableOrderingComposer
    extends Composer<_$AppDatabase, $ReferenceImagesTable> {
  $$ReferenceImagesTableOrderingComposer({
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

  ColumnOrderings<String> get authorId => $composableBuilder(
    column: $table.authorId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteUrl => $composableBuilder(
    column: $table.remoteUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metadata => $composableBuilder(
    column: $table.metadata,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$PoisTableOrderingComposer get poiId {
    final $$PoisTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.poiId,
      referencedTable: $db.pois,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PoisTableOrderingComposer(
            $db: $db,
            $table: $db.pois,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReferenceImagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReferenceImagesTable> {
  $$ReferenceImagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get authorId =>
      $composableBuilder(column: $table.authorId, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<String> get remoteUrl =>
      $composableBuilder(column: $table.remoteUrl, builder: (column) => column);

  GeneratedColumn<String> get metadata =>
      $composableBuilder(column: $table.metadata, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$PoisTableAnnotationComposer get poiId {
    final $$PoisTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.poiId,
      referencedTable: $db.pois,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PoisTableAnnotationComposer(
            $db: $db,
            $table: $db.pois,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> mediaAssetsRefs<T extends Object>(
    Expression<T> Function($$MediaAssetsTableAnnotationComposer a) f,
  ) {
    final $$MediaAssetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mediaAssets,
      getReferencedColumn: (t) => t.referenceImageId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MediaAssetsTableAnnotationComposer(
            $db: $db,
            $table: $db.mediaAssets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ReferenceImagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReferenceImagesTable,
          ReferenceImage,
          $$ReferenceImagesTableFilterComposer,
          $$ReferenceImagesTableOrderingComposer,
          $$ReferenceImagesTableAnnotationComposer,
          $$ReferenceImagesTableCreateCompanionBuilder,
          $$ReferenceImagesTableUpdateCompanionBuilder,
          (ReferenceImage, $$ReferenceImagesTableReferences),
          ReferenceImage,
          PrefetchHooks Function({bool poiId, bool mediaAssetsRefs})
        > {
  $$ReferenceImagesTableTableManager(
    _$AppDatabase db,
    $ReferenceImagesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReferenceImagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReferenceImagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReferenceImagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> poiId = const Value.absent(),
                Value<String> authorId = const Value.absent(),
                Value<String?> localPath = const Value.absent(),
                Value<String?> remoteUrl = const Value.absent(),
                Value<String?> metadata = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReferenceImagesCompanion(
                id: id,
                poiId: poiId,
                authorId: authorId,
                localPath: localPath,
                remoteUrl: remoteUrl,
                metadata: metadata,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String poiId,
                required String authorId,
                Value<String?> localPath = const Value.absent(),
                Value<String?> remoteUrl = const Value.absent(),
                Value<String?> metadata = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReferenceImagesCompanion.insert(
                id: id,
                poiId: poiId,
                authorId: authorId,
                localPath: localPath,
                remoteUrl: remoteUrl,
                metadata: metadata,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ReferenceImagesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({poiId = false, mediaAssetsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (mediaAssetsRefs) db.mediaAssets],
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
                    if (poiId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.poiId,
                                referencedTable:
                                    $$ReferenceImagesTableReferences
                                        ._poiIdTable(db),
                                referencedColumn:
                                    $$ReferenceImagesTableReferences
                                        ._poiIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (mediaAssetsRefs)
                    await $_getPrefetchedData<
                      ReferenceImage,
                      $ReferenceImagesTable,
                      MediaAsset
                    >(
                      currentTable: table,
                      referencedTable: $$ReferenceImagesTableReferences
                          ._mediaAssetsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$ReferenceImagesTableReferences(
                            db,
                            table,
                            p0,
                          ).mediaAssetsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.referenceImageId == item.id,
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

typedef $$ReferenceImagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReferenceImagesTable,
      ReferenceImage,
      $$ReferenceImagesTableFilterComposer,
      $$ReferenceImagesTableOrderingComposer,
      $$ReferenceImagesTableAnnotationComposer,
      $$ReferenceImagesTableCreateCompanionBuilder,
      $$ReferenceImagesTableUpdateCompanionBuilder,
      (ReferenceImage, $$ReferenceImagesTableReferences),
      ReferenceImage,
      PrefetchHooks Function({bool poiId, bool mediaAssetsRefs})
    >;
typedef $$MediaAssetsTableCreateCompanionBuilder =
    MediaAssetsCompanion Function({
      required String id,
      required String poiId,
      required String authorId,
      required String type,
      Value<String?> localPath,
      Value<String?> remoteUrl,
      Value<String?> metadata,
      Value<String?> referenceImageId,
      Value<int> createdAt,
      Value<int> rowid,
    });
typedef $$MediaAssetsTableUpdateCompanionBuilder =
    MediaAssetsCompanion Function({
      Value<String> id,
      Value<String> poiId,
      Value<String> authorId,
      Value<String> type,
      Value<String?> localPath,
      Value<String?> remoteUrl,
      Value<String?> metadata,
      Value<String?> referenceImageId,
      Value<int> createdAt,
      Value<int> rowid,
    });

final class $$MediaAssetsTableReferences
    extends BaseReferences<_$AppDatabase, $MediaAssetsTable, MediaAsset> {
  $$MediaAssetsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PoisTable _poiIdTable(_$AppDatabase db) => db.pois.createAlias(
    $_aliasNameGenerator(db.mediaAssets.poiId, db.pois.id),
  );

  $$PoisTableProcessedTableManager get poiId {
    final $_column = $_itemColumn<String>('poi_id')!;

    final manager = $$PoisTableTableManager(
      $_db,
      $_db.pois,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_poiIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ReferenceImagesTable _referenceImageIdTable(_$AppDatabase db) =>
      db.referenceImages.createAlias(
        $_aliasNameGenerator(
          db.mediaAssets.referenceImageId,
          db.referenceImages.id,
        ),
      );

  $$ReferenceImagesTableProcessedTableManager? get referenceImageId {
    final $_column = $_itemColumn<String>('reference_image_id');
    if ($_column == null) return null;
    final manager = $$ReferenceImagesTableTableManager(
      $_db,
      $_db.referenceImages,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_referenceImageIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MediaAssetsTableFilterComposer
    extends Composer<_$AppDatabase, $MediaAssetsTable> {
  $$MediaAssetsTableFilterComposer({
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

  ColumnFilters<String> get authorId => $composableBuilder(
    column: $table.authorId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteUrl => $composableBuilder(
    column: $table.remoteUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metadata => $composableBuilder(
    column: $table.metadata,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$PoisTableFilterComposer get poiId {
    final $$PoisTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.poiId,
      referencedTable: $db.pois,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PoisTableFilterComposer(
            $db: $db,
            $table: $db.pois,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ReferenceImagesTableFilterComposer get referenceImageId {
    final $$ReferenceImagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.referenceImageId,
      referencedTable: $db.referenceImages,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReferenceImagesTableFilterComposer(
            $db: $db,
            $table: $db.referenceImages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MediaAssetsTableOrderingComposer
    extends Composer<_$AppDatabase, $MediaAssetsTable> {
  $$MediaAssetsTableOrderingComposer({
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

  ColumnOrderings<String> get authorId => $composableBuilder(
    column: $table.authorId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteUrl => $composableBuilder(
    column: $table.remoteUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metadata => $composableBuilder(
    column: $table.metadata,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$PoisTableOrderingComposer get poiId {
    final $$PoisTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.poiId,
      referencedTable: $db.pois,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PoisTableOrderingComposer(
            $db: $db,
            $table: $db.pois,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ReferenceImagesTableOrderingComposer get referenceImageId {
    final $$ReferenceImagesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.referenceImageId,
      referencedTable: $db.referenceImages,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReferenceImagesTableOrderingComposer(
            $db: $db,
            $table: $db.referenceImages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MediaAssetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MediaAssetsTable> {
  $$MediaAssetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get authorId =>
      $composableBuilder(column: $table.authorId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<String> get remoteUrl =>
      $composableBuilder(column: $table.remoteUrl, builder: (column) => column);

  GeneratedColumn<String> get metadata =>
      $composableBuilder(column: $table.metadata, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$PoisTableAnnotationComposer get poiId {
    final $$PoisTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.poiId,
      referencedTable: $db.pois,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PoisTableAnnotationComposer(
            $db: $db,
            $table: $db.pois,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ReferenceImagesTableAnnotationComposer get referenceImageId {
    final $$ReferenceImagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.referenceImageId,
      referencedTable: $db.referenceImages,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReferenceImagesTableAnnotationComposer(
            $db: $db,
            $table: $db.referenceImages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MediaAssetsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MediaAssetsTable,
          MediaAsset,
          $$MediaAssetsTableFilterComposer,
          $$MediaAssetsTableOrderingComposer,
          $$MediaAssetsTableAnnotationComposer,
          $$MediaAssetsTableCreateCompanionBuilder,
          $$MediaAssetsTableUpdateCompanionBuilder,
          (MediaAsset, $$MediaAssetsTableReferences),
          MediaAsset,
          PrefetchHooks Function({bool poiId, bool referenceImageId})
        > {
  $$MediaAssetsTableTableManager(_$AppDatabase db, $MediaAssetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MediaAssetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MediaAssetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MediaAssetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> poiId = const Value.absent(),
                Value<String> authorId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String?> localPath = const Value.absent(),
                Value<String?> remoteUrl = const Value.absent(),
                Value<String?> metadata = const Value.absent(),
                Value<String?> referenceImageId = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MediaAssetsCompanion(
                id: id,
                poiId: poiId,
                authorId: authorId,
                type: type,
                localPath: localPath,
                remoteUrl: remoteUrl,
                metadata: metadata,
                referenceImageId: referenceImageId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String poiId,
                required String authorId,
                required String type,
                Value<String?> localPath = const Value.absent(),
                Value<String?> remoteUrl = const Value.absent(),
                Value<String?> metadata = const Value.absent(),
                Value<String?> referenceImageId = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MediaAssetsCompanion.insert(
                id: id,
                poiId: poiId,
                authorId: authorId,
                type: type,
                localPath: localPath,
                remoteUrl: remoteUrl,
                metadata: metadata,
                referenceImageId: referenceImageId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MediaAssetsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({poiId = false, referenceImageId = false}) {
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
                    if (poiId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.poiId,
                                referencedTable: $$MediaAssetsTableReferences
                                    ._poiIdTable(db),
                                referencedColumn: $$MediaAssetsTableReferences
                                    ._poiIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (referenceImageId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.referenceImageId,
                                referencedTable: $$MediaAssetsTableReferences
                                    ._referenceImageIdTable(db),
                                referencedColumn: $$MediaAssetsTableReferences
                                    ._referenceImageIdTable(db)
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

typedef $$MediaAssetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MediaAssetsTable,
      MediaAsset,
      $$MediaAssetsTableFilterComposer,
      $$MediaAssetsTableOrderingComposer,
      $$MediaAssetsTableAnnotationComposer,
      $$MediaAssetsTableCreateCompanionBuilder,
      $$MediaAssetsTableUpdateCompanionBuilder,
      (MediaAsset, $$MediaAssetsTableReferences),
      MediaAsset,
      PrefetchHooks Function({bool poiId, bool referenceImageId})
    >;
typedef $$PlacesTableCreateCompanionBuilder =
    PlacesCompanion Function({
      required String placeKey,
      required String name,
      required double lat,
      required double lng,
      Value<String?> description,
      Value<String?> address,
      Value<String?> businessHours,
      Value<String?> contactInfo,
      Value<String?> accessTips,
      Value<String?> links,
      Value<String?> coverLocalPath,
      Value<String?> coverRemoteUrl,
      Value<String?> source,
      Value<String?> sourceUrl,
      Value<String?> privateNote,
      Value<String> visibility,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$PlacesTableUpdateCompanionBuilder =
    PlacesCompanion Function({
      Value<String> placeKey,
      Value<String> name,
      Value<double> lat,
      Value<double> lng,
      Value<String?> description,
      Value<String?> address,
      Value<String?> businessHours,
      Value<String?> contactInfo,
      Value<String?> accessTips,
      Value<String?> links,
      Value<String?> coverLocalPath,
      Value<String?> coverRemoteUrl,
      Value<String?> source,
      Value<String?> sourceUrl,
      Value<String?> privateNote,
      Value<String> visibility,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$PlacesTableReferences
    extends BaseReferences<_$AppDatabase, $PlacesTable, Place> {
  $$PlacesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PlaceLabelsTable, List<PlaceLabel>>
  _placeLabelsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.placeLabels,
    aliasName: $_aliasNameGenerator(
      db.places.placeKey,
      db.placeLabels.placeKey,
    ),
  );

  $$PlaceLabelsTableProcessedTableManager get placeLabelsRefs {
    final manager = $$PlaceLabelsTableTableManager($_db, $_db.placeLabels)
        .filter(
          (f) =>
              f.placeKey.placeKey.sqlEquals($_itemColumn<String>('place_key')!),
        );

    final cache = $_typedResult.readTableOrNull(_placeLabelsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PhotosTable, List<Photo>> _photosRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.photos,
    aliasName: $_aliasNameGenerator(db.places.placeKey, db.photos.placeKey),
  );

  $$PhotosTableProcessedTableManager get photosRefs {
    final manager = $$PhotosTableTableManager($_db, $_db.photos).filter(
      (f) => f.placeKey.placeKey.sqlEquals($_itemColumn<String>('place_key')!),
    );

    final cache = $_typedResult.readTableOrNull(_photosRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PlaceVisitsTable, List<PlaceVisit>>
  _placeVisitsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.placeVisits,
    aliasName: $_aliasNameGenerator(
      db.places.placeKey,
      db.placeVisits.placeKey,
    ),
  );

  $$PlaceVisitsTableProcessedTableManager get placeVisitsRefs {
    final manager = $$PlaceVisitsTableTableManager($_db, $_db.placeVisits)
        .filter(
          (f) =>
              f.placeKey.placeKey.sqlEquals($_itemColumn<String>('place_key')!),
        );

    final cache = $_typedResult.readTableOrNull(_placeVisitsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$NewReferenceImagesTable, List<NewReferenceImage>>
  _newReferenceImagesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.newReferenceImages,
        aliasName: $_aliasNameGenerator(
          db.places.placeKey,
          db.newReferenceImages.placeKey,
        ),
      );

  $$NewReferenceImagesTableProcessedTableManager get newReferenceImagesRefs {
    final manager =
        $$NewReferenceImagesTableTableManager(
          $_db,
          $_db.newReferenceImages,
        ).filter(
          (f) =>
              f.placeKey.placeKey.sqlEquals($_itemColumn<String>('place_key')!),
        );

    final cache = $_typedResult.readTableOrNull(
      _newReferenceImagesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PlacesTableFilterComposer
    extends Composer<_$AppDatabase, $PlacesTable> {
  $$PlacesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get placeKey => $composableBuilder(
    column: $table.placeKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lng => $composableBuilder(
    column: $table.lng,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get businessHours => $composableBuilder(
    column: $table.businessHours,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contactInfo => $composableBuilder(
    column: $table.contactInfo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accessTips => $composableBuilder(
    column: $table.accessTips,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get links => $composableBuilder(
    column: $table.links,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverLocalPath => $composableBuilder(
    column: $table.coverLocalPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverRemoteUrl => $composableBuilder(
    column: $table.coverRemoteUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get privateNote => $composableBuilder(
    column: $table.privateNote,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get visibility => $composableBuilder(
    column: $table.visibility,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get updatedAt =>
      $composableBuilder(
        column: $table.updatedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  Expression<bool> placeLabelsRefs(
    Expression<bool> Function($$PlaceLabelsTableFilterComposer f) f,
  ) {
    final $$PlaceLabelsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.placeKey,
      referencedTable: $db.placeLabels,
      getReferencedColumn: (t) => t.placeKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaceLabelsTableFilterComposer(
            $db: $db,
            $table: $db.placeLabels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> photosRefs(
    Expression<bool> Function($$PhotosTableFilterComposer f) f,
  ) {
    final $$PhotosTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.placeKey,
      referencedTable: $db.photos,
      getReferencedColumn: (t) => t.placeKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PhotosTableFilterComposer(
            $db: $db,
            $table: $db.photos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> placeVisitsRefs(
    Expression<bool> Function($$PlaceVisitsTableFilterComposer f) f,
  ) {
    final $$PlaceVisitsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.placeKey,
      referencedTable: $db.placeVisits,
      getReferencedColumn: (t) => t.placeKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaceVisitsTableFilterComposer(
            $db: $db,
            $table: $db.placeVisits,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> newReferenceImagesRefs(
    Expression<bool> Function($$NewReferenceImagesTableFilterComposer f) f,
  ) {
    final $$NewReferenceImagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.placeKey,
      referencedTable: $db.newReferenceImages,
      getReferencedColumn: (t) => t.placeKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NewReferenceImagesTableFilterComposer(
            $db: $db,
            $table: $db.newReferenceImages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PlacesTableOrderingComposer
    extends Composer<_$AppDatabase, $PlacesTable> {
  $$PlacesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get placeKey => $composableBuilder(
    column: $table.placeKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lng => $composableBuilder(
    column: $table.lng,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get businessHours => $composableBuilder(
    column: $table.businessHours,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contactInfo => $composableBuilder(
    column: $table.contactInfo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accessTips => $composableBuilder(
    column: $table.accessTips,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get links => $composableBuilder(
    column: $table.links,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverLocalPath => $composableBuilder(
    column: $table.coverLocalPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverRemoteUrl => $composableBuilder(
    column: $table.coverRemoteUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get privateNote => $composableBuilder(
    column: $table.privateNote,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get visibility => $composableBuilder(
    column: $table.visibility,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlacesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlacesTable> {
  $$PlacesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get placeKey =>
      $composableBuilder(column: $table.placeKey, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get lat =>
      $composableBuilder(column: $table.lat, builder: (column) => column);

  GeneratedColumn<double> get lng =>
      $composableBuilder(column: $table.lng, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<String> get businessHours => $composableBuilder(
    column: $table.businessHours,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contactInfo => $composableBuilder(
    column: $table.contactInfo,
    builder: (column) => column,
  );

  GeneratedColumn<String> get accessTips => $composableBuilder(
    column: $table.accessTips,
    builder: (column) => column,
  );

  GeneratedColumn<String> get links =>
      $composableBuilder(column: $table.links, builder: (column) => column);

  GeneratedColumn<String> get coverLocalPath => $composableBuilder(
    column: $table.coverLocalPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get coverRemoteUrl => $composableBuilder(
    column: $table.coverRemoteUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get sourceUrl =>
      $composableBuilder(column: $table.sourceUrl, builder: (column) => column);

  GeneratedColumn<String> get privateNote => $composableBuilder(
    column: $table.privateNote,
    builder: (column) => column,
  );

  GeneratedColumn<String> get visibility => $composableBuilder(
    column: $table.visibility,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> placeLabelsRefs<T extends Object>(
    Expression<T> Function($$PlaceLabelsTableAnnotationComposer a) f,
  ) {
    final $$PlaceLabelsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.placeKey,
      referencedTable: $db.placeLabels,
      getReferencedColumn: (t) => t.placeKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaceLabelsTableAnnotationComposer(
            $db: $db,
            $table: $db.placeLabels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> photosRefs<T extends Object>(
    Expression<T> Function($$PhotosTableAnnotationComposer a) f,
  ) {
    final $$PhotosTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.placeKey,
      referencedTable: $db.photos,
      getReferencedColumn: (t) => t.placeKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PhotosTableAnnotationComposer(
            $db: $db,
            $table: $db.photos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> placeVisitsRefs<T extends Object>(
    Expression<T> Function($$PlaceVisitsTableAnnotationComposer a) f,
  ) {
    final $$PlaceVisitsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.placeKey,
      referencedTable: $db.placeVisits,
      getReferencedColumn: (t) => t.placeKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaceVisitsTableAnnotationComposer(
            $db: $db,
            $table: $db.placeVisits,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> newReferenceImagesRefs<T extends Object>(
    Expression<T> Function($$NewReferenceImagesTableAnnotationComposer a) f,
  ) {
    final $$NewReferenceImagesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.placeKey,
          referencedTable: $db.newReferenceImages,
          getReferencedColumn: (t) => t.placeKey,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$NewReferenceImagesTableAnnotationComposer(
                $db: $db,
                $table: $db.newReferenceImages,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$PlacesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlacesTable,
          Place,
          $$PlacesTableFilterComposer,
          $$PlacesTableOrderingComposer,
          $$PlacesTableAnnotationComposer,
          $$PlacesTableCreateCompanionBuilder,
          $$PlacesTableUpdateCompanionBuilder,
          (Place, $$PlacesTableReferences),
          Place,
          PrefetchHooks Function({
            bool placeLabelsRefs,
            bool photosRefs,
            bool placeVisitsRefs,
            bool newReferenceImagesRefs,
          })
        > {
  $$PlacesTableTableManager(_$AppDatabase db, $PlacesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlacesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlacesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlacesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> placeKey = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double> lat = const Value.absent(),
                Value<double> lng = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> address = const Value.absent(),
                Value<String?> businessHours = const Value.absent(),
                Value<String?> contactInfo = const Value.absent(),
                Value<String?> accessTips = const Value.absent(),
                Value<String?> links = const Value.absent(),
                Value<String?> coverLocalPath = const Value.absent(),
                Value<String?> coverRemoteUrl = const Value.absent(),
                Value<String?> source = const Value.absent(),
                Value<String?> sourceUrl = const Value.absent(),
                Value<String?> privateNote = const Value.absent(),
                Value<String> visibility = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlacesCompanion(
                placeKey: placeKey,
                name: name,
                lat: lat,
                lng: lng,
                description: description,
                address: address,
                businessHours: businessHours,
                contactInfo: contactInfo,
                accessTips: accessTips,
                links: links,
                coverLocalPath: coverLocalPath,
                coverRemoteUrl: coverRemoteUrl,
                source: source,
                sourceUrl: sourceUrl,
                privateNote: privateNote,
                visibility: visibility,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String placeKey,
                required String name,
                required double lat,
                required double lng,
                Value<String?> description = const Value.absent(),
                Value<String?> address = const Value.absent(),
                Value<String?> businessHours = const Value.absent(),
                Value<String?> contactInfo = const Value.absent(),
                Value<String?> accessTips = const Value.absent(),
                Value<String?> links = const Value.absent(),
                Value<String?> coverLocalPath = const Value.absent(),
                Value<String?> coverRemoteUrl = const Value.absent(),
                Value<String?> source = const Value.absent(),
                Value<String?> sourceUrl = const Value.absent(),
                Value<String?> privateNote = const Value.absent(),
                Value<String> visibility = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlacesCompanion.insert(
                placeKey: placeKey,
                name: name,
                lat: lat,
                lng: lng,
                description: description,
                address: address,
                businessHours: businessHours,
                contactInfo: contactInfo,
                accessTips: accessTips,
                links: links,
                coverLocalPath: coverLocalPath,
                coverRemoteUrl: coverRemoteUrl,
                source: source,
                sourceUrl: sourceUrl,
                privateNote: privateNote,
                visibility: visibility,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$PlacesTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                placeLabelsRefs = false,
                photosRefs = false,
                placeVisitsRefs = false,
                newReferenceImagesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (placeLabelsRefs) db.placeLabels,
                    if (photosRefs) db.photos,
                    if (placeVisitsRefs) db.placeVisits,
                    if (newReferenceImagesRefs) db.newReferenceImages,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (placeLabelsRefs)
                        await $_getPrefetchedData<
                          Place,
                          $PlacesTable,
                          PlaceLabel
                        >(
                          currentTable: table,
                          referencedTable: $$PlacesTableReferences
                              ._placeLabelsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PlacesTableReferences(
                                db,
                                table,
                                p0,
                              ).placeLabelsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.placeKey == item.placeKey,
                              ),
                          typedResults: items,
                        ),
                      if (photosRefs)
                        await $_getPrefetchedData<Place, $PlacesTable, Photo>(
                          currentTable: table,
                          referencedTable: $$PlacesTableReferences
                              ._photosRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PlacesTableReferences(db, table, p0).photosRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.placeKey == item.placeKey,
                              ),
                          typedResults: items,
                        ),
                      if (placeVisitsRefs)
                        await $_getPrefetchedData<
                          Place,
                          $PlacesTable,
                          PlaceVisit
                        >(
                          currentTable: table,
                          referencedTable: $$PlacesTableReferences
                              ._placeVisitsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PlacesTableReferences(
                                db,
                                table,
                                p0,
                              ).placeVisitsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.placeKey == item.placeKey,
                              ),
                          typedResults: items,
                        ),
                      if (newReferenceImagesRefs)
                        await $_getPrefetchedData<
                          Place,
                          $PlacesTable,
                          NewReferenceImage
                        >(
                          currentTable: table,
                          referencedTable: $$PlacesTableReferences
                              ._newReferenceImagesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PlacesTableReferences(
                                db,
                                table,
                                p0,
                              ).newReferenceImagesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.placeKey == item.placeKey,
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

typedef $$PlacesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlacesTable,
      Place,
      $$PlacesTableFilterComposer,
      $$PlacesTableOrderingComposer,
      $$PlacesTableAnnotationComposer,
      $$PlacesTableCreateCompanionBuilder,
      $$PlacesTableUpdateCompanionBuilder,
      (Place, $$PlacesTableReferences),
      Place,
      PrefetchHooks Function({
        bool placeLabelsRefs,
        bool photosRefs,
        bool placeVisitsRefs,
        bool newReferenceImagesRefs,
      })
    >;
typedef $$LabelsTableCreateCompanionBuilder =
    LabelsCompanion Function({
      required String id,
      required String kind,
      required String name,
      Value<String?> bangumiId,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$LabelsTableUpdateCompanionBuilder =
    LabelsCompanion Function({
      Value<String> id,
      Value<String> kind,
      Value<String> name,
      Value<String?> bangumiId,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$LabelsTableReferences
    extends BaseReferences<_$AppDatabase, $LabelsTable, Label> {
  $$LabelsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PlaceLabelsTable, List<PlaceLabel>>
  _placeLabelsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.placeLabels,
    aliasName: $_aliasNameGenerator(db.labels.id, db.placeLabels.labelId),
  );

  $$PlaceLabelsTableProcessedTableManager get placeLabelsRefs {
    final manager = $$PlaceLabelsTableTableManager(
      $_db,
      $_db.placeLabels,
    ).filter((f) => f.labelId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_placeLabelsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$StopLabelsTable, List<StopLabel>>
  _stopLabelsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.stopLabels,
    aliasName: $_aliasNameGenerator(db.labels.id, db.stopLabels.labelId),
  );

  $$StopLabelsTableProcessedTableManager get stopLabelsRefs {
    final manager = $$StopLabelsTableTableManager(
      $_db,
      $_db.stopLabels,
    ).filter((f) => f.labelId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_stopLabelsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LabelsTableFilterComposer
    extends Composer<_$AppDatabase, $LabelsTable> {
  $$LabelsTableFilterComposer({
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

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bangumiId => $composableBuilder(
    column: $table.bangumiId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> placeLabelsRefs(
    Expression<bool> Function($$PlaceLabelsTableFilterComposer f) f,
  ) {
    final $$PlaceLabelsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.placeLabels,
      getReferencedColumn: (t) => t.labelId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaceLabelsTableFilterComposer(
            $db: $db,
            $table: $db.placeLabels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> stopLabelsRefs(
    Expression<bool> Function($$StopLabelsTableFilterComposer f) f,
  ) {
    final $$StopLabelsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.stopLabels,
      getReferencedColumn: (t) => t.labelId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StopLabelsTableFilterComposer(
            $db: $db,
            $table: $db.stopLabels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LabelsTableOrderingComposer
    extends Composer<_$AppDatabase, $LabelsTable> {
  $$LabelsTableOrderingComposer({
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

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bangumiId => $composableBuilder(
    column: $table.bangumiId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LabelsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LabelsTable> {
  $$LabelsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get bangumiId =>
      $composableBuilder(column: $table.bangumiId, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> placeLabelsRefs<T extends Object>(
    Expression<T> Function($$PlaceLabelsTableAnnotationComposer a) f,
  ) {
    final $$PlaceLabelsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.placeLabels,
      getReferencedColumn: (t) => t.labelId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaceLabelsTableAnnotationComposer(
            $db: $db,
            $table: $db.placeLabels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> stopLabelsRefs<T extends Object>(
    Expression<T> Function($$StopLabelsTableAnnotationComposer a) f,
  ) {
    final $$StopLabelsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.stopLabels,
      getReferencedColumn: (t) => t.labelId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StopLabelsTableAnnotationComposer(
            $db: $db,
            $table: $db.stopLabels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LabelsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LabelsTable,
          Label,
          $$LabelsTableFilterComposer,
          $$LabelsTableOrderingComposer,
          $$LabelsTableAnnotationComposer,
          $$LabelsTableCreateCompanionBuilder,
          $$LabelsTableUpdateCompanionBuilder,
          (Label, $$LabelsTableReferences),
          Label,
          PrefetchHooks Function({bool placeLabelsRefs, bool stopLabelsRefs})
        > {
  $$LabelsTableTableManager(_$AppDatabase db, $LabelsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LabelsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LabelsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LabelsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> bangumiId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LabelsCompanion(
                id: id,
                kind: kind,
                name: name,
                bangumiId: bangumiId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String kind,
                required String name,
                Value<String?> bangumiId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LabelsCompanion.insert(
                id: id,
                kind: kind,
                name: name,
                bangumiId: bangumiId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$LabelsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({placeLabelsRefs = false, stopLabelsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (placeLabelsRefs) db.placeLabels,
                    if (stopLabelsRefs) db.stopLabels,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (placeLabelsRefs)
                        await $_getPrefetchedData<
                          Label,
                          $LabelsTable,
                          PlaceLabel
                        >(
                          currentTable: table,
                          referencedTable: $$LabelsTableReferences
                              ._placeLabelsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LabelsTableReferences(
                                db,
                                table,
                                p0,
                              ).placeLabelsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.labelId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (stopLabelsRefs)
                        await $_getPrefetchedData<
                          Label,
                          $LabelsTable,
                          StopLabel
                        >(
                          currentTable: table,
                          referencedTable: $$LabelsTableReferences
                              ._stopLabelsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LabelsTableReferences(
                                db,
                                table,
                                p0,
                              ).stopLabelsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.labelId == item.id,
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

typedef $$LabelsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LabelsTable,
      Label,
      $$LabelsTableFilterComposer,
      $$LabelsTableOrderingComposer,
      $$LabelsTableAnnotationComposer,
      $$LabelsTableCreateCompanionBuilder,
      $$LabelsTableUpdateCompanionBuilder,
      (Label, $$LabelsTableReferences),
      Label,
      PrefetchHooks Function({bool placeLabelsRefs, bool stopLabelsRefs})
    >;
typedef $$PlaceLabelsTableCreateCompanionBuilder =
    PlaceLabelsCompanion Function({
      required String placeKey,
      required String labelId,
      Value<int> rowid,
    });
typedef $$PlaceLabelsTableUpdateCompanionBuilder =
    PlaceLabelsCompanion Function({
      Value<String> placeKey,
      Value<String> labelId,
      Value<int> rowid,
    });

final class $$PlaceLabelsTableReferences
    extends BaseReferences<_$AppDatabase, $PlaceLabelsTable, PlaceLabel> {
  $$PlaceLabelsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PlacesTable _placeKeyTable(_$AppDatabase db) => db.places.createAlias(
    $_aliasNameGenerator(db.placeLabels.placeKey, db.places.placeKey),
  );

  $$PlacesTableProcessedTableManager get placeKey {
    final $_column = $_itemColumn<String>('place_key')!;

    final manager = $$PlacesTableTableManager(
      $_db,
      $_db.places,
    ).filter((f) => f.placeKey.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_placeKeyTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $LabelsTable _labelIdTable(_$AppDatabase db) => db.labels.createAlias(
    $_aliasNameGenerator(db.placeLabels.labelId, db.labels.id),
  );

  $$LabelsTableProcessedTableManager get labelId {
    final $_column = $_itemColumn<String>('label_id')!;

    final manager = $$LabelsTableTableManager(
      $_db,
      $_db.labels,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_labelIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PlaceLabelsTableFilterComposer
    extends Composer<_$AppDatabase, $PlaceLabelsTable> {
  $$PlaceLabelsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$PlacesTableFilterComposer get placeKey {
    final $$PlacesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.placeKey,
      referencedTable: $db.places,
      getReferencedColumn: (t) => t.placeKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlacesTableFilterComposer(
            $db: $db,
            $table: $db.places,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LabelsTableFilterComposer get labelId {
    final $$LabelsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.labelId,
      referencedTable: $db.labels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LabelsTableFilterComposer(
            $db: $db,
            $table: $db.labels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaceLabelsTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaceLabelsTable> {
  $$PlaceLabelsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$PlacesTableOrderingComposer get placeKey {
    final $$PlacesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.placeKey,
      referencedTable: $db.places,
      getReferencedColumn: (t) => t.placeKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlacesTableOrderingComposer(
            $db: $db,
            $table: $db.places,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LabelsTableOrderingComposer get labelId {
    final $$LabelsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.labelId,
      referencedTable: $db.labels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LabelsTableOrderingComposer(
            $db: $db,
            $table: $db.labels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaceLabelsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaceLabelsTable> {
  $$PlaceLabelsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$PlacesTableAnnotationComposer get placeKey {
    final $$PlacesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.placeKey,
      referencedTable: $db.places,
      getReferencedColumn: (t) => t.placeKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlacesTableAnnotationComposer(
            $db: $db,
            $table: $db.places,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LabelsTableAnnotationComposer get labelId {
    final $$LabelsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.labelId,
      referencedTable: $db.labels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LabelsTableAnnotationComposer(
            $db: $db,
            $table: $db.labels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaceLabelsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlaceLabelsTable,
          PlaceLabel,
          $$PlaceLabelsTableFilterComposer,
          $$PlaceLabelsTableOrderingComposer,
          $$PlaceLabelsTableAnnotationComposer,
          $$PlaceLabelsTableCreateCompanionBuilder,
          $$PlaceLabelsTableUpdateCompanionBuilder,
          (PlaceLabel, $$PlaceLabelsTableReferences),
          PlaceLabel,
          PrefetchHooks Function({bool placeKey, bool labelId})
        > {
  $$PlaceLabelsTableTableManager(_$AppDatabase db, $PlaceLabelsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaceLabelsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaceLabelsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaceLabelsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> placeKey = const Value.absent(),
                Value<String> labelId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlaceLabelsCompanion(
                placeKey: placeKey,
                labelId: labelId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String placeKey,
                required String labelId,
                Value<int> rowid = const Value.absent(),
              }) => PlaceLabelsCompanion.insert(
                placeKey: placeKey,
                labelId: labelId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PlaceLabelsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({placeKey = false, labelId = false}) {
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
                    if (placeKey) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.placeKey,
                                referencedTable: $$PlaceLabelsTableReferences
                                    ._placeKeyTable(db),
                                referencedColumn: $$PlaceLabelsTableReferences
                                    ._placeKeyTable(db)
                                    .placeKey,
                              )
                              as T;
                    }
                    if (labelId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.labelId,
                                referencedTable: $$PlaceLabelsTableReferences
                                    ._labelIdTable(db),
                                referencedColumn: $$PlaceLabelsTableReferences
                                    ._labelIdTable(db)
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

typedef $$PlaceLabelsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlaceLabelsTable,
      PlaceLabel,
      $$PlaceLabelsTableFilterComposer,
      $$PlaceLabelsTableOrderingComposer,
      $$PlaceLabelsTableAnnotationComposer,
      $$PlaceLabelsTableCreateCompanionBuilder,
      $$PlaceLabelsTableUpdateCompanionBuilder,
      (PlaceLabel, $$PlaceLabelsTableReferences),
      PlaceLabel,
      PrefetchHooks Function({bool placeKey, bool labelId})
    >;
typedef $$PhotosTableCreateCompanionBuilder =
    PhotosCompanion Function({
      required String id,
      required String placeKey,
      Value<String?> tripId,
      Value<String> kind,
      Value<String?> derivedFromId,
      Value<String?> referenceImageId,
      required String localPath,
      Value<String?> remoteUrl,
      Value<bool> isShared,
      Value<DateTime?> takenAt,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$PhotosTableUpdateCompanionBuilder =
    PhotosCompanion Function({
      Value<String> id,
      Value<String> placeKey,
      Value<String?> tripId,
      Value<String> kind,
      Value<String?> derivedFromId,
      Value<String?> referenceImageId,
      Value<String> localPath,
      Value<String?> remoteUrl,
      Value<bool> isShared,
      Value<DateTime?> takenAt,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$PhotosTableReferences
    extends BaseReferences<_$AppDatabase, $PhotosTable, Photo> {
  $$PhotosTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PlacesTable _placeKeyTable(_$AppDatabase db) => db.places.createAlias(
    $_aliasNameGenerator(db.photos.placeKey, db.places.placeKey),
  );

  $$PlacesTableProcessedTableManager get placeKey {
    final $_column = $_itemColumn<String>('place_key')!;

    final manager = $$PlacesTableTableManager(
      $_db,
      $_db.places,
    ).filter((f) => f.placeKey.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_placeKeyTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PhotosTableFilterComposer
    extends Composer<_$AppDatabase, $PhotosTable> {
  $$PhotosTableFilterComposer({
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

  ColumnFilters<String> get tripId => $composableBuilder(
    column: $table.tripId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get derivedFromId => $composableBuilder(
    column: $table.derivedFromId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get referenceImageId => $composableBuilder(
    column: $table.referenceImageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteUrl => $composableBuilder(
    column: $table.remoteUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isShared => $composableBuilder(
    column: $table.isShared,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get takenAt => $composableBuilder(
    column: $table.takenAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$PlacesTableFilterComposer get placeKey {
    final $$PlacesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.placeKey,
      referencedTable: $db.places,
      getReferencedColumn: (t) => t.placeKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlacesTableFilterComposer(
            $db: $db,
            $table: $db.places,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PhotosTableOrderingComposer
    extends Composer<_$AppDatabase, $PhotosTable> {
  $$PhotosTableOrderingComposer({
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

  ColumnOrderings<String> get tripId => $composableBuilder(
    column: $table.tripId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get derivedFromId => $composableBuilder(
    column: $table.derivedFromId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get referenceImageId => $composableBuilder(
    column: $table.referenceImageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteUrl => $composableBuilder(
    column: $table.remoteUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isShared => $composableBuilder(
    column: $table.isShared,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get takenAt => $composableBuilder(
    column: $table.takenAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$PlacesTableOrderingComposer get placeKey {
    final $$PlacesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.placeKey,
      referencedTable: $db.places,
      getReferencedColumn: (t) => t.placeKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlacesTableOrderingComposer(
            $db: $db,
            $table: $db.places,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PhotosTableAnnotationComposer
    extends Composer<_$AppDatabase, $PhotosTable> {
  $$PhotosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tripId =>
      $composableBuilder(column: $table.tripId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get derivedFromId => $composableBuilder(
    column: $table.derivedFromId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get referenceImageId => $composableBuilder(
    column: $table.referenceImageId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<String> get remoteUrl =>
      $composableBuilder(column: $table.remoteUrl, builder: (column) => column);

  GeneratedColumn<bool> get isShared =>
      $composableBuilder(column: $table.isShared, builder: (column) => column);

  GeneratedColumn<DateTime> get takenAt =>
      $composableBuilder(column: $table.takenAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$PlacesTableAnnotationComposer get placeKey {
    final $$PlacesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.placeKey,
      referencedTable: $db.places,
      getReferencedColumn: (t) => t.placeKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlacesTableAnnotationComposer(
            $db: $db,
            $table: $db.places,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PhotosTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PhotosTable,
          Photo,
          $$PhotosTableFilterComposer,
          $$PhotosTableOrderingComposer,
          $$PhotosTableAnnotationComposer,
          $$PhotosTableCreateCompanionBuilder,
          $$PhotosTableUpdateCompanionBuilder,
          (Photo, $$PhotosTableReferences),
          Photo,
          PrefetchHooks Function({bool placeKey})
        > {
  $$PhotosTableTableManager(_$AppDatabase db, $PhotosTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PhotosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PhotosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PhotosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> placeKey = const Value.absent(),
                Value<String?> tripId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> derivedFromId = const Value.absent(),
                Value<String?> referenceImageId = const Value.absent(),
                Value<String> localPath = const Value.absent(),
                Value<String?> remoteUrl = const Value.absent(),
                Value<bool> isShared = const Value.absent(),
                Value<DateTime?> takenAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PhotosCompanion(
                id: id,
                placeKey: placeKey,
                tripId: tripId,
                kind: kind,
                derivedFromId: derivedFromId,
                referenceImageId: referenceImageId,
                localPath: localPath,
                remoteUrl: remoteUrl,
                isShared: isShared,
                takenAt: takenAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String placeKey,
                Value<String?> tripId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> derivedFromId = const Value.absent(),
                Value<String?> referenceImageId = const Value.absent(),
                required String localPath,
                Value<String?> remoteUrl = const Value.absent(),
                Value<bool> isShared = const Value.absent(),
                Value<DateTime?> takenAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PhotosCompanion.insert(
                id: id,
                placeKey: placeKey,
                tripId: tripId,
                kind: kind,
                derivedFromId: derivedFromId,
                referenceImageId: referenceImageId,
                localPath: localPath,
                remoteUrl: remoteUrl,
                isShared: isShared,
                takenAt: takenAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$PhotosTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({placeKey = false}) {
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
                    if (placeKey) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.placeKey,
                                referencedTable: $$PhotosTableReferences
                                    ._placeKeyTable(db),
                                referencedColumn: $$PhotosTableReferences
                                    ._placeKeyTable(db)
                                    .placeKey,
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

typedef $$PhotosTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PhotosTable,
      Photo,
      $$PhotosTableFilterComposer,
      $$PhotosTableOrderingComposer,
      $$PhotosTableAnnotationComposer,
      $$PhotosTableCreateCompanionBuilder,
      $$PhotosTableUpdateCompanionBuilder,
      (Photo, $$PhotosTableReferences),
      Photo,
      PrefetchHooks Function({bool placeKey})
    >;
typedef $$PlaceVisitsTableCreateCompanionBuilder =
    PlaceVisitsCompanion Function({
      required String id,
      required String placeKey,
      required String date,
      Value<String?> tripId,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$PlaceVisitsTableUpdateCompanionBuilder =
    PlaceVisitsCompanion Function({
      Value<String> id,
      Value<String> placeKey,
      Value<String> date,
      Value<String?> tripId,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$PlaceVisitsTableReferences
    extends BaseReferences<_$AppDatabase, $PlaceVisitsTable, PlaceVisit> {
  $$PlaceVisitsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PlacesTable _placeKeyTable(_$AppDatabase db) => db.places.createAlias(
    $_aliasNameGenerator(db.placeVisits.placeKey, db.places.placeKey),
  );

  $$PlacesTableProcessedTableManager get placeKey {
    final $_column = $_itemColumn<String>('place_key')!;

    final manager = $$PlacesTableTableManager(
      $_db,
      $_db.places,
    ).filter((f) => f.placeKey.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_placeKeyTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PlaceVisitsTableFilterComposer
    extends Composer<_$AppDatabase, $PlaceVisitsTable> {
  $$PlaceVisitsTableFilterComposer({
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

  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tripId => $composableBuilder(
    column: $table.tripId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$PlacesTableFilterComposer get placeKey {
    final $$PlacesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.placeKey,
      referencedTable: $db.places,
      getReferencedColumn: (t) => t.placeKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlacesTableFilterComposer(
            $db: $db,
            $table: $db.places,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaceVisitsTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaceVisitsTable> {
  $$PlaceVisitsTableOrderingComposer({
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

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tripId => $composableBuilder(
    column: $table.tripId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$PlacesTableOrderingComposer get placeKey {
    final $$PlacesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.placeKey,
      referencedTable: $db.places,
      getReferencedColumn: (t) => t.placeKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlacesTableOrderingComposer(
            $db: $db,
            $table: $db.places,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaceVisitsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaceVisitsTable> {
  $$PlaceVisitsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get tripId =>
      $composableBuilder(column: $table.tripId, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$PlacesTableAnnotationComposer get placeKey {
    final $$PlacesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.placeKey,
      referencedTable: $db.places,
      getReferencedColumn: (t) => t.placeKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlacesTableAnnotationComposer(
            $db: $db,
            $table: $db.places,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaceVisitsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlaceVisitsTable,
          PlaceVisit,
          $$PlaceVisitsTableFilterComposer,
          $$PlaceVisitsTableOrderingComposer,
          $$PlaceVisitsTableAnnotationComposer,
          $$PlaceVisitsTableCreateCompanionBuilder,
          $$PlaceVisitsTableUpdateCompanionBuilder,
          (PlaceVisit, $$PlaceVisitsTableReferences),
          PlaceVisit,
          PrefetchHooks Function({bool placeKey})
        > {
  $$PlaceVisitsTableTableManager(_$AppDatabase db, $PlaceVisitsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaceVisitsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaceVisitsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaceVisitsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> placeKey = const Value.absent(),
                Value<String> date = const Value.absent(),
                Value<String?> tripId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlaceVisitsCompanion(
                id: id,
                placeKey: placeKey,
                date: date,
                tripId: tripId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String placeKey,
                required String date,
                Value<String?> tripId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlaceVisitsCompanion.insert(
                id: id,
                placeKey: placeKey,
                date: date,
                tripId: tripId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PlaceVisitsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({placeKey = false}) {
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
                    if (placeKey) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.placeKey,
                                referencedTable: $$PlaceVisitsTableReferences
                                    ._placeKeyTable(db),
                                referencedColumn: $$PlaceVisitsTableReferences
                                    ._placeKeyTable(db)
                                    .placeKey,
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

typedef $$PlaceVisitsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlaceVisitsTable,
      PlaceVisit,
      $$PlaceVisitsTableFilterComposer,
      $$PlaceVisitsTableOrderingComposer,
      $$PlaceVisitsTableAnnotationComposer,
      $$PlaceVisitsTableCreateCompanionBuilder,
      $$PlaceVisitsTableUpdateCompanionBuilder,
      (PlaceVisit, $$PlaceVisitsTableReferences),
      PlaceVisit,
      PrefetchHooks Function({bool placeKey})
    >;
typedef $$NewReferenceImagesTableCreateCompanionBuilder =
    NewReferenceImagesCompanion Function({
      required String id,
      Value<String?> placeKey,
      Value<String?> stopId,
      Value<String?> localPath,
      Value<String?> remoteUrl,
      Value<String?> animeLabelId,
      Value<String?> episode,
      Value<int?> timestampS,
      Value<String?> source,
      Value<String?> sourceUrl,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$NewReferenceImagesTableUpdateCompanionBuilder =
    NewReferenceImagesCompanion Function({
      Value<String> id,
      Value<String?> placeKey,
      Value<String?> stopId,
      Value<String?> localPath,
      Value<String?> remoteUrl,
      Value<String?> animeLabelId,
      Value<String?> episode,
      Value<int?> timestampS,
      Value<String?> source,
      Value<String?> sourceUrl,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$NewReferenceImagesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $NewReferenceImagesTable,
          NewReferenceImage
        > {
  $$NewReferenceImagesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PlacesTable _placeKeyTable(_$AppDatabase db) => db.places.createAlias(
    $_aliasNameGenerator(db.newReferenceImages.placeKey, db.places.placeKey),
  );

  $$PlacesTableProcessedTableManager? get placeKey {
    final $_column = $_itemColumn<String>('place_key');
    if ($_column == null) return null;
    final manager = $$PlacesTableTableManager(
      $_db,
      $_db.places,
    ).filter((f) => f.placeKey.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_placeKeyTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$NewReferenceImagesTableFilterComposer
    extends Composer<_$AppDatabase, $NewReferenceImagesTable> {
  $$NewReferenceImagesTableFilterComposer({
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

  ColumnFilters<String> get stopId => $composableBuilder(
    column: $table.stopId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteUrl => $composableBuilder(
    column: $table.remoteUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get animeLabelId => $composableBuilder(
    column: $table.animeLabelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get episode => $composableBuilder(
    column: $table.episode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timestampS => $composableBuilder(
    column: $table.timestampS,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$PlacesTableFilterComposer get placeKey {
    final $$PlacesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.placeKey,
      referencedTable: $db.places,
      getReferencedColumn: (t) => t.placeKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlacesTableFilterComposer(
            $db: $db,
            $table: $db.places,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NewReferenceImagesTableOrderingComposer
    extends Composer<_$AppDatabase, $NewReferenceImagesTable> {
  $$NewReferenceImagesTableOrderingComposer({
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

  ColumnOrderings<String> get stopId => $composableBuilder(
    column: $table.stopId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteUrl => $composableBuilder(
    column: $table.remoteUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get animeLabelId => $composableBuilder(
    column: $table.animeLabelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get episode => $composableBuilder(
    column: $table.episode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timestampS => $composableBuilder(
    column: $table.timestampS,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$PlacesTableOrderingComposer get placeKey {
    final $$PlacesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.placeKey,
      referencedTable: $db.places,
      getReferencedColumn: (t) => t.placeKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlacesTableOrderingComposer(
            $db: $db,
            $table: $db.places,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NewReferenceImagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $NewReferenceImagesTable> {
  $$NewReferenceImagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get stopId =>
      $composableBuilder(column: $table.stopId, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<String> get remoteUrl =>
      $composableBuilder(column: $table.remoteUrl, builder: (column) => column);

  GeneratedColumn<String> get animeLabelId => $composableBuilder(
    column: $table.animeLabelId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get episode =>
      $composableBuilder(column: $table.episode, builder: (column) => column);

  GeneratedColumn<int> get timestampS => $composableBuilder(
    column: $table.timestampS,
    builder: (column) => column,
  );

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get sourceUrl =>
      $composableBuilder(column: $table.sourceUrl, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$PlacesTableAnnotationComposer get placeKey {
    final $$PlacesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.placeKey,
      referencedTable: $db.places,
      getReferencedColumn: (t) => t.placeKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlacesTableAnnotationComposer(
            $db: $db,
            $table: $db.places,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NewReferenceImagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NewReferenceImagesTable,
          NewReferenceImage,
          $$NewReferenceImagesTableFilterComposer,
          $$NewReferenceImagesTableOrderingComposer,
          $$NewReferenceImagesTableAnnotationComposer,
          $$NewReferenceImagesTableCreateCompanionBuilder,
          $$NewReferenceImagesTableUpdateCompanionBuilder,
          (NewReferenceImage, $$NewReferenceImagesTableReferences),
          NewReferenceImage,
          PrefetchHooks Function({bool placeKey})
        > {
  $$NewReferenceImagesTableTableManager(
    _$AppDatabase db,
    $NewReferenceImagesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NewReferenceImagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NewReferenceImagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NewReferenceImagesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> placeKey = const Value.absent(),
                Value<String?> stopId = const Value.absent(),
                Value<String?> localPath = const Value.absent(),
                Value<String?> remoteUrl = const Value.absent(),
                Value<String?> animeLabelId = const Value.absent(),
                Value<String?> episode = const Value.absent(),
                Value<int?> timestampS = const Value.absent(),
                Value<String?> source = const Value.absent(),
                Value<String?> sourceUrl = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NewReferenceImagesCompanion(
                id: id,
                placeKey: placeKey,
                stopId: stopId,
                localPath: localPath,
                remoteUrl: remoteUrl,
                animeLabelId: animeLabelId,
                episode: episode,
                timestampS: timestampS,
                source: source,
                sourceUrl: sourceUrl,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> placeKey = const Value.absent(),
                Value<String?> stopId = const Value.absent(),
                Value<String?> localPath = const Value.absent(),
                Value<String?> remoteUrl = const Value.absent(),
                Value<String?> animeLabelId = const Value.absent(),
                Value<String?> episode = const Value.absent(),
                Value<int?> timestampS = const Value.absent(),
                Value<String?> source = const Value.absent(),
                Value<String?> sourceUrl = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NewReferenceImagesCompanion.insert(
                id: id,
                placeKey: placeKey,
                stopId: stopId,
                localPath: localPath,
                remoteUrl: remoteUrl,
                animeLabelId: animeLabelId,
                episode: episode,
                timestampS: timestampS,
                source: source,
                sourceUrl: sourceUrl,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$NewReferenceImagesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({placeKey = false}) {
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
                    if (placeKey) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.placeKey,
                                referencedTable:
                                    $$NewReferenceImagesTableReferences
                                        ._placeKeyTable(db),
                                referencedColumn:
                                    $$NewReferenceImagesTableReferences
                                        ._placeKeyTable(db)
                                        .placeKey,
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

typedef $$NewReferenceImagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NewReferenceImagesTable,
      NewReferenceImage,
      $$NewReferenceImagesTableFilterComposer,
      $$NewReferenceImagesTableOrderingComposer,
      $$NewReferenceImagesTableAnnotationComposer,
      $$NewReferenceImagesTableCreateCompanionBuilder,
      $$NewReferenceImagesTableUpdateCompanionBuilder,
      (NewReferenceImage, $$NewReferenceImagesTableReferences),
      NewReferenceImage,
      PrefetchHooks Function({bool placeKey})
    >;
typedef $$TripsTableCreateCompanionBuilder =
    TripsCompanion Function({
      required String id,
      required String title,
      Value<String?> description,
      required String ownerId,
      Value<String> sharing,
      Value<String?> startDate,
      Value<int> dayCount,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<String?> updatedBy,
      Value<DateTime?> deletedAt,
      Value<int> syncStatus,
      Value<int> rowid,
    });
typedef $$TripsTableUpdateCompanionBuilder =
    TripsCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String?> description,
      Value<String> ownerId,
      Value<String> sharing,
      Value<String?> startDate,
      Value<int> dayCount,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<String?> updatedBy,
      Value<DateTime?> deletedAt,
      Value<int> syncStatus,
      Value<int> rowid,
    });

final class $$TripsTableReferences
    extends BaseReferences<_$AppDatabase, $TripsTable, Trip> {
  $$TripsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TripDaysTable, List<TripDay>> _tripDaysRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.tripDays,
    aliasName: $_aliasNameGenerator(db.trips.id, db.tripDays.tripId),
  );

  $$TripDaysTableProcessedTableManager get tripDaysRefs {
    final manager = $$TripDaysTableTableManager(
      $_db,
      $_db.tripDays,
    ).filter((f) => f.tripId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_tripDaysRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$StopsTable, List<Stop>> _stopsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.stops,
    aliasName: $_aliasNameGenerator(db.trips.id, db.stops.tripId),
  );

  $$StopsTableProcessedTableManager get stopsRefs {
    final manager = $$StopsTableTableManager(
      $_db,
      $_db.stops,
    ).filter((f) => f.tripId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_stopsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ScheduleItemsTable, List<ScheduleItem>>
  _scheduleItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.scheduleItems,
    aliasName: $_aliasNameGenerator(db.trips.id, db.scheduleItems.tripId),
  );

  $$ScheduleItemsTableProcessedTableManager get scheduleItemsRefs {
    final manager = $$ScheduleItemsTableTableManager(
      $_db,
      $_db.scheduleItems,
    ).filter((f) => f.tripId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_scheduleItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TripsTableFilterComposer extends Composer<_$AppDatabase, $TripsTable> {
  $$TripsTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sharing => $composableBuilder(
    column: $table.sharing,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dayCount => $composableBuilder(
    column: $table.dayCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get updatedAt =>
      $composableBuilder(
        column: $table.updatedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get updatedBy => $composableBuilder(
    column: $table.updatedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, int> get deletedAt =>
      $composableBuilder(
        column: $table.deletedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> tripDaysRefs(
    Expression<bool> Function($$TripDaysTableFilterComposer f) f,
  ) {
    final $$TripDaysTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tripDays,
      getReferencedColumn: (t) => t.tripId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripDaysTableFilterComposer(
            $db: $db,
            $table: $db.tripDays,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> stopsRefs(
    Expression<bool> Function($$StopsTableFilterComposer f) f,
  ) {
    final $$StopsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.stops,
      getReferencedColumn: (t) => t.tripId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StopsTableFilterComposer(
            $db: $db,
            $table: $db.stops,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> scheduleItemsRefs(
    Expression<bool> Function($$ScheduleItemsTableFilterComposer f) f,
  ) {
    final $$ScheduleItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.scheduleItems,
      getReferencedColumn: (t) => t.tripId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScheduleItemsTableFilterComposer(
            $db: $db,
            $table: $db.scheduleItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TripsTableOrderingComposer
    extends Composer<_$AppDatabase, $TripsTable> {
  $$TripsTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sharing => $composableBuilder(
    column: $table.sharing,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dayCount => $composableBuilder(
    column: $table.dayCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedBy => $composableBuilder(
    column: $table.updatedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TripsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TripsTable> {
  $$TripsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<String> get sharing =>
      $composableBuilder(column: $table.sharing, builder: (column) => column);

  GeneratedColumn<String> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<int> get dayCount =>
      $composableBuilder(column: $table.dayCount, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get updatedBy =>
      $composableBuilder(column: $table.updatedBy, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime?, int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  Expression<T> tripDaysRefs<T extends Object>(
    Expression<T> Function($$TripDaysTableAnnotationComposer a) f,
  ) {
    final $$TripDaysTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tripDays,
      getReferencedColumn: (t) => t.tripId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripDaysTableAnnotationComposer(
            $db: $db,
            $table: $db.tripDays,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> stopsRefs<T extends Object>(
    Expression<T> Function($$StopsTableAnnotationComposer a) f,
  ) {
    final $$StopsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.stops,
      getReferencedColumn: (t) => t.tripId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StopsTableAnnotationComposer(
            $db: $db,
            $table: $db.stops,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> scheduleItemsRefs<T extends Object>(
    Expression<T> Function($$ScheduleItemsTableAnnotationComposer a) f,
  ) {
    final $$ScheduleItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.scheduleItems,
      getReferencedColumn: (t) => t.tripId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScheduleItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.scheduleItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TripsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TripsTable,
          Trip,
          $$TripsTableFilterComposer,
          $$TripsTableOrderingComposer,
          $$TripsTableAnnotationComposer,
          $$TripsTableCreateCompanionBuilder,
          $$TripsTableUpdateCompanionBuilder,
          (Trip, $$TripsTableReferences),
          Trip,
          PrefetchHooks Function({
            bool tripDaysRefs,
            bool stopsRefs,
            bool scheduleItemsRefs,
          })
        > {
  $$TripsTableTableManager(_$AppDatabase db, $TripsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TripsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TripsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TripsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String> ownerId = const Value.absent(),
                Value<String> sharing = const Value.absent(),
                Value<String?> startDate = const Value.absent(),
                Value<int> dayCount = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String?> updatedBy = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TripsCompanion(
                id: id,
                title: title,
                description: description,
                ownerId: ownerId,
                sharing: sharing,
                startDate: startDate,
                dayCount: dayCount,
                createdAt: createdAt,
                updatedAt: updatedAt,
                updatedBy: updatedBy,
                deletedAt: deletedAt,
                syncStatus: syncStatus,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                Value<String?> description = const Value.absent(),
                required String ownerId,
                Value<String> sharing = const Value.absent(),
                Value<String?> startDate = const Value.absent(),
                Value<int> dayCount = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String?> updatedBy = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TripsCompanion.insert(
                id: id,
                title: title,
                description: description,
                ownerId: ownerId,
                sharing: sharing,
                startDate: startDate,
                dayCount: dayCount,
                createdAt: createdAt,
                updatedAt: updatedAt,
                updatedBy: updatedBy,
                deletedAt: deletedAt,
                syncStatus: syncStatus,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$TripsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                tripDaysRefs = false,
                stopsRefs = false,
                scheduleItemsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (tripDaysRefs) db.tripDays,
                    if (stopsRefs) db.stops,
                    if (scheduleItemsRefs) db.scheduleItems,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (tripDaysRefs)
                        await $_getPrefetchedData<Trip, $TripsTable, TripDay>(
                          currentTable: table,
                          referencedTable: $$TripsTableReferences
                              ._tripDaysRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TripsTableReferences(
                                db,
                                table,
                                p0,
                              ).tripDaysRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.tripId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (stopsRefs)
                        await $_getPrefetchedData<Trip, $TripsTable, Stop>(
                          currentTable: table,
                          referencedTable: $$TripsTableReferences
                              ._stopsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TripsTableReferences(db, table, p0).stopsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.tripId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (scheduleItemsRefs)
                        await $_getPrefetchedData<
                          Trip,
                          $TripsTable,
                          ScheduleItem
                        >(
                          currentTable: table,
                          referencedTable: $$TripsTableReferences
                              ._scheduleItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TripsTableReferences(
                                db,
                                table,
                                p0,
                              ).scheduleItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.tripId == item.id,
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

typedef $$TripsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TripsTable,
      Trip,
      $$TripsTableFilterComposer,
      $$TripsTableOrderingComposer,
      $$TripsTableAnnotationComposer,
      $$TripsTableCreateCompanionBuilder,
      $$TripsTableUpdateCompanionBuilder,
      (Trip, $$TripsTableReferences),
      Trip,
      PrefetchHooks Function({
        bool tripDaysRefs,
        bool stopsRefs,
        bool scheduleItemsRefs,
      })
    >;
typedef $$TripDaysTableCreateCompanionBuilder =
    TripDaysCompanion Function({
      required String id,
      required String tripId,
      required String sortKey,
      Value<String?> title,
      Value<String?> pinnedDate,
      Value<DateTime> updatedAt,
      Value<String?> updatedBy,
      Value<DateTime?> deletedAt,
      Value<int> syncStatus,
      Value<int> rowid,
    });
typedef $$TripDaysTableUpdateCompanionBuilder =
    TripDaysCompanion Function({
      Value<String> id,
      Value<String> tripId,
      Value<String> sortKey,
      Value<String?> title,
      Value<String?> pinnedDate,
      Value<DateTime> updatedAt,
      Value<String?> updatedBy,
      Value<DateTime?> deletedAt,
      Value<int> syncStatus,
      Value<int> rowid,
    });

final class $$TripDaysTableReferences
    extends BaseReferences<_$AppDatabase, $TripDaysTable, TripDay> {
  $$TripDaysTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TripsTable _tripIdTable(_$AppDatabase db) => db.trips.createAlias(
    $_aliasNameGenerator(db.tripDays.tripId, db.trips.id),
  );

  $$TripsTableProcessedTableManager get tripId {
    final $_column = $_itemColumn<String>('trip_id')!;

    final manager = $$TripsTableTableManager(
      $_db,
      $_db.trips,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tripIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ScheduleItemsTable, List<ScheduleItem>>
  _scheduleItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.scheduleItems,
    aliasName: $_aliasNameGenerator(db.tripDays.id, db.scheduleItems.dayId),
  );

  $$ScheduleItemsTableProcessedTableManager get scheduleItemsRefs {
    final manager = $$ScheduleItemsTableTableManager(
      $_db,
      $_db.scheduleItems,
    ).filter((f) => f.dayId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_scheduleItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TripDaysTableFilterComposer
    extends Composer<_$AppDatabase, $TripDaysTable> {
  $$TripDaysTableFilterComposer({
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

  ColumnFilters<String> get sortKey => $composableBuilder(
    column: $table.sortKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pinnedDate => $composableBuilder(
    column: $table.pinnedDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get updatedAt =>
      $composableBuilder(
        column: $table.updatedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get updatedBy => $composableBuilder(
    column: $table.updatedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, int> get deletedAt =>
      $composableBuilder(
        column: $table.deletedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  $$TripsTableFilterComposer get tripId {
    final $$TripsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tripId,
      referencedTable: $db.trips,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripsTableFilterComposer(
            $db: $db,
            $table: $db.trips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> scheduleItemsRefs(
    Expression<bool> Function($$ScheduleItemsTableFilterComposer f) f,
  ) {
    final $$ScheduleItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.scheduleItems,
      getReferencedColumn: (t) => t.dayId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScheduleItemsTableFilterComposer(
            $db: $db,
            $table: $db.scheduleItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TripDaysTableOrderingComposer
    extends Composer<_$AppDatabase, $TripDaysTable> {
  $$TripDaysTableOrderingComposer({
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

  ColumnOrderings<String> get sortKey => $composableBuilder(
    column: $table.sortKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pinnedDate => $composableBuilder(
    column: $table.pinnedDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedBy => $composableBuilder(
    column: $table.updatedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  $$TripsTableOrderingComposer get tripId {
    final $$TripsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tripId,
      referencedTable: $db.trips,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripsTableOrderingComposer(
            $db: $db,
            $table: $db.trips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TripDaysTableAnnotationComposer
    extends Composer<_$AppDatabase, $TripDaysTable> {
  $$TripDaysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sortKey =>
      $composableBuilder(column: $table.sortKey, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get pinnedDate => $composableBuilder(
    column: $table.pinnedDate,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DateTime, int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get updatedBy =>
      $composableBuilder(column: $table.updatedBy, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime?, int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  $$TripsTableAnnotationComposer get tripId {
    final $$TripsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tripId,
      referencedTable: $db.trips,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripsTableAnnotationComposer(
            $db: $db,
            $table: $db.trips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> scheduleItemsRefs<T extends Object>(
    Expression<T> Function($$ScheduleItemsTableAnnotationComposer a) f,
  ) {
    final $$ScheduleItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.scheduleItems,
      getReferencedColumn: (t) => t.dayId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScheduleItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.scheduleItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TripDaysTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TripDaysTable,
          TripDay,
          $$TripDaysTableFilterComposer,
          $$TripDaysTableOrderingComposer,
          $$TripDaysTableAnnotationComposer,
          $$TripDaysTableCreateCompanionBuilder,
          $$TripDaysTableUpdateCompanionBuilder,
          (TripDay, $$TripDaysTableReferences),
          TripDay,
          PrefetchHooks Function({bool tripId, bool scheduleItemsRefs})
        > {
  $$TripDaysTableTableManager(_$AppDatabase db, $TripDaysTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TripDaysTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TripDaysTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TripDaysTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tripId = const Value.absent(),
                Value<String> sortKey = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> pinnedDate = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String?> updatedBy = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TripDaysCompanion(
                id: id,
                tripId: tripId,
                sortKey: sortKey,
                title: title,
                pinnedDate: pinnedDate,
                updatedAt: updatedAt,
                updatedBy: updatedBy,
                deletedAt: deletedAt,
                syncStatus: syncStatus,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tripId,
                required String sortKey,
                Value<String?> title = const Value.absent(),
                Value<String?> pinnedDate = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String?> updatedBy = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TripDaysCompanion.insert(
                id: id,
                tripId: tripId,
                sortKey: sortKey,
                title: title,
                pinnedDate: pinnedDate,
                updatedAt: updatedAt,
                updatedBy: updatedBy,
                deletedAt: deletedAt,
                syncStatus: syncStatus,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TripDaysTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({tripId = false, scheduleItemsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (scheduleItemsRefs) db.scheduleItems,
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
                    if (tripId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.tripId,
                                referencedTable: $$TripDaysTableReferences
                                    ._tripIdTable(db),
                                referencedColumn: $$TripDaysTableReferences
                                    ._tripIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (scheduleItemsRefs)
                    await $_getPrefetchedData<
                      TripDay,
                      $TripDaysTable,
                      ScheduleItem
                    >(
                      currentTable: table,
                      referencedTable: $$TripDaysTableReferences
                          ._scheduleItemsRefsTable(db),
                      managerFromTypedResult: (p0) => $$TripDaysTableReferences(
                        db,
                        table,
                        p0,
                      ).scheduleItemsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.dayId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$TripDaysTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TripDaysTable,
      TripDay,
      $$TripDaysTableFilterComposer,
      $$TripDaysTableOrderingComposer,
      $$TripDaysTableAnnotationComposer,
      $$TripDaysTableCreateCompanionBuilder,
      $$TripDaysTableUpdateCompanionBuilder,
      (TripDay, $$TripDaysTableReferences),
      TripDay,
      PrefetchHooks Function({bool tripId, bool scheduleItemsRefs})
    >;
typedef $$StopsTableCreateCompanionBuilder =
    StopsCompanion Function({
      required String id,
      required String tripId,
      required String placeKey,
      required String name,
      required double lat,
      required double lng,
      Value<String?> description,
      Value<String?> address,
      Value<String?> businessHours,
      Value<String?> contactInfo,
      Value<String?> accessTips,
      Value<String?> links,
      Value<String?> coverLocalPath,
      Value<String?> coverRemoteUrl,
      Value<String?> source,
      Value<String?> sourceUrl,
      Value<String?> area,
      Value<String?> note,
      required String addedBy,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<String?> updatedBy,
      Value<DateTime?> deletedAt,
      Value<int> syncStatus,
      Value<int> rowid,
    });
typedef $$StopsTableUpdateCompanionBuilder =
    StopsCompanion Function({
      Value<String> id,
      Value<String> tripId,
      Value<String> placeKey,
      Value<String> name,
      Value<double> lat,
      Value<double> lng,
      Value<String?> description,
      Value<String?> address,
      Value<String?> businessHours,
      Value<String?> contactInfo,
      Value<String?> accessTips,
      Value<String?> links,
      Value<String?> coverLocalPath,
      Value<String?> coverRemoteUrl,
      Value<String?> source,
      Value<String?> sourceUrl,
      Value<String?> area,
      Value<String?> note,
      Value<String> addedBy,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<String?> updatedBy,
      Value<DateTime?> deletedAt,
      Value<int> syncStatus,
      Value<int> rowid,
    });

final class $$StopsTableReferences
    extends BaseReferences<_$AppDatabase, $StopsTable, Stop> {
  $$StopsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TripsTable _tripIdTable(_$AppDatabase db) =>
      db.trips.createAlias($_aliasNameGenerator(db.stops.tripId, db.trips.id));

  $$TripsTableProcessedTableManager get tripId {
    final $_column = $_itemColumn<String>('trip_id')!;

    final manager = $$TripsTableTableManager(
      $_db,
      $_db.trips,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tripIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$StopLabelsTable, List<StopLabel>>
  _stopLabelsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.stopLabels,
    aliasName: $_aliasNameGenerator(db.stops.id, db.stopLabels.stopId),
  );

  $$StopLabelsTableProcessedTableManager get stopLabelsRefs {
    final manager = $$StopLabelsTableTableManager(
      $_db,
      $_db.stopLabels,
    ).filter((f) => f.stopId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_stopLabelsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ScheduleItemsTable, List<ScheduleItem>>
  _scheduleItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.scheduleItems,
    aliasName: $_aliasNameGenerator(db.stops.id, db.scheduleItems.stopId),
  );

  $$ScheduleItemsTableProcessedTableManager get scheduleItemsRefs {
    final manager = $$ScheduleItemsTableTableManager(
      $_db,
      $_db.scheduleItems,
    ).filter((f) => f.stopId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_scheduleItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$StopsTableFilterComposer extends Composer<_$AppDatabase, $StopsTable> {
  $$StopsTableFilterComposer({
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

  ColumnFilters<String> get placeKey => $composableBuilder(
    column: $table.placeKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lng => $composableBuilder(
    column: $table.lng,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get businessHours => $composableBuilder(
    column: $table.businessHours,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contactInfo => $composableBuilder(
    column: $table.contactInfo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accessTips => $composableBuilder(
    column: $table.accessTips,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get links => $composableBuilder(
    column: $table.links,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverLocalPath => $composableBuilder(
    column: $table.coverLocalPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverRemoteUrl => $composableBuilder(
    column: $table.coverRemoteUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get area => $composableBuilder(
    column: $table.area,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get addedBy => $composableBuilder(
    column: $table.addedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get updatedAt =>
      $composableBuilder(
        column: $table.updatedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get updatedBy => $composableBuilder(
    column: $table.updatedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, int> get deletedAt =>
      $composableBuilder(
        column: $table.deletedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  $$TripsTableFilterComposer get tripId {
    final $$TripsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tripId,
      referencedTable: $db.trips,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripsTableFilterComposer(
            $db: $db,
            $table: $db.trips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> stopLabelsRefs(
    Expression<bool> Function($$StopLabelsTableFilterComposer f) f,
  ) {
    final $$StopLabelsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.stopLabels,
      getReferencedColumn: (t) => t.stopId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StopLabelsTableFilterComposer(
            $db: $db,
            $table: $db.stopLabels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> scheduleItemsRefs(
    Expression<bool> Function($$ScheduleItemsTableFilterComposer f) f,
  ) {
    final $$ScheduleItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.scheduleItems,
      getReferencedColumn: (t) => t.stopId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScheduleItemsTableFilterComposer(
            $db: $db,
            $table: $db.scheduleItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$StopsTableOrderingComposer
    extends Composer<_$AppDatabase, $StopsTable> {
  $$StopsTableOrderingComposer({
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

  ColumnOrderings<String> get placeKey => $composableBuilder(
    column: $table.placeKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lng => $composableBuilder(
    column: $table.lng,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get businessHours => $composableBuilder(
    column: $table.businessHours,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contactInfo => $composableBuilder(
    column: $table.contactInfo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accessTips => $composableBuilder(
    column: $table.accessTips,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get links => $composableBuilder(
    column: $table.links,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverLocalPath => $composableBuilder(
    column: $table.coverLocalPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverRemoteUrl => $composableBuilder(
    column: $table.coverRemoteUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get area => $composableBuilder(
    column: $table.area,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get addedBy => $composableBuilder(
    column: $table.addedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedBy => $composableBuilder(
    column: $table.updatedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  $$TripsTableOrderingComposer get tripId {
    final $$TripsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tripId,
      referencedTable: $db.trips,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripsTableOrderingComposer(
            $db: $db,
            $table: $db.trips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StopsTableAnnotationComposer
    extends Composer<_$AppDatabase, $StopsTable> {
  $$StopsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get placeKey =>
      $composableBuilder(column: $table.placeKey, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get lat =>
      $composableBuilder(column: $table.lat, builder: (column) => column);

  GeneratedColumn<double> get lng =>
      $composableBuilder(column: $table.lng, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<String> get businessHours => $composableBuilder(
    column: $table.businessHours,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contactInfo => $composableBuilder(
    column: $table.contactInfo,
    builder: (column) => column,
  );

  GeneratedColumn<String> get accessTips => $composableBuilder(
    column: $table.accessTips,
    builder: (column) => column,
  );

  GeneratedColumn<String> get links =>
      $composableBuilder(column: $table.links, builder: (column) => column);

  GeneratedColumn<String> get coverLocalPath => $composableBuilder(
    column: $table.coverLocalPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get coverRemoteUrl => $composableBuilder(
    column: $table.coverRemoteUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get sourceUrl =>
      $composableBuilder(column: $table.sourceUrl, builder: (column) => column);

  GeneratedColumn<String> get area =>
      $composableBuilder(column: $table.area, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get addedBy =>
      $composableBuilder(column: $table.addedBy, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get updatedBy =>
      $composableBuilder(column: $table.updatedBy, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime?, int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  $$TripsTableAnnotationComposer get tripId {
    final $$TripsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tripId,
      referencedTable: $db.trips,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripsTableAnnotationComposer(
            $db: $db,
            $table: $db.trips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> stopLabelsRefs<T extends Object>(
    Expression<T> Function($$StopLabelsTableAnnotationComposer a) f,
  ) {
    final $$StopLabelsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.stopLabels,
      getReferencedColumn: (t) => t.stopId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StopLabelsTableAnnotationComposer(
            $db: $db,
            $table: $db.stopLabels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> scheduleItemsRefs<T extends Object>(
    Expression<T> Function($$ScheduleItemsTableAnnotationComposer a) f,
  ) {
    final $$ScheduleItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.scheduleItems,
      getReferencedColumn: (t) => t.stopId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScheduleItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.scheduleItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$StopsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StopsTable,
          Stop,
          $$StopsTableFilterComposer,
          $$StopsTableOrderingComposer,
          $$StopsTableAnnotationComposer,
          $$StopsTableCreateCompanionBuilder,
          $$StopsTableUpdateCompanionBuilder,
          (Stop, $$StopsTableReferences),
          Stop,
          PrefetchHooks Function({
            bool tripId,
            bool stopLabelsRefs,
            bool scheduleItemsRefs,
          })
        > {
  $$StopsTableTableManager(_$AppDatabase db, $StopsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StopsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StopsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StopsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tripId = const Value.absent(),
                Value<String> placeKey = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double> lat = const Value.absent(),
                Value<double> lng = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> address = const Value.absent(),
                Value<String?> businessHours = const Value.absent(),
                Value<String?> contactInfo = const Value.absent(),
                Value<String?> accessTips = const Value.absent(),
                Value<String?> links = const Value.absent(),
                Value<String?> coverLocalPath = const Value.absent(),
                Value<String?> coverRemoteUrl = const Value.absent(),
                Value<String?> source = const Value.absent(),
                Value<String?> sourceUrl = const Value.absent(),
                Value<String?> area = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String> addedBy = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String?> updatedBy = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StopsCompanion(
                id: id,
                tripId: tripId,
                placeKey: placeKey,
                name: name,
                lat: lat,
                lng: lng,
                description: description,
                address: address,
                businessHours: businessHours,
                contactInfo: contactInfo,
                accessTips: accessTips,
                links: links,
                coverLocalPath: coverLocalPath,
                coverRemoteUrl: coverRemoteUrl,
                source: source,
                sourceUrl: sourceUrl,
                area: area,
                note: note,
                addedBy: addedBy,
                createdAt: createdAt,
                updatedAt: updatedAt,
                updatedBy: updatedBy,
                deletedAt: deletedAt,
                syncStatus: syncStatus,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tripId,
                required String placeKey,
                required String name,
                required double lat,
                required double lng,
                Value<String?> description = const Value.absent(),
                Value<String?> address = const Value.absent(),
                Value<String?> businessHours = const Value.absent(),
                Value<String?> contactInfo = const Value.absent(),
                Value<String?> accessTips = const Value.absent(),
                Value<String?> links = const Value.absent(),
                Value<String?> coverLocalPath = const Value.absent(),
                Value<String?> coverRemoteUrl = const Value.absent(),
                Value<String?> source = const Value.absent(),
                Value<String?> sourceUrl = const Value.absent(),
                Value<String?> area = const Value.absent(),
                Value<String?> note = const Value.absent(),
                required String addedBy,
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String?> updatedBy = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StopsCompanion.insert(
                id: id,
                tripId: tripId,
                placeKey: placeKey,
                name: name,
                lat: lat,
                lng: lng,
                description: description,
                address: address,
                businessHours: businessHours,
                contactInfo: contactInfo,
                accessTips: accessTips,
                links: links,
                coverLocalPath: coverLocalPath,
                coverRemoteUrl: coverRemoteUrl,
                source: source,
                sourceUrl: sourceUrl,
                area: area,
                note: note,
                addedBy: addedBy,
                createdAt: createdAt,
                updatedAt: updatedAt,
                updatedBy: updatedBy,
                deletedAt: deletedAt,
                syncStatus: syncStatus,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$StopsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                tripId = false,
                stopLabelsRefs = false,
                scheduleItemsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (stopLabelsRefs) db.stopLabels,
                    if (scheduleItemsRefs) db.scheduleItems,
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
                        if (tripId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.tripId,
                                    referencedTable: $$StopsTableReferences
                                        ._tripIdTable(db),
                                    referencedColumn: $$StopsTableReferences
                                        ._tripIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (stopLabelsRefs)
                        await $_getPrefetchedData<Stop, $StopsTable, StopLabel>(
                          currentTable: table,
                          referencedTable: $$StopsTableReferences
                              ._stopLabelsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$StopsTableReferences(
                                db,
                                table,
                                p0,
                              ).stopLabelsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.stopId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (scheduleItemsRefs)
                        await $_getPrefetchedData<
                          Stop,
                          $StopsTable,
                          ScheduleItem
                        >(
                          currentTable: table,
                          referencedTable: $$StopsTableReferences
                              ._scheduleItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$StopsTableReferences(
                                db,
                                table,
                                p0,
                              ).scheduleItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.stopId == item.id,
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

typedef $$StopsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StopsTable,
      Stop,
      $$StopsTableFilterComposer,
      $$StopsTableOrderingComposer,
      $$StopsTableAnnotationComposer,
      $$StopsTableCreateCompanionBuilder,
      $$StopsTableUpdateCompanionBuilder,
      (Stop, $$StopsTableReferences),
      Stop,
      PrefetchHooks Function({
        bool tripId,
        bool stopLabelsRefs,
        bool scheduleItemsRefs,
      })
    >;
typedef $$StopLabelsTableCreateCompanionBuilder =
    StopLabelsCompanion Function({
      required String stopId,
      required String labelId,
      Value<int> rowid,
    });
typedef $$StopLabelsTableUpdateCompanionBuilder =
    StopLabelsCompanion Function({
      Value<String> stopId,
      Value<String> labelId,
      Value<int> rowid,
    });

final class $$StopLabelsTableReferences
    extends BaseReferences<_$AppDatabase, $StopLabelsTable, StopLabel> {
  $$StopLabelsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $StopsTable _stopIdTable(_$AppDatabase db) => db.stops.createAlias(
    $_aliasNameGenerator(db.stopLabels.stopId, db.stops.id),
  );

  $$StopsTableProcessedTableManager get stopId {
    final $_column = $_itemColumn<String>('stop_id')!;

    final manager = $$StopsTableTableManager(
      $_db,
      $_db.stops,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_stopIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $LabelsTable _labelIdTable(_$AppDatabase db) => db.labels.createAlias(
    $_aliasNameGenerator(db.stopLabels.labelId, db.labels.id),
  );

  $$LabelsTableProcessedTableManager get labelId {
    final $_column = $_itemColumn<String>('label_id')!;

    final manager = $$LabelsTableTableManager(
      $_db,
      $_db.labels,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_labelIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$StopLabelsTableFilterComposer
    extends Composer<_$AppDatabase, $StopLabelsTable> {
  $$StopLabelsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$StopsTableFilterComposer get stopId {
    final $$StopsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.stopId,
      referencedTable: $db.stops,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StopsTableFilterComposer(
            $db: $db,
            $table: $db.stops,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LabelsTableFilterComposer get labelId {
    final $$LabelsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.labelId,
      referencedTable: $db.labels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LabelsTableFilterComposer(
            $db: $db,
            $table: $db.labels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StopLabelsTableOrderingComposer
    extends Composer<_$AppDatabase, $StopLabelsTable> {
  $$StopLabelsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$StopsTableOrderingComposer get stopId {
    final $$StopsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.stopId,
      referencedTable: $db.stops,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StopsTableOrderingComposer(
            $db: $db,
            $table: $db.stops,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LabelsTableOrderingComposer get labelId {
    final $$LabelsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.labelId,
      referencedTable: $db.labels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LabelsTableOrderingComposer(
            $db: $db,
            $table: $db.labels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StopLabelsTableAnnotationComposer
    extends Composer<_$AppDatabase, $StopLabelsTable> {
  $$StopLabelsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$StopsTableAnnotationComposer get stopId {
    final $$StopsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.stopId,
      referencedTable: $db.stops,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StopsTableAnnotationComposer(
            $db: $db,
            $table: $db.stops,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LabelsTableAnnotationComposer get labelId {
    final $$LabelsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.labelId,
      referencedTable: $db.labels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LabelsTableAnnotationComposer(
            $db: $db,
            $table: $db.labels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StopLabelsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StopLabelsTable,
          StopLabel,
          $$StopLabelsTableFilterComposer,
          $$StopLabelsTableOrderingComposer,
          $$StopLabelsTableAnnotationComposer,
          $$StopLabelsTableCreateCompanionBuilder,
          $$StopLabelsTableUpdateCompanionBuilder,
          (StopLabel, $$StopLabelsTableReferences),
          StopLabel,
          PrefetchHooks Function({bool stopId, bool labelId})
        > {
  $$StopLabelsTableTableManager(_$AppDatabase db, $StopLabelsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StopLabelsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StopLabelsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StopLabelsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> stopId = const Value.absent(),
                Value<String> labelId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StopLabelsCompanion(
                stopId: stopId,
                labelId: labelId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String stopId,
                required String labelId,
                Value<int> rowid = const Value.absent(),
              }) => StopLabelsCompanion.insert(
                stopId: stopId,
                labelId: labelId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$StopLabelsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({stopId = false, labelId = false}) {
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
                    if (stopId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.stopId,
                                referencedTable: $$StopLabelsTableReferences
                                    ._stopIdTable(db),
                                referencedColumn: $$StopLabelsTableReferences
                                    ._stopIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (labelId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.labelId,
                                referencedTable: $$StopLabelsTableReferences
                                    ._labelIdTable(db),
                                referencedColumn: $$StopLabelsTableReferences
                                    ._labelIdTable(db)
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

typedef $$StopLabelsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StopLabelsTable,
      StopLabel,
      $$StopLabelsTableFilterComposer,
      $$StopLabelsTableOrderingComposer,
      $$StopLabelsTableAnnotationComposer,
      $$StopLabelsTableCreateCompanionBuilder,
      $$StopLabelsTableUpdateCompanionBuilder,
      (StopLabel, $$StopLabelsTableReferences),
      StopLabel,
      PrefetchHooks Function({bool stopId, bool labelId})
    >;
typedef $$ScheduleItemsTableCreateCompanionBuilder =
    ScheduleItemsCompanion Function({
      required String id,
      required String tripId,
      required String stopId,
      required String dayId,
      required String sortKey,
      Value<int> stayMinutes,
      Value<int> transitMinutes,
      Value<int?> fixedTime,
      Value<String> status,
      Value<DateTime> updatedAt,
      Value<String?> updatedBy,
      Value<DateTime?> deletedAt,
      Value<int> syncStatus,
      Value<int> rowid,
    });
typedef $$ScheduleItemsTableUpdateCompanionBuilder =
    ScheduleItemsCompanion Function({
      Value<String> id,
      Value<String> tripId,
      Value<String> stopId,
      Value<String> dayId,
      Value<String> sortKey,
      Value<int> stayMinutes,
      Value<int> transitMinutes,
      Value<int?> fixedTime,
      Value<String> status,
      Value<DateTime> updatedAt,
      Value<String?> updatedBy,
      Value<DateTime?> deletedAt,
      Value<int> syncStatus,
      Value<int> rowid,
    });

final class $$ScheduleItemsTableReferences
    extends BaseReferences<_$AppDatabase, $ScheduleItemsTable, ScheduleItem> {
  $$ScheduleItemsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TripsTable _tripIdTable(_$AppDatabase db) => db.trips.createAlias(
    $_aliasNameGenerator(db.scheduleItems.tripId, db.trips.id),
  );

  $$TripsTableProcessedTableManager get tripId {
    final $_column = $_itemColumn<String>('trip_id')!;

    final manager = $$TripsTableTableManager(
      $_db,
      $_db.trips,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tripIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $StopsTable _stopIdTable(_$AppDatabase db) => db.stops.createAlias(
    $_aliasNameGenerator(db.scheduleItems.stopId, db.stops.id),
  );

  $$StopsTableProcessedTableManager get stopId {
    final $_column = $_itemColumn<String>('stop_id')!;

    final manager = $$StopsTableTableManager(
      $_db,
      $_db.stops,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_stopIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TripDaysTable _dayIdTable(_$AppDatabase db) =>
      db.tripDays.createAlias(
        $_aliasNameGenerator(db.scheduleItems.dayId, db.tripDays.id),
      );

  $$TripDaysTableProcessedTableManager get dayId {
    final $_column = $_itemColumn<String>('day_id')!;

    final manager = $$TripDaysTableTableManager(
      $_db,
      $_db.tripDays,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_dayIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ScheduleItemsTableFilterComposer
    extends Composer<_$AppDatabase, $ScheduleItemsTable> {
  $$ScheduleItemsTableFilterComposer({
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

  ColumnFilters<String> get sortKey => $composableBuilder(
    column: $table.sortKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get stayMinutes => $composableBuilder(
    column: $table.stayMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get transitMinutes => $composableBuilder(
    column: $table.transitMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fixedTime => $composableBuilder(
    column: $table.fixedTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get updatedAt =>
      $composableBuilder(
        column: $table.updatedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get updatedBy => $composableBuilder(
    column: $table.updatedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, int> get deletedAt =>
      $composableBuilder(
        column: $table.deletedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  $$TripsTableFilterComposer get tripId {
    final $$TripsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tripId,
      referencedTable: $db.trips,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripsTableFilterComposer(
            $db: $db,
            $table: $db.trips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$StopsTableFilterComposer get stopId {
    final $$StopsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.stopId,
      referencedTable: $db.stops,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StopsTableFilterComposer(
            $db: $db,
            $table: $db.stops,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TripDaysTableFilterComposer get dayId {
    final $$TripDaysTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.dayId,
      referencedTable: $db.tripDays,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripDaysTableFilterComposer(
            $db: $db,
            $table: $db.tripDays,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ScheduleItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $ScheduleItemsTable> {
  $$ScheduleItemsTableOrderingComposer({
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

  ColumnOrderings<String> get sortKey => $composableBuilder(
    column: $table.sortKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get stayMinutes => $composableBuilder(
    column: $table.stayMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get transitMinutes => $composableBuilder(
    column: $table.transitMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fixedTime => $composableBuilder(
    column: $table.fixedTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedBy => $composableBuilder(
    column: $table.updatedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  $$TripsTableOrderingComposer get tripId {
    final $$TripsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tripId,
      referencedTable: $db.trips,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripsTableOrderingComposer(
            $db: $db,
            $table: $db.trips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$StopsTableOrderingComposer get stopId {
    final $$StopsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.stopId,
      referencedTable: $db.stops,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StopsTableOrderingComposer(
            $db: $db,
            $table: $db.stops,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TripDaysTableOrderingComposer get dayId {
    final $$TripDaysTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.dayId,
      referencedTable: $db.tripDays,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripDaysTableOrderingComposer(
            $db: $db,
            $table: $db.tripDays,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ScheduleItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ScheduleItemsTable> {
  $$ScheduleItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sortKey =>
      $composableBuilder(column: $table.sortKey, builder: (column) => column);

  GeneratedColumn<int> get stayMinutes => $composableBuilder(
    column: $table.stayMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get transitMinutes => $composableBuilder(
    column: $table.transitMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get fixedTime =>
      $composableBuilder(column: $table.fixedTime, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get updatedBy =>
      $composableBuilder(column: $table.updatedBy, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime?, int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  $$TripsTableAnnotationComposer get tripId {
    final $$TripsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tripId,
      referencedTable: $db.trips,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripsTableAnnotationComposer(
            $db: $db,
            $table: $db.trips,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$StopsTableAnnotationComposer get stopId {
    final $$StopsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.stopId,
      referencedTable: $db.stops,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StopsTableAnnotationComposer(
            $db: $db,
            $table: $db.stops,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TripDaysTableAnnotationComposer get dayId {
    final $$TripDaysTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.dayId,
      referencedTable: $db.tripDays,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripDaysTableAnnotationComposer(
            $db: $db,
            $table: $db.tripDays,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ScheduleItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ScheduleItemsTable,
          ScheduleItem,
          $$ScheduleItemsTableFilterComposer,
          $$ScheduleItemsTableOrderingComposer,
          $$ScheduleItemsTableAnnotationComposer,
          $$ScheduleItemsTableCreateCompanionBuilder,
          $$ScheduleItemsTableUpdateCompanionBuilder,
          (ScheduleItem, $$ScheduleItemsTableReferences),
          ScheduleItem,
          PrefetchHooks Function({bool tripId, bool stopId, bool dayId})
        > {
  $$ScheduleItemsTableTableManager(_$AppDatabase db, $ScheduleItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScheduleItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ScheduleItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ScheduleItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tripId = const Value.absent(),
                Value<String> stopId = const Value.absent(),
                Value<String> dayId = const Value.absent(),
                Value<String> sortKey = const Value.absent(),
                Value<int> stayMinutes = const Value.absent(),
                Value<int> transitMinutes = const Value.absent(),
                Value<int?> fixedTime = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String?> updatedBy = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ScheduleItemsCompanion(
                id: id,
                tripId: tripId,
                stopId: stopId,
                dayId: dayId,
                sortKey: sortKey,
                stayMinutes: stayMinutes,
                transitMinutes: transitMinutes,
                fixedTime: fixedTime,
                status: status,
                updatedAt: updatedAt,
                updatedBy: updatedBy,
                deletedAt: deletedAt,
                syncStatus: syncStatus,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tripId,
                required String stopId,
                required String dayId,
                required String sortKey,
                Value<int> stayMinutes = const Value.absent(),
                Value<int> transitMinutes = const Value.absent(),
                Value<int?> fixedTime = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String?> updatedBy = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ScheduleItemsCompanion.insert(
                id: id,
                tripId: tripId,
                stopId: stopId,
                dayId: dayId,
                sortKey: sortKey,
                stayMinutes: stayMinutes,
                transitMinutes: transitMinutes,
                fixedTime: fixedTime,
                status: status,
                updatedAt: updatedAt,
                updatedBy: updatedBy,
                deletedAt: deletedAt,
                syncStatus: syncStatus,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ScheduleItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({tripId = false, stopId = false, dayId = false}) {
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
                        if (tripId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.tripId,
                                    referencedTable:
                                        $$ScheduleItemsTableReferences
                                            ._tripIdTable(db),
                                    referencedColumn:
                                        $$ScheduleItemsTableReferences
                                            ._tripIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (stopId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.stopId,
                                    referencedTable:
                                        $$ScheduleItemsTableReferences
                                            ._stopIdTable(db),
                                    referencedColumn:
                                        $$ScheduleItemsTableReferences
                                            ._stopIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (dayId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.dayId,
                                    referencedTable:
                                        $$ScheduleItemsTableReferences
                                            ._dayIdTable(db),
                                    referencedColumn:
                                        $$ScheduleItemsTableReferences
                                            ._dayIdTable(db)
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

typedef $$ScheduleItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ScheduleItemsTable,
      ScheduleItem,
      $$ScheduleItemsTableFilterComposer,
      $$ScheduleItemsTableOrderingComposer,
      $$ScheduleItemsTableAnnotationComposer,
      $$ScheduleItemsTableCreateCompanionBuilder,
      $$ScheduleItemsTableUpdateCompanionBuilder,
      (ScheduleItem, $$ScheduleItemsTableReferences),
      ScheduleItem,
      PrefetchHooks Function({bool tripId, bool stopId, bool dayId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$RoisTableTableManager get rois => $$RoisTableTableManager(_db, _db.rois);
  $$PoisTableTableManager get pois => $$PoisTableTableManager(_db, _db.pois);
  $$AnimesTableTableManager get animes =>
      $$AnimesTableTableManager(_db, _db.animes);
  $$TagsTableTableManager get tags => $$TagsTableTableManager(_db, _db.tags);
  $$PoiAnimesTableTableManager get poiAnimes =>
      $$PoiAnimesTableTableManager(_db, _db.poiAnimes);
  $$PoiTagsTableTableManager get poiTags =>
      $$PoiTagsTableTableManager(_db, _db.poiTags);
  $$TimeChunksTableTableManager get timeChunks =>
      $$TimeChunksTableTableManager(_db, _db.timeChunks);
  $$ReferenceImagesTableTableManager get referenceImages =>
      $$ReferenceImagesTableTableManager(_db, _db.referenceImages);
  $$MediaAssetsTableTableManager get mediaAssets =>
      $$MediaAssetsTableTableManager(_db, _db.mediaAssets);
  $$PlacesTableTableManager get places =>
      $$PlacesTableTableManager(_db, _db.places);
  $$LabelsTableTableManager get labels =>
      $$LabelsTableTableManager(_db, _db.labels);
  $$PlaceLabelsTableTableManager get placeLabels =>
      $$PlaceLabelsTableTableManager(_db, _db.placeLabels);
  $$PhotosTableTableManager get photos =>
      $$PhotosTableTableManager(_db, _db.photos);
  $$PlaceVisitsTableTableManager get placeVisits =>
      $$PlaceVisitsTableTableManager(_db, _db.placeVisits);
  $$NewReferenceImagesTableTableManager get newReferenceImages =>
      $$NewReferenceImagesTableTableManager(_db, _db.newReferenceImages);
  $$TripsTableTableManager get trips =>
      $$TripsTableTableManager(_db, _db.trips);
  $$TripDaysTableTableManager get tripDays =>
      $$TripDaysTableTableManager(_db, _db.tripDays);
  $$StopsTableTableManager get stops =>
      $$StopsTableTableManager(_db, _db.stops);
  $$StopLabelsTableTableManager get stopLabels =>
      $$StopLabelsTableTableManager(_db, _db.stopLabels);
  $$ScheduleItemsTableTableManager get scheduleItems =>
      $$ScheduleItemsTableTableManager(_db, _db.scheduleItems);
}
