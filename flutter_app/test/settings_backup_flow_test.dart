import 'dart:async';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_app/main.dart';
import 'package:flutter_app/models/article_draft.dart';
import 'package:flutter_app/models/backup_data.dart';
import 'package:flutter_app/models/backup_manager.dart';
import 'package:flutter_app/screens/backup_page.dart';
import 'package:flutter_app/storage/article_database.dart';
import 'package:flutter_test/flutter_test.dart';

final class _BackupFile extends PlatformFile {
  _BackupFile(this.bytes);
  final Uint8List bytes;

  @override
  Future<Uint8List> readAsBytes() async => bytes;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _BackupPicker extends FilePickerPlatform {
  PlatformFile? file;

  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    expect(type, FileType.custom);
    expect(allowedExtensions, ['json']);
    return file;
  }
}

class _FailingRestoreDatabase extends ArticleDatabase {
  _FailingRestoreDatabase() : super(NativeDatabase.memory());

  bool failRestore = true;
  final finishRestore = Completer<void>();
  int successfulAttempts = 0;
  int activeListReads = 0;

  @override
  Future<List<ArticleDraft>> listDrafts(DraftStatus status) {
    if (status == DraftStatus.active) activeListReads++;
    return super.listDrafts(status);
  }

  @override
  Future<void> restoreBackupData(BackupData backup) async {
    if (failRestore) throw StateError('restore failed');
    successfulAttempts++;
    await finishRestore.future;
    await super.restoreBackupData(backup);
  }
}

void main() {
  testWidgets('returns to the list and reloads after a confirmed restore', (
    tester,
  ) async {
    final database = _FailingRestoreDatabase();
    addTearDown(database.close);
    await tester.runAsync(
      () => database.saveDraft(
        ArticleDraft(
          id: 'c82ad43a-527c-4717-9c7a-8bc10d6730ae',
          title: '現在の記事',
          articleType: '日記',
          questions: [],
        ),
      ),
    );
    final originalPicker = FilePickerPlatform.instance;
    final picker = _BackupPicker();
    FilePickerPlatform.instance = picker;
    addTearDown(() => FilePickerPlatform.instance = originalPicker);

    Future<void> tap(Finder finder, {bool opensDialog = false}) async {
      await tester.tap(finder);
      if (opensDialog) {
        // The progress indicator keeps animating while the dialog is open.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      } else {
        await tester.pumpAndSettle();
      }
    }

    await tester.pumpWidget(MyApp(database: database));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('現在の記事'), findsOneWidget);

    await tap(find.byTooltip('メニュー'));
    await tap(find.text('設定'));
    await tap(find.text('バックアップ'));
    expect(find.byType(BackupPage), findsOneWidget);

    final import = find.text('バックアップを読み込む');
    const notice = 'バックアップを読み込みました。';
    await tap(import);
    expect(find.byType(BackupPage), findsOneWidget);
    expect(find.text(notice), findsNothing);
    picker.file = _BackupFile(Uint8List.fromList([1, 2, 3]));
    await tap(import);
    expect(find.byType(BackupPage), findsOneWidget);
    expect(find.text(notice), findsNothing);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    picker.file = _BackupFile(
      BackupManager().encode(
        BackupData(
          schemaVersion: 1,
          exportedAt: DateTime.utc(2026),
          drafts: [
            ArticleDraft(
              id: '5d35cccd-ff13-4bbe-a4e0-3effabff9b75',
              title: '復元した記事',
              articleType: '日記',
              questions: [],
            ),
          ],
          templates: [],
        ),
      ),
    );
    await tap(import, opensDialog: true);
    await tap(find.text('キャンセル'));
    expect(find.byType(BackupPage), findsOneWidget);
    expect(find.text(notice), findsNothing);

    await tap(import, opensDialog: true);
    await tap(find.text('復元する'));
    expect(find.byType(BackupPage), findsOneWidget);
    expect(find.text('バックアップを復元できませんでした。'), findsOneWidget);
    expect(find.text(notice), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    final readsBeforeRestore = database.activeListReads;
    database.failRestore = false;
    await tap(import, opensDialog: true);
    await tap(find.text('復元する'), opensDialog: true);
    expect(database.successfulAttempts, 1);
    await tester.tap(find.byTooltip('戻る'));
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(BackupPage), findsOneWidget);
    expect(database.activeListReads, readsBeforeRestore);
    expect(find.text(notice), findsNothing);
    database.finishRestore.complete();
    await tester.pumpAndSettle();
    expect(find.byType(BackupPage), findsNothing);
    expect(find.text('設定'), findsNothing);
    expect(find.text('現在の記事'), findsNothing);
    expect(find.text('復元した記事'), findsOneWidget);
    expect(find.text(notice), findsOneWidget);
    expect(database.activeListReads, readsBeforeRestore + 1);
    expect(database.successfulAttempts, 1);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text(notice), findsNothing);
  });
}
