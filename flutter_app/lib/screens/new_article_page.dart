import 'package:material_ui/material_ui.dart';

import '../models/article_draft.dart';
import '../models/article_template.dart';
import '../models/json_compat.dart';
import '../storage/article_database.dart';
import 'content_page_frame.dart';

class NewArticlePage extends StatefulWidget {
  const NewArticlePage({
    super.key,
    required this.database,
    required this.templates,
  });

  final ArticleDatabase database;
  final List<ArticleTemplate> templates;

  @override
  State<NewArticlePage> createState() => _NewArticlePageState();
}

class _NewArticlePageState extends State<NewArticlePage> {
  final _title = TextEditingController();
  late ArticleTemplate _template = widget.templates.first;
  bool _creating = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final title = _title.text;
    if (_creating || title.trim().isEmpty) return;
    setState(() => _creating = true);
    final draft = ArticleDraft(
      id: newUuid(),
      title: title,
      articleType: _template.name,
      questions: List.of(_template.questions),
    );
    try {
      await widget.database.saveDraft(draft);
      if (mounted) Navigator.of(context).pop(draft);
    } catch (_) {
      if (!mounted) return;
      setState(() => _creating = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('記事を作成できませんでした。')));
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_creating,
    child: ContentPageFrame(
      title: '新しい記事',
      showBackButton: false,
      actions: [
        TextButton(
          onPressed: _creating ? null : () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        TextButton(
          onPressed: _creating || _title.text.trim().isEmpty ? null : _create,
          child: Text(_creating ? '作成中…' : '作成'),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('記事タイトル', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _title,
            enabled: !_creating,
            onChanged: (_) => setState(() {}),
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            minLines: 1,
            maxLines: null,
            decoration: const InputDecoration(
              labelText: 'タイトルを入力',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<ArticleTemplate>(
            initialValue: _template,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'テンプレート',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final template in widget.templates)
                DropdownMenuItem(value: template, child: Text(template.name)),
            ],
            onChanged: _creating
                ? null
                : (value) {
                    if (value != null) setState(() => _template = value);
                  },
          ),
          const SizedBox(height: 20),
          Text('質問内容', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final question in _template.questions)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.help_outline),
              title: Text(question),
            ),
        ],
      ),
    ),
  );
}
