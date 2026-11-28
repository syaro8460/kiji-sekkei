import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/main.dart';
import 'package:flutter_app/models/article_draft.dart';
import 'package:flutter_app/screens/settings_page.dart';
import 'package:flutter_app/screens/startup_screen.dart';
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
  String? sortOrder;
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
    if (parameters.filter.allowList!.contains(
      AppPreferences.draftSortOrderKey,
    )) {
      return {AppPreferences.draftSortOrderKey: ?state.sortOrder};
    }
    if (state.failRead) throw StateError('read failed');
    final value = state.pendingRead == null
        ? state.value
        : await state.pendingRead!.future;
    return {'appearanceMode': ?value};
  }

  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (key == AppPreferences.draftSortOrderKey) {
      state.sortOrder = value as String;
      return true;
    }
    expect(key, 'appearanceMode');
    state.writes++;
    await state.pendingSave?.future;
    state.value = value as String;
    return true;
  }
}

final class _PendingDataStore extends InMemorySharedPreferencesAsync {
  _PendingDataStore() : super.empty();

  final read = Completer<String?>();
  final keys = <String>[];

  @override
  Future<String?> getString(String key, SharedPreferencesOptions options) {
    keys.add(key);
    return read.future;
  }
}

class _SettingsDatabase extends ArticleDatabase {
  _SettingsDatabase() : super(NativeDatabase.memory());

  int reads = 0;

  @override
  Future<List<ArticleDraft>> listDrafts(DraftStatus status) async {
    reads++;
    return [];
  }
}

