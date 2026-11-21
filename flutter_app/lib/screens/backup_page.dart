import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../storage/article_database.dart';

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
        _notify('バックアップを書き出しました。');
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
    child: Scaffold(
      appBar: AppBar(title: const Text('バックアップ')),
      body: SafeArea(
        child: ListView(
          children: [
            ListTile(
              enabled: !_busy,
              leading: const Icon(Icons.file_download_outlined),
              title: const Text('JSONを書き出す'),
              subtitle: const Text('記事とカスタムテンプレートをファイルに保存'),
              onTap: _export,
            ),
            ListTile(
              enabled: !_busy,
              leading: const Icon(Icons.file_upload_outlined),
              title: const Text('バックアップから復元'),
              subtitle: const Text('保存したJSONファイルを選択'),
              onTap: _import,
            ),
            if (_busy) const LinearProgressIndicator(),
          ],
        ),
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
  return saved != null;
}
