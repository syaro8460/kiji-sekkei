// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'article_database.dart';

// ignore_for_file: type=lint
class $DraftsTable extends Drafts with TableInfo<$DraftsTable, DraftRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DraftsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _articleTypeMeta = const VerificationMeta(
    'articleType',
  );
  @override
  late final GeneratedColumn<String> articleType = GeneratedColumn<String>(
    'article_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _questionsMeta = const VerificationMeta(
    'questions',
  );
  @override
  late final GeneratedColumn<String> questions = GeneratedColumn<String>(
    'questions',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _answersMeta = const VerificationMeta(
    'answers',
  );
  @override
  late final GeneratedColumn<String> answers = GeneratedColumn<String>(
    'answers',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
    'tags',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    articleType,
    questions,
    answers,
    tags,
    updatedAt,
    status,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'drafts';
  @override
  VerificationContext validateIntegrity(
    Insertable<DraftRow> instance, {
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
    if (data.containsKey('article_type')) {
      context.handle(
        _articleTypeMeta,
        articleType.isAcceptableOrUnknown(
          data['article_type']!,
          _articleTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_articleTypeMeta);
    }
    if (data.containsKey('questions')) {
      context.handle(
        _questionsMeta,
        questions.isAcceptableOrUnknown(data['questions']!, _questionsMeta),
      );
    } else if (isInserting) {
      context.missing(_questionsMeta);
    }
    if (data.containsKey('answers')) {
      context.handle(
        _answersMeta,
        answers.isAcceptableOrUnknown(data['answers']!, _answersMeta),
      );
    } else if (isInserting) {
      context.missing(_answersMeta);
    }
    if (data.containsKey('tags')) {
      context.handle(
        _tagsMeta,
        tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta),
      );
    } else if (isInserting) {
      context.missing(_tagsMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
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
  DraftRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DraftRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      articleType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}article_type'],
      )!,
      questions: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}questions'],
      )!,
      answers: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}answers'],
      )!,
      tags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $DraftsTable createAlias(String alias) {
    return $DraftsTable(attachedDatabase, alias);
  }
}

