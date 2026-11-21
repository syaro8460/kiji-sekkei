import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'models/article_draft.dart';
import 'models/article_template.dart';
import 'models/json_compat.dart';
import 'screens/article_preview_page.dart';
import 'screens/backup_page.dart';
import 'screens/template_page.dart';
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
    locale: const Locale('ja', 'JP'),
    supportedLocales: const [Locale('ja', 'JP')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
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

  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _setSearch(String value) {
    _search.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    setState(() {});
  }

  List<ArticleDraft> _filterDrafts(List<ArticleDraft> drafts) {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return drafts;
    final keywords = query.split(RegExp(r'\s+'));
    return drafts.where((draft) {
      final fields = [
        draft.title,
        draft.articleType,
        ...draft.questions,
        ...draft.answers.values,
        ...draft.tags,
      ].map((field) => field.toLowerCase()).toList();
      return keywords.every(
        (word) => fields.any((field) => field.contains(word)),
      );
    }).toList();
  }

  Future<List<ArticleDraft>> _loadDrafts() =>
      widget.database.listDrafts(DraftStatus.active);

  void _reload() {
    setState(() {
      _drafts = _loadDrafts();
    });
  }

  void _openTemplates() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => TemplatePage(database: widget.database),
      ),
    );
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
        id: newUuid(),
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
          onPressed: _openTemplates,
          tooltip: 'テンプレート管理',
          icon: const Icon(Icons.dashboard_customize_outlined),
        ),

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
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: '記事を検索',
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () => _setSearch(''),
                      tooltip: '検索をクリア',
                      icon: const Icon(Icons.clear),
                    ),
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<ArticleDraft>>(
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
                      TextButton(
                        onPressed: _reload,
                        child: const Text('再読み込み'),
                      ),
                    ],
                  ),
                );
              }
              final drafts = _filterDrafts(snapshot.requireData);
              if (drafts.isEmpty) {
                final message = _search.text.trim().isEmpty
                    ? '記事はまだありません'
                    : '条件に一致する記事はありません';
                return Center(child: Text(message));
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
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(draft.articleType),
                        if (draft.tags.isNotEmpty)
                          Wrap(
                            spacing: 8,
                            children: [
                              for (final tag in draft.tags)
                                ActionChip(
                                  label: Text(tag),
                                  onPressed: () {
                                    FocusManager.instance.primaryFocus
                                        ?.unfocus();
                                    _setSearch(tag);
                                  },
                                ),
                            ],
                          ),
                      ],
                    ),
                    trailing: PopupMenuButton<void>(
                      tooltip: '記事の操作',
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          onTap: () => Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder: (context) =>
                                  ArticlePreviewPage(draft: draft),
                            ),
                          ),
                          child: const Text('プレビュー'),
                        ),
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
        ),
      ],
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
  late final _tags = List<String>.of(widget.draft.tags);
  final _tagInput = TextEditingController();

  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _tagInput.dispose();
    for (final controller in _answers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addTag() {
    final tag = _tagInput.text.trim();
    if (tag.isEmpty) return;
    setState(() {
      if (!_tags.contains(tag)) _tags.add(tag);
      _tagInput.clear();
    });
  }

  ArticleDraft _currentDraft() {
    final original = widget.draft;
    final pendingTag = _tagInput.text.trim();
    return ArticleDraft(
      id: original.id,
      title: _title.text.trim(),
      articleType: original.articleType,
      questions: original.questions,
      answers: {
        ...original.answers,
        for (final entry in _answers.entries) entry.key: entry.value.text,
      },
      tags: [
        ..._tags,
        if (pendingTag.isNotEmpty && !_tags.contains(pendingTag)) pendingTag,
      ],
      updatedAt: DateTime.now(),
      status: original.status,
      deletedAt: original.deletedAt,
    );
  }

  void _preview() {
    if (!_form.currentState!.validate()) return;
    final draft = _currentDraft();
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (context) => ArticlePreviewPage(draft: draft)),
    );
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.database.saveDraft(_currentDraft());
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
      appBar: AppBar(
        title: Text(widget.isNew ? '新しい記事' : '記事を編集'),
        actions: [
          IconButton(
            onPressed: _saving ? null : _preview,
            icon: const Icon(Icons.visibility_outlined),
            tooltip: 'プレビュー',
          ),
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '保存中…' : '保存'),
          ),
        ],
      ),
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
              const SizedBox(height: 16),
              if (_tags.isNotEmpty)
                Wrap(
                  spacing: 8,
                  children: [
                    for (final (index, tag) in _tags.indexed)
                      InputChip(
                        label: Text(tag),
                        deleteButtonTooltipMessage: '$tag のタグを削除',
                        onDeleted: _saving
                            ? null
                            : () {
                                setState(() {
                                  _tags.removeAt(index);
                                });
                              },
                      ),
                  ],
                ),
              TextField(
                controller: _tagInput,
                enabled: !_saving,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _addTag(),
                decoration: InputDecoration(
                  labelText: 'タグを追加',
                  border: const OutlineInputBorder(),
                  suffixIcon: Tooltip(
                    message: 'タグを追加',
                    child: TextButton(
                      onPressed: _saving ? null : _addTag,
                      child: const Text('追加'),
                    ),
                  ),
                ),
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
            ],
          ),
        ),
      ),
    ),
  );
}
