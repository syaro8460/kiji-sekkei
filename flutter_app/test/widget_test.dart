import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart';
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
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('まだ記事がありません'), findsOneWidget);
    final listContext = tester.element(find.text('記事設計'));
    expect(Localizations.localeOf(listContext), const Locale('ja', 'JP'));
    expect(MaterialLocalizations.of(listContext).backButtonTooltip, '戻る');

    await tester.tap(find.text('新しい記事を作成'));
    await tester.pumpAndSettle();
    final template = ArticleTemplate.builtInTemplates.first;
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '作成'))
          .onPressed,
      isNull,
    );
    expect(find.text(template.questions.first), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'キャンセルする記事');
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    expect(find.text('まだ記事がありません'), findsOneWidget);
    await tester.tap(find.text('新しい記事を作成'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '最初の記事');
    await tester.pump();
    await tester.tap(find.text('作成'));
    await tester.pumpAndSettle();

    final title = find.byType(TextFormField).first;
    await tester.enterText(title, '最初の記事');
    final answer = find.byType(TextFormField).at(1);
    await tester.enterText(answer, '記事のメモ');
    final field = find.descendant(
      of: answer,
      matching: find.byType(EditableText),
    );
    final editable = tester.widget<EditableText>(field);
    final selection = editable.controller.selection;
    final dispatcher = tester.platformDispatcher;
    addTearDown(dispatcher.clearPlatformBrightnessTestValue);
    dispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(field)).brightness, Brightness.dark);
    final after = tester.widget<EditableText>(field);
    expect(after.controller, same(editable.controller));
    expect(after.focusNode, same(editable.focusNode));
    expect(after.focusNode.hasFocus, isTrue);
    expect(after.controller.text, '記事のメモ');
    expect(after.controller.selection, selection);
    expect(find.text('最初の記事'), findsOneWidget);
    expect(find.text('記事を書き出す'), findsOneWidget);
    await tester.tap(find.text('記事構成を作成'));
    await tester.pumpAndSettle();
    expect(find.text('記事構成'), findsOneWidget);
    expect(find.text('記事を書き出す'), findsNothing);
    expect(find.text('記事のメモ'), findsOneWidget);
    await tester.tap(find.byTooltip('戻る'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextButton, '保存'), findsNothing);
    await tester.tap(find.byTooltip('戻る'));
    await tester.pumpAndSettle();
    expect(find.text('最初の記事'), findsOneWidget);

    await tester.tap(find.text('最初の記事'));
    await tester.pumpAndSettle();
    expect(find.text('記事のメモ'), findsOneWidget);
    await tester.enterText(title, '編集した記事');
    await tester.tap(find.byTooltip('戻る'));
    await tester.pumpAndSettle();
    expect(find.text('編集した記事'), findsOneWidget);
    expect(find.text('最初の記事'), findsNothing);

    final drafts = await tester.runAsync(
      () => database.listDrafts(DraftStatus.active),
    );
    expect(drafts!.single.title, '編集した記事');
    expect(drafts.single.answers[template.questions.first], '記事のメモ');
  });

  testWidgets('creates an article with its multiline title unchanged', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(700, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = ArticleDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.runAsync(() => database.listDrafts(DraftStatus.active));
    await tester.pumpWidget(MyApp(database: database));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('新しい記事を作成'));
    await tester.pumpAndSettle();

    final title = find.byType(TextField).first;
    final titleInput = tester.widget<TextField>(title);
    expect(titleInput.minLines, 1);
    expect(titleInput.maxLines, isNull);
    expect(titleInput.keyboardType, TextInputType.multiline);
    expect(titleInput.textInputAction, TextInputAction.newline);
    await tester.showKeyboard(title);
    expect(
      tester.testTextInput.setClientArgs!['inputAction'],
      'TextInputAction.newline',
    );

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: ' \n\t',
        selection: TextSelection.collapsed(offset: 3),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '作成'))
          .onPressed,
      isNull,
    );

    const enteredTitle = '\n  一行目\n二行目  \n';
    tester.testTextInput.updateEditingValue(
      TextEditingValue(
        text: enteredTitle,
        selection: TextSelection.collapsed(offset: enteredTitle.length),
      ),
    );
    await tester.testTextInput.receiveAction(TextInputAction.newline);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '作成'))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.text('作成'));
    await tester.pumpAndSettle();

    final editorTitle = tester.widget<TextField>(
      find.descendant(
        of: find.byType(TextFormField).first,
        matching: find.byType(TextField),
      ),
    );
    expect(editorTitle.controller!.text, enteredTitle);
    final drafts = await tester.runAsync(
      () => database.listDrafts(DraftStatus.active),
    );
    expect(drafts!.single.title, enteredTitle);
  });

  testWidgets('truncates article list titles after two lines', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = ArticleDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    const explicitTitle = '明示1行目\n明示2行目\n明示3行目';
    const wrappedTitle =
        '幅によって自動折り返しされる長いタイトルを表示して省略表示を確認するための文章'
        '幅によって自動折り返しされる長いタイトルを表示して省略表示を確認するための文章'
        '幅によって自動折り返しされる長いタイトルを表示して省略表示を確認するための文章'
        '幅によって自動折り返しされる長いタイトルを表示して省略表示を確認するための文章';
    const twoLineTitle = '1行目\n2行目';
    const familyEmoji = '👨‍👩‍👧‍👦';
    final emojiTitle = List.filled(60, familyEmoji).join();
    await tester.runAsync(() async {
      await database.saveDraft(
        ArticleDraft(
          id: '84c99aa0-85c1-4fa2-936c-10627414a1ba',
          title: explicitTitle,
          articleType: '日記',
          questions: [],
        ),
      );
      await database.saveDraft(
        ArticleDraft(
          id: '84c99aa0-85c1-4fa2-936c-10627414a1bb',
          title: wrappedTitle,
          articleType: '日記',
          questions: [],
        ),
      );
      await database.saveDraft(
        ArticleDraft(
          id: '84c99aa0-85c1-4fa2-936c-10627414a1bc',
          title: twoLineTitle,
          articleType: '日記',
          questions: [],
        ),
      );
      await database.saveDraft(
        ArticleDraft(
          id: '84c99aa0-85c1-4fa2-936c-10627414a1bd',
          title: emojiTitle,
          articleType: '日記',
          questions: [],
        ),
      );
    });
    await tester.pumpWidget(MyApp(database: database));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    for (final (title, prefix, truncated) in [
      (explicitTitle, '明示1行目', true),
      (wrappedTitle, '幅によって', true),
      (twoLineTitle, twoLineTitle, false),
    ]) {
      final finder = truncated
          ? find.byWidgetPredicate(
              (widget) =>
                  widget is Text && widget.data?.startsWith(prefix) == true,
            )
          : find.text(title);
      final titleWidget = tester.widget<Text>(finder);
      final paragraph = tester.renderObject<RenderParagraph>(finder);
      expect(titleWidget.maxLines, 2);
      expect(titleWidget.overflow, TextOverflow.ellipsis);
      expect(titleWidget.softWrap, isTrue);
      expect(paragraph.softWrap, isTrue);
      expect(titleWidget.data!.endsWith('…'), truncated);
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(
        paragraph.size.width,
        lessThanOrEqualTo(paragraph.constraints.maxWidth + 0.01),
      );
      if (truncated) {
        expect(
          titleWidget.data!.characters.length,
          lessThan(title.characters.length),
        );
      } else {
        expect(titleWidget.data, title);
      }
    }

    final emojiFinder = find.byWidgetPredicate(
      (widget) =>
          widget is Text && widget.data?.startsWith(familyEmoji) == true,
    );
    final displayedEmojiTitle = tester.widget<Text>(emojiFinder).data!;
    expect(displayedEmojiTitle.endsWith('…'), isTrue);
    final displayedEmojiPrefix = displayedEmojiTitle.substring(
      0,
      displayedEmojiTitle.length - 1,
    );
    expect(
      displayedEmojiPrefix.characters.every(
        (cluster) => cluster == familyEmoji,
      ),
      isTrue,
    );

    await tester.binding.setSurfaceSize(const Size(1440, 900));
    await tester.pumpAndSettle();
    for (final prefix in ['明示1行目', '幅によって', familyEmoji]) {
      final finder = find.byWidgetPredicate(
        (widget) => widget is Text && widget.data?.startsWith(prefix) == true,
      );
      final displayedTitle = tester.widget<Text>(finder).data!;
      final paragraph = tester.renderObject<RenderParagraph>(finder);
      expect(displayedTitle.endsWith('…'), isTrue);
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(
        paragraph.size.width,
        lessThanOrEqualTo(paragraph.constraints.maxWidth + 0.01),
      );
    }

    final storedTitles = await tester.runAsync(
      () => database.listDrafts(DraftStatus.active),
    );
    expect(storedTitles!.map((draft) => draft.title).toSet(), {
      explicitTitle,
      wrappedTitle,
      twoLineTitle,
      emojiTitle,
    });
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
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    Future<void> tap(Finder finder) async {
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    Future<void> moveToTrash() async {
      await tap(find.byTooltip('記事の操作'));
      expect(find.text('プレビュー'), findsNothing);
      await tap(find.text('ゴミ箱に移動'));
      expect(find.text('まだ記事がありません'), findsOneWidget);
      await tap(find.byTooltip('メニュー'));
      await tap(find.text('ゴミ箱'));
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
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    Future<void> tap(Finder finder) async {
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    Future<void> fill(String name, String questions) async {
      await tester.enterText(find.byType(TextFormField).first, name);
      final lines = questions.split('\n');
      for (final (index, question) in lines.indexed) {
        final fields = find.byType(TextFormField);
        if (fields.evaluate().length <= index + 1) {
          await tap(find.text('質問を追加'));
        }
        final field = fields.at(index + 1);
        await tester.ensureVisible(field);
        await tester.enterText(field, question);
      }
      await tap(find.text('保存'));
    }

    await tap(find.byTooltip('メニュー'));
    await tap(find.text('テンプレート管理'));
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
    await tap(find.text('新しい記事を作成'));
    await tap(find.text(ArticleTemplate.builtInTemplates.first.name));
    await tap(find.text('週次レビュー').last);
    expect(find.text('次にやること'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '今週の記事');
    await tester.pump();
    await tap(find.text('作成'));
    await tap(find.byTooltip('戻る'));

    await tap(find.byTooltip('メニュー'));
    await tap(find.text('テンプレート管理'));
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
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      Future<void> tap(Finder finder) async {
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      await tap(find.text('Release Notes'));
      final input = find.widgetWithText(TextField, 'タグを追加');
      await tester.enterText(input, ' 作業記録 ');
      await tap(find.widgetWithText(TextButton, '追加'));
      expect(tester.widget<TextField>(input).focusNode!.hasFocus, isTrue);
      await tester.enterText(input, '作業記録');
      await tap(find.widgetWithText(TextButton, '追加'));
      expect(find.widgetWithText(InputChip, '作業記録'), findsOneWidget);
      await tester.enterText(input, '未登録の入力');
      await tap(find.byTooltip('戻る'));
      expect(find.widgetWithText(ActionChip, '未登録の入力'), findsNothing);

      await tap(find.widgetWithText(ActionChip, '作業記録'));
      expect(find.text('Release Notes'), findsOneWidget);
      expect(find.text('別の記事'), findsNothing);
      await tap(find.byTooltip('検索をクリア'));
      expect(find.text('別の記事'), findsOneWidget);

      final search = find.widgetWithText(TextField, '検索');
      await tester.enterText(search, 'ＲＥＬＥＡＳＥ　フリカエリ');
      await tester.pumpAndSettle();
      expect(find.text('Release Notes'), findsOneWidget);
      expect(find.text('別の記事'), findsNothing);
      await tester.enterText(search, 'releze ふりかえり');
      await tester.pumpAndSettle();
      expect(find.text('Release Notes'), findsOneWidget);
      expect(find.text('別の記事'), findsNothing);
      await tester.enterText(search, '見つからない検索');
      await tester.pumpAndSettle();
      expect(find.text('検索結果がありません'), findsOneWidget);
      expect(find.text('別のキーワードで検索してみてください。'), findsOneWidget);
      await tap(find.byTooltip('検索をクリア'));

      await tap(find.text('Release Notes'));
      await tap(find.byTooltip('作業記録 のタグを削除'));
      await tap(find.byTooltip('戻る'));
      final drafts = await tester.runAsync(
        () => database.listDrafts(DraftStatus.active),
      );
      expect(drafts!.singleWhere((draft) => draft.id == id).tags, isEmpty);
    },
  );

  testWidgets(
    'preserves edited title whitespace and shows numbered bounded answers',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(700, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final database = ArticleDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      const id = 'b9576c40-75ea-4fd8-86f6-fdcfc0d6ed74';
      await tester.runAsync(
        () => database.saveDraft(
          ArticleDraft(
            id: id,
            title: '編集前のタイトル',
            articleType: '日記',
            questions: ['最初の質問', '次の質問'],
            answers: {'最初の質問': '', '次の質問': ''},
          ),
        ),
      );
      await tester.pumpWidget(MyApp(database: database));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      await tester.tap(find.text('編集前のタイトル'));
      await tester.pumpAndSettle();

      final title = find.byType(TextFormField).first;
      final titleInput = tester.widget<TextField>(
        find.descendant(of: title, matching: find.byType(TextField)),
      );
      expect(titleInput.minLines, 1);
      expect(titleInput.maxLines, isNull);
      expect(titleInput.keyboardType, TextInputType.multiline);
      expect(titleInput.textInputAction, TextInputAction.newline);
      final firstAnswerFinder = find.byKey(const ValueKey('最初の質問'));
      final firstAnswer = tester.widget<TextField>(
        find.descendant(
          of: firstAnswerFinder,
          matching: find.byType(TextField),
        ),
      );
      expect(firstAnswer.minLines, 3);
      expect(firstAnswer.maxLines, 8);
      expect(find.text('【質問1】'), findsOneWidget);
      expect(find.text('【質問2】'), findsOneWidget);
      expect(find.text('【回答】'), findsNWidgets(2));

      await tester.showKeyboard(title);
      expect(
        tester.testTextInput.setClientArgs!['inputAction'],
        'TextInputAction.newline',
      );
      const imeTitle = 'IME入力';
      tester.testTextInput.updateEditingValue(
        TextEditingValue(
          text: '$imeTitle\n',
          selection: TextSelection.collapsed(offset: imeTitle.length + 1),
        ),
      );
      await tester.testTextInput.receiveAction(TextInputAction.newline);
      await tester.pumpAndSettle();
      expect(titleInput.controller!.text, '$imeTitle\n');
      var drafts = await tester.runAsync(
        () => database.listDrafts(DraftStatus.active),
      );
      expect(drafts!.single.title, '$imeTitle\n');

      const multilineTitle = '  前後の空白\nタイトル\n  ';
      await tester.enterText(title, multilineTitle);
      await tester.pumpAndSettle();
      drafts = await tester.runAsync(
        () => database.listDrafts(DraftStatus.active),
      );
      expect(drafts!.single.title, multilineTitle);

      await tester.tap(find.text('記事構成を作成'));
      await tester.pumpAndSettle();
      expect(find.text(multilineTitle), findsOneWidget);
      await tester.tap(find.byTooltip('戻る'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('戻る'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              widget.data?.startsWith('  前後の空白\nタイトル') == true,
        ),
      );
      await tester.pumpAndSettle();
      final reopenedTitle = tester.widget<TextField>(
        find.descendant(
          of: find.byType(TextFormField).first,
          matching: find.byType(TextField),
        ),
      );
      expect(reopenedTitle.controller!.text, multilineTitle);

      const blankTitle = ' \n\t';
      await tester.enterText(title, blankTitle);
      await tester.pumpAndSettle();
      drafts = await tester.runAsync(
        () => database.listDrafts(DraftStatus.active),
      );
      expect(drafts!.single.title, blankTitle);
      await tester.tap(find.byTooltip('戻る'));
      await tester.pumpAndSettle();
      expect(find.text('無題の記事'), findsOneWidget);
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
    await tester.pump(const Duration(milliseconds: 500));
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

    final search = find.widgetWithText(TextField, '検索');
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
    await tester.pump(const Duration(milliseconds: 500));
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
      await tester.pump(const Duration(milliseconds: 500));
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
      expect(
        tester.getTopLeft(find.text('【質問1】')).dy,
        lessThan(tester.getTopLeft(find.text('新しい質問')).dy),
      );
      expect(
        tester.getTopLeft(find.text('【質問2】')).dy,
        lessThan(tester.getTopLeft(find.text('名前を変えた質問')).dy),
      );
      expect(find.text('編集した回答'), findsOneWidget);
      await tap(find.byTooltip('戻る'));

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
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      Future<void> tap(Finder finder) async {
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      await tap(find.byTooltip('記事の操作'));
      await tap(find.text('複製'));
      expect(find.text('記事の内容'), findsOneWidget);
      expect(find.text('元の記事（コピー）'), findsOneWidget);
      expect(find.text('元の回答'), findsOneWidget);
      expect(find.widgetWithText(InputChip, '取材記録'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('質問')), 'コピーの回答');
      await tap(find.byTooltip('戻る'));

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

      await tap(find.byTooltip('メニュー'));
      await tap(find.text('テンプレート管理'));
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
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    final search = find.widgetWithText(TextField, '検索');
    expect(find.text('記事一覧'), findsOneWidget);
    expect(tester.getCenter(search).dx, closeTo(720, 1));
    expect(tester.getSize(search).width, lessThan(960));
    expect(
      find.ancestor(
        of: find.text('新しい記事を作成'),
        matching: find.byWidgetPredicate((widget) => widget is FilledButton),
      ),
      findsOneWidget,
    );

    Future<void> checkMenu() async {
      final menu = find.byTooltip('メニュー');
      expect(
        tester.getCenter(menu).dx,
        lessThan(tester.getCenter(find.text('記事設計')).dx),
      );
      await tester.tap(menu);
      await tester.pumpAndSettle();
      expect(find.text('テンプレート管理'), findsOneWidget);
      expect(find.text('ゴミ箱'), findsOneWidget);
      expect(find.byType(PopupMenuDivider), findsOneWidget);
      expect(find.text('バックアップ'), findsNothing);
      await tester.tap(find.text('設定'));
      await tester.pumpAndSettle();
      expect(find.text('外観'), findsOneWidget);
      expect(find.byTooltip('並べ替え'), findsNothing);
      await tester.tap(find.byTooltip('戻る'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('並べ替え'), findsOneWidget);
    }

    await checkMenu();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpAndSettle();
    expect(tester.getSize(search).width, lessThan(390));
    expect(find.byType(FloatingActionButton), findsOneWidget);
    await checkMenu();
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens the short landscape menu and restores keyboard focus', (
    tester,
  ) async {
    final database = ArticleDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(900, 240));
    await tester.runAsync(() => database.listDrafts(DraftStatus.active));
    await tester.pumpWidget(MyApp(database: database));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    Future<void> key(LogicalKeyboardKey key) async {
      await tester.sendKeyEvent(key);
      await tester.pumpAndSettle();
    }

    await key(LogicalKeyboardKey.tab);
    await key(LogicalKeyboardKey.enter);
    for (final label in ['テンプレート管理', 'ゴミ箱', '設定']) {
      expect(find.text(label).hitTestable(), findsOneWidget);
    }
    await key(LogicalKeyboardKey.escape);
    expect(find.text('設定'), findsNothing);
    // Enter alone reopens the menu if focus returned to the trigger.
    await key(LogicalKeyboardKey.enter);
    expect(find.text('設定'), findsOneWidget);
    await key(LogicalKeyboardKey.arrowDown);
    await key(LogicalKeyboardKey.arrowDown);
    await key(LogicalKeyboardKey.arrowDown);
    await key(LogicalKeyboardKey.enter);
    expect(find.text('外観'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps an unsuccessful auto-save editable and can retry', (
    tester,
  ) async {
    final database = _FailOnceArticleDatabase();
    addTearDown(database.close);
    await tester.runAsync(
      () => database.saveDraft(
        ArticleDraft(
          id: '836ae6aa-d595-47bf-b416-90ee746f8b03',
          title: '保存前のタイトル',
          articleType: '日記',
          questions: [],
        ),
      ),
    );
    await tester.pumpWidget(MyApp(database: database));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存前のタイトル'));
    await tester.pumpAndSettle();

    database.failNextSave = true;
    await tester.enterText(find.byType(TextFormField).first, '保存したいタイトル');
    await tester.pumpAndSettle();
    expect(find.text('保存を再試行'), findsOneWidget);
    final before = await tester.runAsync(
      () => database.listDrafts(DraftStatus.active),
    );
    expect(before!.single.title, '保存前のタイトル');

    await tester.tap(find.text('保存を再試行'));
    await tester.pumpAndSettle();
    expect(find.text('自動保存済み'), findsOneWidget);
    final after = await tester.runAsync(
      () => database.listDrafts(DraftStatus.active),
    );
    expect(after!.single.title, '保存したいタイトル');
  });

  testWidgets('waits for the newest pending auto-save when going back', (
    tester,
  ) async {
    final database = _FailOnceArticleDatabase();
    addTearDown(database.close);
    await tester.runAsync(
      () => database.saveDraft(
        ArticleDraft(
          id: '837255b5-5ea0-4c2d-8e60-ea6bbeceb0ad',
          title: '元のタイトル',
          articleType: '日記',
          questions: [],
        ),
      ),
    );
    await tester.pumpWidget(MyApp(database: database));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('元のタイトル'));
    await tester.pumpAndSettle();

    final writeGate = Completer<void>();
    database.nextSaveGate = writeGate.future;
    final title = find.byType(TextFormField).first;
    await tester.enterText(title, '途中の入力');
    await tester.enterText(title, '最後の入力');
    await tester.tap(find.byTooltip('戻る'));
    await tester.pump();
    expect(find.text('記事の内容'), findsOneWidget);
    writeGate.complete();
    await tester.pumpAndSettle();
    expect(find.text('最後の入力'), findsOneWidget);
    expect(find.text('途中の入力'), findsNothing);

    final drafts = await tester.runAsync(
      () => database.listDrafts(DraftStatus.active),
    );
    expect(drafts!.single.title, '最後の入力');
  });

  testWidgets('changes an article template with the iOS answer options', (
    tester,
  ) async {
    final database = ArticleDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.runAsync(() async {
      await database.saveDraft(
        ArticleDraft(
          id: 'c2488e26-f025-492e-9ddf-5c0aae104bdd',
          title: '種類変更の記事',
          articleType: '元の種類',
          questions: ['共通の質問', '元だけの質問'],
          answers: {'共通の質問': '残す回答', '元だけの質問': '外す回答'},
          tags: ['残すタグ'],
        ),
      );
      await database.saveCustomTemplate(
        ArticleTemplate(
          id: 'd559f1e3-097d-464b-920b-c57c7cc6fd79',
          name: '変更先',
          questions: ['共通の質問', '新しい質問'],
        ),
      );
    });
    await tester.pumpWidget(MyApp(database: database));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    Future<void> tap(String label) async {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    Future<void> choose() async {
      await tap('記事種類');
      expect(find.text('テンプレートを選択'), findsOneWidget);
      await tap('変更先');
    }

    await tap('種類変更の記事');
    await choose();
    await tap('キャンセル');
    await tester.tap(find.byTooltip('戻る'));
    await tester.pumpAndSettle();
    expect(find.text('残す回答'), findsOneWidget);

    await choose();
    await tap('共通する質問・回答を引き継ぐ');
    final kept = await tester.runAsync(
      () => database.listDrafts(DraftStatus.active),
    );
    expect(kept!.single.articleType, '変更先');
    expect(kept.single.questions, ['共通の質問', '新しい質問']);
    expect(kept.single.answers, {'共通の質問': '残す回答', '新しい質問': ''});
    expect(kept.single.tags, ['残すタグ']);

    await choose();
    await tap('質問と回答をリセット');
    final reset = await tester.runAsync(
      () => database.listDrafts(DraftStatus.active),
    );
    expect(reset!.single.answers.values, everyElement(isEmpty));
  });
}

class _FailOnceArticleDatabase extends ArticleDatabase {
  _FailOnceArticleDatabase() : super(NativeDatabase.memory());

  bool failNextSave = false;
  Future<void>? nextSaveGate;

  @override
  Future<void> saveDraft(ArticleDraft draft) async {
    if (failNextSave) {
      failNextSave = false;
      throw StateError('Simulated write failure');
    }
    final gate = nextSaveGate;
    nextSaveGate = null;
    if (gate != null) await gate;
    await super.saveDraft(draft);
  }
}
