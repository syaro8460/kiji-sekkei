import 'package:material_ui/material_ui.dart';

import '../models/article_template.dart';
import '../models/json_compat.dart';
import '../storage/article_database.dart';
import 'content_page_frame.dart';

enum _TemplateAction { edit, duplicate, up, down, delete }

class TemplatePage extends StatefulWidget {
  const TemplatePage({super.key, required this.database});

  final ArticleDatabase database;

  @override
  State<TemplatePage> createState() => _TemplatePageState();
}

class _TemplatePageState extends State<TemplatePage> {
  late Future<List<ArticleTemplate>> _templates = widget.database
      .listCustomTemplates();
  bool _busy = false;

  void _reload() {
    setState(() {
      _templates = widget.database.listCustomTemplates();
    });
  }

  Future<void> _saveChanges(
    Future<void> Function() operation, {
    required String failureMessage,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await operation();
      if (mounted) _reload();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(failureMessage)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit([ArticleTemplate? existing]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            _TemplateEditor(database: widget.database, existing: existing),
      ),
    );
    if (mounted && saved == true) _reload();
  }

  Future<void> _reorder(List<ArticleTemplate> templates) async {
    final updated = await Navigator.of(context).push<List<ArticleTemplate>>(
      MaterialPageRoute(
        builder: (_) => _ReorderPage(
          title: 'テンプレートを並び替え',
          items: templates,
          labelFor: (template) => template.name,
          save: (order) => widget.database.reorderCustomTemplates(
            order.map((template) => template.id).toList(),
          ),
        ),
      ),
    );
    if (mounted && updated != null) _reload();
  }

  void _viewBuiltIn(ArticleTemplate template) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ContentPageFrame(
          title: template.name,
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              for (final (index, question) in template.questions.indexed)
                ListTile(title: Text(question), leading: Text('${index + 1}')),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _duplicate(ArticleTemplate original) {
    return _saveChanges(
      () => widget.database.saveCustomTemplate(
        ArticleTemplate(
          id: newUuid(),
          name: '${original.name} コピー',
          questions: List.of(original.questions),
          iconName: original.iconName,
        ),
      ),
      failureMessage: 'テンプレートを複製できませんでした。',
    );
  }

  Future<void> _delete(ArticleTemplate template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('テンプレートを削除しますか？'),
        content: Text('「${template.name}」を削除します。作成済みの記事には影響しません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    await _saveChanges(() async {
      await widget.database.deleteCustomTemplate(template.id);
    }, failureMessage: 'テンプレートを削除できませんでした。');
  }

  Future<void> _move(List<ArticleTemplate> templates, int from, int to) {
    final order = templates.map((template) => template.id).toList();
    order.insert(to, order.removeAt(from));
    return _saveChanges(
      () => widget.database.reorderCustomTemplates(order),
      failureMessage: 'テンプレートの順番を変更できませんでした。',
    );
  }

  void _handleAction(
    _TemplateAction action,
    List<ArticleTemplate> templates,
    int index,
  ) {
    switch (action) {
      case _TemplateAction.edit:
        _edit(templates[index]);
      case _TemplateAction.duplicate:
        _duplicate(templates[index]);
      case _TemplateAction.up:
        _move(templates, index, index - 1);
      case _TemplateAction.down:
        _move(templates, index, index + 1);
      case _TemplateAction.delete:
        _delete(templates[index]);
    }
  }

