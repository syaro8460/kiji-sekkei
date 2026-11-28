import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/main.dart';
import 'package:flutter_app/models/article_draft.dart';
import 'package:flutter_app/screens/startup_screen.dart';
import 'package:flutter_app/storage/article_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _migrationChannel = MethodChannel('kijisekkei/legacy_ios_migration');

class _StartupDatabase extends ArticleDatabase {
  _StartupDatabase() : super(NativeDatabase.memory());

  var draftLoad = Completer<List<ArticleDraft>>();

  @override
  Future<List<ArticleDraft>> listDrafts(DraftStatus status) => draftLoad.future;

  @override
  Future<bool> hasCompletedLegacyIosMigration() async => false;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final brightness in Brightness.values) {
    testWidgets('shows the startup design in $brightness', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await tester.binding.setSurfaceSize(const Size(560, 240));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const MaterialApp(home: StartupScreen()));

      final expectedColor = brightness == Brightness.dark
          ? const Color(0xFF30D158)
          : const Color(0xFF34C759);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        expectedColor,
      );
      final logo = find.byType(Image);
      expect(tester.getSize(logo), const Size(120, 120));
      expect(
        tester.widget<Image>(logo).image,
        isA<AssetImage>().having(
          (image) => image.assetName,
          'assetName',
          'assets/startup_logo.png',
        ),
      );
      expect(
        tester.widget<ClipRRect>(find.byType(ClipRRect)).borderRadius,
        BorderRadius.circular(24),
      );
      final title = find.text('記事設計');
      final titleStyle = tester.widget<Text>(title).style!;
      expect(titleStyle.fontSize, 34);
      expect(titleStyle.fontWeight, FontWeight.bold);
      expect(titleStyle.color, Colors.white);
      expect(tester.getTopLeft(title).dy - tester.getBottomLeft(logo).dy, 24);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'measures 500 ms from first rasterization even when data is ready',
    (tester) async {
      final database = _StartupDatabase();
      addTearDown(database.close);
      final firstFrame = Completer<void>();
      database.draftLoad.complete([]);
      await tester.pumpWidget(
        MyApp(database: database, firstFrameRasterized: firstFrame.future),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(StartupScreen), findsOneWidget);

      firstFrame.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 499));
      expect(find.byType(StartupScreen), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.byType(StartupScreen), findsNothing);
      expect(find.text('まだ記事がありません'), findsOneWidget);
    },
  );

  testWidgets('does not wait again when the initial read takes over 500 ms', (
    tester,
  ) async {
    final database = _StartupDatabase();
    addTearDown(database.close);
    await tester.pumpWidget(MyApp(database: database));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byType(StartupScreen), findsOneWidget);
    database.draftLoad.complete([]);
    await tester.idle();
    await tester.pump();
    expect(find.byType(StartupScreen), findsNothing);
    expect(find.text('まだ記事がありません'), findsOneWidget);
  });

  testWidgets(
    'shows a first read error after 500 ms and retries without startup',
    (tester) async {
      final database = _StartupDatabase();
      addTearDown(database.close);
      await tester.pumpWidget(MyApp(database: database));
      database.draftLoad.completeError(StateError('test read failure'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 499));
      expect(find.byType(StartupScreen), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.byType(StartupScreen), findsNothing);
      expect(find.text('記事を読み込めませんでした。'), findsOneWidget);

      database.draftLoad = Completer<List<ArticleDraft>>();
      await tester.tap(find.text('再読み込み'));
      await tester.pump();
      expect(find.byType(StartupScreen), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      database.draftLoad.complete([]);
      await tester.pump();
      expect(find.text('まだ記事がありません'), findsOneWidget);
    },
  );

  testWidgets('disposes cleanly during the minimum display time', (
    tester,
  ) async {
    final database = _StartupDatabase();
    addTearDown(database.close);
    await tester.pumpWidget(MyApp(database: database));
    expect(find.byType(StartupScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    database.draftLoad.complete([]);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  for (final retry in [false, true]) {
    testWidgets(
      'shows migration progress and handles failure (retry: $retry)',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final database = _StartupDatabase();
        addTearDown(database.close);

        final migration = Completer<Map<String, Object?>>();
        final secondAttempt = Completer<Map<String, Object?>>();
        final messenger = tester.binding.defaultBinaryMessenger;
        var attempts = 0;
        messenger.setMockMethodCallHandler(_migrationChannel, (call) {
          expect(call.method, 'read');
          attempts++;
          return attempts == 1 ? migration.future : secondAttempt.future;
        });
        addTearDown(
          () => messenger.setMockMethodCallHandler(_migrationChannel, null),
        );

        await tester.pumpWidget(MyApp(database: database));
        expect(find.byType(StartupScreen), findsOneWidget);
        expect(find.bySemanticsLabel('旧版のデータを移行しています'), findsOneWidget);

        migration.completeError(PlatformException(code: 'test_failure'));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byType(StartupScreen), findsNothing);
        expect(find.text('再試行'), findsOneWidget);
        expect(find.text('現在のデータで開く'), findsOneWidget);

        await tester.tap(find.text(retry ? '再試行' : '現在のデータで開く'));
        await tester.pump();
        expect(find.byType(StartupScreen), findsOneWidget);
        if (retry) {
          expect(attempts, 2);
          expect(find.bySemanticsLabel('旧版のデータを移行しています'), findsOneWidget);
          secondAttempt.complete({'applicable': false});
          await tester.pump();
        } else {
          expect(attempts, 1);
        }
        expect(find.byType(CircularProgressIndicator), findsNothing);
        database.draftLoad.complete([]);
        await tester.pump();
        expect(find.byType(StartupScreen), findsNothing);
        expect(find.text('まだ記事がありません'), findsOneWidget);
      },
    );
  }
}
