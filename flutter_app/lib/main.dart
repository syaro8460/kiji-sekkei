import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/article_draft.dart';
import 'models/article_template.dart';
import 'models/json_compat.dart';
import 'screens/article_preview_page.dart';
import 'screens/article_questions_page.dart';
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

enum _DraftSortOrder {
  updatedNewest('更新日（新しい順）'),
  updatedOldest('更新日（古い順）'),
  titleAscending('タイトル（昇順）'),
  titleDescending('タイトル（降順）');

  const _DraftSortOrder(this.label);

  final String label;
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
  static const _sortPreferenceKey = 'draftSortOrder';
  _DraftSortOrder _sortOrder = _DraftSortOrder.updatedNewest;
  late final _preferences = SharedPreferences.getInstance();
  bool _writingSortOrder = false;
  bool _duplicating = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSortOrder());
  }

  Future<void> _loadSortOrder() async {
    try {
      final preferences = await _preferences;
      final saved = preferences.getString(_sortPreferenceKey);
      final order = _DraftSortOrder.values
          .where((order) => order.name == saved)
          .firstOrNull;
      if (mounted && order != null && !_writingSortOrder) {
        setState(() => _sortOrder = order);
      }
    } catch (_) {
      // Keep the default sort order when preferences are unavailable.
    }
  }

  Future<void> _selectSortOrder(_DraftSortOrder order) async {
    if (_writingSortOrder || order == _sortOrder) return;
    setState(() => _writingSortOrder = true);
    try {
      final preferences = await _preferences;
      final saved = await preferences.setString(_sortPreferenceKey, order.name);
      if (!saved) throw StateError('Sort order could not be saved.');
      if (mounted) setState(() => _sortOrder = order);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('並べ替えの設定を保存できませんでした。')));
      }
    } finally {
      if (mounted) setState(() => _writingSortOrder = false);
    }
  }

  List<ArticleDraft> _sortedDrafts(List<ArticleDraft> drafts) {
    return List<ArticleDraft>.of(drafts)..sort((a, b) {
      final comparison = switch (_sortOrder) {
        _DraftSortOrder.updatedNewest => b.updatedAt.compareTo(a.updatedAt),
        _DraftSortOrder.updatedOldest => a.updatedAt.compareTo(b.updatedAt),
        _DraftSortOrder.titleAscending => a.title.toLowerCase().compareTo(
          b.title.toLowerCase(),
        ),
        _DraftSortOrder.titleDescending => b.title.toLowerCase().compareTo(
          a.title.toLowerCase(),
        ),
      };
      return comparison != 0 ? comparison : a.id.compareTo(b.id);
    });
  }

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

  Future<void> _duplicateDraft(ArticleDraft original) async {
    if (_duplicating) return;
    _duplicating = true;
    final copy = ArticleDraft(
      id: newUuid(),
      title: '${original.title}（コピー）',
      articleType: original.articleType,
      questions: List.of(original.questions),
      answers: Map.of(original.answers),
      tags: List.of(original.tags),
    );
    try {
      await widget.database.saveDraft(copy);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('記事を複製できませんでした。')));
      }
      return;
    } finally {
      _duplicating = false;
    }
    if (!mounted) return;
    _reload();
    if (ModalRoute.of(context)?.isCurrent == true) {
      await _openEditor(copy);
    }
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

  Widget _buildDraftList(List<ArticleDraft> drafts, {required bool wide}) {
    return ListView.separated(
      padding: EdgeInsets.only(bottom: wide ? 28 : 88),
      itemCount: drafts.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final draft = drafts[index];
        final theme = Theme.of(context);
        final colors = theme.colorScheme;
        return Card(
          color: colors.surface,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colors.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 6,
            ),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.article_outlined,
                color: colors.onPrimaryContainer,
              ),
            ),
            title: Text(draft.title, style: theme.textTheme.titleMedium),
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
                            FocusManager.instance.primaryFocus?.unfocus();
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
                      builder: (context) => ArticlePreviewPage(draft: draft),
                    ),
                  ),
                  child: const Text('プレビュー'),
                ),
                PopupMenuItem(
                  onTap: () => _duplicateDraft(draft),
                  child: const Text('複製'),
                ),

                PopupMenuItem(
                  onTap: () => _moveToTrash(draft),
                  child: const Text('ゴミ箱に移動'),
                ),
              ],
            ),
            onTap: () => _openEditor(draft),
          ),
        );
      },
    );
  }

  Widget _buildResults({required bool wide}) =>
      FutureBuilder<List<ArticleDraft>>(
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
          final drafts = _sortedDrafts(_filterDrafts(snapshot.requireData));
          final searching = _search.text.trim().isNotEmpty;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${searching ? '検索結果' : '記事数'}：${drafts.length}件',
                      ),
                    ),
                    PopupMenuButton<_DraftSortOrder>(
                      tooltip: '並べ替え',
                      icon: const Icon(Icons.sort),
                      enabled: !_writingSortOrder,
                      onSelected: _selectSortOrder,
                      itemBuilder: (_) => [
                        for (final order in _DraftSortOrder.values)
                          CheckedPopupMenuItem(
                            value: order,
                            checked: _sortOrder == order,
                            child: Text(order.label),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: drafts.isEmpty
                    ? Center(
                        child: Text(
                          searching ? '条件に一致する記事はありません' : '記事はまだありません',
                        ),
                      )
                    : _buildDraftList(drafts, wide: wide),
              ),
            ],
          );
        },
      );

  Widget _toolbarAction({
    required bool wide,
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    if (wide) {
      return TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
      );
    }
    return IconButton(onPressed: onPressed, tooltip: label, icon: Icon(icon));
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final wide = width >= 840;
      final outerInset = wide && width > 960 ? (width - 960) / 2 : 0.0;
      final theme = Theme.of(context);
      final colors = theme.colorScheme;

      return Scaffold(
        backgroundColor: colors.surfaceContainerLow,
        appBar: AppBar(
          backgroundColor: colors.surface,
          surfaceTintColor: Colors.transparent,
          shape: Border(bottom: BorderSide(color: colors.outlineVariant)),
          titleSpacing: outerInset + (wide ? 24 : 16),
          actionsPadding: EdgeInsets.only(right: outerInset + (wide ? 16 : 4)),
          title: const Text('記事設計'),
          actions: [
            _toolbarAction(
              wide: wide,
              label: 'テンプレート管理',
              icon: Icons.dashboard_customize_outlined,
              onPressed: _openTemplates,
            ),
            _toolbarAction(
              wide: wide,
              label: 'バックアップ',
              icon: Icons.backup_outlined,
              onPressed: _openBackup,
            ),
            _toolbarAction(
              wide: wide,
              label: 'ゴミ箱',
              icon: Icons.delete_outline,
              onPressed: _openTrash,
            ),
          ],
        ),
        floatingActionButton: wide
            ? null
            : FloatingActionButton.extended(
                onPressed: _newArticle,
                icon: const Icon(Icons.add),
                label: const Text('新しい記事'),
              ),
        body: SafeArea(
          bottom: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  wide ? 24 : 16,
                  wide ? 28 : 12,
                  wide ? 24 : 16,
                  0,
                ),
                child: Column(
                  children: [
                    if (wide) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '記事一覧',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: _newArticle,
                            icon: const Icon(Icons.add),
                            label: const Text('新しい記事'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                    TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        labelText: '記事を検索',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: colors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: colors.outlineVariant),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: colors.outlineVariant),
                        ),
                        suffixIcon: _search.text.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () => _setSearch(''),
                                tooltip: '検索をクリア',
                                icon: const Icon(Icons.clear),
                              ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(child: _buildResults(wide: wide)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
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
  late List<String> _questions = List.of(widget.draft.questions);
  late Map<String, TextEditingController> _answers = {
    for (final question in _questions.toSet())
      question: TextEditingController(text: widget.draft.answers[question]),
  };
  late final _extraAnswers = Map<String, String>.of(widget.draft.answers)
    ..removeWhere((question, _) => widget.draft.questions.contains(question));

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

  Future<void> _editQuestions() async {
    final edited = await Navigator.of(context).push<List<ArticleQuestion>>(
      MaterialPageRoute(
        builder: (context) => ArticleQuestionsPage(
          questions: [
            for (final question in _questions)
              (text: question, answer: _answers[question]!.text),
          ],
        ),
      ),
    );
    if (!mounted || edited == null) return;

    final previousControllers = _answers.values.toList();
    final nextControllers = <String, TextEditingController>{};
    for (final question in edited) {
      nextControllers.putIfAbsent(
        question.text,
        () => TextEditingController(text: question.answer),
      );
    }
    setState(() {
      _questions = edited.map((question) => question.text).toList();
      _answers = nextControllers;
      _extraAnswers.removeWhere(
        (question, _) => _answers.containsKey(question),
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final controller in previousControllers) {
        controller.dispose();
      }
    });
  }

  ArticleDraft _currentDraft() {
    final original = widget.draft;
    final pendingTag = _tagInput.text.trim();
    return ArticleDraft(
      id: original.id,
      title: _title.text.trim(),
      articleType: original.articleType,
      questions: List.of(_questions),
      answers: {
        ..._extraAnswers,
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

              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _saving ? null : _editQuestions,
                  icon: const Icon(Icons.edit_note),
                  label: const Text('質問を編集'),
                ),
              ),

              for (final entry in _answers.entries) ...[
                const SizedBox(height: 16),
                TextFormField(
                  key: ValueKey(entry.key),
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
