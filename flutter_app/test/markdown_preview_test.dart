import 'dart:convert';

import 'package:flutter_app/export/markdown_exporter.dart';
import 'package:flutter_app/models/article_draft.dart';
import 'package:flutter_app/screens/article_preview_page.dart';
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

  testWidgets('previews content and writes Markdown as UTF-8', (tester) async {
    String? savedText;
    await tester.pumpWidget(
      MaterialApp(
        home: ArticlePreviewPage(
          draft: draft,
          saveMarkdown: (filename, bytes) async {
            expect(filename, 'kiji-記事 _ 見出し.md');
            savedText = utf8.decode(bytes);
            return true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('記事 / 見出し'), findsOneWidget);
    expect(find.text('記事タグ'), findsOneWidget);
    expect(find.text('一行目\n二行目'), findsOneWidget);
    expect(find.text('未回答'), findsOneWidget);
    await tester.tap(find.text('記事をファイルに保存'));
    await tester.pumpAndSettle();
    expect(savedText, expected);
    expect(find.text('記事をファイルに保存しました。'), findsOneWidget);
  });
}
