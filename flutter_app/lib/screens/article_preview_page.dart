import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:material_ui/material_ui.dart';

import '../models/article_draft.dart';
import '../export/article_structure_exporter.dart';
import 'content_page_frame.dart';

class ArticlePreviewPage extends StatefulWidget {
  const ArticlePreviewPage({super.key, required this.draft});

  final ArticleDraft draft;

  @override
  State<ArticlePreviewPage> createState() => _ArticlePreviewPageState();
}

enum _PreviewMode { card, copyText }

class _ArticlePreviewPageState extends State<ArticlePreviewPage> {
  _PreviewMode _mode = _PreviewMode.card;
  Future<void> _copyStructure(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('記事構成をコピーしました。ChatGPTやnoteに貼り付けられます。')),
        );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('記事構成をコピーできませんでした。')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    final copyText = exportArticleStructure(draft);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final typography = theme.textTheme;

    return ContentPageFrame(
      title: '記事構成',
      bottomAction: FilledButton.icon(
        onPressed: () => _copyStructure(copyText),
        icon: const Icon(Icons.copy_outlined),
        label: const Text('記事構成をコピー'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: SegmentedButton<_PreviewMode>(
              segments: const [
                ButtonSegment(value: _PreviewMode.card, label: Text('カード表示')),
                ButtonSegment(
                  value: _PreviewMode.copyText,
                  label: Text('コピー内容'),
                ),
              ],
              selected: {_mode},
              showSelectedIcon: false,
              onSelectionChanged: (selection) {
                setState(() => _mode = selection.single);
              },
            ),
          ),
          Expanded(
            child: SelectionArea(
              key: ValueKey(_mode),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (_mode == _PreviewMode.copyText)
                    Text(
                      copyText,
                      style: typography.bodyLarge?.copyWith(height: 1.6),
                    )
                  else
                    Card(
                      margin: EdgeInsets.zero,
                      color: colors.surface,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: colors.outlineVariant),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              draft.articleType,
                              style: typography.labelLarge?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              draft.title,
                              style: typography.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (draft.tags.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final tag in draft.tags)
                                    Chip(label: Text(tag)),
                                ],
                              ),
                            ],
                            for (final question in draft.questions) ...[
                              const SizedBox(height: 16),
                              Divider(color: colors.outlineVariant),
                              const SizedBox(height: 8),
                              Text(question, style: typography.titleMedium),
                              const SizedBox(height: 6),
                              Text(
                                _answerFor(draft, question),
                                style: typography.bodyLarge?.copyWith(
                                  height: 1.6,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _answerFor(ArticleDraft draft, String question) {
  final answer = draft.answers[question] ?? '';
  return answer.trim().isEmpty ? '未回答' : answer;
}
