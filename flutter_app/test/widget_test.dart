import 'package:drift/native.dart';
import 'package:flutter_app/main.dart';
import 'package:flutter_app/models/article_draft.dart';
import 'package:flutter_app/models/article_template.dart';
import 'package:flutter_app/models/backup_manager.dart';
import 'package:flutter_app/storage/article_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('creates and edits a saved article from the list', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = ArticleDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.runAsync(() => database.listDrafts(DraftStatus.active));
    await tester.pumpWidget(MyApp(database: database));
    await tester.pumpAndSettle();
    expect(find.text('記事はまだありません'), findsOneWidget);
    final listContext = tester.element(find.text('記事設計'));
    expect(Localizations.localeOf(listContext), const Locale('ja', 'JP'));
    expect(MaterialLocalizations.of(listContext).backButtonTooltip, '戻る');

    await tester.tap(find.text('新しい記事'));
    await tester.pumpAndSettle();
    final template = ArticleTemplate.builtInTemplates.first;
    await tester.tap(find.text(template.name));
    await tester.pumpAndSettle();

    final title = find.byType(TextFormField).first;
    await tester.enterText(title, '最初の記事');
    await tester.enterText(find.byType(TextFormField).at(1), '記事のメモ');
    await tester.tap(find.byTooltip('プレビュー'));
    await tester.pumpAndSettle();
    expect(find.text('記事のプレビュー'), findsOneWidget);
    expect(find.text('記事のメモ'), findsOneWidget);
    await tester.tap(find.byTooltip('戻る'));
    await tester.pumpAndSettle();

    final save = find.widgetWithText(TextButton, '保存');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('最初の記事'), findsOneWidget);

    await tester.tap(find.text('最初の記事'));
    await tester.pumpAndSettle();
    expect(find.text('記事のメモ'), findsOneWidget);
    await tester.enterText(title, '編集した記事');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('編集した記事'), findsOneWidget);
    expect(find.text('最初の記事'), findsNothing);

    final drafts = await tester.runAsync(
      () => database.listDrafts(DraftStatus.active),
    );
    expect(drafts!.single.title, '編集した記事');
    expect(drafts.single.answers[template.questions.first], '記事のメモ');
  });

  testWidgets('moves, restores, and permanently deletes an article', (
    tester,
  ) async {
    final database = ArticleDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    const id = 'dccccccc-cccc-4ccc-8ccc-cccccccccccc';
    const expiredId = 'eccccccc-cccc-4ccc-8ccc-cccccccccccc';
    await tester.runAsync(() async {
      await database.saveDraft(
        ArticleDraft(id: id, title: '保存した記事', articleType: '日記', questions: []),
      );
      await database.saveDraft(
        ArticleDraft(
          id: expiredId,
          title: '期限切れの記事',
          articleType: '日記',
          questions: [],
        ),
      );
      await database.moveToTrash(expiredId, now: DateTime(2000));
    });
    await tester.pumpWidget(MyApp(database: database));
    await tester.pumpAndSettle();

    Future<void> tap(Finder finder) async {
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    Future<void> moveToTrash() async {
      await tap(find.byTooltip('記事の操作'));
      await tap(find.text('ゴミ箱に移動'));
      expect(find.text('記事はまだありません'), findsOneWidget);
      await tap(find.byTooltip('ゴミ箱'));
      expect(find.text('保存した記事'), findsOneWidget);
      expect(find.text('期限切れの記事'), findsNothing);
    }

    await moveToTrash();
    await tap(find.byTooltip('ゴミ箱の記事の操作'));
    await tap(find.text('復元'));
    expect(find.text('ゴミ箱は空です'), findsOneWidget);
    await tap(find.byTooltip('戻る'));
    expect(find.text('保存した記事'), findsOneWidget);

    await moveToTrash();
    await tap(find.byTooltip('ゴミ箱の記事の操作'));
    await tap(find.text('完全に削除'));
    await tap(find.text('キャンセル'));
    expect(find.text('保存した記事'), findsOneWidget);
    await tap(find.byTooltip('ゴミ箱の記事の操作'));
    await tap(find.text('完全に削除'));
    expect(find.text('記事を完全に削除しますか？'), findsOneWidget);
    await tap(find.text('完全に削除'));
    expect(find.text('ゴミ箱は空です'), findsOneWidget);

    final backup = await tester.runAsync(database.exportBackup);
    expect(BackupManager().decode(backup!).drafts, isEmpty);
  });

  testWidgets('manages custom templates and creates an article from one', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(700, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = ArticleDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.runAsync(() => database.listCustomTemplates());
    await tester.pumpWidget(MyApp(database: database));
    await tester.pumpAndSettle();

    Future<void> tap(Finder finder) async {
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    Future<void> fill(String name, String questions) async {
      await tester.enterText(find.byType(TextFormField).first, name);
      await tester.enterText(find.byType(TextFormField).last, questions);
      await tap(find.text('保存'));
    }

    await tap(find.byTooltip('テンプレート管理'));
    expect(find.text('カスタムテンプレートはまだありません'), findsOneWidget);
    await tap(find.text('新しいテンプレート'));
    await fill('インタビュー', '目的\n相手');
    await tap(find.text('新しいテンプレート'));
    await fill('ふりかえり', '気づき');
    await tap(find.byTooltip('ふりかえりの操作'));
    await tap(find.text('上に移動'));
    expect(
      tester.getTopLeft(find.text('ふりかえり')).dy,
      lessThan(tester.getTopLeft(find.text('インタビュー')).dy),
    );

    await tap(find.text('ふりかえり'));
    await fill('週次レビュー', '気づき\n次にやること');
    await tap(find.byTooltip('戻る'));
    await tap(find.text('新しい記事'));
    await tap(find.text('週次レビュー'));
    expect(find.text('次にやること'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, '今週の記事');
    final save = find.widgetWithText(TextButton, '保存');
    await tester.ensureVisible(save);
    await tap(save);

    await tap(find.byTooltip('テンプレート管理'));
    await tap(find.byTooltip('週次レビューの操作'));
    await tap(find.text('削除'));
    await tap(find.text('キャンセル'));
    expect(find.text('週次レビュー'), findsOneWidget);
    await tap(find.byTooltip('週次レビューの操作'));
    await tap(find.text('削除'));
    await tap(find.text('削除'));
    expect(find.text('週次レビュー'), findsNothing);
    await tap(find.byTooltip('戻る'));

    await tap(find.text('今週の記事'));
    expect(find.text('次にやること'), findsOneWidget);
  });

  testWidgets(
    'saves and removes tags, and searches titles, answers, and tags',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final database = ArticleDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      const id = 'f8888888-8888-4888-8888-888888888888';
      await tester.runAsync(() async {
        await database.saveDraft(
          ArticleDraft(
            id: id,
            title: 'Release Notes',
            articleType: '日記',
            questions: ['概要'],
            answers: {'概要': '今月のふりかえり'},
          ),
        );
        await database.saveDraft(
          ArticleDraft(
            id: 'f9999999-9999-4999-8999-999999999999',
            title: '別の記事',
            articleType: '日記',
            questions: [],
          ),
        );
      });
      await tester.pumpWidget(MyApp(database: database));
      await tester.pumpAndSettle();

      Future<void> tap(Finder finder) async {
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      await tap(find.text('Release Notes'));
      final input = find.widgetWithText(TextField, 'タグを追加');
      await tester.enterText(input, ' 作業記録 ');
      await tap(find.widgetWithText(TextButton, '追加'));
      await tester.enterText(input, '作業記録');
      await tap(find.widgetWithText(TextButton, '追加'));
      expect(find.widgetWithText(InputChip, '作業記録'), findsOneWidget);
      await tester.enterText(input, '未登録の入力');
      final save = find.widgetWithText(TextButton, '保存');
      await tap(save);
      expect(find.widgetWithText(ActionChip, '未登録の入力'), findsOneWidget);

      await tap(find.widgetWithText(ActionChip, '作業記録'));
      expect(find.text('Release Notes'), findsOneWidget);
      expect(find.text('別の記事'), findsNothing);
      await tap(find.byTooltip('検索をクリア'));
      expect(find.text('別の記事'), findsOneWidget);

      final search = find.widgetWithText(TextField, '記事を検索');
      await tester.enterText(search, 'RELEASE ふりかえり');
      await tester.pumpAndSettle();
      expect(find.text('Release Notes'), findsOneWidget);
      expect(find.text('別の記事'), findsNothing);
      await tester.enterText(search, '見つからない検索');
      await tester.pumpAndSettle();
      expect(find.text('条件に一致する記事はありません'), findsOneWidget);
      await tap(find.byTooltip('検索をクリア'));

      await tap(find.text('Release Notes'));
      await tap(find.byTooltip('作業記録 のタグを削除'));
      await tap(save);
      final drafts = await tester.runAsync(
        () => database.listDrafts(DraftStatus.active),
      );
      expect(drafts!.singleWhere((draft) => draft.id == id).tags, ['未登録の入力']);
    },
  );

  testWidgets('sorts matching articles and restores the saved order', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'draftSortOrder': 'unknown-setting',
    });
    final database = ArticleDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.runAsync(() async {
      await database.saveDraft(
        ArticleDraft(
          id: 'aefbe144-0cfc-428c-82c7-4704d2abcc01',
          title: 'A 古い記事',
          articleType: '日記',
          questions: [],
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
      );
      await database.saveDraft(
        ArticleDraft(
          id: 'aefbe144-0cfc-428c-82c7-4704d2abcc02',
          title: 'Z 新しい記事',
          articleType: '日記',
          questions: [],
          updatedAt: DateTime.utc(2026, 1, 2),
        ),
      );
    });
    const oldTitle = 'A 古い記事';
    const newTitle = 'Z 新しい記事';
    bool appearsBefore(String first, String second) =>
        tester.getTopLeft(find.text(first)).dy <
        tester.getTopLeft(find.text(second)).dy;

    await tester.pumpWidget(MyApp(database: database));
    await tester.pumpAndSettle();
    expect(find.text('記事数：2件'), findsOneWidget);
    expect(appearsBefore(newTitle, oldTitle), isTrue);

    Future<void> chooseOrder(String title) async {
      await tester.tap(find.byTooltip('並べ替え'));
      await tester.pumpAndSettle();
      final option = find.ancestor(
        of: find.text(title),
        matching: find.byWidgetPredicate(
          (widget) => widget is CheckedPopupMenuItem,
        ),
      );
      await tester.tap(option);
      await tester.pumpAndSettle();
    }

    await chooseOrder('更新日（古い順）');
    expect(appearsBefore(oldTitle, newTitle), isTrue);
    await chooseOrder('タイトル（降順）');
    expect(appearsBefore(newTitle, oldTitle), isTrue);
    await chooseOrder('タイトル（昇順）');
    expect(appearsBefore(oldTitle, newTitle), isTrue);
    await chooseOrder('更新日（新しい順）');
    expect(appearsBefore(newTitle, oldTitle), isTrue);
    await chooseOrder('タイトル（昇順）');

    final search = find.widgetWithText(TextField, '記事を検索');
    await tester.enterText(search, '古い');
    await tester.pumpAndSettle();
    expect(find.text('検索結果：1件'), findsOneWidget);
    expect(find.text(newTitle), findsNothing);
    await tester.enterText(search, '見つからない');
    await tester.pumpAndSettle();
    expect(find.text('検索結果：0件'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    SharedPreferences.resetStatic();
    await tester.pumpAndSettle();
    await tester.pumpWidget(MyApp(database: database));
    await tester.pumpAndSettle();
    expect(appearsBefore(oldTitle, newTitle), isTrue);
  });

  testWidgets(
    'edits an article question list while preserving renamed answers',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(700, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final database = ArticleDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await tester.runAsync(
        () => database.saveDraft(
          ArticleDraft(
            id: '6017fdb4-7019-4228-98c0-55af8167ac20',
            title: '質問を編集する記事',
            articleType: '日記',
            questions: ['元の質問', '削除する質問'],
            answers: {'元の質問': '保存済みの回答', '削除する質問': '消す回答', '互換用': '保持する'},
          ),
        ),
      );
      await tester.pumpWidget(MyApp(database: database));
      await tester.pumpAndSettle();

      Future<void> tap(Finder finder) async {
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      await tap(find.text('質問を編集する記事'));
      await tester.enterText(find.byKey(const ValueKey('元の質問')), '編集した回答');
      await tap(find.text('質問を編集'));
      await tap(find.text('元の質問'));
      await tester.enterText(find.byType(TextFormField).last, '名前を変えた質問');
      await tap(find.text('完了'));

      await tap(find.text('質問を追加'));
      await tester.enterText(find.byType(TextFormField).last, '新しい質問');
      await tap(find.text('完了'));
      final handle = find.byTooltip('新しい質問 をドラッグして並べ替え');
      expect(
        tester.getCenter(handle).dx,
        greaterThan(tester.getCenter(find.byTooltip('新しい質問 の操作')).dx),
      );
      final target = tester.getCenter(find.text('名前を変えた質問')).dy;
      await tester.timedDrag(
        handle,
        Offset(0, target - tester.getCenter(handle).dy - 12),
        const Duration(milliseconds: 400),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('新しい質問')).dy,
        lessThan(tester.getTopLeft(find.text('名前を変えた質問')).dy),
      );

      await tap(find.byTooltip('新しい質問 の操作'));
      expect(find.text('上に移動'), findsNothing);
      expect(find.text('下に移動'), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tap(find.byTooltip('削除する質問 の操作'));
      await tap(find.text('削除'));
      await tap(find.text('キャンセル'));
      expect(find.text('削除する質問'), findsOneWidget);
      await tap(find.byTooltip('削除する質問 の操作'));
      await tap(find.text('削除'));
      await tap(find.text('削除'));
      await tap(find.text('反映'));
      expect(find.text('編集した回答'), findsOneWidget);
      final draftsBeforeSave = await tester.runAsync(
        () => database.listDrafts(DraftStatus.active),
      );
      expect(draftsBeforeSave!.single.questions, ['元の質問', '削除する質問']);
      await tap(find.widgetWithText(TextButton, '保存'));

      final drafts = await tester.runAsync(
        () => database.listDrafts(DraftStatus.active),
      );
      final draft = drafts!.single;
      expect(draft.questions, ['新しい質問', '名前を変えた質問']);
      expect(draft.answers, {'新しい質問': '', '名前を変えた質問': '編集した回答', '互換用': '保持する'});
    },
  );

  testWidgets(
    'duplicates articles and templates without changing the original',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(700, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final database = ArticleDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      const originalId = '17c1f880-f91d-4803-bcb0-8ebdbd2f2011';
      const templateId = '17c1f880-f91d-4803-bcb0-8ebdbd2f2012';
      await tester.runAsync(() async {
        await database.saveDraft(
          ArticleDraft(
            id: originalId,
            title: '元の記事',
            articleType: '取材',
            questions: ['質問'],
            answers: {'質問': '元の回答'},
            tags: ['取材記録'],
            updatedAt: DateTime.utc(2026, 1, 1),
          ),
        );
        await database.saveCustomTemplate(
          ArticleTemplate(
            id: templateId,
            name: '取材',
            questions: ['質問'],
            iconName: 'person.text.rectangle',
          ),
        );
      });
      await tester.pumpWidget(MyApp(database: database));
      await tester.pumpAndSettle();

      Future<void> tap(Finder finder) async {
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      await tap(find.byTooltip('記事の操作'));
      await tap(find.text('複製'));
      expect(find.text('記事を編集'), findsOneWidget);
      expect(find.text('元の記事（コピー）'), findsOneWidget);
      expect(find.text('元の回答'), findsOneWidget);
      expect(find.widgetWithText(InputChip, '取材記録'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('質問')), 'コピーの回答');
      await tap(find.widgetWithText(TextButton, '保存'));

      final drafts = await tester.runAsync(
        () => database.listDrafts(DraftStatus.active),
      );
      final original = drafts!.singleWhere((draft) => draft.id == originalId);
      final copy = drafts.singleWhere((draft) => draft.id != originalId);
      expect(original.answers, {'質問': '元の回答'});
      expect(copy.answers, {'質問': 'コピーの回答'});
      expect(copy.questions, original.questions);
      expect(copy.tags, original.tags);
      expect(copy.articleType, original.articleType);

      await tap(find.byTooltip('テンプレート管理'));
      await tap(find.byTooltip('取材の操作'));
      await tap(find.text('複製'));
      expect(find.text('取材'), findsOneWidget);
      expect(find.text('取材 コピー'), findsOneWidget);

      final templates = await tester.runAsync(database.listCustomTemplates);
      expect(templates!.first.id, templateId);
      final templateCopy = templates.last;
      expect(templateCopy.id, isNot(templateId));
      expect(templateCopy.questions, ['質問']);
      expect(templateCopy.iconName, 'person.text.rectangle');
    },
  );

  testWidgets('keeps the desktop list centered and preserves compact actions', (
    tester,
  ) async {
    final database = ArticleDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.runAsync(() => database.listDrafts(DraftStatus.active));
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    await tester.pumpWidget(MyApp(database: database));
    await tester.pumpAndSettle();

    final search = find.widgetWithText(TextField, '記事を検索');
    expect(find.text('記事一覧'), findsOneWidget);
    expect(tester.getCenter(search).dx, closeTo(720, 1));
    expect(tester.getSize(search).width, lessThan(960));
    expect(
      find.ancestor(
        of: find.text('新しい記事'),
        matching: find.byWidgetPredicate((widget) => widget is FilledButton),
      ),
      findsOneWidget,
    );
    expect(find.text('テンプレート管理'), findsOneWidget);

    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpAndSettle();
    expect(tester.getSize(search).width, lessThan(390));
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.byTooltip('テンプレート管理'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
