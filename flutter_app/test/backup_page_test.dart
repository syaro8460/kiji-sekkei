import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_app/models/article_draft.dart';
import 'package:flutter_app/models/backup_data.dart';
import 'package:flutter_app/models/backup_manager.dart';
import 'package:flutter_app/screens/backup_page.dart';
import 'package:flutter_app/storage/article_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('backup export, cancel, invalid file, and confirmed restore', (
    tester,
  ) async {
    final database = ArticleDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final draft = ArticleDraft(
      id: 'c82ad43a-527c-4717-9c7a-8bc10d6730ae',
      title: '現在の記事',
      articleType: '日記',
      questions: [],
    );
    await tester.runAsync(() => database.saveDraft(draft));
    Uint8List? exported;
    Uint8List? file;
    bool? restored;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                restored = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (context) => BackupPage(
                      database: database,
                      pickBackup: () async => file,
                      saveBackup: (filename, bytes) async {
                        expect(
                          filename,
                          matches(r'^kiji-sekkei-\d{4}-\d{2}-\d{2}\.json$'),
                        );
                        exported = bytes;
                        return true;
                      },
                    ),
                  ),
                );
              },
              child: const Text('開く'),
            ),
          ),
        ),
      ),
    );

    Future<void> tap(String label, {bool dialog = false}) async {
      await tester.tap(find.text(label));
      if (dialog) {
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      } else {
        await tester.pumpAndSettle();
      }
    }

    await tap('開く');
    await tap('バックアップを書き出す');
    expect(BackupManager().decode(exported!).drafts.single.title, '現在の記事');

    await tap('バックアップを読み込む');
    expect(find.text('バックアップを復元しますか？'), findsNothing);

    file = Uint8List.fromList([1, 2, 3]);
    await tap('バックアップを読み込む');
    expect(find.text('バックアップを復元しますか？'), findsNothing);
    expect(find.text('対応するJSONバックアップを選んでください。'), findsOneWidget);

    final incoming = ArticleDraft(
      id: '5d35cccd-ff13-4bbe-a4e0-3effabff9b75',
      title: '復元した記事',
      articleType: '日記',
      questions: [],
    );
    file = BackupManager().encode(
      BackupData(
        schemaVersion: 1,
        exportedAt: DateTime.utc(2026),
        drafts: [incoming],
        templates: [],
      ),
    );
    await tap('バックアップを読み込む', dialog: true);
    await tap('キャンセル');
    final afterCancel = await tester.runAsync(
      () => database.listDrafts(DraftStatus.active),
    );
    expect(afterCancel!.single.title, '現在の記事');

    await tap('バックアップを読み込む', dialog: true);
    await tap('復元する');
    expect(restored, isTrue);
    final afterRestore = await tester.runAsync(
      () => database.listDrafts(DraftStatus.active),
    );
    expect(afterRestore!.single.title, '復元した記事');
  });
}
