import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb, listEquals, mapEquals;

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

class MigrationReceipts extends Table {
  TextColumn get id => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Drafts, CustomTemplates, MigrationReceipts])
class ArticleDatabase extends _$ArticleDatabase {
  ArticleDatabase(super.executor);

  ArticleDatabase.local()
    : this(
        driftDatabase(
          name: 'kiji_sekkei',
          web: DriftWebOptions(
            sqlite3Wasm: Uri.parse('sqlite3.wasm'),
            driftWorker: Uri.parse('drift_worker.js'),
            onResult: (result) {
              if (result.chosenImplementation ==
                  WasmStorageImplementation.inMemory) {
                unawaited(result.resolvedExecutor.close());
                throw UnsupportedError(
                  'Persistent browser storage is unavailable.',
                );
              }
            },
          ),
        ),
      );

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 2) await migrator.createTable(migrationReceipts);
    },
  );

  static const _legacyIosReceipt = 'swiftui-ios-1.0';

  Future<bool> hasCompletedLegacyIosMigration() async =>
      await (select(
        migrationReceipts,
      )..where((row) => row.id.equals(_legacyIosReceipt))).getSingleOrNull() !=
      null;

  Future<void> importLegacyIosData(
    List<ArticleDraft> sourceDrafts,
    List<ArticleTemplate> sourceTemplates,
  ) {
    return transaction(() async {
      if (await hasCompletedLegacyIosMigration()) return;

      final expectedDrafts = {
        for (final draft in sourceDrafts) requireUuid(draft.id, 'id'): draft,
      };
      final expectedTemplates = {
        for (final template in sourceTemplates)
          requireUuid(template.id, 'id'): template,
      };
      if (expectedDrafts.length != sourceDrafts.length ||
          expectedTemplates.length != sourceTemplates.length) {
        throw const FormatException('Duplicate IDs in legacy data.');
      }

      final localDrafts = {
        for (final row in await select(drafts).get()) row.id: row,
      };
      for (final entry in expectedDrafts.entries) {
        final existing = localDrafts[entry.key];
        if (existing == null) {
          await into(drafts).insert(_draftRow(entry.value));
        } else if (!_matchesLegacyDraft(existing, entry.value)) {
          throw const FormatException(
            'Legacy article conflicts with local data.',
          );
        }
      }

      final ordered = await _orderedTemplates();
      final localTemplates = {for (final row in ordered) row.id: row};
      var nextPosition = ordered.isEmpty ? 0 : ordered.last.position + 1;
      for (final entry in expectedTemplates.entries) {
        final expected = _templateRow(entry.value, nextPosition);
        final existing = localTemplates[entry.key];
        if (existing == null) {
          await into(customTemplates).insert(expected);
          nextPosition++;
        } else if (!_matchesLegacyTemplate(existing, entry.value)) {
          throw const FormatException(
            'Legacy template conflicts with local data.',
          );
        }
      }

      final verifiedDrafts = {
        for (final row in await select(drafts).get()) row.id: row,
      };
      final verifiedTemplates = (await _orderedTemplates())
          .where((row) => expectedTemplates.containsKey(row.id))
          .toList();
      if (!expectedDrafts.entries.every((entry) {
            final row = verifiedDrafts[entry.key];
            return row != null && _matchesLegacyDraft(row, entry.value);
          }) ||
          !listEquals(
            verifiedTemplates.map((row) => row.id).toList(),
            expectedTemplates.keys.toList(),
          ) ||
          !verifiedTemplates.every(
            (row) => _matchesLegacyTemplate(row, expectedTemplates[row.id]!),
          )) {
        throw const FormatException('Legacy migration verification failed.');
      }

      await into(migrationReceipts)
          .insert(const MigrationReceipt(id: _legacyIosReceipt));
    });
  }

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

  bool get autoRemovesExpiredTrash =>
      kIsWeb || defaultTargetPlatform != TargetPlatform.iOS;

  Future<int> removeExpiredTrash({DateTime? now}) {
    if (!autoRemovesExpiredTrash) return Future.value(0);
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
    await restoreBackupData(BackupManager().decode(bytes));
  }

  Future<void> restoreBackupData(BackupData backup) async {
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

bool _matchesLegacyDraft(DraftRow row, ArticleDraft source) {
  final draft = _draft(row);
  return draft.title == source.title &&
      draft.articleType == source.articleType &&
      listEquals(draft.questions, source.questions) &&
      mapEquals(draft.answers, source.answers) &&
      listEquals(draft.tags, source.tags) &&
      draft.updatedAt.isAtSameMomentAs(source.updatedAt) &&
      draft.status == source.status &&
      draft.deletedAt?.microsecondsSinceEpoch ==
          source.deletedAt?.microsecondsSinceEpoch;
}

bool _matchesLegacyTemplate(TemplateRow row, ArticleTemplate source) =>
    row.name == source.name &&
    row.iconName == source.iconName &&
    listEquals(_decodeList(row.questions), source.questions);
