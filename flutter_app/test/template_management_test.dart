import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_app/models/article_draft.dart';
import 'package:flutter_app/models/article_template.dart';
import 'package:flutter_app/screens/template_page.dart';
import 'package:flutter_app/storage/article_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const firstId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const secondId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

class _TestDatabase extends ArticleDatabase {
  _TestDatabase() : super(NativeDatabase.memory());

  Completer<void>? saveGate;
  int saveRequests = 0;
  bool failSave = false;
  bool failOrder = false;

  @override
  Future<void> saveCustomTemplate(ArticleTemplate template) async {
    saveRequests++;
    final gate = saveGate;
    if (gate != null) await gate.future;
    if (failSave) throw StateError('test save failure');
    await super.saveCustomTemplate(template);
  }

  @override
  Future<void> reorderCustomTemplates(List<String> ids) async {
    if (failOrder) throw StateError('test reorder failure');
    await super.reorderCustomTemplates(ids);
  }
}

ArticleTemplate _template(String id, String name, List<String> questions) =>
    ArticleTemplate(
      id: id,
      name: name,
      questions: questions,
      iconName: 'star.bubble',
    );

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _moveFirstDown(WidgetTester tester) async {
  await tester.timedDrag(
    find.byTooltip('1番をドラッグして並び替え'),
    const Offset(0, 75),
    const Duration(milliseconds: 400),
  );
  await tester.pumpAndSettle();
}

