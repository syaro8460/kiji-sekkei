import 'package:drift/native.dart';
import 'package:flutter_app/main.dart';
import 'package:flutter_app/models/article_draft.dart';
import 'package:flutter_app/screens/article_questions_page.dart';
import 'package:flutter_app/storage/article_database.dart';
import 'package:flutter_app/storage/appearance_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const _originalQuestions = [
  (text: '最初の質問', answer: '最初の回答'),
  (text: '次の質問', answer: '次の回答'),
];
final _confirmation = find.text('変更を破棄しますか？');
final _back = find.byType(BackButton);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _openQuestions(
  WidgetTester tester, {
  List<ArticleQuestion> questions = _originalQuestions,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push<List<ArticleQuestion>>(
              MaterialPageRoute(
                builder: (_) => ArticleQuestionsPage(questions: questions),
              ),
            ),
            child: const Text('記事'),
          ),
        ),
      ),
    ),
  );
  await _tap(tester, find.text('記事'));
}

Future<void> _add(WidgetTester tester, {bool cancel = false}) async {
  await _tap(tester, find.text('質問を追加'));
  await tester.enterText(find.byType(TextFormField), '追加した質問');
  await _tap(tester, find.text(cancel ? 'キャンセル' : '完了'));
}

Future<void> _rename(WidgetTester tester, String from, String to) async {
  await _tap(tester, find.text(from));
  await tester.enterText(find.byType(TextFormField), to);
  await _tap(tester, find.text('完了'));
}

Future<void> _delete(WidgetTester tester, String question) async {
  await _tap(tester, find.byTooltip('$question の操作'));
  await _tap(tester, find.text('削除'));
  await _tap(tester, find.text('削除'));
}

Future<void> _moveSecondQuestionToFirst(
  WidgetTester tester, {
  String first = '最初の質問',
  String second = '次の質問',
  bool duplicates = false,
}) async {
  final handles = find.byTooltip('$second をドラッグして並べ替え');
  final handle = duplicates ? handles.last : handles;
  final target = tester.getCenter(find.text(first).first).dy;
  await tester.timedDrag(
    handle,
    Offset(0, target - tester.getCenter(handle).dy - 12),
    const Duration(milliseconds: 400),
  );
  await tester.pumpAndSettle();
}

void _expectCleanExit() {
  expect(_confirmation, findsNothing);
  expect(find.byType(ArticleQuestionsPage), findsNothing);
  expect(find.text('記事'), findsOneWidget);
}

