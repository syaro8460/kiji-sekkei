import 'package:drift/native.dart';
import 'package:flutter_app/main.dart';
import 'package:flutter_app/models/article_draft.dart';
import 'package:flutter_app/models/article_template.dart';
import 'package:flutter_app/storage/article_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

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

    await tester.tap(find.text('新しい記事'));
    await tester.pumpAndSettle();
    final template = ArticleTemplate.builtInTemplates.first;
    await tester.tap(find.text(template.name));
    await tester.pumpAndSettle();

    final title = find.byType(TextFormField).first;
    await tester.enterText(title, '最初の記事');
    await tester.enterText(find.byType(TextFormField).at(1), '記事のメモ');
    final save = find.widgetWithText(FilledButton, '保存');
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
}
