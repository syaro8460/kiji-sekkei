import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';

import '../models/article_draft.dart';
import '../export/markdown_exporter.dart';
import 'article_page_frame.dart';

class ArticlePreviewPage extends StatefulWidget {
  const ArticlePreviewPage({
    super.key,
    required this.draft,
    this.saveMarkdown = _saveMarkdown,
  });

  final ArticleDraft draft;
  final Future<bool> Function(String filename, Uint8List bytes) saveMarkdown;

  @override
  State<ArticlePreviewPage> createState() => _ArticlePreviewPageState();
}

class _ArticlePreviewPageState extends State<ArticlePreviewPage> {
  bool _exporting = false;

  Future<void> _export() async {
    if (_exporting) return;
    setState(() => _exporting = true);

    try {
      final draft = widget.draft;
      final safeTitle = draft.title.replaceAll(
        RegExp(r'[<>:"/\\|?*\x00-\x1F]'),
        '_',
      );
      final shortTitle = String.fromCharCodes(safeTitle.trim().runes.take(40));
      final filename = shortTitle.isEmpty ? 'kiji.md' : 'kiji-$shortTitle.md';
      final saved = await widget.saveMarkdown(
        filename,
        utf8.encode(exportMarkdown(draft)),
      );
      if (!mounted || !saved) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(kIsWeb ? '記事ファイルのダウンロードを開始しました。' : '記事をファイルに保存しました。'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('記事をファイルに保存できませんでした。')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final typography = theme.textTheme;

    return ArticlePageFrame(
      title: '記事のプレビュー',
      bottomAction: FilledButton.icon(
        onPressed: _exporting ? null : _export,
        icon: const Icon(Icons.file_download_outlined),
        label: Text(_exporting ? '保存中…' : '記事をファイルに保存'),
      ),
      body: SelectionArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
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
                          for (final tag in draft.tags) Chip(label: Text(tag)),
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
                        style: typography.bodyLarge?.copyWith(height: 1.6),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _answerFor(ArticleDraft draft, String question) {
  final answer = draft.answers[question] ?? '';
  return answer.trim().isEmpty ? '未回答' : answer;
}

Future<bool> _saveMarkdown(String filename, Uint8List bytes) async {
  final saved = await FilePicker.saveFile(
    fileName: filename,
    mimeType: 'text/markdown',
    bytes: bytes,
  );
  // The web picker starts a download and returns no file URI.
  return kIsWeb || saved != null;
}
