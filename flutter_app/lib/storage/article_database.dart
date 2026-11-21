import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../models/article_draft.dart';
import '../models/article_template.dart';
import '../models/backup_data.dart';
import '../models/backup_manager.dart';
import '../models/json_compat.dart';

part 'article_database.g.dart';

@DataClassName('DraftRow')
class Drafts extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get articleType => text()();
  TextColumn get questions => text()();
  TextColumn get answers => text()();
  TextColumn get tags => text()();
  IntColumn get updatedAt => integer()();
  TextColumn get status => text()();
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('TemplateRow')
class CustomTemplates extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get questions => text()();
  TextColumn get iconName => text()();
  IntColumn get position => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Drafts, CustomTemplates])
class ArticleDatabase extends _$ArticleDatabase {
  ArticleDatabase(super.executor);

  ArticleDatabase.local() : this(driftDatabase(name: 'kiji_sekkei'));

  @override
  int get schemaVersion => 1;

  Future<void> saveDraft(ArticleDraft draft) async {
    await into(drafts).insertOnConflictUpdate(_draftRow(draft));
  }

  Future<List<ArticleDraft>> listDrafts(DraftStatus status) async {
    final query = select(drafts)
      ..where((row) => row.status.equals(status.name))
      ..orderBy([
        if (status == DraftStatus.trashed)
          (row) => OrderingTerm.desc(row.deletedAt),
        (row) => OrderingTerm.desc(row.updatedAt),
        (row) => OrderingTerm.asc(row.id),
      ]);
    return (await query.get()).map(_draft).toList();
  }

  Future<void> moveToTrash(String id, {DateTime? now}) async {
    final query = update(drafts)
      ..where(
        (row) =>
            row.id.equals(requireUuid(id, 'id')) &
            row.status.equals(DraftStatus.active.name),
      );
    await query.write(
      DraftsCompanion(
        status: Value(DraftStatus.trashed.name),
        deletedAt: Value((now ?? DateTime.now()).microsecondsSinceEpoch),
      ),
    );
  }

  Future<void> restoreDraft(String id, {DateTime? now}) async {
    final query = update(drafts)
      ..where(
        (row) =>
            row.id.equals(requireUuid(id, 'id')) &
            row.status.equals(DraftStatus.trashed.name),
      );
    await query.write(
      DraftsCompanion(
        status: Value(DraftStatus.active.name),
        deletedAt: const Value(null),
        updatedAt: Value((now ?? DateTime.now()).microsecondsSinceEpoch),
      ),
    );
  }

  Future<int> deletePermanently(String id) {
    return (delete(drafts)..where(
          (row) =>
              row.id.equals(requireUuid(id, 'id')) &
              row.status.equals(DraftStatus.trashed.name),
        ))
        .go();
  }

  Future<int> removeExpiredTrash({DateTime? now}) {
    final local = (now ?? DateTime.now()).toLocal();
    final cutoff = DateTime(
      local.year,
      local.month,
      local.day - 30,
      local.hour,
      local.minute,
      local.second,
      local.millisecond,
      local.microsecond,
    );
    return (delete(drafts)..where(
          (row) =>
              row.status.equals(DraftStatus.trashed.name) &
              row.deletedAt.isSmallerThanValue(cutoff.microsecondsSinceEpoch),
        ))
        .go();
  }

  Future<List<ArticleTemplate>> listCustomTemplates() async {
    return (await _orderedTemplates()).map(_template).toList();
  }

  Future<void> saveCustomTemplate(ArticleTemplate template) {
    return transaction(() async {
      final id = requireUuid(template.id, 'id');
      final rows = await _orderedTemplates();
      final existing = rows.where((row) => row.id == id).firstOrNull;
      final nextPosition = rows.isEmpty ? 0 : rows.last.position + 1;
      await into(customTemplates).insertOnConflictUpdate(
        _templateRow(template, existing?.position ?? nextPosition),
      );
    });
  }

