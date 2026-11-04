// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_database.dart';

// ignore_for_file: type=lint
class $CachedFormsTable extends CachedForms
    with TableInfo<$CachedFormsTable, CachedForm> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedFormsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _formIdMeta = const VerificationMeta('formId');
  @override
  late final GeneratedColumn<String> formId = GeneratedColumn<String>(
    'form_id',
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
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [formId, title, serverId, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_forms';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedForm> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('form_id')) {
      context.handle(
        _formIdMeta,
        formId.isAcceptableOrUnknown(data['form_id']!, _formIdMeta),
      );
    } else if (isInserting) {
      context.missing(_formIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {formId};
  @override
  CachedForm map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedForm(
      formId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}form_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $CachedFormsTable createAlias(String alias) {
    return $CachedFormsTable(attachedDatabase, alias);
  }
}

class CachedForm extends DataClass implements Insertable<CachedForm> {
  /// The XForm's form id (the `id` attribute of its primary instance).
  final String formId;

  /// The form title shown in lists.
  final String? title;

  /// The id of the server's `forms` record, if downloaded from a server.
  final String? serverId;

  /// When this row last changed.
  final DateTime updatedAt;
  const CachedForm({
    required this.formId,
    this.title,
    this.serverId,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['form_id'] = Variable<String>(formId);
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<String>(serverId);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CachedFormsCompanion toCompanion(bool nullToAbsent) {
    return CachedFormsCompanion(
      formId: Value(formId),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      updatedAt: Value(updatedAt),
    );
  }

  factory CachedForm.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedForm(
      formId: serializer.fromJson<String>(json['formId']),
      title: serializer.fromJson<String?>(json['title']),
      serverId: serializer.fromJson<String?>(json['serverId']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'formId': serializer.toJson<String>(formId),
      'title': serializer.toJson<String?>(title),
      'serverId': serializer.toJson<String?>(serverId),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CachedForm copyWith({
    String? formId,
    Value<String?> title = const Value.absent(),
    Value<String?> serverId = const Value.absent(),
    DateTime? updatedAt,
  }) => CachedForm(
    formId: formId ?? this.formId,
    title: title.present ? title.value : this.title,
    serverId: serverId.present ? serverId.value : this.serverId,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CachedForm copyWithCompanion(CachedFormsCompanion data) {
    return CachedForm(
      formId: data.formId.present ? data.formId.value : this.formId,
      title: data.title.present ? data.title.value : this.title,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedForm(')
          ..write('formId: $formId, ')
          ..write('title: $title, ')
          ..write('serverId: $serverId, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(formId, title, serverId, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedForm &&
          other.formId == this.formId &&
          other.title == this.title &&
          other.serverId == this.serverId &&
          other.updatedAt == this.updatedAt);
}

class CachedFormsCompanion extends UpdateCompanion<CachedForm> {
  final Value<String> formId;
  final Value<String?> title;
  final Value<String?> serverId;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CachedFormsCompanion({
    this.formId = const Value.absent(),
    this.title = const Value.absent(),
    this.serverId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedFormsCompanion.insert({
    required String formId,
    this.title = const Value.absent(),
    this.serverId = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : formId = Value(formId),
       updatedAt = Value(updatedAt);
  static Insertable<CachedForm> custom({
    Expression<String>? formId,
    Expression<String>? title,
    Expression<String>? serverId,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (formId != null) 'form_id': formId,
      if (title != null) 'title': title,
      if (serverId != null) 'server_id': serverId,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedFormsCompanion copyWith({
    Value<String>? formId,
    Value<String?>? title,
    Value<String?>? serverId,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return CachedFormsCompanion(
      formId: formId ?? this.formId,
      title: title ?? this.title,
      serverId: serverId ?? this.serverId,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (formId.present) {
      map['form_id'] = Variable<String>(formId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedFormsCompanion(')
          ..write('formId: $formId, ')
          ..write('title: $title, ')
          ..write('serverId: $serverId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedFormVersionsTable extends CachedFormVersions
    with TableInfo<$CachedFormVersionsTable, CachedFormVersion> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedFormVersionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _formIdMeta = const VerificationMeta('formId');
  @override
  late final GeneratedColumn<String> formId = GeneratedColumn<String>(
    'form_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<String> version = GeneratedColumn<String>(
    'version',
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
  static const VerificationMeta _xformXmlMeta = const VerificationMeta(
    'xformXml',
  );
  @override
  late final GeneratedColumn<String> xformXml = GeneratedColumn<String>(
    'xform_xml',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _manifestMeta = const VerificationMeta(
    'manifest',
  );
  @override
  late final GeneratedColumn<String> manifest = GeneratedColumn<String>(
    'manifest',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _publishedAtMeta = const VerificationMeta(
    'publishedAt',
  );
  @override
  late final GeneratedColumn<DateTime> publishedAt = GeneratedColumn<DateTime>(
    'published_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _downloadedAtMeta = const VerificationMeta(
    'downloadedAt',
  );
  @override
  late final GeneratedColumn<DateTime> downloadedAt = GeneratedColumn<DateTime>(
    'downloaded_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    formId,
    version,
    title,
    xformXml,
    manifest,
    serverId,
    publishedAt,
    downloadedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_form_versions';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedFormVersion> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('form_id')) {
      context.handle(
        _formIdMeta,
        formId.isAcceptableOrUnknown(data['form_id']!, _formIdMeta),
      );
    } else if (isInserting) {
      context.missing(_formIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('xform_xml')) {
      context.handle(
        _xformXmlMeta,
        xformXml.isAcceptableOrUnknown(data['xform_xml']!, _xformXmlMeta),
      );
    } else if (isInserting) {
      context.missing(_xformXmlMeta);
    }
    if (data.containsKey('manifest')) {
      context.handle(
        _manifestMeta,
        manifest.isAcceptableOrUnknown(data['manifest']!, _manifestMeta),
      );
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    if (data.containsKey('published_at')) {
      context.handle(
        _publishedAtMeta,
        publishedAt.isAcceptableOrUnknown(
          data['published_at']!,
          _publishedAtMeta,
        ),
      );
    }
    if (data.containsKey('downloaded_at')) {
      context.handle(
        _downloadedAtMeta,
        downloadedAt.isAcceptableOrUnknown(
          data['downloaded_at']!,
          _downloadedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_downloadedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {formId, version};
  @override
  CachedFormVersion map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedFormVersion(
      formId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}form_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}version'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      xformXml: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}xform_xml'],
      )!,
      manifest: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}manifest'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      ),
      publishedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}published_at'],
      ),
      downloadedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}downloaded_at'],
      )!,
    );
  }

  @override
  $CachedFormVersionsTable createAlias(String alias) {
    return $CachedFormVersionsTable(attachedDatabase, alias);
  }
}

class CachedFormVersion extends DataClass
    implements Insertable<CachedFormVersion> {
  /// The form id this version belongs to.
  final String formId;

  /// The `version` attribute of the XForm's primary instance.
  final String version;

  /// The form title from this version's XForm.
  final String? title;

  /// The complete XForm XML.
  final String xformXml;

  /// JSON list of the version's media files (empty until media ships).
  final String manifest;

  /// The id of the server's `form_versions` record, if any.
  final String? serverId;

  /// When the server published this version, if known.
  final DateTime? publishedAt;

  /// When this device stored this version.
  final DateTime downloadedAt;
  const CachedFormVersion({
    required this.formId,
    required this.version,
    this.title,
    required this.xformXml,
    required this.manifest,
    this.serverId,
    this.publishedAt,
    required this.downloadedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['form_id'] = Variable<String>(formId);
    map['version'] = Variable<String>(version);
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    map['xform_xml'] = Variable<String>(xformXml);
    map['manifest'] = Variable<String>(manifest);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<String>(serverId);
    }
    if (!nullToAbsent || publishedAt != null) {
      map['published_at'] = Variable<DateTime>(publishedAt);
    }
    map['downloaded_at'] = Variable<DateTime>(downloadedAt);
    return map;
  }

  CachedFormVersionsCompanion toCompanion(bool nullToAbsent) {
    return CachedFormVersionsCompanion(
      formId: Value(formId),
      version: Value(version),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      xformXml: Value(xformXml),
      manifest: Value(manifest),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      publishedAt: publishedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(publishedAt),
      downloadedAt: Value(downloadedAt),
    );
  }

  factory CachedFormVersion.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedFormVersion(
      formId: serializer.fromJson<String>(json['formId']),
      version: serializer.fromJson<String>(json['version']),
      title: serializer.fromJson<String?>(json['title']),
      xformXml: serializer.fromJson<String>(json['xformXml']),
      manifest: serializer.fromJson<String>(json['manifest']),
      serverId: serializer.fromJson<String?>(json['serverId']),
      publishedAt: serializer.fromJson<DateTime?>(json['publishedAt']),
      downloadedAt: serializer.fromJson<DateTime>(json['downloadedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'formId': serializer.toJson<String>(formId),
      'version': serializer.toJson<String>(version),
      'title': serializer.toJson<String?>(title),
      'xformXml': serializer.toJson<String>(xformXml),
      'manifest': serializer.toJson<String>(manifest),
      'serverId': serializer.toJson<String?>(serverId),
      'publishedAt': serializer.toJson<DateTime?>(publishedAt),
      'downloadedAt': serializer.toJson<DateTime>(downloadedAt),
    };
  }

  CachedFormVersion copyWith({
    String? formId,
    String? version,
    Value<String?> title = const Value.absent(),
    String? xformXml,
    String? manifest,
    Value<String?> serverId = const Value.absent(),
    Value<DateTime?> publishedAt = const Value.absent(),
    DateTime? downloadedAt,
  }) => CachedFormVersion(
    formId: formId ?? this.formId,
    version: version ?? this.version,
    title: title.present ? title.value : this.title,
    xformXml: xformXml ?? this.xformXml,
    manifest: manifest ?? this.manifest,
    serverId: serverId.present ? serverId.value : this.serverId,
    publishedAt: publishedAt.present ? publishedAt.value : this.publishedAt,
    downloadedAt: downloadedAt ?? this.downloadedAt,
  );
  CachedFormVersion copyWithCompanion(CachedFormVersionsCompanion data) {
    return CachedFormVersion(
      formId: data.formId.present ? data.formId.value : this.formId,
      version: data.version.present ? data.version.value : this.version,
      title: data.title.present ? data.title.value : this.title,
      xformXml: data.xformXml.present ? data.xformXml.value : this.xformXml,
      manifest: data.manifest.present ? data.manifest.value : this.manifest,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      publishedAt: data.publishedAt.present
          ? data.publishedAt.value
          : this.publishedAt,
      downloadedAt: data.downloadedAt.present
          ? data.downloadedAt.value
          : this.downloadedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedFormVersion(')
          ..write('formId: $formId, ')
          ..write('version: $version, ')
          ..write('title: $title, ')
          ..write('xformXml: $xformXml, ')
          ..write('manifest: $manifest, ')
          ..write('serverId: $serverId, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('downloadedAt: $downloadedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    formId,
    version,
    title,
    xformXml,
    manifest,
    serverId,
    publishedAt,
    downloadedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedFormVersion &&
          other.formId == this.formId &&
          other.version == this.version &&
          other.title == this.title &&
          other.xformXml == this.xformXml &&
          other.manifest == this.manifest &&
          other.serverId == this.serverId &&
          other.publishedAt == this.publishedAt &&
          other.downloadedAt == this.downloadedAt);
}

class CachedFormVersionsCompanion extends UpdateCompanion<CachedFormVersion> {
  final Value<String> formId;
  final Value<String> version;
  final Value<String?> title;
  final Value<String> xformXml;
  final Value<String> manifest;
  final Value<String?> serverId;
  final Value<DateTime?> publishedAt;
  final Value<DateTime> downloadedAt;
  final Value<int> rowid;
  const CachedFormVersionsCompanion({
    this.formId = const Value.absent(),
    this.version = const Value.absent(),
    this.title = const Value.absent(),
    this.xformXml = const Value.absent(),
    this.manifest = const Value.absent(),
    this.serverId = const Value.absent(),
    this.publishedAt = const Value.absent(),
    this.downloadedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedFormVersionsCompanion.insert({
    required String formId,
    required String version,
    this.title = const Value.absent(),
    required String xformXml,
    this.manifest = const Value.absent(),
    this.serverId = const Value.absent(),
    this.publishedAt = const Value.absent(),
    required DateTime downloadedAt,
    this.rowid = const Value.absent(),
  }) : formId = Value(formId),
       version = Value(version),
       xformXml = Value(xformXml),
       downloadedAt = Value(downloadedAt);
  static Insertable<CachedFormVersion> custom({
    Expression<String>? formId,
    Expression<String>? version,
    Expression<String>? title,
    Expression<String>? xformXml,
    Expression<String>? manifest,
    Expression<String>? serverId,
    Expression<DateTime>? publishedAt,
    Expression<DateTime>? downloadedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (formId != null) 'form_id': formId,
      if (version != null) 'version': version,
      if (title != null) 'title': title,
      if (xformXml != null) 'xform_xml': xformXml,
      if (manifest != null) 'manifest': manifest,
      if (serverId != null) 'server_id': serverId,
      if (publishedAt != null) 'published_at': publishedAt,
      if (downloadedAt != null) 'downloaded_at': downloadedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedFormVersionsCompanion copyWith({
    Value<String>? formId,
    Value<String>? version,
    Value<String?>? title,
    Value<String>? xformXml,
    Value<String>? manifest,
    Value<String?>? serverId,
    Value<DateTime?>? publishedAt,
    Value<DateTime>? downloadedAt,
    Value<int>? rowid,
  }) {
    return CachedFormVersionsCompanion(
      formId: formId ?? this.formId,
      version: version ?? this.version,
      title: title ?? this.title,
      xformXml: xformXml ?? this.xformXml,
      manifest: manifest ?? this.manifest,
      serverId: serverId ?? this.serverId,
      publishedAt: publishedAt ?? this.publishedAt,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (formId.present) {
      map['form_id'] = Variable<String>(formId.value);
    }
    if (version.present) {
      map['version'] = Variable<String>(version.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (xformXml.present) {
      map['xform_xml'] = Variable<String>(xformXml.value);
    }
    if (manifest.present) {
      map['manifest'] = Variable<String>(manifest.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (publishedAt.present) {
      map['published_at'] = Variable<DateTime>(publishedAt.value);
    }
    if (downloadedAt.present) {
      map['downloaded_at'] = Variable<DateTime>(downloadedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedFormVersionsCompanion(')
          ..write('formId: $formId, ')
          ..write('version: $version, ')
          ..write('title: $title, ')
          ..write('xformXml: $xformXml, ')
          ..write('manifest: $manifest, ')
          ..write('serverId: $serverId, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('downloadedAt: $downloadedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DraftsTable extends Drafts with TableInfo<$DraftsTable, Draft> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DraftsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _instanceIdMeta = const VerificationMeta(
    'instanceId',
  );
  @override
  late final GeneratedColumn<String> instanceId = GeneratedColumn<String>(
    'instance_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _formIdMeta = const VerificationMeta('formId');
  @override
  late final GeneratedColumn<String> formId = GeneratedColumn<String>(
    'form_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _formVersionMeta = const VerificationMeta(
    'formVersion',
  );
  @override
  late final GeneratedColumn<String> formVersion = GeneratedColumn<String>(
    'form_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _instanceXmlMeta = const VerificationMeta(
    'instanceXml',
  );
  @override
  late final GeneratedColumn<String> instanceXml = GeneratedColumn<String>(
    'instance_xml',
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
    requiredDuringInsert: true,
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
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    instanceId,
    formId,
    formVersion,
    instanceXml,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'drafts';
  @override
  VerificationContext validateIntegrity(
    Insertable<Draft> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('instance_id')) {
      context.handle(
        _instanceIdMeta,
        instanceId.isAcceptableOrUnknown(data['instance_id']!, _instanceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_instanceIdMeta);
    }
    if (data.containsKey('form_id')) {
      context.handle(
        _formIdMeta,
        formId.isAcceptableOrUnknown(data['form_id']!, _formIdMeta),
      );
    } else if (isInserting) {
      context.missing(_formIdMeta);
    }
    if (data.containsKey('form_version')) {
      context.handle(
        _formVersionMeta,
        formVersion.isAcceptableOrUnknown(
          data['form_version']!,
          _formVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_formVersionMeta);
    }
    if (data.containsKey('instance_xml')) {
      context.handle(
        _instanceXmlMeta,
        instanceXml.isAcceptableOrUnknown(
          data['instance_xml']!,
          _instanceXmlMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_instanceXmlMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {instanceId};
  @override
  Draft map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Draft(
      instanceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}instance_id'],
      )!,
      formId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}form_id'],
      )!,
      formVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}form_version'],
      )!,
      instanceXml: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}instance_xml'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $DraftsTable createAlias(String alias) {
    return $DraftsTable(attachedDatabase, alias);
  }
}

class Draft extends DataClass implements Insertable<Draft> {
  /// The instance's `meta/instanceID`, kept when the draft is finalised.
  final String instanceId;

  /// The form id.
  final String formId;

  /// The form version the draft is filled against.
  final String formVersion;

  /// The partial instance XML (non-relevant answers included).
  final String instanceXml;

  /// When the draft was first saved.
  final DateTime createdAt;

  /// When the draft was last saved.
  final DateTime updatedAt;
  const Draft({
    required this.instanceId,
    required this.formId,
    required this.formVersion,
    required this.instanceXml,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['instance_id'] = Variable<String>(instanceId);
    map['form_id'] = Variable<String>(formId);
    map['form_version'] = Variable<String>(formVersion);
    map['instance_xml'] = Variable<String>(instanceXml);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  DraftsCompanion toCompanion(bool nullToAbsent) {
    return DraftsCompanion(
      instanceId: Value(instanceId),
      formId: Value(formId),
      formVersion: Value(formVersion),
      instanceXml: Value(instanceXml),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Draft.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Draft(
      instanceId: serializer.fromJson<String>(json['instanceId']),
      formId: serializer.fromJson<String>(json['formId']),
      formVersion: serializer.fromJson<String>(json['formVersion']),
      instanceXml: serializer.fromJson<String>(json['instanceXml']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'instanceId': serializer.toJson<String>(instanceId),
      'formId': serializer.toJson<String>(formId),
      'formVersion': serializer.toJson<String>(formVersion),
      'instanceXml': serializer.toJson<String>(instanceXml),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Draft copyWith({
    String? instanceId,
    String? formId,
    String? formVersion,
    String? instanceXml,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Draft(
    instanceId: instanceId ?? this.instanceId,
    formId: formId ?? this.formId,
    formVersion: formVersion ?? this.formVersion,
    instanceXml: instanceXml ?? this.instanceXml,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Draft copyWithCompanion(DraftsCompanion data) {
    return Draft(
      instanceId: data.instanceId.present
          ? data.instanceId.value
          : this.instanceId,
      formId: data.formId.present ? data.formId.value : this.formId,
      formVersion: data.formVersion.present
          ? data.formVersion.value
          : this.formVersion,
      instanceXml: data.instanceXml.present
          ? data.instanceXml.value
          : this.instanceXml,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Draft(')
          ..write('instanceId: $instanceId, ')
          ..write('formId: $formId, ')
          ..write('formVersion: $formVersion, ')
          ..write('instanceXml: $instanceXml, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    instanceId,
    formId,
    formVersion,
    instanceXml,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Draft &&
          other.instanceId == this.instanceId &&
          other.formId == this.formId &&
          other.formVersion == this.formVersion &&
          other.instanceXml == this.instanceXml &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class DraftsCompanion extends UpdateCompanion<Draft> {
  final Value<String> instanceId;
  final Value<String> formId;
  final Value<String> formVersion;
  final Value<String> instanceXml;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const DraftsCompanion({
    this.instanceId = const Value.absent(),
    this.formId = const Value.absent(),
    this.formVersion = const Value.absent(),
    this.instanceXml = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DraftsCompanion.insert({
    required String instanceId,
    required String formId,
    required String formVersion,
    required String instanceXml,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : instanceId = Value(instanceId),
       formId = Value(formId),
       formVersion = Value(formVersion),
       instanceXml = Value(instanceXml),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Draft> custom({
    Expression<String>? instanceId,
    Expression<String>? formId,
    Expression<String>? formVersion,
    Expression<String>? instanceXml,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (instanceId != null) 'instance_id': instanceId,
      if (formId != null) 'form_id': formId,
      if (formVersion != null) 'form_version': formVersion,
      if (instanceXml != null) 'instance_xml': instanceXml,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DraftsCompanion copyWith({
    Value<String>? instanceId,
    Value<String>? formId,
    Value<String>? formVersion,
    Value<String>? instanceXml,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return DraftsCompanion(
      instanceId: instanceId ?? this.instanceId,
      formId: formId ?? this.formId,
      formVersion: formVersion ?? this.formVersion,
      instanceXml: instanceXml ?? this.instanceXml,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (instanceId.present) {
      map['instance_id'] = Variable<String>(instanceId.value);
    }
    if (formId.present) {
      map['form_id'] = Variable<String>(formId.value);
    }
    if (formVersion.present) {
      map['form_version'] = Variable<String>(formVersion.value);
    }
    if (instanceXml.present) {
      map['instance_xml'] = Variable<String>(instanceXml.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DraftsCompanion(')
          ..write('instanceId: $instanceId, ')
          ..write('formId: $formId, ')
          ..write('formVersion: $formVersion, ')
          ..write('instanceXml: $instanceXml, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutboxTable extends Outbox with TableInfo<$OutboxTable, OutboxEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _instanceIdMeta = const VerificationMeta(
    'instanceId',
  );
  @override
  late final GeneratedColumn<String> instanceId = GeneratedColumn<String>(
    'instance_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _formIdMeta = const VerificationMeta('formId');
  @override
  late final GeneratedColumn<String> formId = GeneratedColumn<String>(
    'form_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _formVersionMeta = const VerificationMeta(
    'formVersion',
  );
  @override
  late final GeneratedColumn<String> formVersion = GeneratedColumn<String>(
    'form_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _instanceXmlMeta = const VerificationMeta(
    'instanceXml',
  );
  @override
  late final GeneratedColumn<String> instanceXml = GeneratedColumn<String>(
    'instance_xml',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attachmentsMeta = const VerificationMeta(
    'attachments',
  );
  @override
  late final GeneratedColumn<String> attachments = GeneratedColumn<String>(
    'attachments',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  @override
  late final GeneratedColumnWithTypeConverter<OutboxState, String> state =
      GeneratedColumn<String>(
        'state',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<OutboxState>($OutboxTable.$converterstate);
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastErrorMessageMeta = const VerificationMeta(
    'lastErrorMessage',
  );
  @override
  late final GeneratedColumn<String> lastErrorMessage = GeneratedColumn<String>(
    'last_error_message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nextAttemptAtMeta = const VerificationMeta(
    'nextAttemptAt',
  );
  @override
  late final GeneratedColumn<DateTime> nextAttemptAt =
      GeneratedColumn<DateTime>(
        'next_attempt_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
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
    requiredDuringInsert: true,
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
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sentAtMeta = const VerificationMeta('sentAt');
  @override
  late final GeneratedColumn<DateTime> sentAt = GeneratedColumn<DateTime>(
    'sent_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    instanceId,
    formId,
    formVersion,
    instanceXml,
    attachments,
    state,
    attempts,
    lastError,
    lastErrorMessage,
    nextAttemptAt,
    serverId,
    createdAt,
    updatedAt,
    sentAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('instance_id')) {
      context.handle(
        _instanceIdMeta,
        instanceId.isAcceptableOrUnknown(data['instance_id']!, _instanceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_instanceIdMeta);
    }
    if (data.containsKey('form_id')) {
      context.handle(
        _formIdMeta,
        formId.isAcceptableOrUnknown(data['form_id']!, _formIdMeta),
      );
    } else if (isInserting) {
      context.missing(_formIdMeta);
    }
    if (data.containsKey('form_version')) {
      context.handle(
        _formVersionMeta,
        formVersion.isAcceptableOrUnknown(
          data['form_version']!,
          _formVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_formVersionMeta);
    }
    if (data.containsKey('instance_xml')) {
      context.handle(
        _instanceXmlMeta,
        instanceXml.isAcceptableOrUnknown(
          data['instance_xml']!,
          _instanceXmlMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_instanceXmlMeta);
    }
    if (data.containsKey('attachments')) {
      context.handle(
        _attachmentsMeta,
        attachments.isAcceptableOrUnknown(
          data['attachments']!,
          _attachmentsMeta,
        ),
      );
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('last_error_message')) {
      context.handle(
        _lastErrorMessageMeta,
        lastErrorMessage.isAcceptableOrUnknown(
          data['last_error_message']!,
          _lastErrorMessageMeta,
        ),
      );
    }
    if (data.containsKey('next_attempt_at')) {
      context.handle(
        _nextAttemptAtMeta,
        nextAttemptAt.isAcceptableOrUnknown(
          data['next_attempt_at']!,
          _nextAttemptAtMeta,
        ),
      );
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('sent_at')) {
      context.handle(
        _sentAtMeta,
        sentAt.isAcceptableOrUnknown(data['sent_at']!, _sentAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {instanceId};
  @override
  OutboxEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxEntry(
      instanceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}instance_id'],
      )!,
      formId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}form_id'],
      )!,
      formVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}form_version'],
      )!,
      instanceXml: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}instance_xml'],
      )!,
      attachments: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attachments'],
      )!,
      state: $OutboxTable.$converterstate.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}state'],
        )!,
      ),
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      lastErrorMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error_message'],
      ),
      nextAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_attempt_at'],
      ),
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      sentAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}sent_at'],
      ),
    );
  }

  @override
  $OutboxTable createAlias(String alias) {
    return $OutboxTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<OutboxState, String, String> $converterstate =
      const EnumNameConverter<OutboxState>(OutboxState.values);
}

class OutboxEntry extends DataClass implements Insertable<OutboxEntry> {
  /// The submission's `meta/instanceID`; the server's idempotency key.
  final String instanceId;

  /// The form id.
  final String formId;

  /// The form version the submission was filled with.
  final String formVersion;

  /// The final instance XML exactly as it will be uploaded.
  final String instanceXml;

  /// JSON list of local paths of files sent with the submission.
  final String attachments;

  /// Where the submission is on its way to the server.
  final OutboxState state;

  /// How many times sending has been tried since it was last queued by a
  /// person.
  final int attempts;

  /// The [ProblemCode] name of the last failure, if any.
  final String? lastError;

  /// The server's own message for the last failure, for support staff.
  final String? lastErrorMessage;

  /// Not to be tried before this time (exponential backoff).
  final DateTime? nextAttemptAt;

  /// The id of the server's `submissions` record, once sent.
  final String? serverId;

  /// When the submission was finalised.
  final DateTime createdAt;

  /// When this row last changed.
  final DateTime updatedAt;

  /// When the server confirmed the submission.
  final DateTime? sentAt;
  const OutboxEntry({
    required this.instanceId,
    required this.formId,
    required this.formVersion,
    required this.instanceXml,
    required this.attachments,
    required this.state,
    required this.attempts,
    this.lastError,
    this.lastErrorMessage,
    this.nextAttemptAt,
    this.serverId,
    required this.createdAt,
    required this.updatedAt,
    this.sentAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['instance_id'] = Variable<String>(instanceId);
    map['form_id'] = Variable<String>(formId);
    map['form_version'] = Variable<String>(formVersion);
    map['instance_xml'] = Variable<String>(instanceXml);
    map['attachments'] = Variable<String>(attachments);
    {
      map['state'] = Variable<String>(
        $OutboxTable.$converterstate.toSql(state),
      );
    }
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    if (!nullToAbsent || lastErrorMessage != null) {
      map['last_error_message'] = Variable<String>(lastErrorMessage);
    }
    if (!nullToAbsent || nextAttemptAt != null) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt);
    }
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<String>(serverId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || sentAt != null) {
      map['sent_at'] = Variable<DateTime>(sentAt);
    }
    return map;
  }

  OutboxCompanion toCompanion(bool nullToAbsent) {
    return OutboxCompanion(
      instanceId: Value(instanceId),
      formId: Value(formId),
      formVersion: Value(formVersion),
      instanceXml: Value(instanceXml),
      attachments: Value(attachments),
      state: Value(state),
      attempts: Value(attempts),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      lastErrorMessage: lastErrorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(lastErrorMessage),
      nextAttemptAt: nextAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextAttemptAt),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      sentAt: sentAt == null && nullToAbsent
          ? const Value.absent()
          : Value(sentAt),
    );
  }

  factory OutboxEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxEntry(
      instanceId: serializer.fromJson<String>(json['instanceId']),
      formId: serializer.fromJson<String>(json['formId']),
      formVersion: serializer.fromJson<String>(json['formVersion']),
      instanceXml: serializer.fromJson<String>(json['instanceXml']),
      attachments: serializer.fromJson<String>(json['attachments']),
      state: $OutboxTable.$converterstate.fromJson(
        serializer.fromJson<String>(json['state']),
      ),
      attempts: serializer.fromJson<int>(json['attempts']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      lastErrorMessage: serializer.fromJson<String?>(json['lastErrorMessage']),
      nextAttemptAt: serializer.fromJson<DateTime?>(json['nextAttemptAt']),
      serverId: serializer.fromJson<String?>(json['serverId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      sentAt: serializer.fromJson<DateTime?>(json['sentAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'instanceId': serializer.toJson<String>(instanceId),
      'formId': serializer.toJson<String>(formId),
      'formVersion': serializer.toJson<String>(formVersion),
      'instanceXml': serializer.toJson<String>(instanceXml),
      'attachments': serializer.toJson<String>(attachments),
      'state': serializer.toJson<String>(
        $OutboxTable.$converterstate.toJson(state),
      ),
      'attempts': serializer.toJson<int>(attempts),
      'lastError': serializer.toJson<String?>(lastError),
      'lastErrorMessage': serializer.toJson<String?>(lastErrorMessage),
      'nextAttemptAt': serializer.toJson<DateTime?>(nextAttemptAt),
      'serverId': serializer.toJson<String?>(serverId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'sentAt': serializer.toJson<DateTime?>(sentAt),
    };
  }

  OutboxEntry copyWith({
    String? instanceId,
    String? formId,
    String? formVersion,
    String? instanceXml,
    String? attachments,
    OutboxState? state,
    int? attempts,
    Value<String?> lastError = const Value.absent(),
    Value<String?> lastErrorMessage = const Value.absent(),
    Value<DateTime?> nextAttemptAt = const Value.absent(),
    Value<String?> serverId = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> sentAt = const Value.absent(),
  }) => OutboxEntry(
    instanceId: instanceId ?? this.instanceId,
    formId: formId ?? this.formId,
    formVersion: formVersion ?? this.formVersion,
    instanceXml: instanceXml ?? this.instanceXml,
    attachments: attachments ?? this.attachments,
    state: state ?? this.state,
    attempts: attempts ?? this.attempts,
    lastError: lastError.present ? lastError.value : this.lastError,
    lastErrorMessage: lastErrorMessage.present
        ? lastErrorMessage.value
        : this.lastErrorMessage,
    nextAttemptAt: nextAttemptAt.present
        ? nextAttemptAt.value
        : this.nextAttemptAt,
    serverId: serverId.present ? serverId.value : this.serverId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    sentAt: sentAt.present ? sentAt.value : this.sentAt,
  );
  OutboxEntry copyWithCompanion(OutboxCompanion data) {
    return OutboxEntry(
      instanceId: data.instanceId.present
          ? data.instanceId.value
          : this.instanceId,
      formId: data.formId.present ? data.formId.value : this.formId,
      formVersion: data.formVersion.present
          ? data.formVersion.value
          : this.formVersion,
      instanceXml: data.instanceXml.present
          ? data.instanceXml.value
          : this.instanceXml,
      attachments: data.attachments.present
          ? data.attachments.value
          : this.attachments,
      state: data.state.present ? data.state.value : this.state,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      lastErrorMessage: data.lastErrorMessage.present
          ? data.lastErrorMessage.value
          : this.lastErrorMessage,
      nextAttemptAt: data.nextAttemptAt.present
          ? data.nextAttemptAt.value
          : this.nextAttemptAt,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      sentAt: data.sentAt.present ? data.sentAt.value : this.sentAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxEntry(')
          ..write('instanceId: $instanceId, ')
          ..write('formId: $formId, ')
          ..write('formVersion: $formVersion, ')
          ..write('instanceXml: $instanceXml, ')
          ..write('attachments: $attachments, ')
          ..write('state: $state, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('lastErrorMessage: $lastErrorMessage, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('serverId: $serverId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('sentAt: $sentAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    instanceId,
    formId,
    formVersion,
    instanceXml,
    attachments,
    state,
    attempts,
    lastError,
    lastErrorMessage,
    nextAttemptAt,
    serverId,
    createdAt,
    updatedAt,
    sentAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxEntry &&
          other.instanceId == this.instanceId &&
          other.formId == this.formId &&
          other.formVersion == this.formVersion &&
          other.instanceXml == this.instanceXml &&
          other.attachments == this.attachments &&
          other.state == this.state &&
          other.attempts == this.attempts &&
          other.lastError == this.lastError &&
          other.lastErrorMessage == this.lastErrorMessage &&
          other.nextAttemptAt == this.nextAttemptAt &&
          other.serverId == this.serverId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.sentAt == this.sentAt);
}

class OutboxCompanion extends UpdateCompanion<OutboxEntry> {
  final Value<String> instanceId;
  final Value<String> formId;
  final Value<String> formVersion;
  final Value<String> instanceXml;
  final Value<String> attachments;
  final Value<OutboxState> state;
  final Value<int> attempts;
  final Value<String?> lastError;
  final Value<String?> lastErrorMessage;
  final Value<DateTime?> nextAttemptAt;
  final Value<String?> serverId;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> sentAt;
  final Value<int> rowid;
  const OutboxCompanion({
    this.instanceId = const Value.absent(),
    this.formId = const Value.absent(),
    this.formVersion = const Value.absent(),
    this.instanceXml = const Value.absent(),
    this.attachments = const Value.absent(),
    this.state = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    this.lastErrorMessage = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.serverId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.sentAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OutboxCompanion.insert({
    required String instanceId,
    required String formId,
    required String formVersion,
    required String instanceXml,
    this.attachments = const Value.absent(),
    required OutboxState state,
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    this.lastErrorMessage = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.serverId = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.sentAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : instanceId = Value(instanceId),
       formId = Value(formId),
       formVersion = Value(formVersion),
       instanceXml = Value(instanceXml),
       state = Value(state),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<OutboxEntry> custom({
    Expression<String>? instanceId,
    Expression<String>? formId,
    Expression<String>? formVersion,
    Expression<String>? instanceXml,
    Expression<String>? attachments,
    Expression<String>? state,
    Expression<int>? attempts,
    Expression<String>? lastError,
    Expression<String>? lastErrorMessage,
    Expression<DateTime>? nextAttemptAt,
    Expression<String>? serverId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? sentAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (instanceId != null) 'instance_id': instanceId,
      if (formId != null) 'form_id': formId,
      if (formVersion != null) 'form_version': formVersion,
      if (instanceXml != null) 'instance_xml': instanceXml,
      if (attachments != null) 'attachments': attachments,
      if (state != null) 'state': state,
      if (attempts != null) 'attempts': attempts,
      if (lastError != null) 'last_error': lastError,
      if (lastErrorMessage != null) 'last_error_message': lastErrorMessage,
      if (nextAttemptAt != null) 'next_attempt_at': nextAttemptAt,
      if (serverId != null) 'server_id': serverId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (sentAt != null) 'sent_at': sentAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OutboxCompanion copyWith({
    Value<String>? instanceId,
    Value<String>? formId,
    Value<String>? formVersion,
    Value<String>? instanceXml,
    Value<String>? attachments,
    Value<OutboxState>? state,
    Value<int>? attempts,
    Value<String?>? lastError,
    Value<String?>? lastErrorMessage,
    Value<DateTime?>? nextAttemptAt,
    Value<String?>? serverId,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? sentAt,
    Value<int>? rowid,
  }) {
    return OutboxCompanion(
      instanceId: instanceId ?? this.instanceId,
      formId: formId ?? this.formId,
      formVersion: formVersion ?? this.formVersion,
      instanceXml: instanceXml ?? this.instanceXml,
      attachments: attachments ?? this.attachments,
      state: state ?? this.state,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
      lastErrorMessage: lastErrorMessage ?? this.lastErrorMessage,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      serverId: serverId ?? this.serverId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sentAt: sentAt ?? this.sentAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (instanceId.present) {
      map['instance_id'] = Variable<String>(instanceId.value);
    }
    if (formId.present) {
      map['form_id'] = Variable<String>(formId.value);
    }
    if (formVersion.present) {
      map['form_version'] = Variable<String>(formVersion.value);
    }
    if (instanceXml.present) {
      map['instance_xml'] = Variable<String>(instanceXml.value);
    }
    if (attachments.present) {
      map['attachments'] = Variable<String>(attachments.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(
        $OutboxTable.$converterstate.toSql(state.value),
      );
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (lastErrorMessage.present) {
      map['last_error_message'] = Variable<String>(lastErrorMessage.value);
    }
    if (nextAttemptAt.present) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (sentAt.present) {
      map['sent_at'] = Variable<DateTime>(sentAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxCompanion(')
          ..write('instanceId: $instanceId, ')
          ..write('formId: $formId, ')
          ..write('formVersion: $formVersion, ')
          ..write('instanceXml: $instanceXml, ')
          ..write('attachments: $attachments, ')
          ..write('state: $state, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('lastErrorMessage: $lastErrorMessage, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('serverId: $serverId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('sentAt: $sentAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DeviceSettingsTable extends DeviceSettings
    with TableInfo<$DeviceSettingsTable, DeviceSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DeviceSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<DeviceSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  DeviceSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DeviceSetting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $DeviceSettingsTable createAlias(String alias) {
    return $DeviceSettingsTable(attachedDatabase, alias);
  }
}

class DeviceSetting extends DataClass implements Insertable<DeviceSetting> {
  /// The setting's name.
  final String key;

  /// The setting's value.
  final String value;
  const DeviceSetting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  DeviceSettingsCompanion toCompanion(bool nullToAbsent) {
    return DeviceSettingsCompanion(key: Value(key), value: Value(value));
  }

  factory DeviceSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DeviceSetting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  DeviceSetting copyWith({String? key, String? value}) =>
      DeviceSetting(key: key ?? this.key, value: value ?? this.value);
  DeviceSetting copyWithCompanion(DeviceSettingsCompanion data) {
    return DeviceSetting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DeviceSetting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DeviceSetting &&
          other.key == this.key &&
          other.value == this.value);
}

class DeviceSettingsCompanion extends UpdateCompanion<DeviceSetting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const DeviceSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DeviceSettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<DeviceSetting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DeviceSettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return DeviceSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DeviceSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$DeviceDatabase extends GeneratedDatabase {
  _$DeviceDatabase(QueryExecutor e) : super(e);
  $DeviceDatabaseManager get managers => $DeviceDatabaseManager(this);
  late final $CachedFormsTable cachedForms = $CachedFormsTable(this);
  late final $CachedFormVersionsTable cachedFormVersions =
      $CachedFormVersionsTable(this);
  late final $DraftsTable drafts = $DraftsTable(this);
  late final $OutboxTable outbox = $OutboxTable(this);
  late final $DeviceSettingsTable deviceSettings = $DeviceSettingsTable(this);
  late final Index draftsForm = Index(
    'drafts_form',
    'CREATE INDEX drafts_form ON drafts (form_id, form_version)',
  );
  late final Index outboxStateDue = Index(
    'outbox_state_due',
    'CREATE INDEX outbox_state_due ON outbox (state, next_attempt_at)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    cachedForms,
    cachedFormVersions,
    drafts,
    outbox,
    deviceSettings,
    draftsForm,
    outboxStateDue,
  ];
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}

typedef $$CachedFormsTableCreateCompanionBuilder =
    CachedFormsCompanion Function({
      required String formId,
      Value<String?> title,
      Value<String?> serverId,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$CachedFormsTableUpdateCompanionBuilder =
    CachedFormsCompanion Function({
      Value<String> formId,
      Value<String?> title,
      Value<String?> serverId,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$CachedFormsTableFilterComposer
    extends Composer<_$DeviceDatabase, $CachedFormsTable> {
  $$CachedFormsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get formId => $composableBuilder(
    column: $table.formId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedFormsTableOrderingComposer
    extends Composer<_$DeviceDatabase, $CachedFormsTable> {
  $$CachedFormsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get formId => $composableBuilder(
    column: $table.formId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedFormsTableAnnotationComposer
    extends Composer<_$DeviceDatabase, $CachedFormsTable> {
  $$CachedFormsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get formId =>
      $composableBuilder(column: $table.formId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CachedFormsTableTableManager
    extends
        RootTableManager<
          _$DeviceDatabase,
          $CachedFormsTable,
          CachedForm,
          $$CachedFormsTableFilterComposer,
          $$CachedFormsTableOrderingComposer,
          $$CachedFormsTableAnnotationComposer,
          $$CachedFormsTableCreateCompanionBuilder,
          $$CachedFormsTableUpdateCompanionBuilder,
          (
            CachedForm,
            BaseReferences<_$DeviceDatabase, $CachedFormsTable, CachedForm>,
          ),
          CachedForm,
          PrefetchHooks Function()
        > {
  $$CachedFormsTableTableManager(_$DeviceDatabase db, $CachedFormsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedFormsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedFormsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedFormsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> formId = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> serverId = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedFormsCompanion(
                formId: formId,
                title: title,
                serverId: serverId,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String formId,
                Value<String?> title = const Value.absent(),
                Value<String?> serverId = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedFormsCompanion.insert(
                formId: formId,
                title: title,
                serverId: serverId,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CachedFormsTable, CachedForm>(table),
                  BaseReferences<
                    _$DeviceDatabase,
                    $CachedFormsTable,
                    CachedForm
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedFormsTableProcessedTableManager =
    ProcessedTableManager<
      _$DeviceDatabase,
      $CachedFormsTable,
      CachedForm,
      $$CachedFormsTableFilterComposer,
      $$CachedFormsTableOrderingComposer,
      $$CachedFormsTableAnnotationComposer,
      $$CachedFormsTableCreateCompanionBuilder,
      $$CachedFormsTableUpdateCompanionBuilder,
      (
        CachedForm,
        BaseReferences<_$DeviceDatabase, $CachedFormsTable, CachedForm>,
      ),
      CachedForm,
      PrefetchHooks Function()
    >;
typedef $$CachedFormVersionsTableCreateCompanionBuilder =
    CachedFormVersionsCompanion Function({
      required String formId,
      required String version,
      Value<String?> title,
      required String xformXml,
      Value<String> manifest,
      Value<String?> serverId,
      Value<DateTime?> publishedAt,
      required DateTime downloadedAt,
      Value<int> rowid,
    });
typedef $$CachedFormVersionsTableUpdateCompanionBuilder =
    CachedFormVersionsCompanion Function({
      Value<String> formId,
      Value<String> version,
      Value<String?> title,
      Value<String> xformXml,
      Value<String> manifest,
      Value<String?> serverId,
      Value<DateTime?> publishedAt,
      Value<DateTime> downloadedAt,
      Value<int> rowid,
    });

class $$CachedFormVersionsTableFilterComposer
    extends Composer<_$DeviceDatabase, $CachedFormVersionsTable> {
  $$CachedFormVersionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get formId => $composableBuilder(
    column: $table.formId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get xformXml => $composableBuilder(
    column: $table.xformXml,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get manifest => $composableBuilder(
    column: $table.manifest,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get downloadedAt => $composableBuilder(
    column: $table.downloadedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedFormVersionsTableOrderingComposer
    extends Composer<_$DeviceDatabase, $CachedFormVersionsTable> {
  $$CachedFormVersionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get formId => $composableBuilder(
    column: $table.formId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get xformXml => $composableBuilder(
    column: $table.xformXml,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get manifest => $composableBuilder(
    column: $table.manifest,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get downloadedAt => $composableBuilder(
    column: $table.downloadedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedFormVersionsTableAnnotationComposer
    extends Composer<_$DeviceDatabase, $CachedFormVersionsTable> {
  $$CachedFormVersionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get formId =>
      $composableBuilder(column: $table.formId, builder: (column) => column);

  GeneratedColumn<String> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get xformXml =>
      $composableBuilder(column: $table.xformXml, builder: (column) => column);

  GeneratedColumn<String> get manifest =>
      $composableBuilder(column: $table.manifest, builder: (column) => column);

  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<DateTime> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get downloadedAt => $composableBuilder(
    column: $table.downloadedAt,
    builder: (column) => column,
  );
}

class $$CachedFormVersionsTableTableManager
    extends
        RootTableManager<
          _$DeviceDatabase,
          $CachedFormVersionsTable,
          CachedFormVersion,
          $$CachedFormVersionsTableFilterComposer,
          $$CachedFormVersionsTableOrderingComposer,
          $$CachedFormVersionsTableAnnotationComposer,
          $$CachedFormVersionsTableCreateCompanionBuilder,
          $$CachedFormVersionsTableUpdateCompanionBuilder,
          (
            CachedFormVersion,
            BaseReferences<
              _$DeviceDatabase,
              $CachedFormVersionsTable,
              CachedFormVersion
            >,
          ),
          CachedFormVersion,
          PrefetchHooks Function()
        > {
  $$CachedFormVersionsTableTableManager(
    _$DeviceDatabase db,
    $CachedFormVersionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedFormVersionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedFormVersionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedFormVersionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> formId = const Value.absent(),
                Value<String> version = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String> xformXml = const Value.absent(),
                Value<String> manifest = const Value.absent(),
                Value<String?> serverId = const Value.absent(),
                Value<DateTime?> publishedAt = const Value.absent(),
                Value<DateTime> downloadedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedFormVersionsCompanion(
                formId: formId,
                version: version,
                title: title,
                xformXml: xformXml,
                manifest: manifest,
                serverId: serverId,
                publishedAt: publishedAt,
                downloadedAt: downloadedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String formId,
                required String version,
                Value<String?> title = const Value.absent(),
                required String xformXml,
                Value<String> manifest = const Value.absent(),
                Value<String?> serverId = const Value.absent(),
                Value<DateTime?> publishedAt = const Value.absent(),
                required DateTime downloadedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedFormVersionsCompanion.insert(
                formId: formId,
                version: version,
                title: title,
                xformXml: xformXml,
                manifest: manifest,
                serverId: serverId,
                publishedAt: publishedAt,
                downloadedAt: downloadedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CachedFormVersionsTable, CachedFormVersion>(
                    table,
                  ),
                  BaseReferences<
                    _$DeviceDatabase,
                    $CachedFormVersionsTable,
                    CachedFormVersion
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedFormVersionsTableProcessedTableManager =
    ProcessedTableManager<
      _$DeviceDatabase,
      $CachedFormVersionsTable,
      CachedFormVersion,
      $$CachedFormVersionsTableFilterComposer,
      $$CachedFormVersionsTableOrderingComposer,
      $$CachedFormVersionsTableAnnotationComposer,
      $$CachedFormVersionsTableCreateCompanionBuilder,
      $$CachedFormVersionsTableUpdateCompanionBuilder,
      (
        CachedFormVersion,
        BaseReferences<
          _$DeviceDatabase,
          $CachedFormVersionsTable,
          CachedFormVersion
        >,
      ),
      CachedFormVersion,
      PrefetchHooks Function()
    >;
typedef $$DraftsTableCreateCompanionBuilder = DraftsCompanion Function({
  required String instanceId,
  required String formId,
  required String formVersion,
  required String instanceXml,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$DraftsTableUpdateCompanionBuilder = DraftsCompanion Function({
  Value<String> instanceId,
  Value<String> formId,
  Value<String> formVersion,
  Value<String> instanceXml,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$DraftsTableFilterComposer
    extends Composer<_$DeviceDatabase, $DraftsTable> {
  $$DraftsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get instanceId => $composableBuilder(
    column: $table.instanceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get formId => $composableBuilder(
    column: $table.formId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get formVersion => $composableBuilder(
    column: $table.formVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get instanceXml => $composableBuilder(
    column: $table.instanceXml,
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
}

class $$DraftsTableOrderingComposer
    extends Composer<_$DeviceDatabase, $DraftsTable> {
  $$DraftsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get instanceId => $composableBuilder(
    column: $table.instanceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get formId => $composableBuilder(
    column: $table.formId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get formVersion => $composableBuilder(
    column: $table.formVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get instanceXml => $composableBuilder(
    column: $table.instanceXml,
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
}

class $$DraftsTableAnnotationComposer
    extends Composer<_$DeviceDatabase, $DraftsTable> {
  $$DraftsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get instanceId => $composableBuilder(
    column: $table.instanceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get formId =>
      $composableBuilder(column: $table.formId, builder: (column) => column);

  GeneratedColumn<String> get formVersion => $composableBuilder(
    column: $table.formVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get instanceXml => $composableBuilder(
    column: $table.instanceXml,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$DraftsTableTableManager
    extends
        RootTableManager<
          _$DeviceDatabase,
          $DraftsTable,
          Draft,
          $$DraftsTableFilterComposer,
          $$DraftsTableOrderingComposer,
          $$DraftsTableAnnotationComposer,
          $$DraftsTableCreateCompanionBuilder,
          $$DraftsTableUpdateCompanionBuilder,
          (Draft, BaseReferences<_$DeviceDatabase, $DraftsTable, Draft>),
          Draft,
          PrefetchHooks Function()
        > {
  $$DraftsTableTableManager(_$DeviceDatabase db, $DraftsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DraftsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DraftsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DraftsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> instanceId = const Value.absent(),
                Value<String> formId = const Value.absent(),
                Value<String> formVersion = const Value.absent(),
                Value<String> instanceXml = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DraftsCompanion(
                instanceId: instanceId,
                formId: formId,
                formVersion: formVersion,
                instanceXml: instanceXml,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String instanceId,
                required String formId,
                required String formVersion,
                required String instanceXml,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => DraftsCompanion.insert(
                instanceId: instanceId,
                formId: formId,
                formVersion: formVersion,
                instanceXml: instanceXml,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DraftsTable, Draft>(table),
                  BaseReferences<_$DeviceDatabase, $DraftsTable, Draft>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DraftsTableProcessedTableManager =
    ProcessedTableManager<
      _$DeviceDatabase,
      $DraftsTable,
      Draft,
      $$DraftsTableFilterComposer,
      $$DraftsTableOrderingComposer,
      $$DraftsTableAnnotationComposer,
      $$DraftsTableCreateCompanionBuilder,
      $$DraftsTableUpdateCompanionBuilder,
      (Draft, BaseReferences<_$DeviceDatabase, $DraftsTable, Draft>),
      Draft,
      PrefetchHooks Function()
    >;
typedef $$OutboxTableCreateCompanionBuilder = OutboxCompanion Function({
  required String instanceId,
  required String formId,
  required String formVersion,
  required String instanceXml,
  Value<String> attachments,
  required OutboxState state,
  Value<int> attempts,
  Value<String?> lastError,
  Value<String?> lastErrorMessage,
  Value<DateTime?> nextAttemptAt,
  Value<String?> serverId,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<DateTime?> sentAt,
  Value<int> rowid,
});
typedef $$OutboxTableUpdateCompanionBuilder = OutboxCompanion Function({
  Value<String> instanceId,
  Value<String> formId,
  Value<String> formVersion,
  Value<String> instanceXml,
  Value<String> attachments,
  Value<OutboxState> state,
  Value<int> attempts,
  Value<String?> lastError,
  Value<String?> lastErrorMessage,
  Value<DateTime?> nextAttemptAt,
  Value<String?> serverId,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> sentAt,
  Value<int> rowid,
});

class $$OutboxTableFilterComposer
    extends Composer<_$DeviceDatabase, $OutboxTable> {
  $$OutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get instanceId => $composableBuilder(
    column: $table.instanceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get formId => $composableBuilder(
    column: $table.formId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get formVersion => $composableBuilder(
    column: $table.formVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get instanceXml => $composableBuilder(
    column: $table.instanceXml,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get attachments => $composableBuilder(
    column: $table.attachments,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<OutboxState, OutboxState, String> get state =>
      $composableBuilder(
        column: $table.state,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastErrorMessage => $composableBuilder(
    column: $table.lastErrorMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
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

  ColumnFilters<DateTime> get sentAt => $composableBuilder(
    column: $table.sentAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OutboxTableOrderingComposer
    extends Composer<_$DeviceDatabase, $OutboxTable> {
  $$OutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get instanceId => $composableBuilder(
    column: $table.instanceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get formId => $composableBuilder(
    column: $table.formId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get formVersion => $composableBuilder(
    column: $table.formVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get instanceXml => $composableBuilder(
    column: $table.instanceXml,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get attachments => $composableBuilder(
    column: $table.attachments,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastErrorMessage => $composableBuilder(
    column: $table.lastErrorMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
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

  ColumnOrderings<DateTime> get sentAt => $composableBuilder(
    column: $table.sentAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OutboxTableAnnotationComposer
    extends Composer<_$DeviceDatabase, $OutboxTable> {
  $$OutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get instanceId => $composableBuilder(
    column: $table.instanceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get formId =>
      $composableBuilder(column: $table.formId, builder: (column) => column);

  GeneratedColumn<String> get formVersion => $composableBuilder(
    column: $table.formVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get instanceXml => $composableBuilder(
    column: $table.instanceXml,
    builder: (column) => column,
  );

  GeneratedColumn<String> get attachments => $composableBuilder(
    column: $table.attachments,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<OutboxState, String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<String> get lastErrorMessage => $composableBuilder(
    column: $table.lastErrorMessage,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get sentAt =>
      $composableBuilder(column: $table.sentAt, builder: (column) => column);
}

class $$OutboxTableTableManager
    extends
        RootTableManager<
          _$DeviceDatabase,
          $OutboxTable,
          OutboxEntry,
          $$OutboxTableFilterComposer,
          $$OutboxTableOrderingComposer,
          $$OutboxTableAnnotationComposer,
          $$OutboxTableCreateCompanionBuilder,
          $$OutboxTableUpdateCompanionBuilder,
          (
            OutboxEntry,
            BaseReferences<_$DeviceDatabase, $OutboxTable, OutboxEntry>,
          ),
          OutboxEntry,
          PrefetchHooks Function()
        > {
  $$OutboxTableTableManager(_$DeviceDatabase db, $OutboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> instanceId = const Value.absent(),
                Value<String> formId = const Value.absent(),
                Value<String> formVersion = const Value.absent(),
                Value<String> instanceXml = const Value.absent(),
                Value<String> attachments = const Value.absent(),
                Value<OutboxState> state = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<String?> lastErrorMessage = const Value.absent(),
                Value<DateTime?> nextAttemptAt = const Value.absent(),
                Value<String?> serverId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> sentAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OutboxCompanion(
                instanceId: instanceId,
                formId: formId,
                formVersion: formVersion,
                instanceXml: instanceXml,
                attachments: attachments,
                state: state,
                attempts: attempts,
                lastError: lastError,
                lastErrorMessage: lastErrorMessage,
                nextAttemptAt: nextAttemptAt,
                serverId: serverId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                sentAt: sentAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String instanceId,
                required String formId,
                required String formVersion,
                required String instanceXml,
                Value<String> attachments = const Value.absent(),
                required OutboxState state,
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<String?> lastErrorMessage = const Value.absent(),
                Value<DateTime?> nextAttemptAt = const Value.absent(),
                Value<String?> serverId = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> sentAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OutboxCompanion.insert(
                instanceId: instanceId,
                formId: formId,
                formVersion: formVersion,
                instanceXml: instanceXml,
                attachments: attachments,
                state: state,
                attempts: attempts,
                lastError: lastError,
                lastErrorMessage: lastErrorMessage,
                nextAttemptAt: nextAttemptAt,
                serverId: serverId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                sentAt: sentAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OutboxTable, OutboxEntry>(table),
                  BaseReferences<_$DeviceDatabase, $OutboxTable, OutboxEntry>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$DeviceDatabase,
      $OutboxTable,
      OutboxEntry,
      $$OutboxTableFilterComposer,
      $$OutboxTableOrderingComposer,
      $$OutboxTableAnnotationComposer,
      $$OutboxTableCreateCompanionBuilder,
      $$OutboxTableUpdateCompanionBuilder,
      (
        OutboxEntry,
        BaseReferences<_$DeviceDatabase, $OutboxTable, OutboxEntry>,
      ),
      OutboxEntry,
      PrefetchHooks Function()
    >;
typedef $$DeviceSettingsTableCreateCompanionBuilder =
    DeviceSettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$DeviceSettingsTableUpdateCompanionBuilder =
    DeviceSettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$DeviceSettingsTableFilterComposer
    extends Composer<_$DeviceDatabase, $DeviceSettingsTable> {
  $$DeviceSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DeviceSettingsTableOrderingComposer
    extends Composer<_$DeviceDatabase, $DeviceSettingsTable> {
  $$DeviceSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DeviceSettingsTableAnnotationComposer
    extends Composer<_$DeviceDatabase, $DeviceSettingsTable> {
  $$DeviceSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$DeviceSettingsTableTableManager
    extends
        RootTableManager<
          _$DeviceDatabase,
          $DeviceSettingsTable,
          DeviceSetting,
          $$DeviceSettingsTableFilterComposer,
          $$DeviceSettingsTableOrderingComposer,
          $$DeviceSettingsTableAnnotationComposer,
          $$DeviceSettingsTableCreateCompanionBuilder,
          $$DeviceSettingsTableUpdateCompanionBuilder,
          (
            DeviceSetting,
            BaseReferences<
              _$DeviceDatabase,
              $DeviceSettingsTable,
              DeviceSetting
            >,
          ),
          DeviceSetting,
          PrefetchHooks Function()
        > {
  $$DeviceSettingsTableTableManager(
    _$DeviceDatabase db,
    $DeviceSettingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DeviceSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DeviceSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DeviceSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => DeviceSettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => DeviceSettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DeviceSettingsTable, DeviceSetting>(table),
                  BaseReferences<
                    _$DeviceDatabase,
                    $DeviceSettingsTable,
                    DeviceSetting
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DeviceSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$DeviceDatabase,
      $DeviceSettingsTable,
      DeviceSetting,
      $$DeviceSettingsTableFilterComposer,
      $$DeviceSettingsTableOrderingComposer,
      $$DeviceSettingsTableAnnotationComposer,
      $$DeviceSettingsTableCreateCompanionBuilder,
      $$DeviceSettingsTableUpdateCompanionBuilder,
      (
        DeviceSetting,
        BaseReferences<_$DeviceDatabase, $DeviceSettingsTable, DeviceSetting>,
      ),
      DeviceSetting,
      PrefetchHooks Function()
    >;

class $DeviceDatabaseManager {
  final _$DeviceDatabase _db;
  $DeviceDatabaseManager(this._db);
  $$CachedFormsTableTableManager get cachedForms =>
      $$CachedFormsTableTableManager(_db, _db.cachedForms);
  $$CachedFormVersionsTableTableManager get cachedFormVersions =>
      $$CachedFormVersionsTableTableManager(_db, _db.cachedFormVersions);
  $$DraftsTableTableManager get drafts =>
      $$DraftsTableTableManager(_db, _db.drafts);
  $$OutboxTableTableManager get outbox =>
      $$OutboxTableTableManager(_db, _db.outbox);
  $$DeviceSettingsTableTableManager get deviceSettings =>
      $$DeviceSettingsTableTableManager(_db, _db.deviceSettings);
}
