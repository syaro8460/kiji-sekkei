import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_app/models/article_draft.dart';
import 'package:flutter_app/models/article_template.dart';
import 'package:flutter_app/models/backup_data.dart';
import 'package:flutter_app/models/backup_manager.dart';
import 'package:flutter_app/storage/article_database.dart';
import 'package:flutter_test/flutter_test.dart';

const draftId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const firstTemplateId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const secondTemplateId = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';

ArticleDraft makeDraft() => ArticleDraft(
  id: draftId,
  title: '記事',
  articleType: '日記',
  questions: ['質問'],
  answers: {'質問': '回答'},
  tags: ['タグ'],
  updatedAt: DateTime.utc(2026, 11, 21, 12, 0, 0, 123, 456),
);

ArticleTemplate makeTemplate(String id, String name) =>
    ArticleTemplate(id: id, name: name, questions: ['質問']);

void main() {
  test('article survives reopening a database file', () async {
    final directory = await Directory.systemTemp.createTemp('articles-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/articles.sqlite');
    final draft = makeDraft();
    final writer = ArticleDatabase(NativeDatabase(file));
    try {
      await writer.saveDraft(draft);
    } finally {
      await writer.close();
    }

    final reader = ArticleDatabase(NativeDatabase(file));
    try {
      final saved = (await reader.listDrafts(DraftStatus.active)).single;
      expect(saved.toJson(), draft.toJson());
      expect(saved.updatedAt, draft.updatedAt);
    } finally {
      await reader.close();
    }
  });

  group('in-memory database', () {
    late ArticleDatabase database;

    setUp(() => database = ArticleDatabase(NativeDatabase.memory()));
    tearDown(() async => database.close());

    test(
      'trash retains the original deletion date and can be restored',
      () async {
        final now = DateTime(2026, 11, 21, 12);
        final draft = makeDraft();
        await database.saveDraft(draft);
        draft.title = '編集中';
        await database.saveDraft(draft);
        expect(await database.deletePermanently(draftId), 0);
        await database.moveToTrash(draftId, now: now);
        await database.moveToTrash(
          draftId,
          now: now.add(const Duration(days: 1)),
        );

        expect(await database.listDrafts(DraftStatus.active), isEmpty);
        final trashed = (await database.listDrafts(DraftStatus.trashed)).single;
        expect(trashed.title, '編集中');
        expect(trashed.deletedAt, now.toUtc());
        expect(
          await database.removeExpiredTrash(now: DateTime(2026, 12, 21, 12)),
          0,
        );

        await database.restoreDraft(draftId, now: now);
        final restored = (await database.listDrafts(DraftStatus.active)).single;
        expect(restored.deletedAt, isNull);
        expect(restored.updatedAt, now.toUtc());

        await database.moveToTrash(draftId, now: now);
        expect(
          await database.removeExpiredTrash(now: DateTime(2026, 12, 21, 13)),
          1,
        );
        expect(await database.listDrafts(DraftStatus.trashed), isEmpty);
      },
    );

    test(
      'template edits preserve order and invalid reorder preserves data',
      () async {
        await database.saveCustomTemplate(makeTemplate(firstTemplateId, '最初'));
        await database.saveCustomTemplate(makeTemplate(secondTemplateId, '次'));
        await database.reorderCustomTemplates([
          secondTemplateId,
          firstTemplateId,
        ]);
        await database.saveCustomTemplate(makeTemplate(secondTemplateId, '編集'));
        await expectLater(
          database.reorderCustomTemplates([firstTemplateId, firstTemplateId]),
          throwsArgumentError,
        );
        expect(
          (await database.listCustomTemplates()).map(
            (template) => template.name,
          ),
          ['編集', '最初'],
        );
      },
    );

    test('backup round trips and restores both tables atomically', () async {
      final now = DateTime.utc(2026, 11, 21);
      await database.saveDraft(makeDraft());
      await database.moveToTrash(draftId, now: now);
      await database.saveCustomTemplate(makeTemplate(firstTemplateId, '最初'));
      final bytes = await database.exportBackup(now: now);
      final backup = BackupManager().decode(bytes);
      expect(backup.drafts.single.status, DraftStatus.trashed);
      final invalid = BackupManager().encode(
        BackupData(
          schemaVersion: 1,
          exportedAt: now,
          drafts: [],
          templates: [backup.templates.single, backup.templates.single],
        ),
      );
      await expectLater(database.restoreBackup(invalid), throwsException);
      expect(await database.exportBackup(now: now), orderedEquals(bytes));

      await database.deletePermanently(draftId);
      await database.saveCustomTemplate(makeTemplate(secondTemplateId, '置換対象'));
      await database.restoreBackup(bytes);
      expect(await database.exportBackup(now: now), orderedEquals(bytes));
    });
  });
}
