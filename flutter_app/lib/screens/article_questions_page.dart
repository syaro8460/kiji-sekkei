import 'package:material_ui/material_ui.dart';

import 'article_page_frame.dart';

typedef ArticleQuestion = ({String text, String answer});

enum _QuestionAction { rename, delete }

class ArticleQuestionsPage extends StatefulWidget {
  const ArticleQuestionsPage({super.key, required this.questions});

  final List<ArticleQuestion> questions;

  @override
  State<ArticleQuestionsPage> createState() => _ArticleQuestionsPageState();
}

class _QuestionRow {
  _QuestionRow(this.question);

  ArticleQuestion question;
}

class _ArticleQuestionsPageState extends State<ArticleQuestionsPage> {
  late final _questions = widget.questions.map(_QuestionRow.new).toList();

  Future<void> _editQuestion([int? index]) async {
    final original = index == null ? null : _questions[index].question;
    final text = await showDialog<String>(
      context: context,
      builder: (context) => _QuestionDialog(
        original: original?.text,
        usedTexts: {
          for (final (position, question) in _questions.indexed)
            if (position != index) question.question.text,
        },
      ),
    );
    if (!mounted || text == null) return;
    setState(() {
      final question = (text: text, answer: original?.answer ?? '');
      if (index == null) {
        _questions.add(_QuestionRow(question));
      } else {
        _questions[index].question = question;
      }
    });
  }

  Future<void> _deleteQuestion(int index) async {
    final question = _questions[index].question;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('質問を削除しますか？'),
        content: Text(
          question.answer.isEmpty
              ? '「${question.text}」をこの記事から削除します。'
              : '「${question.text}」と入力した回答をこの記事から削除します。',
        ),
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
    if (mounted && confirmed == true) {
      setState(() {
        _questions.removeAt(index);
      });
    }
  }

  void _moveQuestion(int from, int to) {
    setState(() {
      _questions.insert(to, _questions.removeAt(from));
    });
  }

  void _handleAction(_QuestionAction action, int index) {
    switch (action) {
      case _QuestionAction.rename:
        _editQuestion(index);
      case _QuestionAction.delete:
        _deleteQuestion(index);
    }
  }

  @override
  Widget build(BuildContext context) => ArticlePageFrame(
    title: '質問を編集',
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(
          context,
          _questions.map((row) => row.question).toList(),
        ),
        child: const Text('反映'),
      ),
    ],
    bottomAction: FilledButton.icon(
      onPressed: () => _editQuestion(),
      icon: const Icon(Icons.add),
      label: const Text('質問を追加'),
    ),
    body: _questions.isEmpty
        ? const Center(child: Text('質問はまだありません'))
        : ReorderableListView.builder(
            padding: const EdgeInsets.all(20),

            itemCount: _questions.length,
            buildDefaultDragHandles: false,
            onReorderItem: _moveQuestion,
            itemBuilder: (context, index) {
              final row = _questions[index];
              final question = row.question;
              final colors = Theme.of(context).colorScheme;
              return Card(
                key: ObjectKey(row),
                color: colors.surface,
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: colors.outlineVariant),
                ),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  title: Text(question.text),
                  onTap: () => _editQuestion(index),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PopupMenuButton<_QuestionAction>(
                        tooltip: '${question.text} の操作',
                        onSelected: (action) => _handleAction(action, index),
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: _QuestionAction.rename,
                            child: Text('質問名を変更'),
                          ),
                          const PopupMenuItem(
                            value: _QuestionAction.delete,
                            child: Text('削除'),
                          ),
                        ],
                      ),
                      ReorderableDragStartListener(
                        index: index,
                        child: Tooltip(
                          message: '${question.text} をドラッグして並べ替え',
                          child: const SizedBox(
                            width: 48,
                            height: 48,
                            child: Center(child: Icon(Icons.drag_handle)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
  );
}

class _QuestionDialog extends StatefulWidget {
  const _QuestionDialog({required this.original, required this.usedTexts});

  final String? original;
  final Set<String> usedTexts;

  @override
  State<_QuestionDialog> createState() => _QuestionDialogState();
}

class _QuestionDialogState extends State<_QuestionDialog> {
  final _form = GlobalKey<FormState>();
  late final _text = TextEditingController(text: widget.original);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    final text = _text.text;
    Navigator.pop(context, text == widget.original ? text : text.trim());
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(widget.original == null ? '質問を追加' : '質問名を変更'),
    content: Form(
      key: _form,
      child: TextFormField(
        controller: _text,
        maxLines: 3,
        minLines: 1,
        decoration: const InputDecoration(labelText: '質問'),
        validator: (value) {
          if (widget.original != null && value == widget.original) return null;
          final text = (value ?? '').trim();
          if (text.isEmpty) return '質問を入力してください';
          if (widget.usedTexts.contains(text)) return '同じ質問があります';
          return null;
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('キャンセル'),
      ),
      FilledButton(onPressed: _submit, child: const Text('完了')),
    ],
  );
}