class DraftRow extends DataClass implements Insertable<DraftRow> {
  final String id;
  final String title;
  final String articleType;
  final String questions;
  final String answers;
  final String tags;
  final int updatedAt;
  final String status;
  final int? deletedAt;
  const DraftRow({
    required this.id,
    required this.title,
    required this.articleType,
    required this.questions,
    required this.answers,
    required this.tags,
    required this.updatedAt,
    required this.status,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['article_type'] = Variable<String>(articleType);
    map['questions'] = Variable<String>(questions);
    map['answers'] = Variable<String>(answers);
    map['tags'] = Variable<String>(tags);
    map['updated_at'] = Variable<int>(updatedAt);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    return map;
  }

  DraftsCompanion toCompanion(bool nullToAbsent) {
    return DraftsCompanion(
      id: Value(id),
      title: Value(title),
      articleType: Value(articleType),
      questions: Value(questions),
      answers: Value(answers),
      tags: Value(tags),
      updatedAt: Value(updatedAt),
      status: Value(status),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory DraftRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DraftRow(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      articleType: serializer.fromJson<String>(json['articleType']),
      questions: serializer.fromJson<String>(json['questions']),
      answers: serializer.fromJson<String>(json['answers']),
      tags: serializer.fromJson<String>(json['tags']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      status: serializer.fromJson<String>(json['status']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'articleType': serializer.toJson<String>(articleType),
      'questions': serializer.toJson<String>(questions),
      'answers': serializer.toJson<String>(answers),
      'tags': serializer.toJson<String>(tags),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'status': serializer.toJson<String>(status),
      'deletedAt': serializer.toJson<int?>(deletedAt),
    };
  }

  DraftRow copyWith({
    String? id,
    String? title,
    String? articleType,
    String? questions,
    String? answers,
    String? tags,
    int? updatedAt,
    String? status,
    Value<int?> deletedAt = const Value.absent(),
  }) => DraftRow(
    id: id ?? this.id,
    title: title ?? this.title,
    articleType: articleType ?? this.articleType,
    questions: questions ?? this.questions,
    answers: answers ?? this.answers,
    tags: tags ?? this.tags,
    updatedAt: updatedAt ?? this.updatedAt,
    status: status ?? this.status,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  DraftRow copyWithCompanion(DraftsCompanion data) {
    return DraftRow(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      articleType: data.articleType.present
          ? data.articleType.value
          : this.articleType,
      questions: data.questions.present ? data.questions.value : this.questions,
      answers: data.answers.present ? data.answers.value : this.answers,
      tags: data.tags.present ? data.tags.value : this.tags,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      status: data.status.present ? data.status.value : this.status,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DraftRow(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('articleType: $articleType, ')
          ..write('questions: $questions, ')
          ..write('answers: $answers, ')
          ..write('tags: $tags, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('status: $status, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    articleType,
    questions,
    answers,
    tags,
    updatedAt,
    status,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DraftRow &&
          other.id == this.id &&
          other.title == this.title &&
          other.articleType == this.articleType &&
          other.questions == this.questions &&
          other.answers == this.answers &&
          other.tags == this.tags &&
          other.updatedAt == this.updatedAt &&
          other.status == this.status &&
          other.deletedAt == this.deletedAt);
}

class DraftsCompanion extends UpdateCompanion<DraftRow> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> articleType;
  final Value<String> questions;
  final Value<String> answers;
  final Value<String> tags;
  final Value<int> updatedAt;
  final Value<String> status;
  final Value<int?> deletedAt;
  final Value<int> rowid;
  const DraftsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.articleType = const Value.absent(),
    this.questions = const Value.absent(),
    this.answers = const Value.absent(),
    this.tags = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DraftsCompanion.insert({
    required String id,
    required String title,
    required String articleType,
    required String questions,
    required String answers,
    required String tags,
    required int updatedAt,
    required String status,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       articleType = Value(articleType),
       questions = Value(questions),
       answers = Value(answers),
       tags = Value(tags),
       updatedAt = Value(updatedAt),
       status = Value(status);
  static Insertable<DraftRow> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? articleType,
    Expression<String>? questions,
    Expression<String>? answers,
    Expression<String>? tags,
    Expression<int>? updatedAt,
    Expression<String>? status,
    Expression<int>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (articleType != null) 'article_type': articleType,
      if (questions != null) 'questions': questions,
      if (answers != null) 'answers': answers,
      if (tags != null) 'tags': tags,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (status != null) 'status': status,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DraftsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String>? articleType,
    Value<String>? questions,
    Value<String>? answers,
    Value<String>? tags,
    Value<int>? updatedAt,
    Value<String>? status,
    Value<int?>? deletedAt,
    Value<int>? rowid,
  }) {
    return DraftsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      articleType: articleType ?? this.articleType,
      questions: questions ?? this.questions,
      answers: answers ?? this.answers,
      tags: tags ?? this.tags,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
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
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (articleType.present) {
      map['article_type'] = Variable<String>(articleType.value);
    }
    if (questions.present) {
      map['questions'] = Variable<String>(questions.value);
    }
    if (answers.present) {
      map['answers'] = Variable<String>(answers.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DraftsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('articleType: $articleType, ')
          ..write('questions: $questions, ')
          ..write('answers: $answers, ')
          ..write('tags: $tags, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('status: $status, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CustomTemplatesTable extends CustomTemplates
    with TableInfo<$CustomTemplatesTable, TemplateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CustomTemplatesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _questionsMeta = const VerificationMeta(
    'questions',
  );
  @override
  late final GeneratedColumn<String> questions = GeneratedColumn<String>(
    'questions',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iconNameMeta = const VerificationMeta(
    'iconName',
  );
  @override
  late final GeneratedColumn<String> iconName = GeneratedColumn<String>(
    'icon_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    questions,
    iconName,
    position,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'custom_templates';
  @override
  VerificationContext validateIntegrity(
    Insertable<TemplateRow> instance, {
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
    if (data.containsKey('questions')) {
      context.handle(
        _questionsMeta,
        questions.isAcceptableOrUnknown(data['questions']!, _questionsMeta),
      );
    } else if (isInserting) {
      context.missing(_questionsMeta);
    }
    if (data.containsKey('icon_name')) {
      context.handle(
        _iconNameMeta,
        iconName.isAcceptableOrUnknown(data['icon_name']!, _iconNameMeta),
      );
    } else if (isInserting) {
      context.missing(_iconNameMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TemplateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TemplateRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      questions: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}questions'],
      )!,
      iconName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon_name'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
    );
  }

  @override
  $CustomTemplatesTable createAlias(String alias) {
    return $CustomTemplatesTable(attachedDatabase, alias);
  }
}

class TemplateRow extends DataClass implements Insertable<TemplateRow> {
  final String id;
  final String name;
  final String questions;
  final String iconName;
  final int position;
  const TemplateRow({
    required this.id,
    required this.name,
    required this.questions,
    required this.iconName,
    required this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['questions'] = Variable<String>(questions);
    map['icon_name'] = Variable<String>(iconName);
    map['position'] = Variable<int>(position);
    return map;
  }

  CustomTemplatesCompanion toCompanion(bool nullToAbsent) {
    return CustomTemplatesCompanion(
      id: Value(id),
      name: Value(name),
      questions: Value(questions),
      iconName: Value(iconName),
      position: Value(position),
    );
  }

  factory TemplateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TemplateRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      questions: serializer.fromJson<String>(json['questions']),
      iconName: serializer.fromJson<String>(json['iconName']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'questions': serializer.toJson<String>(questions),
      'iconName': serializer.toJson<String>(iconName),
      'position': serializer.toJson<int>(position),
    };
  }

  TemplateRow copyWith({
    String? id,
    String? name,
    String? questions,
    String? iconName,
    int? position,
  }) => TemplateRow(
    id: id ?? this.id,
    name: name ?? this.name,
    questions: questions ?? this.questions,
    iconName: iconName ?? this.iconName,
    position: position ?? this.position,
  );
  TemplateRow copyWithCompanion(CustomTemplatesCompanion data) {
    return TemplateRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      questions: data.questions.present ? data.questions.value : this.questions,
      iconName: data.iconName.present ? data.iconName.value : this.iconName,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TemplateRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('questions: $questions, ')
          ..write('iconName: $iconName, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, questions, iconName, position);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TemplateRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.questions == this.questions &&
          other.iconName == this.iconName &&
          other.position == this.position);
}

class CustomTemplatesCompanion extends UpdateCompanion<TemplateRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> questions;
  final Value<String> iconName;
  final Value<int> position;
  final Value<int> rowid;
  const CustomTemplatesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.questions = const Value.absent(),
    this.iconName = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CustomTemplatesCompanion.insert({
    required String id,
    required String name,
    required String questions,
    required String iconName,
    required int position,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       questions = Value(questions),
       iconName = Value(iconName),
       position = Value(position);
  static Insertable<TemplateRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? questions,
    Expression<String>? iconName,
    Expression<int>? position,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (questions != null) 'questions': questions,
      if (iconName != null) 'icon_name': iconName,
      if (position != null) 'position': position,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CustomTemplatesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? questions,
    Value<String>? iconName,
    Value<int>? position,
    Value<int>? rowid,
  }) {
    return CustomTemplatesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      questions: questions ?? this.questions,
      iconName: iconName ?? this.iconName,
      position: position ?? this.position,
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
    if (questions.present) {
      map['questions'] = Variable<String>(questions.value);
    }
    if (iconName.present) {
      map['icon_name'] = Variable<String>(iconName.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CustomTemplatesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('questions: $questions, ')
          ..write('iconName: $iconName, ')
          ..write('position: $position, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MigrationReceiptsTable extends MigrationReceipts
    with TableInfo<$MigrationReceiptsTable, MigrationReceipt> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MigrationReceiptsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'migration_receipts';
  @override
  VerificationContext validateIntegrity(
    Insertable<MigrationReceipt> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MigrationReceipt map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MigrationReceipt(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
    );
  }

  @override
  $MigrationReceiptsTable createAlias(String alias) {
    return $MigrationReceiptsTable(attachedDatabase, alias);
  }
}

class MigrationReceipt extends DataClass
    implements Insertable<MigrationReceipt> {
  final String id;
  const MigrationReceipt({required this.id});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    return map;
  }

  MigrationReceiptsCompanion toCompanion(bool nullToAbsent) {
    return MigrationReceiptsCompanion(id: Value(id));
  }

  factory MigrationReceipt.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MigrationReceipt(id: serializer.fromJson<String>(json['id']));
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{'id': serializer.toJson<String>(id)};
  }

  MigrationReceipt copyWith({String? id}) =>
      MigrationReceipt(id: id ?? this.id);
  MigrationReceipt copyWithCompanion(MigrationReceiptsCompanion data) {
    return MigrationReceipt(id: data.id.present ? data.id.value : this.id);
  }

  @override
  String toString() {
    return (StringBuffer('MigrationReceipt(')
          ..write('id: $id')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => id.hashCode;
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MigrationReceipt && other.id == this.id);
}

class MigrationReceiptsCompanion extends UpdateCompanion<MigrationReceipt> {
  final Value<String> id;
  final Value<int> rowid;
  const MigrationReceiptsCompanion({
    this.id = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MigrationReceiptsCompanion.insert({
    required String id,
    this.rowid = const Value.absent(),
  }) : id = Value(id);
  static Insertable<MigrationReceipt> custom({
    Expression<String>? id,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MigrationReceiptsCompanion copyWith({Value<String>? id, Value<int>? rowid}) {
    return MigrationReceiptsCompanion(
      id: id ?? this.id,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MigrationReceiptsCompanion(')
          ..write('id: $id, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$ArticleDatabase extends GeneratedDatabase {
  _$ArticleDatabase(QueryExecutor e) : super(e);
  $ArticleDatabaseManager get managers => $ArticleDatabaseManager(this);
  late final $DraftsTable drafts = $DraftsTable(this);
  late final $CustomTemplatesTable customTemplates = $CustomTemplatesTable(
    this,
  );
  late final $MigrationReceiptsTable migrationReceipts =
      $MigrationReceiptsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    drafts,
    customTemplates,
    migrationReceipts,
  ];
}

typedef $$DraftsTableCreateCompanionBuilder = DraftsCompanion Function({
  required String id,
  required String title,
  required String articleType,
  required String questions,
  required String answers,
  required String tags,
  required int updatedAt,
  required String status,
  Value<int?> deletedAt,
  Value<int> rowid,
});
typedef $$DraftsTableUpdateCompanionBuilder = DraftsCompanion Function({
  Value<String> id,
  Value<String> title,
  Value<String> articleType,
  Value<String> questions,
  Value<String> answers,
  Value<String> tags,
  Value<int> updatedAt,
  Value<String> status,
  Value<int?> deletedAt,
  Value<int> rowid,
});

class $$DraftsTableFilterComposer
    extends Composer<_$ArticleDatabase, $DraftsTable> {
  $$DraftsTableFilterComposer({
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

  ColumnFilters<String> get articleType => $composableBuilder(
    column: $table.articleType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get questions => $composableBuilder(
    column: $table.questions,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get answers => $composableBuilder(
    column: $table.answers,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DraftsTableOrderingComposer
    extends Composer<_$ArticleDatabase, $DraftsTable> {
  $$DraftsTableOrderingComposer({
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

  ColumnOrderings<String> get articleType => $composableBuilder(
    column: $table.articleType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get questions => $composableBuilder(
    column: $table.questions,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get answers => $composableBuilder(
    column: $table.answers,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DraftsTableAnnotationComposer
    extends Composer<_$ArticleDatabase, $DraftsTable> {
  $$DraftsTableAnnotationComposer({
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

  GeneratedColumn<String> get articleType => $composableBuilder(
    column: $table.articleType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get questions =>
      $composableBuilder(column: $table.questions, builder: (column) => column);

  GeneratedColumn<String> get answers =>
      $composableBuilder(column: $table.answers, builder: (column) => column);

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$DraftsTableTableManager
    extends
        RootTableManager<
          _$ArticleDatabase,
          $DraftsTable,
          DraftRow,
          $$DraftsTableFilterComposer,
          $$DraftsTableOrderingComposer,
          $$DraftsTableAnnotationComposer,
          $$DraftsTableCreateCompanionBuilder,
          $$DraftsTableUpdateCompanionBuilder,
          (DraftRow, BaseReferences<_$ArticleDatabase, $DraftsTable, DraftRow>),
          DraftRow,
          PrefetchHooks Function()
        > {
  $$DraftsTableTableManager(_$ArticleDatabase db, $DraftsTable table)
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
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> articleType = const Value.absent(),
                Value<String> questions = const Value.absent(),
                Value<String> answers = const Value.absent(),
                Value<String> tags = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DraftsCompanion(
                id: id,
                title: title,
                articleType: articleType,
                questions: questions,
                answers: answers,
                tags: tags,
                updatedAt: updatedAt,
                status: status,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                required String articleType,
                required String questions,
                required String answers,
                required String tags,
                required int updatedAt,
                required String status,
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DraftsCompanion.insert(
                id: id,
                title: title,
                articleType: articleType,
                questions: questions,
                answers: answers,
                tags: tags,
                updatedAt: updatedAt,
                status: status,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DraftsTable, DraftRow>(table),
                  BaseReferences<_$ArticleDatabase, $DraftsTable, DraftRow>(
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
      _$ArticleDatabase,
      $DraftsTable,
      DraftRow,
      $$DraftsTableFilterComposer,
      $$DraftsTableOrderingComposer,
      $$DraftsTableAnnotationComposer,
      $$DraftsTableCreateCompanionBuilder,
      $$DraftsTableUpdateCompanionBuilder,
      (DraftRow, BaseReferences<_$ArticleDatabase, $DraftsTable, DraftRow>),
      DraftRow,
      PrefetchHooks Function()
    >;
typedef $$CustomTemplatesTableCreateCompanionBuilder =
    CustomTemplatesCompanion Function({
      required String id,
      required String name,
      required String questions,
      required String iconName,
      required int position,
      Value<int> rowid,
    });
typedef $$CustomTemplatesTableUpdateCompanionBuilder =
    CustomTemplatesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> questions,
      Value<String> iconName,
      Value<int> position,
      Value<int> rowid,
    });

class $$CustomTemplatesTableFilterComposer
    extends Composer<_$ArticleDatabase, $CustomTemplatesTable> {
  $$CustomTemplatesTableFilterComposer({
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

  ColumnFilters<String> get questions => $composableBuilder(
    column: $table.questions,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get iconName => $composableBuilder(
    column: $table.iconName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CustomTemplatesTableOrderingComposer
    extends Composer<_$ArticleDatabase, $CustomTemplatesTable> {
  $$CustomTemplatesTableOrderingComposer({
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

  ColumnOrderings<String> get questions => $composableBuilder(
    column: $table.questions,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get iconName => $composableBuilder(
    column: $table.iconName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CustomTemplatesTableAnnotationComposer
    extends Composer<_$ArticleDatabase, $CustomTemplatesTable> {
  $$CustomTemplatesTableAnnotationComposer({
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

  GeneratedColumn<String> get questions =>
      $composableBuilder(column: $table.questions, builder: (column) => column);

  GeneratedColumn<String> get iconName =>
      $composableBuilder(column: $table.iconName, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);
}

class $$CustomTemplatesTableTableManager
    extends
        RootTableManager<
          _$ArticleDatabase,
          $CustomTemplatesTable,
          TemplateRow,
          $$CustomTemplatesTableFilterComposer,
          $$CustomTemplatesTableOrderingComposer,
          $$CustomTemplatesTableAnnotationComposer,
          $$CustomTemplatesTableCreateCompanionBuilder,
          $$CustomTemplatesTableUpdateCompanionBuilder,
          (
            TemplateRow,
            BaseReferences<
              _$ArticleDatabase,
              $CustomTemplatesTable,
              TemplateRow
            >,
          ),
          TemplateRow,
          PrefetchHooks Function()
        > {
  $$CustomTemplatesTableTableManager(
    _$ArticleDatabase db,
    $CustomTemplatesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CustomTemplatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CustomTemplatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CustomTemplatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> questions = const Value.absent(),
                Value<String> iconName = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CustomTemplatesCompanion(
                id: id,
                name: name,
                questions: questions,
                iconName: iconName,
                position: position,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String questions,
                required String iconName,
                required int position,
                Value<int> rowid = const Value.absent(),
              }) => CustomTemplatesCompanion.insert(
                id: id,
                name: name,
                questions: questions,
                iconName: iconName,
                position: position,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CustomTemplatesTable, TemplateRow>(table),
                  BaseReferences<
                    _$ArticleDatabase,
                    $CustomTemplatesTable,
                    TemplateRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CustomTemplatesTableProcessedTableManager =
    ProcessedTableManager<
      _$ArticleDatabase,
      $CustomTemplatesTable,
      TemplateRow,
      $$CustomTemplatesTableFilterComposer,
      $$CustomTemplatesTableOrderingComposer,
      $$CustomTemplatesTableAnnotationComposer,
      $$CustomTemplatesTableCreateCompanionBuilder,
      $$CustomTemplatesTableUpdateCompanionBuilder,
      (
        TemplateRow,
        BaseReferences<_$ArticleDatabase, $CustomTemplatesTable, TemplateRow>,
      ),
      TemplateRow,
      PrefetchHooks Function()
    >;
typedef $$MigrationReceiptsTableCreateCompanionBuilder =
    MigrationReceiptsCompanion Function({required String id, Value<int> rowid});
typedef $$MigrationReceiptsTableUpdateCompanionBuilder =
    MigrationReceiptsCompanion Function({Value<String> id, Value<int> rowid});

class $$MigrationReceiptsTableFilterComposer
    extends Composer<_$ArticleDatabase, $MigrationReceiptsTable> {
  $$MigrationReceiptsTableFilterComposer({
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
}

class $$MigrationReceiptsTableOrderingComposer
    extends Composer<_$ArticleDatabase, $MigrationReceiptsTable> {
  $$MigrationReceiptsTableOrderingComposer({
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
}

class $$MigrationReceiptsTableAnnotationComposer
    extends Composer<_$ArticleDatabase, $MigrationReceiptsTable> {
  $$MigrationReceiptsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);
}

class $$MigrationReceiptsTableTableManager
    extends
        RootTableManager<
          _$ArticleDatabase,
          $MigrationReceiptsTable,
          MigrationReceipt,
          $$MigrationReceiptsTableFilterComposer,
          $$MigrationReceiptsTableOrderingComposer,
          $$MigrationReceiptsTableAnnotationComposer,
          $$MigrationReceiptsTableCreateCompanionBuilder,
          $$MigrationReceiptsTableUpdateCompanionBuilder,
          (
            MigrationReceipt,
            BaseReferences<
              _$ArticleDatabase,
              $MigrationReceiptsTable,
              MigrationReceipt
            >,
          ),
          MigrationReceipt,
          PrefetchHooks Function()
        > {
  $$MigrationReceiptsTableTableManager(
    _$ArticleDatabase db,
    $MigrationReceiptsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MigrationReceiptsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MigrationReceiptsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MigrationReceiptsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => MigrationReceiptsCompanion(id: id, rowid: rowid),
          createCompanionCallback: ({
            required String id,
            Value<int> rowid = const Value.absent(),
          }) => MigrationReceiptsCompanion.insert(id: id, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MigrationReceiptsTable, MigrationReceipt>(table),
                  BaseReferences<
                    _$ArticleDatabase,
                    $MigrationReceiptsTable,
                    MigrationReceipt
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MigrationReceiptsTableProcessedTableManager =
    ProcessedTableManager<
      _$ArticleDatabase,
      $MigrationReceiptsTable,
      MigrationReceipt,
      $$MigrationReceiptsTableFilterComposer,
      $$MigrationReceiptsTableOrderingComposer,
      $$MigrationReceiptsTableAnnotationComposer,
      $$MigrationReceiptsTableCreateCompanionBuilder,
      $$MigrationReceiptsTableUpdateCompanionBuilder,
      (
        MigrationReceipt,
        BaseReferences<
          _$ArticleDatabase,
          $MigrationReceiptsTable,
          MigrationReceipt
        >,
      ),
      MigrationReceipt,
      PrefetchHooks Function()
    >;

class $ArticleDatabaseManager {
  final _$ArticleDatabase _db;
  $ArticleDatabaseManager(this._db);
  $$DraftsTableTableManager get drafts =>
      $$DraftsTableTableManager(_db, _db.drafts);
  $$CustomTemplatesTableTableManager get customTemplates =>
      $$CustomTemplatesTableTableManager(_db, _db.customTemplates);
  $$MigrationReceiptsTableTableManager get migrationReceipts =>
      $$MigrationReceiptsTableTableManager(_db, _db.migrationReceipts);
}
