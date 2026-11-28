import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../storage/appearance_preferences.dart';
import '../storage/article_database.dart';
import 'backup_page.dart';
import 'content_page_frame.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.database,
    required this.appearance,
    required this.onAppearanceChanged,
  });

  final ArticleDatabase database;
  final ValueListenable<AppearanceMode> appearance;
  final Future<void> Function(AppearanceMode) onAppearanceChanged;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _version = '-';
  bool _selectingAppearance = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted && info.version.isNotEmpty) {
        setState(() => _version = info.version);
      }
    } catch (_) {
      // Keep the fallback when build metadata is unavailable.
    }
  }

  Future<void> _selectAppearance() async {
    if (_selectingAppearance) return;
    final current = widget.appearance.value;
    setState(() => _selectingAppearance = true);
    try {
      final selected = await showDialog<AppearanceMode>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('外観'),
          children: [
            for (final mode in AppearanceMode.values)
              ListTile(
                title: Text(mode.label),
                selected: mode == current,
                leading: Icon(
                  mode == current
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                onTap: () => Navigator.pop(context, mode),
              ),
          ],
        ),
      );
      if (!mounted || selected == null || selected == current) return;
      await widget.onAppearanceChanged(selected);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('外観の設定を保存できませんでした。')));
      }
    } finally {
      if (mounted) setState(() => _selectingAppearance = false);
    }
  }

  Future<void> _openBackup() async {
    final restored = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => BackupPage(database: widget.database)),
    );
    if (mounted && restored == true) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_selectingAppearance,
    child: ContentPageFrame(
      title: '設定',
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _section('表示', [
            ListTile(
              title: const Text('外観'),
              trailing: ValueListenableBuilder<AppearanceMode>(
                valueListenable: widget.appearance,
                builder: (context, mode, child) => Text(mode.label),
              ),
              onTap: _selectingAppearance ? null : _selectAppearance,
            ),
          ]),
          _section('データ', [
            ListTile(
              title: const Text('バックアップ'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _selectingAppearance ? null : _openBackup,
            ),
          ]),
          _section('アプリ', [
            ListTile(title: const Text('バージョン'), trailing: Text(_version)),
            const Divider(height: 1),
            ListTile(
              title: const Text('オープンソースライセンス'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _selectingAppearance
                  ? null
                  : () => showLicensePage(
                      context: context,
                      applicationName: '記事設計',
                      applicationVersion: _version,
                    ),
            ),
          ]),
        ],
      ),
    ),
  );

  Widget _section(String title, List<Widget> rows) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(title, style: Theme.of(context).textTheme.titleSmall),
        ),
        ContentCard(child: Column(children: rows)),
      ],
    ),
  );
}
