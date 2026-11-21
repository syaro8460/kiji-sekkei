import 'dart:async';
import 'dart:math';

import 'package:material_ui/material_ui.dart';

import 'models/article_draft.dart';
import 'models/article_template.dart';
import 'screens/backup_page.dart';
import 'screens/trash_page.dart';
import 'storage/article_database.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.database});

  final ArticleDatabase? database;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final ArticleDatabase _database =
      widget.database ?? ArticleDatabase.local();

  @override
  void dispose() {
    if (widget.database == null) unawaited(_database.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '記事設計',
    theme: ThemeData(colorSchemeSeed: const Color(0xFF365C51)),
    home: _ArticleList(database: _database),
  );
}

class _ArticleList extends StatefulWidget {
  const _ArticleList({required this.database});

  final ArticleDatabase database;

  @override
  State<_ArticleList> createState() => _ArticleListState();
}

class _ArticleListState extends State<_ArticleList> {
  late Future<List<ArticleDraft>> _drafts = _loadDrafts();

  Future<List<ArticleDraft>> _loadDrafts() =>
      widget.database.listDrafts(DraftStatus.active);

  void _reload() {
    setState(() {
      _drafts = _loadDrafts();
    });
  }

  Future<void> _openBackup() async {
    final restored = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => BackupPage(database: widget.database),
      ),
    );
    if (!mounted || restored != true) return;
    _reload();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('バックアップを復元しました。')));
  }

  Future<void> _openTrash() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => TrashPage(database: widget.database),
      ),
    );
    if (mounted) _reload();
  }

  Future<void> _moveToTrash(ArticleDraft draft) async {
    try {
      await widget.database.moveToTrash(draft.id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('記事をゴミ箱へ移動できませんでした。')));
      return;
    }
    if (mounted) _reload();
  }

  Future<void> _newArticle() async {
    List<ArticleTemplate> customTemplates;
    try {
      customTemplates = await widget.database.listCustomTemplates();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('テンプレートを読み込めませんでした。')));
      return;
    }
    if (!mounted) return;

    final template = await showModalBottomSheet<ArticleTemplate>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('テンプレートを選ぶ')),
            for (final template in [
              ...ArticleTemplate.builtInTemplates,
              ...customTemplates,
            ])
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(template.name),
                onTap: () => Navigator.pop(context, template),
              ),
          ],
        ),
      ),
    );
    if (!mounted || template == null) return;
    await _openEditor(
      ArticleDraft(
        id: _newDraftId(),
        title: '',
        articleType: template.name,
        questions: List.of(template.questions),
      ),
      isNew: true,
    );
  }

  Future<void> _openEditor(ArticleDraft draft, {bool isNew = false}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => _ArticleEditor(
          database: widget.database,
          draft: draft,
          isNew: isNew,
        ),
      ),
    );
    if (mounted && saved == true) _reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('記事設計'),
      actions: [
        IconButton(
          onPressed: _openBackup,
          tooltip: 'バックアップ',
          icon: const Icon(Icons.backup_outlined),
        ),

        IconButton(
          onPressed: _openTrash,
          tooltip: 'ゴミ箱',
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _newArticle,
      icon: const Icon(Icons.add),
      label: const Text('新しい記事'),
    ),
    body: FutureBuilder<List<ArticleDraft>>(
      future: _drafts,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('記事を読み込めませんでした。'),
                TextButton(onPressed: _reload, child: const Text('再読み込み')),
              ],
            ),
          );
        }
        final drafts = snapshot.requireData;
        if (drafts.isEmpty) {
          return const Center(child: Text('記事はまだありません'));
        }
        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 88),
          itemCount: drafts.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final draft = drafts[index];
            return ListTile(
              leading: const Icon(Icons.article_outlined),
              title: Text(draft.title),
              subtitle: Text(draft.articleType),
              trailing: PopupMenuButton<void>(
                tooltip: '記事の操作',
                itemBuilder: (context) => [
                  PopupMenuItem(
                    onTap: () => _moveToTrash(draft),
                    child: const Text('ゴミ箱に移動'),
                  ),
                ],
              ),
              onTap: () => _openEditor(draft),
            );
          },
        );
      },
    ),
  );
}

class _ArticleEditor extends StatefulWidget {
  const _ArticleEditor({
    required this.database,
    required this.draft,
    required this.isNew,
  });

  final ArticleDatabase database;
  final ArticleDraft draft;
  final bool isNew;

  @override
  State<_ArticleEditor> createState() => _ArticleEditorState();
}

class _ArticleEditorState extends State<_ArticleEditor> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.draft.title);
  late final _answers = {
    for (final question in widget.draft.questions)
      question: TextEditingController(text: widget.draft.answers[question]),
  };
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    for (final controller in _answers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final original = widget.draft;
    try {
      await widget.database.saveDraft(
        ArticleDraft(
          id: original.id,
          title: _title.text.trim(),
          articleType: original.articleType,
          questions: original.questions,
          answers: {
            ...original.answers,
            for (final entry in _answers.entries) entry.key: entry.value.text,
          },
          tags: original.tags,
          updatedAt: DateTime.now(),
          status: original.status,
          deletedAt: original.deletedAt,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('保存できませんでした。もう一度お試しください。')));
      return;
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(title: Text(widget.isNew ? '新しい記事' : '記事を編集')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(widget.draft.articleType),
              const SizedBox(height: 12),
              TextFormField(
                controller: _title,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'タイトル',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? 'タイトルを入力してください' : null,
              ),
              for (final entry in _answers.entries) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: entry.value,
                  enabled: !_saving,
                  minLines: 3,
                  maxLines: null,
                  decoration: InputDecoration(
                    labelText: entry.key,
                    border: const OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? '保存中…' : '保存'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

String _newDraftId() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  // Set the version and variant bits for an RFC UUID v4.
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return [
    hex.substring(0, 8),
    hex.substring(8, 12),
    hex.substring(12, 16),
    hex.substring(16, 20),
    hex.substring(20),
  ].join('-');
}
