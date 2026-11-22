import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/models/article_draft.dart';
import 'package:flutter_app/models/article_template.dart';
import 'package:flutter_app/storage/article_database.dart';
import 'package:flutter_app/storage/legacy_ios_migration.dart';
import 'package:flutter_test/flutter_test.dart';

const firstId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const secondId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const otherId = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
const channel = MethodChannel('kijisekkei/legacy_ios_migration');

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late ArticleDatabase database;
  Directory? migrationDirectory;

  setUp(() {
    database = ArticleDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
    await database.close();
    await migrationDirectory?.delete(recursive: true);
    migrationDirectory = null;
  });

  test('bridge data preserves microseconds, order and expired trash', () async {
    const updatedAt = 1700000000123456;
    const deletedAt = 1700000000234567;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      expect(call.method, 'read');
      return {
        'applicable': true,
        'version': 1,
        'drafts': [
          {
            'id': firstId.toUpperCase(),
            'title': '以前の記事',
            'articleType': '日記',
            'questions': ['二番目', '一番目'],
            'answers': {'一番目': '内容'},
            'tags': ['取材', '下書き'],
            'status': 'trashed',
            'updatedAtMicros': updatedAt,
            'deletedAtMicros': deletedAt,
          },
        ],
        'templates': [
          template(secondId, '先頭').toJson(),
          template(firstId, '末尾').toJson(),
        ],
      };
    });

    await migrateLegacyIosData(database);
    expect(await database.hasCompletedLegacyIosMigration(), isTrue);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(await database.removeExpiredTrash(now: DateTime.utc(2026)), 0);
    final draft = (await database.listDrafts(DraftStatus.trashed)).single;
    expect(draft.id, firstId);
    expect(draft.updatedAt.microsecondsSinceEpoch, updatedAt);
    expect(draft.deletedAt!.microsecondsSinceEpoch, deletedAt);
    expect(draft.questions, ['二番目', '一番目']);
    expect(draft.answers, {'一番目': '内容'});
    expect(draft.tags, ['取材', '下書き']);
    expect(
      (await database.listCustomTemplates()).map((template) => template.id),
      [secondId, firstId],
    );

    await database.deletePermanently(firstId);
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      fail('A completed migration must not read the legacy store again.');
    });
    await migrateLegacyIosData(database);
    expect(await database.listDrafts(DraftStatus.trashed), isEmpty);
  });

  test('a bridge read failure writes no receipt or local changes', () async {
    await database.saveDraft(draft(otherId, '以前からある記事'));
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'legacy_source_ambiguous');
    });
    await expectLater(
      migrateLegacyIosData(database),
      throwsA(isA<PlatformException>()),
    );
    expect(await database.hasCompletedLegacyIosMigration(), isFalse);
    expect(
      (await database.listDrafts(DraftStatus.active)).single.title,
      '以前からある記事',
    );
  });

  test(
    'a conflicting local template rolls back newly inserted drafts',
    () async {
      await database.saveCustomTemplate(template(firstId, '既存'));
      await expectLater(
        database.importLegacyIosData(
          [draft(secondId, '移行対象')],
          [template(firstId, '旧版')],
        ),
        throwsFormatException,
      );
      expect(await database.hasCompletedLegacyIosMigration(), isFalse);
      expect(await database.listDrafts(DraftStatus.active), isEmpty);
      expect((await database.listCustomTemplates()).single.name, '既存');
    },
  );

  test('normalizes legacy UUIDs before detecting duplicate rows', () async {
    await expectLater(
      database.importLegacyIosData([
        draft(firstId, '元'),
        draft(firstId.toUpperCase(), '重複'),
      ], []),
      throwsFormatException,
    );
    expect(await database.hasCompletedLegacyIosMigration(), isFalse);
    expect(await database.listDrafts(DraftStatus.active), isEmpty);
  });

  test(
    'an incompatible template order leaves existing positions untouched',
    () async {
      await database.saveCustomTemplate(template(secondId, '既存の先頭'));
      await database.saveCustomTemplate(template(firstId, '既存の末尾'));
      await expectLater(
        database.importLegacyIosData([], [
          template(firstId, '既存の末尾'),
          template(secondId, '既存の先頭'),
        ]),
        throwsFormatException,
      );
      expect(await database.hasCompletedLegacyIosMigration(), isFalse);
      expect((await database.listCustomTemplates()).map((item) => item.id), [
        secondId,
        firstId,
      ]);
    },
  );

  test('migration receipt survives reopening a version 1 database', () async {
    final directory = await Directory.systemTemp.createTemp('legacy-ios-db-');
    migrationDirectory = directory;
    final file = File('${directory.path}/test.db');
    await database.close();
    database = ArticleDatabase(
      NativeDatabase(
        file,
        setup: (db) {
          db.execute('''
          CREATE TABLE drafts (
            id TEXT NOT NULL PRIMARY KEY, title TEXT NOT NULL,
            article_type TEXT NOT NULL, questions TEXT NOT NULL,
            answers TEXT NOT NULL, tags TEXT NOT NULL,
            updated_at INTEGER NOT NULL, status TEXT NOT NULL, deleted_at INTEGER
          );
          CREATE TABLE custom_templates (
            id TEXT NOT NULL PRIMARY KEY, name TEXT NOT NULL,
            questions TEXT NOT NULL, icon_name TEXT NOT NULL, position INTEGER NOT NULL
          );
          PRAGMA user_version = 1;
        ''');
          db.execute('INSERT INTO drafts VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)', [
            firstId,
            '既存',
            '日記',
            '[]',
            '{}',
            '[]',
            1000000,
            'active',
            null,
          ]);
        },
      ),
    );
    expect(await database.hasCompletedLegacyIosMigration(), isFalse);
    await database.importLegacyIosData([
      draft(firstId, '既存'),
      draft(secondId, '追加'),
    ], []);
    await database.close();
    database = ArticleDatabase(NativeDatabase(file));
    await database.importLegacyIosData([draft(otherId, '再実行')], []);
    expect(await database.hasCompletedLegacyIosMigration(), isTrue);
    expect(
      (await database.listDrafts(DraftStatus.active)).map((item) => item.id),
      unorderedEquals([firstId, secondId]),
    );
  });
}

ArticleDraft draft(String id, String title) => ArticleDraft(
  id: id,
  title: title,
  articleType: '日記',
  questions: [],
  updatedAt: DateTime.fromMicrosecondsSinceEpoch(1000000, isUtc: true),
);

ArticleTemplate template(String id, String name) =>
    ArticleTemplate(id: id, name: name, questions: ['質問']);
