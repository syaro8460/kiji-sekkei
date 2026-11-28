import 'package:material_ui/material_ui.dart';

import 'content_page_frame.dart';

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

class _ArticleQuestionsPopEntry extends PopEntry<List<ArticleQuestion>> {
  _ArticleQuestionsPopEntry(this.onBlockedPop);

  final VoidCallback onBlockedPop;

  @override
  final ValueNotifier<bool> canPopNotifier = ValueNotifier(true);

  @override
  void onPopInvokedWithResult(bool didPop, List<ArticleQuestion>? result) {
    if (!didPop) onBlockedPop();
  }
}

class _ArticleQuestionsPageState extends State<ArticleQuestionsPage> {
  late final List<ArticleQuestion> _originalQuestions;
  late final List<_QuestionRow> _questions;
  late final _popEntry = _ArticleQuestionsPopEntry(_requestDiscardConfirmation);
  ModalRoute<dynamic>? _route;
  bool _confirmingDiscard = false;

  @override
  void initState() {
    super.initState();
    _originalQuestions = List.unmodifiable(widget.questions);
    _questions = _originalQuestions.map(_QuestionRow.new).toList();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (_route == route) return;
    _route?.unregisterPopEntry(_popEntry);
    _route = route;
    route?.registerPopEntry(_popEntry);
  }

  @override
  void dispose() {
    _route?.unregisterPopEntry(_popEntry);
    _popEntry.canPopNotifier.dispose();
    super.dispose();
  }

  void _updateQuestions(VoidCallback edit) {
    setState(edit);
    // The navigator can receive a back request before the next build.
    _popEntry.canPopNotifier.value = !_hasUnappliedChanges;
  }

  bool get _hasUnappliedChanges {
    if (_questions.length != _originalQuestions.length) return true;
    for (final (index, row) in _questions.indexed) {
      if (row.question != _originalQuestions[index]) return true;
    }
    return false;
  }

  void _requestDiscardConfirmation() {
    if (_confirmingDiscard || !_hasUnappliedChanges) return;
    _confirmingDiscard = true;
    // Install the dialog at the start of the frame that builds its route.
    WidgetsBinding.instance.scheduleFrameCallback((_) => _confirmDiscard());
  }

  Future<void> _confirmDiscard() async {
    final route = _route;
    if (!mounted ||
        route == null ||
        !route.isCurrent ||
        !_hasUnappliedChanges) {
      _confirmingDiscard = false;
      return;
    }

    final navigator = Navigator.of(context, rootNavigator: true);
    final dialog = DialogRoute<bool>(
      context: context,
      themes: InheritedTheme.capture(from: context, to: navigator.context),
      barrierColor:
          DialogTheme.of(context).barrierColor ??
          Theme.of(context).dialogTheme.barrierColor ??
          Colors.black54,
      traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
      builder: (context) {
        void close(bool discard) {
          if (ModalRoute.of(context)?.isCurrent == true) {
            Navigator.of(context).pop(discard);
          }
        }

        return AlertDialog(
          title: const Text('変更を破棄しますか？'),
          content: const Text('未反映の変更があります。変更を破棄して戻りますか？'),
          actions: [
            TextButton(
              onPressed: () => close(false),
              child: const Text('編集に戻る'),
            ),
            FilledButton(onPressed: () => close(true), child: const Text('破棄')),
          ],
        );
      },
    );
    final discard = await navigator.push(dialog);
    // Keep repeated back requests blocked until the dialog has left the overlay.
    await dialog.completed;
    _confirmingDiscard = false;
    if (mounted && discard == true && route == _route && route.isCurrent) {
      route.navigator!.pop();
    }
  }

  void _apply() {
    final route = _route;
    if (_confirmingDiscard || route == null || !route.isCurrent) return;
    route.navigator!.pop(_questions.map((row) => row.question).toList());
  }

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
    _updateQuestions(() {
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
      _updateQuestions(() {
        _questions.removeAt(index);
      });
    }
  }

  void _moveQuestion(int from, int to) {
    _updateQuestions(() {
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
  Widget build(BuildContext context) => ContentPageFrame(
    title: '質問を編集',
    actions: [TextButton(onPressed: _apply, child: const Text('反映'))],
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
