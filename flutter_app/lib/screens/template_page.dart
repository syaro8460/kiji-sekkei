import 'package:material_ui/material_ui.dart';

import '../models/article_template.dart';
import '../models/json_compat.dart';
import '../storage/article_database.dart';

enum _TemplateAction { edit, up, down, delete }

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
    final template = await showDialog<ArticleTemplate>(
      context: context,
      builder: (context) => _TemplateEditor(existing: existing),
    );
    if (!mounted || template == null) return;
    await _saveChanges(
      () => widget.database.saveCustomTemplate(template),
      failureMessage: 'テンプレートを保存できませんでした。',
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
      case _TemplateAction.up:
        _move(templates, index, index - 1);
      case _TemplateAction.down:
        _move(templates, index, index + 1);
      case _TemplateAction.delete:
        _delete(templates[index]);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('テンプレート管理')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _busy ? null : () => _edit(),
      icon: const Icon(Icons.add),
      label: const Text('新しいテンプレート'),
    ),
    body: SafeArea(
      child: FutureBuilder<List<ArticleTemplate>>(
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
          if (templates.isEmpty) {
            return const Center(child: Text('カスタムテンプレートはまだありません'));
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: templates.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final template = templates[index];
              return ListTile(
                leading: const Icon(Icons.description_outlined),
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
              );
            },
          );
        },
      ),
    ),
  );
}

class _TemplateEditor extends StatefulWidget {
  const _TemplateEditor({this.existing});

  final ArticleTemplate? existing;

  @override
  State<_TemplateEditor> createState() => _TemplateEditorState();
}

class _TemplateEditorState extends State<_TemplateEditor> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _questions = TextEditingController(
    text: widget.existing?.questions.join('\n'),
  );

  @override
  void dispose() {
    _name.dispose();
    _questions.dispose();
    super.dispose();
  }

  List<String> _questionList(String text) {
    final existing = widget.existing;
    if (existing != null && text == existing.questions.join('\n')) {
      return List.of(existing.questions);
    }
    return text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    final existing = widget.existing;
    final questions = _questionList(_questions.text);

    Navigator.pop(
      context,
      ArticleTemplate(
        id: existing?.id ?? newUuid(),
        name: _name.text.trim(),
        questions: questions,
        iconName: existing?.iconName ?? 'doc.text',
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(widget.existing == null ? 'テンプレートを作成' : 'テンプレートを編集'),
    content: Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'テンプレート名'),
            validator: (value) =>
                (value ?? '').trim().isEmpty ? 'テンプレート名を入力してください' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _questions,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: '質問',
              helperText: '1行に1つずつ入力',
              alignLabelWithHint: true,
            ),
            validator: (value) {
              final input = value ?? '';
              final questions = _questionList(input);
              if (questions.isEmpty) return '質問を1つ以上入力してください';
              if (input != widget.existing?.questions.join('\n') &&
                  questions.toSet().length != questions.length) {
                return '同じ質問が重複しています';
              }
              return null;
            },
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('キャンセル'),
      ),
      FilledButton(onPressed: _submit, child: const Text('保存')),
    ],
  );
}
