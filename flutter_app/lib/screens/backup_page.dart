import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';

import '../storage/article_database.dart';
import 'content_page_frame.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({
    super.key,
    required this.database,
    this.pickBackup = _pickBackup,
    this.saveBackup = _saveBackup,
  });

  final ArticleDatabase database;
  final Future<Uint8List?> Function() pickBackup;
  final Future<bool> Function(String filename, Uint8List bytes) saveBackup;

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  bool _busy = false;
  bool _restoring = false;

  void _notify(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final now = DateTime.now();
      final bytes = await widget.database.exportBackup(now: now);
      if (!mounted) return;
      final day = now.toIso8601String().split('T').first;
      if (await widget.saveBackup(
        'kiji-sekkei-$day.json',
        Uint8List.fromList(bytes),
      )) {
        _notify(kIsWeb ? 'バックアップのダウンロードを開始しました。' : 'バックアップを書き出しました。');
      }
    } catch (_) {
      _notify('バックアップを書き出せませんでした。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    setState(() => _busy = true);
    try {
      final bytes = await widget.pickBackup();
      if (!mounted || bytes == null) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('バックアップを復元しますか？'),
          content: const Text('現在の記事（ゴミ箱を含む）とカスタムテンプレートが、ファイルの内容に置き換わります。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('置き換えて復元'),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;

      setState(() => _restoring = true);
      await widget.database.restoreBackup(bytes);
      if (!mounted) return;
      Navigator.pop(context, true);
    } on FormatException {
      _notify('対応するJSONバックアップを選んでください。');
    } catch (_) {
      _notify('バックアップを復元できませんでした。');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _restoring = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_restoring,
    child: ContentPageFrame(
      title: 'バックアップ',
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ContentCard(
            child: ListTile(
              enabled: !_busy,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              leading: const Icon(Icons.file_download_outlined),
              title: const Text('JSONを書き出す'),
              subtitle: const Text('記事とカスタムテンプレートをファイルに保存'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _export,
            ),
          ),
          const SizedBox(height: 8),
          ContentCard(
            child: ListTile(
              enabled: !_busy,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              leading: const Icon(Icons.file_upload_outlined),
              title: const Text('バックアップから復元'),
              subtitle: const Text('保存したJSONファイルを選択'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _import,
            ),
          ),
          if (_busy) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
        ],
      ),
    ),
  );
}

Future<Uint8List?> _pickBackup() async {
  final file = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: ['json'],
  );
  return file?.readAsBytes();
}

Future<bool> _saveBackup(String filename, Uint8List bytes) async {
  final saved = await FilePicker.saveFile(
    fileName: filename,
    mimeType: 'application/json',
    bytes: bytes,
  );
  // The web picker starts a download and returns no file URI.
  return kIsWeb || saved != null;
}