void main() {
  late _SettingsDatabase database;
  setUp(() {
    database = _SettingsDatabase();
    addTearDown(database.close);
  });

  Future<void> tap(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.byTooltip('メニュー'));
    await tester.pumpAndSettle();
    await tap(tester, '設定');
  }

  Future<void> open(WidgetTester tester, _PreferenceState state) async {
    final app = await MyApp.restore(
      database: database,
      preferences: AppPreferences(store: _PreferencesBackend(state)),
    );
    await tester.pumpWidget(app);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    await openSettings(tester);
  }

  Brightness brightness(WidgetTester tester, Finder finder) =>
      Theme.of(tester.element(finder)).brightness;

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

  testWidgets('selects, applies and restores all appearance modes', (
    tester,
  ) async {
    final preferences = _PreferenceState();
    await open(tester, preferences);
    expect(find.text('システム'), findsOneWidget);
    expect(find.text('外観の変更は今後のアップデートで反映されます。'), findsNothing);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    expect(brightness(tester, find.text('外観')), Brightness.light);
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
        tester.state<NavigatorState>(find.byType(Navigator)),
        same(navigator),
      );
      expect(
        brightness(tester, find.text('外観')),
        mode == AppearanceMode.dark ? Brightness.dark : Brightness.light,
      );
    }
    await tap(tester, '外観');
    await tap(tester, 'ダーク');
    await tester.pumpWidget(const SizedBox());
    await open(tester, preferences);
    expect(find.text('ダーク'), findsOneWidget);
    expect(brightness(tester, find.text('外観')), Brightness.dark);
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

  testWidgets('locks selection during writes and preserves theme on failure', (
    tester,
  ) async {
    final save = Completer<void>();
    final preferences = _PreferenceState()
      ..value = 'light'
      ..pendingSave = save;
    await open(tester, preferences);
    await tap(tester, '外観');
    await tap(tester, 'ダーク');
    expect(find.text('ライト'), findsOneWidget);
    expect(brightness(tester, find.text('外観')), Brightness.light);
    await tap(tester, '外観');
    expect(find.byType(SimpleDialog), findsNothing);
    expect(preferences.writes, 1);
    save.completeError(StateError('save failed'));
    await tester.pumpAndSettle();
    expect(find.text('外観の設定を保存できませんでした。'), findsOneWidget);
    expect(find.text('ライト'), findsOneWidget);
    expect(brightness(tester, find.text('外観')), Brightness.light);
    await tap(tester, '外観');
    expect(find.byType(SimpleDialog), findsOneWidget);
  });

  testWidgets('waits for the saved appearance before creating the app', (
    tester,
  ) async {
    final read = Completer<String?>();
    final state = _PreferenceState()..pendingRead = read;
    MyApp? app;
    final startup = MyApp.restore(
      database: database,
      preferences: AppPreferences(store: _PreferencesBackend(state)),
    ).then((restored) => app = restored);
    await tester.pump(const Duration(milliseconds: 1999));
    expect(app, isNull);
    read.complete('dark');
    await startup;
    await tester.pumpWidget(app!);
    expect(brightness(tester, find.text('記事設計')), Brightness.dark);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final lateError in [false, true]) {
    testWidgets(
      'starts after a stalled read and recovers (error: $lateError)',
      (tester) async {
        tester.platformDispatcher.platformBrightnessTestValue =
            Brightness.light;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        final read = Completer<String?>();
        final rasterized = Completer<void>();
        final state = _PreferenceState()
          ..value = 'light'
          ..sortOrder = 'updatedOldest'
          ..pendingRead = read;
        final preferences = AppPreferences(store: _PreferencesBackend(state));
        MyApp? app;
        final startup = MyApp.restore(
          database: database,
          firstFrameRasterized: rasterized.future,
          preferences: preferences,
        ).then((restored) => app = restored);

        await tester.pump(const Duration(milliseconds: 1999));
        expect(app, isNull);
        await tester.pump(const Duration(milliseconds: 1));
        await startup;
        expect(state.value, 'light');
        expect(state.writes, 0);
        expect(read.isCompleted, isFalse);

        await tester.pumpWidget(app!);
        expect(
          brightness(tester, find.byType(StartupScreen)),
          Brightness.light,
        );
        expect(
          tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
          ThemeMode.system,
        );
        expect(
          await preferences.load(AppPreferences.draftSortOrderKey),
          'updatedOldest',
        );
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(StartupScreen), findsOneWidget);
        rasterized.complete();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 499));
        expect(find.byType(StartupScreen), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 1));
        expect(find.byType(StartupScreen), findsNothing);

        // New operations can reach the backend while the first read is pending.
        state.pendingRead = null;
        await openSettings(tester);
        await tap(tester, '外観');
        await tap(tester, 'ダーク');
        expect(brightness(tester, find.text('外観')), Brightness.dark);
        expect(state.value, 'dark');
        if (lateError) {
          read.completeError(StateError('delayed read failure'));
        } else {
          read.complete('light');
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(brightness(tester, find.text('外観')), Brightness.dark);
        expect(state.value, 'dark');
      },
    );
  }

  testWidgets('counts the Android DataStore fallback in the same deadline', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final previous = SharedPreferencesAsyncPlatform.instance;
    final dataStore = _PendingDataStore();
    SharedPreferencesAsyncPlatform.instance = dataStore;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      SharedPreferencesAsyncPlatform.instance = previous;
    });
    final legacy = Completer<String?>();
    final state = _PreferenceState()..pendingRead = legacy;
    final preferences = AppPreferences(store: _PreferencesBackend(state));
    MyApp? app;
    final startup = MyApp.restore(
      database: database,
      preferences: preferences,
    ).then((restored) => app = restored);
    await tester.pump(const Duration(seconds: 1));
    legacy.complete(null);
    await tester.pump();
    expect(dataStore.keys, ['appearanceMode']);
    await tester.pump(const Duration(milliseconds: 999));
    expect(app, isNull);
    await tester.pump(const Duration(milliseconds: 1));
    await startup;
    await tester.pumpWidget(app!);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.system,
    );
    expect(state.writes, 0);
    dataStore.read.complete('dark');
    await tester.pump();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.system,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('applies a successful save after settings is removed', (
    tester,
  ) async {
    final save = Completer<void>();
    final state = _PreferenceState()..pendingSave = save;
    await open(tester, state);
    final route = ModalRoute.of(tester.element(find.byType(SettingsPage)))!;
    final navigator = route.navigator!;
    await tap(tester, '外観');
    await tap(tester, 'ダーク');
    navigator.removeRoute(route);
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsNothing);
    expect(brightness(tester, find.text('記事設計')), Brightness.light);
    save.complete();
    await tester.pumpAndSettle();
    expect(brightness(tester, find.text('記事設計')), Brightness.dark);
    expect(state.value, 'dark');
    expect(tester.takeException(), isNull);
  });

  for (final failSave in [false, true]) {
    testWidgets('finishes saving after MyApp is disposed (error: $failSave)', (
      tester,
    ) async {
      final save = Completer<void>();
      final state = _PreferenceState()
        ..value = 'light'
        ..pendingSave = save;
      await open(tester, state);
      await tap(tester, '外観');
      await tap(tester, 'ダーク');
      expect(state.writes, 1);
      expect(state.value, 'light');

      await tester.pumpWidget(const SizedBox.shrink());
      if (failSave) {
        save.completeError(StateError('save failed'));
      } else {
        save.complete();
      }
      await tester.pumpAndSettle();
      final reopened = AppPreferences(store: _PreferencesBackend(state));
      expect(
        await AppearancePreferences(preferences: reopened).load(),
        failSave ? AppearanceMode.light : AppearanceMode.dark,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('blocks back during a save and reopens with the saved value', (
    tester,
  ) async {
    final save = Completer<void>();
    final state = _PreferenceState()..pendingSave = save;
    await open(tester, state);
    await tap(tester, '外観');
    await tap(tester, 'ダーク');
    expect(state.writes, 1);
    await tester.tap(find.byType(BackButton));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.text('システム'), findsOneWidget);
    expect(brightness(tester, find.text('外観')), Brightness.light);
    save.complete();
    await tester.pumpAndSettle();
    expect(brightness(tester, find.text('外観')), Brightness.dark);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsNothing);
    await openSettings(tester);
    expect(find.text('ダーク'), findsOneWidget);
  });

  testWidgets('follows OS brightness only in system mode and retains search', (
    tester,
  ) async {
    final dispatcher = tester.platformDispatcher;
    dispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(dispatcher.clearPlatformBrightnessTestValue);
    final state = _PreferenceState();
    await open(tester, state);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('並べ替え'));
    await tester.pumpAndSettle();
    final option = find.ancestor(
      of: find.text('タイトル（昇順）'),
      matching: find.byWidgetPredicate(
        (widget) => widget is CheckedPopupMenuItem,
      ),
    );
    await tester.tap(option);
    await tester.pumpAndSettle();
    expect(state.sortOrder, 'titleAscending');

    final search = find.widgetWithText(TextField, '検索');
    await tester.enterText(search, '保存する検索');
    await openSettings(tester);
    dispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();
    expect(brightness(tester, find.text('外観')), Brightness.dark);
    await tap(tester, '外観');
    await tap(tester, 'ライト');
    expect(brightness(tester, find.text('外観')), Brightness.light);
    dispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpAndSettle();
    dispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();
    expect(brightness(tester, find.text('外観')), Brightness.light);

    await tap(tester, '外観');
    await tap(tester, 'ダーク');
    dispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpAndSettle();
    expect(brightness(tester, find.text('外観')), Brightness.dark);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    final searchField = tester.widget<TextField>(search);
    expect(searchField.controller!.text, '保存する検索');
    final decoration = searchField.decoration!;
    final outline = decoration.enabledBorder!.borderSide.color;
    final colors = Theme.of(tester.element(search)).colorScheme;
    for (final background in [
      decoration.fillColor!,
      colors.surfaceContainerLow,
    ]) {
      expect(
        (outline.computeLuminance() + 0.05) /
            (background.computeLuminance() + 0.05),
        greaterThanOrEqualTo(3),
      );
    }
    expect(database.reads, 1);
    expect(state.value, 'dark');
    expect(state.sortOrder, 'titleAscending');
    await tester.tap(find.byTooltip('並べ替え'));
    await tester.pumpAndSettle();
    expect(tester.widget<CheckedPopupMenuItem>(option).checked, isTrue);
  });
}
