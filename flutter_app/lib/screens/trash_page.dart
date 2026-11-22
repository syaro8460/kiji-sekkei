import 'package:material_ui/material_ui.dart';

import '../models/article_draft.dart';
import '../storage/article_database.dart';
import 'content_page_frame.dart';

enum _TrashAction { restore, delete }

class TrashPage extends StatefulWidget {
  const TrashPage({super.key, required this.database});

  final ArticleDatabase database;

  @override
  State<TrashPage> createState() => _TrashPageState();
}

class _TrashPageState extends State<TrashPage> {
  late Future<List<ArticleDraft>> _drafts = _loadDrafts();
  bool _busy = false;

  Future<List<ArticleDraft>> _loadDrafts() async {
    await widget.database.removeExpiredTrash();
    return widget.database.listDrafts(DraftStatus.trashed);
  }

  void _reload() {
    setState(() {
      _drafts = _loadDrafts();
    });
  }

  Future<void> _apply(_TrashAction action, ArticleDraft draft) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      switch (action) {
        case _TrashAction.restore:
          await widget.database.restoreDraft(draft.id);
        case _TrashAction.delete:
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('記事を完全に削除しますか？'),
              content: Text('「${draft.title}」を削除すると復元できません。'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('キャンセル'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('完全に削除'),
                ),
              ],
            ),
          );
          if (!mounted || confirmed != true) return;
          await widget.database.deletePermanently(draft.id);
      }
      if (mounted) _reload();
    } catch (_) {
      if (!mounted) return;
      final message = switch (action) {
        _TrashAction.restore => '記事を復元できませんでした。',
        _TrashAction.delete => '記事を削除できませんでした。',
      };
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ContentPageFrame(
    title: 'ゴミ箱',
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
                const Text('ゴミ箱を読み込めませんでした。'),
                TextButton(onPressed: _reload, child: const Text('再読み込み')),
              ],
            ),
          );
        }

        final drafts = snapshot.requireData;
        if (drafts.isEmpty) {
          return const Center(child: Text('ゴミ箱は空です'));
        }
        return Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Text(
                widget.database.autoRemovesExpiredTrash
                    ? 'ゴミ箱に移してから30日を過ぎた記事は、ゴミ箱を開いたときに削除されます。'
                    : 'ゴミ箱の記事の自動削除は停止中です。',
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                itemCount: drafts.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final draft = drafts[index];
                  return ContentCard(
                    child: ListTile(
                      leading: const Icon(Icons.article_outlined),
                      title: Text(draft.title),
                      subtitle: Text(draft.articleType),
                      trailing: PopupMenuButton<_TrashAction>(
                        enabled: !_busy,
                        tooltip: 'ゴミ箱の記事の操作',
                        onSelected: (action) => _apply(action, draft),
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: _TrashAction.restore,
                            child: Text('復元'),
                          ),
                          PopupMenuItem(
                            value: _TrashAction.delete,
                            child: Text('完全に削除'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    ),
  );
}