  @override
  Widget build(BuildContext context) => ContentPageFrame(
    title: 'テンプレート管理',
    bottomAction: FilledButton.icon(
      onPressed: _busy ? null : () => _edit(),
      icon: const Icon(Icons.add),
      label: const Text('新しいテンプレート'),
    ),
    body: FutureBuilder<List<ArticleTemplate>>(
      future: _templates,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('テンプレートを読み込めませんでした。'),
                TextButton(onPressed: _reload, child: const Text('再読み込み')),
              ],
            ),
          );
        }

        final templates = snapshot.requireData;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('標準テンプレート', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final template in ArticleTemplate.builtInTemplates) ...[
              ContentCard(
                child: ListTile(
                  leading: Icon(templateIcon(template.iconName)),
                  title: Text(template.name),
                  subtitle: Text('質問 ${template.questions.length} 件'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _busy ? null : () => _viewBuiltIn(template),
                ),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '自作テンプレート',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                TextButton.icon(
                  onPressed: _busy || templates.length < 2
                      ? null
                      : () => _reorder(templates),
                  icon: const Icon(Icons.swap_vert),
                  label: const Text('テンプレートを並び替え'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (templates.isEmpty) const Text('カスタムテンプレートはまだありません'),
            for (final (index, template) in templates.indexed) ...[
              ContentCard(
                child: ListTile(
                  leading: Icon(templateIcon(template.iconName)),
                  title: Text(template.name),
                  subtitle: Text('質問 ${template.questions.length} 件'),
                  onTap: _busy ? null : () => _edit(template),
                  trailing: PopupMenuButton<_TemplateAction>(
                    tooltip: '${template.name}の操作',
                    enabled: !_busy,
                    onSelected: (action) =>
                        _handleAction(action, templates, index),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: _TemplateAction.edit,
                        child: Text('編集'),
                      ),
                      const PopupMenuItem(
                        value: _TemplateAction.duplicate,
                        child: Text('複製'),
                      ),

                      if (index > 0)
                        const PopupMenuItem(
                          value: _TemplateAction.up,
                          child: Text('上に移動'),
                        ),
                      if (index < templates.length - 1)
                        const PopupMenuItem(
                          value: _TemplateAction.down,
                          child: Text('下に移動'),
                        ),
                      const PopupMenuItem(
                        value: _TemplateAction.delete,
                        child: Text('削除'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    ),
  );
}

IconData templateIcon(String? iconName) => switch (iconName) {
  'star.bubble' => Icons.rate_review_outlined,
  'arrow.left.arrow.right' => Icons.compare_arrows,
  'person.text.rectangle' => Icons.person_outline,
  'xmark.circle' => Icons.cancel_outlined,
  _ => Icons.description_outlined,
};

class _TemplateEditor extends StatefulWidget {
  const _TemplateEditor({required this.database, this.existing});

  final ArticleDatabase database;
  final ArticleTemplate? existing;

  @override
  State<_TemplateEditor> createState() => _TemplateEditorState();
}

class _QuestionInput {
  _QuestionInput([this.original = ''])
    : controller = TextEditingController(text: original);

  final String original;
  final TextEditingController controller;

  String get text => controller.text;
  String get savedText => text == original ? original : text.trim();
}

class _TemplateEditorState extends State<_TemplateEditor> {
  late final _id = widget.existing?.id ?? newUuid();
  late final _name = TextEditingController(text: widget.existing?.name);
  late final List<_QuestionInput> _questions = [
    for (final question in widget.existing?.questions ?? const [''])
      _QuestionInput(question),
  ];
  bool _saving = false;
  bool _confirming = false;
  bool _showValidationErrors = false;

  String? _nameError(String name) => name.isEmpty ? 'テンプレート名を入力してください' : null;

  List<String> get _savedQuestions => [
    for (final question in _questions)
      if (question.text.trim().isNotEmpty) question.savedText,
  ];

  bool get _dirty {
    if (_name.text != (widget.existing?.name ?? '')) return true;
    final initial = widget.existing?.questions ?? const [''];
    if (_questions.length != initial.length) return true;
    return _questions.indexed.any(
      (entry) => entry.$2.text != initial[entry.$1],
    );
  }

  @override
  void dispose() {
    _name.dispose();
    for (final question in _questions) {
      question.controller.dispose();
    }
    super.dispose();
  }

  void _changed() => setState(() {});

  void _remove(_QuestionInput question) {
    setState(() {
      _questions.remove(question);
    });
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => question.controller.dispose(),
    );
  }

  Future<void> _reorder() async {
    FocusScope.of(context).unfocus();
    final reordered = await Navigator.of(context).push<List<_QuestionInput>>(
      MaterialPageRoute(
        builder: (_) => _ReorderPage(
          title: '質問を並び替え',
          items: _questions,
          labelFor: (item) => item.text.trim().isEmpty ? '未入力の質問' : item.text,
        ),
      ),
    );
    if (!mounted || reordered == null) return;
    setState(() {
      _questions
        ..clear()
        ..addAll(reordered);
    });
  }

  String? _validateQuestions(List<String> questions) {
    if (questions.isEmpty) return '質問を1つ以上入力してください';
    final previous = <String, int>{};
    for (final question in widget.existing?.questions ?? const <String>[]) {
      previous.update(question.trim(), (count) => count + 1, ifAbsent: () => 1);
    }
    final seen = <String, int>{};
    for (final question in questions) {
      final key = question.trim();
      final count = seen.update(key, (count) => count + 1, ifAbsent: () => 1);
      if (count > 1 && count > (previous[key] ?? 1)) {
        return '同じ質問が重複しています';
      }
    }
    return null;
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _name.text.trim();
    final questions = _savedQuestions;
    if (_nameError(name) != null || _validateQuestions(questions) != null) {
      setState(() => _showValidationErrors = true);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      final existing = widget.existing;
      await widget.database.saveCustomTemplate(
        ArticleTemplate(
          id: _id,
          name: name,
          questions: questions,
          iconName: existing?.iconName ?? 'doc.text',
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('テンプレートを保存できませんでした。端末への書き込みに失敗しました。もう一度保存できます。'),
        ),
      );
    }
  }

  Future<void> _confirmDiscard() async {
    if (_saving || _confirming) return;
    _confirming = true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('変更を破棄しますか？'),
        content: const Text('保存していない変更は失われます。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('編集に戻る'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('破棄'),
          ),
        ],
      ),
    );
    _confirming = false;
    if (mounted && discard == true) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final nameError = _showValidationErrors
        ? _nameError(_name.text.trim())
        : null;
    final questionError = _showValidationErrors
        ? _validateQuestions(_savedQuestions)
        : null;
    final errors = [?nameError, ?questionError];
    final errorStyle = TextStyle(color: Theme.of(context).colorScheme.error);
    final saveButton = FilledButton(
      onPressed: _saving ? null : _save,
      child: Text(_saving ? '保存中…' : '保存'),
    );
    return PopScope<bool>(
      canPop: !_saving && !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: ContentPageFrame(
        title: widget.existing == null ? 'テンプレートを作成' : 'テンプレートを編集',
        bottomAction: errors.isEmpty
            ? saveButton
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      errors.join('\n'),
                      key: const ValueKey('template-validation-summary'),
                      style: errorStyle,
                    ),
                  ),
                  saveButton,
                ],
              ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _name,
              enabled: !_saving,
              onChanged: (_) => _changed(),
              decoration: InputDecoration(
                labelText: 'テンプレート名',
                errorText: nameError,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('質問', style: Theme.of(context).textTheme.titleMedium),
                TextButton.icon(
                  onPressed: _saving || _questions.length < 2 ? null : _reorder,
                  icon: const Icon(Icons.swap_vert),
                  label: const Text('質問を並び替え'),
                ),
              ],
            ),
            for (final (index, question) in _questions.indexed)
              Padding(
                key: ObjectKey(question),
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text('質問${index + 1}')),
                        IconButton(
                          tooltip: '質問${index + 1}を削除',
                          onPressed: _saving ? null : () => _remove(question),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                      ],
                    ),
                    TextFormField(
                      controller: question.controller,
                      enabled: !_saving,
                      onChanged: (_) => _changed(),
                      minLines: 3,
                      maxLines: 8,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        hintText: '質問を入力',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            if (questionError != null) Text(questionError, style: errorStyle),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _saving
                    ? null
                    : () => setState(() {
                        _questions.add(_QuestionInput());
                      }),
                icon: const Icon(Icons.add),
                label: const Text('質問を追加'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReorderPage<T> extends StatefulWidget {
  const _ReorderPage({
    required this.title,
    required this.items,
    required this.labelFor,
    this.save,
  });

  final String title;
  final List<T> items;
  final String Function(T) labelFor;
  final Future<void> Function(List<T>)? save;

  @override
  State<_ReorderPage<T>> createState() => _ReorderPageState<T>();
}

class _ReorderPageState<T> extends State<_ReorderPage<T>> {
  late final _items = List<T>.of(widget.items);
  bool _saving = false;

  Future<void> _finish() async {
    if (_saving) return;
    final save = widget.save;
    if (save != null) {
      setState(() => _saving = true);
      try {
        await save(_items);
      } catch (_) {
        if (!mounted) return;
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('順番を保存できませんでした。もう一度お試しください。')),
        );
        return;
      }
    }
    if (mounted) Navigator.of(context).pop(_items);
  }

  @override
  Widget build(BuildContext context) => PopScope<List<T>>(
    canPop: !_saving,
    child: ContentPageFrame(
      title: widget.title,
      bottomAction: Wrap(
        spacing: 8,
        children: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: _saving ? null : _finish,
            child: Text(_saving ? '保存中…' : '完了'),
          ),
        ],
      ),
      body: ReorderableListView.builder(
        padding: const EdgeInsets.all(20),
        buildDefaultDragHandles: false,
        itemCount: _items.length,
        onReorderItem: (from, to) {
          if (!_saving) {
            setState(() => _items.insert(to, _items.removeAt(from)));
          }
        },
        itemBuilder: (context, index) {
          final item = _items[index];
          final label = widget.labelFor(item);
          return ListTile(
            key: ObjectKey(item),
            leading: Text('${index + 1}'),
            title: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: ReorderableDragStartListener(
              index: index,
              enabled: !_saving,
              child: Tooltip(
                message: '${index + 1}番をドラッグして並び替え',
                child: const SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(Icons.drag_handle),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}