void main() {
  late _TestDatabase db;

  setUp(() => db = _TestDatabase());
  tearDown(() => db.close());

  Future<void> open(WidgetTester tester, {ThemeData? theme}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: TemplatePage(database: db),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'lists built-in templates and lets users inspect only their questions',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(700, 950));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await db.saveCustomTemplate(_template(firstId, '自作テスト', ['質問']));
      await open(tester);

      expect(find.text('標準テンプレート'), findsOneWidget);
      expect(find.text('自作テンプレート'), findsOneWidget);
      expect(find.text('自作テスト'), findsOneWidget);
      for (final template in ArticleTemplate.builtInTemplates) {
        expect(find.text(template.name), findsOneWidget);
        expect(find.byTooltip('${template.name}の操作'), findsNothing);
      }
      await _tap(tester, find.text('レビュー'));
      expect(
        find.text(ArticleTemplate.builtInTemplates.first.questions.first),
        findsOneWidget,
      );
      expect(find.text('保存'), findsNothing);
      expect(find.byType(PopupMenuButton), findsNothing);
    },
  );

  testWidgets(
    'reordering custom templates can be cancelled and retried after failure',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(700, 950));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await db.saveCustomTemplate(_template(firstId, '先頭の自作', ['質問']));
      await db.saveCustomTemplate(_template(secondId, '二番目の自作', ['質問']));
      await open(tester);

      final reorder = find.text('テンプレートを並び替え');
      await _tap(tester, reorder);
      expect(find.text('レビュー'), findsNothing);
      await _moveFirstDown(tester);
      await _tap(tester, find.text('キャンセル'));
      expect((await db.listCustomTemplates()).map((item) => item.id), [
        firstId,
        secondId,
      ]);

      await _tap(tester, reorder);
      await _moveFirstDown(tester);
      db.failOrder = true;
      await _tap(tester, find.text('完了'));
      expect(find.textContaining('順番を保存できませんでした'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('二番目の自作')).dy,
        lessThan(tester.getTopLeft(find.text('先頭の自作')).dy),
      );
      db.failOrder = false;
      await _tap(tester, find.text('完了'));
      expect((await db.listCustomTemplates()).map((item) => item.id), [
        secondId,
        firstId,
      ]);
    },
  );

  testWidgets(
    'preserves multiline and duplicate legacy questions while editing, reordering and retrying',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(700, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const original = ['一行目\n二行目', '同じ', '同じ', '編集前'];
      await db.saveCustomTemplate(_template(firstId, '旧テンプレート', original));
      final article = ArticleDraft(
        id: secondId,
        title: '既存記事',
        articleType: '旧テンプレート',
        questions: original,
        answers: {'編集前': '保存した回答'},
      );
      await db.saveDraft(article);
      await open(tester);
      await _tap(tester, find.text('旧テンプレート'));

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.first, '編集後の名前');
      await tester.ensureVisible(fields.at(4));
      await tester.enterText(fields.at(4), '編集後\n補足');
      await _tap(tester, find.text('質問を追加'));
      await tester.enterText(fields.at(5), '追加した質問');
      await _tap(tester, find.byTooltip('質問5を削除'));

      final reorder = find.text('質問を並び替え');
      await _tap(tester, reorder);
      await _moveFirstDown(tester);
      await _tap(tester, find.text('キャンセル'));
      expect(
        tester.widget<TextFormField>(fields.at(1)).controller!.text,
        original.first,
      );

      await _tap(tester, reorder);
      await _moveFirstDown(tester);
      await _tap(tester, find.text('完了'));
      expect(tester.widget<TextFormField>(fields.at(1)).controller!.text, '同じ');
      expect((await db.listCustomTemplates()).single.questions, original);

      db.failSave = true;
      await _tap(tester, find.text('保存'));
      expect(find.textContaining('テンプレートを保存できませんでした'), findsOneWidget);
      expect(
        tester.widget<TextFormField>(fields.first).controller!.text,
        '編集後の名前',
      );
      expect(
        tester.widget<TextFormField>(fields.at(2)).controller!.text,
        original.first,
      );

      db.failSave = false;
      await _tap(tester, find.text('保存'));
      final saved = (await db.listCustomTemplates()).single;
      expect(saved.id, firstId);
      expect(saved.iconName, 'star.bubble');
      expect(saved.questions, ['同じ', original.first, '同じ', '編集後\n補足']);
      final retained = (await db.listDrafts(DraftStatus.active)).single;
      expect(retained.questions, original);
      expect(retained.answers, article.answers);

      await _tap(tester, find.byTooltip('編集後の名前の操作'));
      await _tap(tester, find.text('削除'));
      await _tap(tester, find.text('削除'));
      expect(await db.listCustomTemplates(), isEmpty);
      final afterDeletion = (await db.listDrafts(DraftStatus.active)).single;
      expect(afterDeletion.questions, original);
      expect(afterDeletion.answers, article.answers);
    },
  );

  testWidgets(
    'checks input and confirms leaving only when changes are unsaved',
    (tester) async {
      await open(tester);
      final create = find.text('新しいテンプレート');
      await _tap(tester, create);
      await _tap(tester, find.byType(BackButton));
      expect(find.text('変更を破棄しますか？'), findsNothing);
      await _tap(tester, create);
      final fields = find.byType(TextFormField);
      await _tap(tester, find.text('保存'));
      expect(find.text('テンプレート名を入力してください'), findsOneWidget);
      expect(find.text('質問を1つ以上入力してください'), findsOneWidget);
      await tester.enterText(fields.first, 'テスト');
      await tester.enterText(fields.at(1), '同じ');
      await _tap(tester, find.text('質問を追加'));
      await tester.enterText(fields.at(2), ' 同じ ');
      await _tap(tester, find.text('保存'));
      expect(find.text('同じ質問が重複しています').hitTestable(), findsWidgets);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('変更を破棄しますか？'), findsOneWidget);
      await _tap(tester, find.text('編集に戻る'));
      expect(
        tester.widget<TextFormField>(fields.at(2)).controller!.text,
        ' 同じ ',
      );
      await _tap(tester, find.byType(BackButton));
      await _tap(tester, find.text('破棄'));
      expect(await db.listCustomTemplates(), isEmpty);
    },
  );

  for (final editing in [false, true]) {
    testWidgets('rejects an offscreen blank name (editing: $editing)', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 560));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final questions = List.generate(12, (index) => '質問の本文 ${index + 1}');
      if (editing) {
        await db.saveCustomTemplate(_template(firstId, '元の名前', questions));
      }
      await open(tester);
      final entry = find.text(editing ? '元の名前' : '新しいテンプレート');
      if (editing) await tester.scrollUntilVisible(entry, 150);
      await _tap(tester, entry);
      final name = find.widgetWithText(TextFormField, 'テンプレート名');
      final body = find.byType(ListView).last;
      final scrollable = find
          .descendant(of: body, matching: find.byType(Scrollable))
          .first;
      await tester.enterText(name, '   ');
      if (!editing) {
        for (final (index, question) in questions.indexed) {
          if (index > 0) {
            final add = find.text('質問を追加');
            await tester.scrollUntilVisible(add, 150, scrollable: scrollable);
            await _tap(tester, add);
          }
          final field = find.byType(TextFormField).last;
          await tester.ensureVisible(field);
          await tester.enterText(field, question);
          await tester.pumpAndSettle();
        }
      }
      FocusManager.instance.primaryFocus?.unfocus();
      final position = tester.state<ScrollableState>(scrollable).position;
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(name, findsNothing);
      final writes = db.saveRequests;
      await _tap(tester, find.text('保存'));
      expect(db.saveRequests, writes);
      final retained = await db.listCustomTemplates();
      if (editing) {
        expect(retained.single.id, firstId);
        expect(retained.single.name, '元の名前');
        expect(retained.single.questions, questions);
      } else {
        expect(retained, isEmpty);
      }
      final summary = find.byKey(const ValueKey('template-validation-summary'));
      expect(summary.hitTestable(), findsOneWidget);
      expect(tester.widget<Text>(summary).data, 'テンプレート名を入力してください');
      position.jumpTo(0);
      await tester.pumpAndSettle();
      await tester.enterText(name, '修正した名前');
      await tester.pumpAndSettle();
      expect(summary, findsNothing);
      await _tap(tester, find.text('保存'));
      final saved = (await db.listCustomTemplates()).single;
      expect(saved.name, '修正した名前');
      expect(saved.questions, questions);
    });
  }

  testWidgets('shows duplicate validation with the end of the list offscreen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 560));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final questions = List.generate(12, (index) => '質問の本文 ${index + 1}');
    await db.saveCustomTemplate(_template(firstId, '自作テスト', questions));
    await open(tester);
    final entry = find.text('自作テスト');
    await tester.scrollUntilVisible(entry, 150);
    await _tap(tester, entry);
    tester.view.viewInsets = const FakeViewPadding(bottom: 220);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    final firstQuestion = find.byType(TextFormField).at(1);
    await tester.enterText(firstQuestion, questions[1]);
    expect(find.text('質問を追加'), findsNothing);
    final writes = db.saveRequests;
    await _tap(tester, find.text('保存'));
    expect(db.saveRequests, writes);
    expect((await db.listCustomTemplates()).single.questions, questions);
    final summary = find.byKey(const ValueKey('template-validation-summary'));
    expect(summary.hitTestable(), findsOneWidget);
    expect(tester.widget<Text>(summary).data, '同じ質問が重複しています');
    await tester.enterText(firstQuestion, '修正した質問');
    await tester.pumpAndSettle();
    expect(summary, findsNothing);
    await _tap(tester, find.text('保存'));
    expect((await db.listCustomTemplates()).single.questions.first, '修正した質問');
  });

  testWidgets('duplicates multiline questions without changing their order', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(700, 950));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const questions = ['最初\n続き', '次の質問\n\n補足', '最後'];
    await db.saveCustomTemplate(_template(firstId, '複製元', questions));
    await open(tester);
    await _tap(tester, find.byTooltip('複製元の操作'));
    await _tap(tester, find.text('複製'));
    final templates = await db.listCustomTemplates();
    expect(templates, hasLength(2));
    expect(templates.first.id, firstId);
    expect(templates.last.id, isNot(firstId));
    expect(templates.last.questions, questions);
    expect(templates.last.iconName, templates.first.iconName);
  });

  testWidgets(
    'guards repeat saves and back navigation until saving completes',
    (tester) async {
      await open(tester);
      await _tap(tester, find.text('新しいテンプレート'));
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.first, '保存テスト');
      await tester.enterText(fields.last, '保存する質問');
      final gate = db.saveGate = Completer<void>();
      final save = find.text('保存');
      await tester.tap(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(db.saveRequests, 1);
      expect(
        find.widgetWithText(FilledButton, '保存中…').evaluate().single.widget,
        isA<FilledButton>().having(
          (button) => button.onPressed,
          'onPressed',
          isNull,
        ),
      );
      await _tap(tester, find.byType(BackButton));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('テンプレートを作成'), findsOneWidget);
      expect(find.text('変更を破棄しますか？'), findsNothing);
      expect(await db.listCustomTemplates(), isEmpty);
      gate.complete();
      await tester.pumpAndSettle();
      expect(db.saveRequests, 1);
      expect(find.text('保存テスト'), findsOneWidget);
      expect(find.text('テンプレートを作成'), findsNothing);
      expect((await db.listCustomTemplates()).single.questions, ['保存する質問']);
    },
  );

  testWidgets('supports a narrow dark screen with a long multiline question', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 560));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await open(tester, theme: ThemeData.dark());
    await _tap(tester, find.text('新しいテンプレート'));
    final field = find.byType(TextFormField).last;
    final longQuestion = List.filled(40, '長い質問の入力です').join('\n');
    await tester.enterText(field, longQuestion);
    await tester.pumpAndSettle();
    final editable = tester.widget<EditableText>(
      find.descendant(of: field, matching: find.byType(EditableText)),
    );
    expect(editable.minLines, 3);
    expect(editable.maxLines, 8);
    expect(editable.textInputAction, TextInputAction.newline);
    final innerScroll = find.descendant(
      of: find.byType(EditableText).last,
      matching: find.byType(Scrollable),
    );
    expect(
      tester.state<ScrollableState>(innerScroll).position.maxScrollExtent,
      greaterThan(0),
    );
    expect(find.text('保存').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