  Future<int> deleteCustomTemplate(String id) {
    return (delete(
      customTemplates,
    )..where((row) => row.id.equals(requireUuid(id, 'id')))).go();
  }

  Future<void> reorderCustomTemplates(List<String> ids) {
    final order = ids.map((id) => requireUuid(id, 'id')).toList();
    return transaction(() async {
      final existingIds = (await _orderedTemplates())
          .map((row) => row.id)
          .toSet();
      if (order.length != existingIds.length ||
          order.toSet().length != existingIds.length ||
          !existingIds.containsAll(order)) {
        throw ArgumentError('Provide each custom template ID exactly once.');
      }
      for (final (position, id) in order.indexed) {
        await (update(customTemplates)..where((row) => row.id.equals(id)))
            .write(CustomTemplatesCompanion(position: Value(position)));
      }
    });
  }

  Future<List<int>> exportBackup({DateTime? now}) {
    return transaction(() async {
      final rows = await (select(
        drafts,
      )..orderBy([(row) => OrderingTerm.asc(row.id)])).get();
      return BackupManager().encode(
        BackupData(
          schemaVersion: BackupManager.supportedSchemaVersion,
          exportedAt: now ?? DateTime.now(),
          drafts: rows.map(_draft).toList(),
          templates: await listCustomTemplates(),
        ),
      );
    });
  }

  Future<void> restoreBackup(List<int> bytes) async {
    final backup = BackupManager().decode(bytes);
    final draftRows = backup.drafts.map(_draftRow).toList();
    final templateRows = [
      for (final (position, template) in backup.templates.indexed)
        _templateRow(template, position),
    ];
    await transaction(() async {
      await delete(drafts).go();
      await delete(customTemplates).go();
      await batch((batch) {
        batch.insertAll(drafts, draftRows);
        batch.insertAll(customTemplates, templateRows);
      });
    });
  }

  Future<List<TemplateRow>> _orderedTemplates() {
    return (select(
      customTemplates,
    )..orderBy([(row) => OrderingTerm.asc(row.position)])).get();
  }
}

DraftsCompanion _draftRow(ArticleDraft draft) => DraftsCompanion.insert(
  id: requireUuid(draft.id, 'id'),
  title: draft.title,
  articleType: draft.articleType,
  questions: jsonEncode(draft.questions),
  answers: jsonEncode(draft.answers),
  tags: jsonEncode(draft.tags),
  updatedAt: draft.updatedAt.microsecondsSinceEpoch,
  status: draft.status.name,
  deletedAt: Value(draft.deletedAt?.microsecondsSinceEpoch),
);

ArticleDraft _draft(DraftRow row) => ArticleDraft(
  id: row.id,
  title: row.title,
  articleType: row.articleType,
  questions: _decodeList(row.questions),
  answers: (jsonDecode(row.answers) as Map<String, dynamic>)
      .cast<String, String>(),
  tags: _decodeList(row.tags),
  updatedAt: DateTime.fromMicrosecondsSinceEpoch(row.updatedAt, isUtc: true),
  status: DraftStatus.values.byName(row.status),
  deletedAt: row.deletedAt == null
      ? null
      : DateTime.fromMicrosecondsSinceEpoch(row.deletedAt!, isUtc: true),
);

CustomTemplatesCompanion _templateRow(ArticleTemplate template, int position) {
  final id = requireUuid(template.id, 'id');
  if (template.isBuiltIn ||
      ArticleTemplate.builtInTemplates.any((builtIn) => builtIn.id == id)) {
    throw FormatException(
      'Built-in templates cannot be stored as custom templates.',
    );
  }
  return CustomTemplatesCompanion.insert(
    id: id,
    name: template.name,
    questions: jsonEncode(template.questions),
    iconName: template.iconName,
    position: position,
  );
}

ArticleTemplate _template(TemplateRow row) => ArticleTemplate(
  id: row.id,
  name: row.name,
  questions: _decodeList(row.questions),
  iconName: row.iconName,
);

List<String> _decodeList(String value) =>
    (jsonDecode(value) as List<dynamic>).cast<String>();