void main() {
  testWidgets('leaves immediately without edits', (tester) async {
    await _openQuestions(tester);
    await _tap(tester, _back);
    _expectCleanExit();
  });

  testWidgets('cancelling the addition dialog keeps the list clean', (
    tester,
  ) async {
    await _openQuestions(tester);
    await _add(tester, cancel: true);
    await _tap(tester, _back);
    _expectCleanExit();
  });

  final edits = <String, Future<void> Function(WidgetTester)>{
    'adding a question': _add,
    'renaming a question': (tester) => _rename(tester, '最初の質問', '変更した質問'),
    'deleting a question': (tester) => _delete(tester, '次の質問'),
    'reordering questions': _moveSecondQuestionToFirst,
    'combining edits': (tester) async {
      await _moveSecondQuestionToFirst(tester);
      await _rename(tester, '最初の質問', '変更した質問');
      await _delete(tester, '次の質問');
      await _add(tester);
    },
  };

  for (final MapEntry(key: name, value: edit) in edits.entries) {
    testWidgets('app bar confirms after $name and discards once', (
      tester,
    ) async {
      await _openQuestions(tester);
      await edit(tester);
      await _tap(tester, _back);
      expect(_confirmation, findsOneWidget);
      expect(find.text('未反映の変更があります。変更を破棄して戻りますか？'), findsOneWidget);
      await _tap(tester, find.text('破棄'));
      _expectCleanExit();
    });
  }

  testWidgets('restoring exact content and order clears the changes', (
    tester,
  ) async {
    await _openQuestions(tester);
    await _moveSecondQuestionToFirst(tester);
    await _moveSecondQuestionToFirst(tester, first: '次の質問', second: '最初の質問');
    await _rename(tester, '最初の質問', '変更した質問');
    await _rename(tester, '変更した質問', '最初の質問');
    await _add(tester);
    await _delete(tester, '追加した質問');
    await _tap(tester, _back);
    _expectCleanExit();
  });

  for (final answersDiffer in [true, false]) {
    testWidgets('compares answers for equal question names ($answersDiffer)', (
      tester,
    ) async {
      await _openQuestions(
        tester,
        questions: [
          (text: '同じ質問', answer: '回答1'),
          (text: '同じ質問', answer: answersDiffer ? '回答2' : '回答1'),
        ],
      );
      final cards = find.byType(Card);
      final originalFirstKey = tester.widget<Card>(cards.first).key!;
      await _moveSecondQuestionToFirst(
        tester,
        first: '同じ質問',
        second: '同じ質問',
        duplicates: true,
      );
      expect(tester.widget<Card>(cards.last).key, originalFirstKey);
      await _tap(tester, _back);
      if (answersDiffer) {
        expect(_confirmation, findsOneWidget);
        await _tap(tester, find.text('破棄'));
      }
      _expectCleanExit();
    });
  }

  testWidgets('re-adding a question without its answer is a change', (
    tester,
  ) async {
    await _openQuestions(
      tester,
      questions: const [(text: '追加した質問', answer: '以前の回答')],
    );
    await _delete(tester, '追加した質問');
    await _add(tester);
    await _tap(tester, _back);
    expect(_confirmation, findsOneWidget);
  });

  testWidgets('system back is guarded and cancelling keeps the working list', (
    tester,
  ) async {
    await _openQuestions(tester);
    await _add(tester);
    await _rename(tester, '最初の質問', '変更した質問');

    final route = ModalRoute.of(tester.element(_back))!;
    await tester.binding.handlePopRoute();
    // Repeated blocked-pop notifications can arrive before the next frame.
    route.onPopInvokedWithResult(false, null);
    route.onPopInvokedWithResult(false, null);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog, skipOffstage: false), findsOneWidget);
    expect(_confirmation, findsOneWidget);

    await _tap(tester, find.text('編集に戻る'));
    expect(_confirmation, findsNothing);
    expect(find.text('追加した質問'), findsOneWidget);
    expect(find.text('変更した質問'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(_confirmation, findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(_confirmation, findsNothing);
    expect(find.text('追加した質問'), findsOneWidget);
    expect(find.text('変更した質問'), findsOneWidget);

    await _tap(tester, _back);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(_confirmation, findsNothing);
    expect(find.text('追加した質問'), findsOneWidget);
    expect(find.text('変更した質問'), findsOneWidget);
  });

  testWidgets('system back before repaint after adding a question', (
    tester,
  ) async {
    await _openQuestions(tester);
    await _tap(tester, find.text('質問を追加'));
    await tester.enterText(find.byType(TextFormField), '追加した質問');
    await tester.tap(find.text('完了'));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(_confirmation, findsOneWidget);
    await _tap(tester, find.text('編集に戻る'));
    expect(find.text('追加した質問'), findsOneWidget);
  });

  testWidgets('app bar back before repaint after a reorder', (tester) async {
    await _openQuestions(tester);
    final list = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView),
    );
    // Deliver the reorder without advancing a frame before the back tap.
    list.onReorderItem!(1, 0);
    await tester.tap(_back);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(_confirmation, findsOneWidget);
    await _tap(tester, find.text('編集に戻る'));
    expect(
      tester.getTopLeft(find.text('次の質問')).dy,
      lessThan(tester.getTopLeft(find.text('最初の質問')).dy),
    );
  });

  testWidgets('repeated back before the first frame and while confirming', (
    tester,
  ) async {
    await _openQuestions(tester);
    await _add(tester);

    await tester.binding.handlePopRoute();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(AlertDialog, skipOffstage: false), findsOneWidget);
    expect(_confirmation, findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(_confirmation, findsNothing);
    expect(find.text('追加した質問'), findsOneWidget);

    await _tap(tester, _back);
    expect(_confirmation, findsOneWidget);
    final discard = tester.getCenter(find.text('破棄'));
    await tester.tapAt(discard);
    await tester.tapAt(discard);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    _expectCleanExit();
  });

  testWidgets('discard is safe if the editing route was already removed', (
    tester,
  ) async {
    await _openQuestions(tester);
    await _add(tester);
    final context = tester.element(_back);
    final route = ModalRoute.of(context)!;
    final navigator = Navigator.of(context);
    await _tap(tester, _back);
    expect(_confirmation, findsOneWidget);

    navigator.removeRoute(route);
    await tester.pumpAndSettle();
    await _tap(tester, find.text('破棄'));
    _expectCleanExit();
    expect(tester.takeException(), isNull);
  });

  for (final mode in [AppearanceMode.light, AppearanceMode.dark]) {
    testWidgets('discard preserves the editor and database in ${mode.name}', (
      tester,
    ) async {
      final database = await _openArticle(tester, mode: mode);
      await _tap(tester, find.text('質問を編集'));
      await _moveSecondQuestionToFirst(tester);
      await _rename(tester, '最初の質問', '変更した質問');
      await _delete(tester, '次の質問');
      await _add(tester);

      await _tap(tester, _back);
      final dialog = find.byType(AlertDialog);
      expect(_confirmation, findsOneWidget);
      expect(
        Theme.of(tester.element(dialog)).brightness,
        mode == AppearanceMode.dark ? Brightness.dark : Brightness.light,
      );
      expect(
        find.widgetWithText(TextButton, '編集に戻る').hitTestable(),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(FilledButton, '破棄').hitTestable(),
        findsOneWidget,
      );
      await _tap(tester, find.text('破棄'));

      expect(_confirmation, findsNothing);
      expect(find.byType(ArticleQuestionsPage), findsNothing);
      expect(find.text('変更した質問'), findsNothing);
      expect(find.text('追加した質問'), findsNothing);
      _expectAnswer(tester, '最初の質問', '最初の回答');
      _expectAnswer(tester, '次の質問', '次の回答');
      expect(
        tester.getTopLeft(find.text('最初の質問')).dy,
        lessThan(tester.getTopLeft(find.text('次の質問')).dy),
      );

      await _tap(tester, _back);
      final saved = await _readArticle(tester, database);
      expect(saved.questions, ['最初の質問', '次の質問']);
      expect(saved.answers, _originalAnswers);
      expect(database.saveRequests, 0);
    });
  }

  testWidgets(
    'apply saves the edited order and answers once and reloads them',
    (tester) async {
      final database = await _openArticle(tester);
      await _tap(tester, find.text('質問を編集'));
      await _moveSecondQuestionToFirst(tester);
      await _rename(tester, '最初の質問', '変更した質問');
      await _add(tester);

      final apply = tester.widget<TextButton>(
        find.widgetWithText(TextButton, '反映'),
      );
      apply.onPressed!();
      apply.onPressed!();
      await tester.pumpAndSettle();
      expect(_confirmation, findsNothing);
      expect(find.byType(ArticleQuestionsPage), findsNothing);
      _expectAnswer(tester, '変更した質問', '最初の回答');
      _expectAnswer(tester, '次の質問', '次の回答');
      _expectAnswer(tester, '追加した質問', '');

      await _tap(tester, _back);
      final saved = await _readArticle(tester, database);
      expect(saved.questions, ['次の質問', '変更した質問', '追加した質問']);
      expect(saved.answers, {
        '次の質問': '次の回答',
        '変更した質問': '最初の回答',
        '追加した質問': '',
        '互換用': '保持する',
      });
      expect(database.saveRequests, 1);

      await _tap(tester, find.text('確認用の記事'));
      _expectAnswer(tester, '次の質問', '次の回答');
      _expectAnswer(tester, '変更した質問', '最初の回答');
      _expectAnswer(tester, '追加した質問', '');
      expect(
        tester.getTopLeft(find.text('次の質問')).dy,
        lessThan(tester.getTopLeft(find.text('変更した質問')).dy),
      );
      expect(
        tester.getTopLeft(find.text('変更した質問')).dy,
        lessThan(tester.getTopLeft(find.text('追加した質問')).dy),
      );
    },
  );
}

