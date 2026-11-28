import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/screens/settings_page.dart';
import 'package:flutter_app/storage/app_preferences.dart';
import 'package:flutter_app/storage/appearance_preferences.dart';
import 'package:flutter_app/storage/article_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

class _PreferenceState {
  String? value;
  bool failRead = false;
  Completer<String?>? pendingRead;
  Completer<void>? pendingSave;
  int writes = 0;
}

class _PreferencesBackend extends InMemorySharedPreferencesStore {
  _PreferencesBackend(this.state) : super.empty();

  final _PreferenceState state;

  @override
  Future<Map<String, Object>> getAllWithParameters(
    GetAllParameters parameters,
  ) async {
    if (state.failRead) throw StateError('read failed');
    final value = state.pendingRead == null
        ? state.value
        : await state.pendingRead!.future;
    return {'appearanceMode': ?value};
  }

  @override
  Future<bool> setValue(String type, String key, Object value) async {
    expect(key, 'appearanceMode');
    state.writes++;
    await state.pendingSave?.future;
    state.value = value as String;
    return true;
  }
}

void main() {
  late ArticleDatabase database;
  setUp(() {
    database = ArticleDatabase(NativeDatabase.memory());
    addTearDown(database.close);
  });

  Future<void> open(WidgetTester tester, _PreferenceState preferences) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ja', 'JP'),
        supportedLocales: const [Locale('ja', 'JP')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: SettingsPage(
          database: database,
          appearancePreferences: AppearancePreferences(
            preferences: AppPreferences(
              store: _PreferencesBackend(preferences),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  test(
    'reads earlier Android DataStore appearance and prefers subsequent saves',
    () async {
      final previous = SharedPreferencesAsyncPlatform.instance;
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({'appearanceMode': 'dark'});
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() {
        SharedPreferencesAsyncPlatform.instance = previous;
        debugDefaultTargetPlatformOverride = null;
      });
      final preferences = AppPreferences(
        store: InMemorySharedPreferencesStore.withData({
          AppPreferences.draftSortOrderKey: 'updatedOldest',
        }),
      );
      final appearance = AppearancePreferences(preferences: preferences);
      expect(await appearance.load(), AppearanceMode.dark);
      await appearance.save(AppearanceMode.light);
      expect(
        await AppearancePreferences(preferences: preferences).load(),
        AppearanceMode.light,
      );
      expect(
        await preferences.load(AppPreferences.draftSortOrderKey),
        'updatedOldest',
      );
    },
  );

  testWidgets('shows the fallback when package metadata cannot be read', (
    tester,
  ) async {
    const channel = MethodChannel('dev.fluttercommunity.plus/package_info');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      throw PlatformException(code: 'unavailable');
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    await open(tester, _PreferenceState());
    expect(find.text('-'), findsOneWidget);
  });

  testWidgets('shows build version and opens localized licenses', (
    tester,
  ) async {
    const channel = MethodChannel('dev.fluttercommunity.plus/package_info');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      expect(call.method, 'getAll');
      return {'version': '3.2.1', 'buildNumber': '456'};
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    await open(tester, _PreferenceState());
    expect(find.text('3.2.1'), findsOneWidget);
    expect(find.textContaining('456'), findsNothing);
    expect(find.text('プライバシーポリシー'), findsNothing);
    await tap(tester, 'オープンソースライセンス');
    final page = tester.widget<LicensePage>(find.byType(LicensePage));
    expect(page.applicationName, '記事設計');
    final context = tester.element(find.byType(LicensePage));
    expect(MaterialLocalizations.of(context).licensesPageTitle, 'ライセンス');
    await tester.tap(find.byTooltip('戻る').first);
    await tester.pumpAndSettle();
    expect(find.text('設定'), findsOneWidget);
  });

  testWidgets('selects and persists all modes without applying a theme', (
    tester,
  ) async {
    final preferences = _PreferenceState();
    await open(tester, preferences);
    expect(find.text('システム'), findsOneWidget);
    expect(find.text('外観の変更は今後のアップデートで反映されます。'), findsOneWidget);
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    for (final mode in [
      AppearanceMode.light,
      AppearanceMode.dark,
      AppearanceMode.system,
    ]) {
      await tap(tester, '外観');
      for (final option in AppearanceMode.values) {
        expect(
          find.widgetWithText(ListTile, option.label).hitTestable(),
          findsOneWidget,
        );
      }
      await tap(tester, mode.label);
      expect(preferences.value, mode.name);
      expect(find.text(mode.label), findsOneWidget);
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        app.themeMode,
      );
      expect(
        Theme.of(tester.element(find.text('外観'))).brightness,
        Brightness.light,
      );
    }
    await tap(tester, '外観');
    await tap(tester, 'ダーク');
    await tester.pumpWidget(const SizedBox());
    await open(tester, preferences);
    expect(find.text('ダーク'), findsOneWidget);
  });

  testWidgets('defaults to system for unknown values and read failures', (
    tester,
  ) async {
    for (final failRead in [false, true]) {
      await open(
        tester,
        _PreferenceState()
          ..value = failRead ? 'dark' : 'unknown'
          ..failRead = failRead,
      );
      expect(find.text('システム'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('locks selection during reads and writes and handles failures', (
    tester,
  ) async {
    final read = Completer<String?>();
    final save = Completer<void>();
    final preferences = _PreferenceState()
      ..pendingRead = read
      ..pendingSave = save;
    await open(tester, preferences);
    await tap(tester, '外観');
    expect(find.byType(SimpleDialog), findsNothing);
    read.complete('light');
    await tester.pumpAndSettle();
    await tap(tester, '外観');
    await tap(tester, 'ダーク');
    expect(find.text('ライト'), findsOneWidget);
    await tap(tester, '外観');
    expect(find.byType(SimpleDialog), findsNothing);
    expect(preferences.writes, 1);
    save.completeError(StateError('save failed'));
    await tester.pumpAndSettle();
    expect(find.text('外観の設定を保存できませんでした。'), findsOneWidget);
    expect(find.text('ライト'), findsOneWidget);
    await tap(tester, '外観');
    expect(find.byType(SimpleDialog), findsOneWidget);
  });

  testWidgets('read and save completions are safe after disposal', (
    tester,
  ) async {
    final read = Completer<String?>();
    final preferences = _PreferenceState()..pendingRead = read;
    await open(tester, preferences);
    await tester.pumpWidget(const SizedBox());
    read.complete('light');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    preferences
      ..pendingRead = null
      ..value = 'light';
    final save = Completer<void>();
    preferences.pendingSave = save;
    await open(tester, preferences);
    await tap(tester, '外観');
    await tap(tester, 'ダーク');
    await tester.pumpWidget(const SizedBox());
    save.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('blocks back during a save and reopens with the saved value', (
    tester,
  ) async {
    final save = Completer<void>();
    final state = _PreferenceState()..pendingSave = save;
    final preferences = AppearancePreferences(
      preferences: AppPreferences(store: _PreferencesBackend(state)),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => SettingsPage(
                    database: database,
                    appearancePreferences: preferences,
                  ),
                ),
              ),
              child: const Text('Open settings'),
            ),
          ),
        ),
      ),
    );
    await tap(tester, 'Open settings');
    await tap(tester, '外観');
    await tap(tester, 'ダーク');
    expect(state.writes, 1);
    await tester.tap(find.byType(BackButton));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.text('システム'), findsOneWidget);
    save.complete();
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsNothing);
    await tap(tester, 'Open settings');
    expect(find.text('ダーク'), findsOneWidget);
  });
}
