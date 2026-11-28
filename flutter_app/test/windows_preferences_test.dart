import 'dart:async';
import 'dart:io' show Platform;

import 'package:drift/native.dart';
import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_app/main.dart';
import 'package:flutter_app/models/article_draft.dart';
import 'package:flutter_app/storage/app_preferences.dart';
import 'package:flutter_app/storage/appearance_preferences.dart';
import 'package:flutter_app/storage/article_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider_windows/path_provider_windows.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences_windows/shared_preferences_windows.dart';

class _PathProvider extends PathProviderWindows {
  _PathProvider(this.directory);

  String? directory;
  Future<String?>? nextRequest;
  int requests = 0;

  @override
  Future<String?> getApplicationSupportPath() async {
    requests++;
    final pending = nextRequest;
    nextRequest = null;
    return pending == null ? directory : await pending;
  }
}

void main() {
  const sortKey = AppPreferences.draftSortOrderKey;
  const appearanceKey = 'appearanceMode';
  final useWindowsPaths = Platform.isWindows;
  final directory = useWindowsPaths ? r'C:\preferences' : '/preferences';
  const fileName = 'shared_preferences.json';
  late MemoryFileSystem fs;
  late _PathProvider paths;
  late bool denyWrites;
  late AppPreferences preferences;

  AppPreferences openStore() => AppPreferences(
    store: SharedPreferencesWindows()
      ..fs = fs
      ..pathProvider = paths,
  );

  setUp(() {
    denyWrites = false;
    fs = MemoryFileSystem(
      style: useWindowsPaths ? FileSystemStyle.windows : FileSystemStyle.posix,
      opHandle: (path, operation) {
        if (denyWrites && operation == FileSystemOp.write) {
          denyWrites = false;
          throw FileSystemException('Write denied', path);
        }
      },
    );
    paths = _PathProvider(directory);
    fs.file(fs.path.join(directory, fileName))
      ..createSync(recursive: true)
      ..writeAsStringSync(
        '{"flutter.draftSortOrder":"updatedOldest","appearanceMode":"light","flutter.other":true}',
      );
    preferences = openStore();
  });

  for (final appearanceFirst in [true, false]) {
    test(
      'both settings survive a fresh read (appearance first: $appearanceFirst)',
      () async {
        final appearance = AppearancePreferences(preferences: preferences);
        expect(await preferences.load(sortKey), 'updatedOldest');
        expect(await appearance.load(), AppearanceMode.light);
        final writes = appearanceFirst
            ? [
                appearance.save(AppearanceMode.dark),
                preferences.save(sortKey, 'titleAscending'),
              ]
            : [
                preferences.save(sortKey, 'titleAscending'),
                appearance.save(AppearanceMode.dark),
              ];
        final reading = preferences.load(appearanceKey);
        await Future.wait(writes);
        expect(await reading, 'dark');

        final reopened = openStore();
        expect(await reopened.load(sortKey), 'titleAscending');
        expect(
          await AppearancePreferences(preferences: reopened).load(),
          AppearanceMode.dark,
        );
        expect(
          fs.file(fs.path.join(directory, fileName)).readAsStringSync(),
          contains('"flutter.other":true'),
        );
      },
    );
  }

  testWidgets('Windows startup reads the same file through a separate cache', (
    tester,
  ) async {
    final previous = SharedPreferencesAsyncPlatform.instance;
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    final startupPaths = _PathProvider(directory);
    SharedPreferencesAsyncPlatform.instance = SharedPreferencesAsyncWindows()
      ..fs = fs
      ..pathProvider = startupPaths;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      SharedPreferencesAsyncPlatform.instance = previous;
    });

    final app = await MyApp.restore(preferences: preferences);
    expect(app.initialAppearance, AppearanceMode.light);
    expect(startupPaths.requests, 1);
    expect(paths.requests, 0);
  });

  testWidgets('Windows writes stay serialized after a startup read times out', (
    tester,
  ) async {
    final previous = SharedPreferencesAsyncPlatform.instance;
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    final diskRead = Completer<String?>();
    final startupPaths = _PathProvider(directory)
      ..nextRequest = diskRead.future;
    SharedPreferencesAsyncPlatform.instance = SharedPreferencesAsyncWindows()
      ..fs = fs
      ..pathProvider = startupPaths;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      SharedPreferencesAsyncPlatform.instance = previous;
    });

    final startup = MyApp.restore(preferences: preferences);
    await tester.pump(const Duration(seconds: 2));
    expect((await startup).initialAppearance, AppearanceMode.system);
    expect(startupPaths.requests, 1);
    expect(paths.requests, 0);
    expect(await preferences.load(sortKey), 'updatedOldest');
    expect(await preferences.load(appearanceKey), 'light');

    final firstWritePath = Completer<String?>();
    paths.nextRequest = firstWritePath.future;
    final writes = Future.wait([
      AppearancePreferences(preferences: preferences).save(AppearanceMode.dark),
      preferences.save(sortKey, 'titleAscending'),
    ]);
    await tester.pump();
    expect(paths.requests, 2); // Cold read and the first write only.
    expect(await openStore().load(appearanceKey), 'light');
    expect(await openStore().load(sortKey), 'updatedOldest');

    diskRead.complete(directory);
    await tester.pump();
    expect(startupPaths.requests, 1);
    // The late read completes while the first write still owns the queue.
    expect(paths.requests, 4); // Includes the two independent disk reads above.
    firstWritePath.complete(directory);
    await writes;

    final reopened = openStore();
    expect(await reopened.load(appearanceKey), 'dark');
    expect(await reopened.load(sortKey), 'titleAscending');
    expect(
      fs.file(fs.path.join(directory, fileName)).readAsStringSync(),
      contains('"flutter.other":true'),
    );
    expect(tester.takeException(), isNull);
  });

  for (final unavailablePath in [true, false]) {
    testWidgets(
      'preserves preferences after a failed Windows write (missing path: $unavailablePath)',
      (tester) async {
        final database = ArticleDatabase(NativeDatabase.memory());
        addTearDown(database.close);
        await tester.runAsync(() => database.listDrafts(DraftStatus.active));
        Future<void> open() async {
          await tester.pumpWidget(
            await MyApp.restore(database: database, preferences: preferences),
          );
          await tester.pump(const Duration(milliseconds: 500));
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('メニュー'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('設定'));
          await tester.pumpAndSettle();
        }

        await open();
        expect(find.text('ライト'), findsOneWidget);
        expect(await preferences.load(sortKey), 'updatedOldest');
        if (unavailablePath) {
          paths.directory = null;
        } else {
          denyWrites = true;
        }

        await tester.tap(find.text('外観'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('ダーク'));
        await tester.pumpAndSettle();
        expect(find.text('外観の設定を保存できませんでした。'), findsOneWidget);
        expect(find.text('ライト'), findsOneWidget);
        if (!unavailablePath) denyWrites = true;
        await expectLater(
          preferences.save(sortKey, 'titleDescending'),
          throwsStateError,
        );
        expect(await preferences.load(sortKey), 'updatedOldest');

        await tester.pumpWidget(const SizedBox());
        await open();
        expect(find.text('ライト'), findsOneWidget);
        paths.directory = directory;
        denyWrites = false;
        final reopened = openStore();
        expect(await reopened.load(sortKey), 'updatedOldest');
        expect(await reopened.load(appearanceKey), 'light');
        await preferences.save(sortKey, 'titleAscending');
        expect(await openStore().load(appearanceKey), 'light');
      },
    );
  }
}