const _originalAnswers = {'最初の質問': '最初の回答', '次の質問': '次の回答', '互換用': '保持する'};

class _CountingDatabase extends ArticleDatabase {
  _CountingDatabase() : super(NativeDatabase.memory());

  int saveRequests = 0;

  @override
  Future<void> saveDraft(ArticleDraft draft) {
    saveRequests++;
    return super.saveDraft(draft);
  }
}

Future<_CountingDatabase> _openArticle(
  WidgetTester tester, {
  AppearanceMode mode = AppearanceMode.light,
}) async {
  await tester.binding.setSurfaceSize(const Size(700, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final database = _CountingDatabase();
  addTearDown(database.close);
  await tester.runAsync(
    () => database.saveDraft(
      ArticleDraft(
        id: '6017fdb4-7019-4228-98c0-55af8167ac20',
        title: '確認用の記事',
        articleType: '日記',
        questions: const ['最初の質問', '次の質問'],
        answers: _originalAnswers,
      ),
    ),
  );
  database.saveRequests = 0;
  await tester.pumpWidget(MyApp(database: database, initialAppearance: mode));
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
  await _tap(tester, find.text('確認用の記事'));
  return database;
}

Future<ArticleDraft> _readArticle(
  WidgetTester tester,
  ArticleDatabase database,
) async =>
    (await tester.runAsync(() => database.listDrafts(DraftStatus.active)))!
        .single;

void _expectAnswer(WidgetTester tester, String question, String answer) {
  final field = tester.widget<TextFormField>(find.byKey(ValueKey(question)));
  expect(field.controller!.text, answer);
}
