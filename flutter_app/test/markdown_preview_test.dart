import 'package:flutter_app/export/markdown_exporter.dart';
import 'package:flutter_app/models/article_draft.dart';
import 'package:flutter_app/screens/article_preview_page.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  final draft = ArticleDraft(
    id: '394905e4-8ad7-4eb2-8b4b-81ee2f5a713d',
    title: '記事 / 見出し',
    articleType: '日記',
    questions: ['回答あり', '回答なし', '次の質問'],
    answers: {'回答あり': '一行目\n二行目', '次の質問': '- 内容', '旧質問': '出力しない'},
    tags: ['記事タグ'],
  );
  const expected =
      '# 記事 / 見出し\n\n'
      '## 回答あり\n\n一行目\n二行目\n\n'
      '## 回答なし\n\n\n\n'
      '## 次の質問\n\n- 内容\n\n';

  test('matches the SwiftUI Markdown headings, order, and blank answers', () {
    expect(exportMarkdown(draft), expected);
  });

  testWidgets(
    'switches preview modes and copies the same article structure in both',
    (tester) async {
      final draft = ArticleDraft(
        id: 'e8ad7e77-d390-4c9a-9c33-a43fd9d89ff9',
        title: '購入したもの',
        articleType: 'レビュー',
        questions: ['編集した質問', 'まだ書いていない質問'],
        tags: ['記事タグ'],
        answers: {
          '編集した質問': '  最初の行\n次の行  ',
          'まだ書いていない質問': '   ',
          '古い質問': 'コピーには載せない',
        },
      );
      String? clipboardText;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboardText =
              (call.arguments as Map<Object?, Object?>)['text'] as String;
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );

      await tester.pumpWidget(
        MaterialApp(home: ArticlePreviewPage(draft: draft)),
      );
      await tester.pumpAndSettle();
      expect(find.text('記事タグ'), findsOneWidget);
      expect(find.text('未回答'), findsOneWidget);
      expect(find.text('編集した質問'), findsOneWidget);
      expect(find.textContaining('【質問1】'), findsNothing);

      await tester.tap(find.text('記事構成をコピー'));
      await tester.pumpAndSettle();

      expect(
        clipboardText,
        '【タイトル】\n購入したもの\n\n【記事種類】\nレビュー\n\n\n'
        '【質問1】\n編集した質問\n\n【回答】\n最初の行\n次の行\n\n'
        '【質問2】\nまだ書いていない質問\n\n【回答】\n【未入力】',
      );
      expect(find.text('記事構成をコピーしました。ChatGPTやnoteに貼り付けられます。'), findsOneWidget);
      final cardCopy = clipboardText!;
      await tester.tap(find.text('コピー内容'));
      await tester.pumpAndSettle();
      final shownText = find.text(cardCopy);
      expect(shownText, findsOneWidget);
      expect(
        find.ancestor(of: shownText, matching: find.byType(SelectionArea)),
        findsOneWidget,
      );
      expect(find.text('記事タグ'), findsNothing);
      expect(cardCopy, isNot(contains('記事タグ')));
      expect(find.text('未回答'), findsNothing);

      clipboardText = null;
      await tester.tap(find.text('記事構成をコピー'));
      await tester.pumpAndSettle();
      expect(clipboardText, tester.widget<Text>(shownText).data);
      expect(clipboardText, cardCopy);

      await tester.tap(find.text('カード表示'));
      await tester.pumpAndSettle();
      expect(find.text('記事タグ'), findsOneWidget);
      expect(find.text('未回答'), findsOneWidget);
      expect(shownText, findsNothing);
      expect(find.text('記事を書き出す'), findsNothing);
    },
  );

  testWidgets('scrolls long copy text on a narrow dark screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 560));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final longAnswer = List.filled(80, '日本語の長い回答を表示します。').join('\n');
    final longDraft = ArticleDraft(
      id: draft.id,
      title: draft.title,
      articleType: draft.articleType,
      questions: draft.questions,
      answers: {'回答あり': longAnswer},
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: ArticlePreviewPage(draft: longDraft),
      ),
    );
    await tester.tap(find.text('コピー内容'));
    await tester.pumpAndSettle();

    final list = find.byType(ListView);
    final scrollable = find.descendant(
      of: list,
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(scrollable).position;
    expect(find.textContaining(longAnswer), findsOneWidget);
    expect(position.maxScrollExtent, greaterThan(0));
    await tester.drag(list, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(position.pixels, greaterThan(0));
    expect(find.text('記事構成をコピー').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
