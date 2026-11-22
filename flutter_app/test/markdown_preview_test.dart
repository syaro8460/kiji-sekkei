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
    'copies the visible article structure with the SwiftUI headings',
    (tester) async {
      final draft = ArticleDraft(
        id: 'e8ad7e77-d390-4c9a-9c33-a43fd9d89ff9',
        title: '購入したもの',
        articleType: 'レビュー',
        questions: ['編集した質問', 'まだ書いていない質問'],
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
      await tester.tap(find.text('記事構成をコピー'));
      await tester.pumpAndSettle();

      expect(
        clipboardText,
        '【タイトル】\n購入したもの\n\n【記事種類】\nレビュー\n\n\n'
        '【質問1】\n編集した質問\n\n【回答】\n最初の行\n次の行\n\n'
        '【質問2】\nまだ書いていない質問\n\n【回答】\n【未入力】',
      );
      expect(find.text('記事構成をコピーしました。ChatGPTやnoteに貼り付けられます。'), findsOneWidget);
      expect(find.text('記事を書き出す'), findsNothing);
    },
  );
}
