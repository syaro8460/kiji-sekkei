import 'dart:async';
import 'dart:convert';
import 'dart:math' show min;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart'
    show PointerDeviceKind, PointerScrollEvent;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'export/markdown_exporter.dart';
import 'models/article_draft.dart';
import 'models/article_template.dart';
import 'models/json_compat.dart';
import 'screens/content_page_frame.dart';
import 'screens/article_preview_page.dart';
import 'screens/article_questions_page.dart';
import 'screens/backup_page.dart';
import 'screens/new_article_page.dart';
import 'screens/startup_screen.dart';
import 'screens/template_page.dart';
import 'screens/trash_page.dart';
import 'storage/article_database.dart';
import 'storage/legacy_ios_migration.dart';

void main() {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp(firstFrameRasterized: binding.waitUntilFirstFrameRasterized));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.database, this.firstFrameRasterized});

  final ArticleDatabase? database;
  final Future<void>? firstFrameRasterized;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final ArticleDatabase _database =
      widget.database ?? ArticleDatabase.local();

  late Future<void> _legacyMigration = migrateLegacyIosData(_database);
  bool _continueWithLocalData = false;
  bool _minimumStartupElapsed = false;
  Timer? _startupTimer;

  @override
  void initState() {
    super.initState();
    final firstFrameRasterized = widget.firstFrameRasterized;
    if (firstFrameRasterized != null) {
      unawaited(firstFrameRasterized.then((_) => _startStartupTimer()));
    } else {
      // Widget tests complete the frame without submitting it to the engine.
      WidgetsBinding.instance.addPostFrameCallback((_) => _startStartupTimer());
    }
  }

  void _startStartupTimer() {
    if (!mounted) return;
    _startupTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _minimumStartupElapsed = true);
    });
  }

  Widget _articleList() => _ArticleList(
    database: _database,
    minimumStartupElapsed: _minimumStartupElapsed,
  );

  Widget _home() {
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.iOS ||
        _continueWithLocalData) {
      return _articleList();
    }
    return FutureBuilder<void>(
      future: _legacyMigration,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const StartupScreen(showMigrationProgress: true);
        }
        if (snapshot.hasError) {
          if (!_minimumStartupElapsed) return const StartupScreen();
          return Scaffold(
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('旧版のデータ移行を保留しました。既存データは保持されています。'),
                      TextButton(
                        onPressed: () => setState(() {
                          _legacyMigration = migrateLegacyIosData(_database);
                        }),
                        child: const Text('再試行'),
                      ),
                      TextButton(
                        onPressed: () => setState(() {
                          _continueWithLocalData = true;
                        }),
                        child: const Text('現在のデータで開く'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        return _articleList();
      },
    );
  }

  @override
  void dispose() {
    _startupTimer?.cancel();
    if (widget.database == null) unawaited(_database.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title:
        kIsWeb &&
            const {'127.0.0.1', 'localhost'}.contains(Uri.base.host) &&
            Uri.base.port == 8081
        ? '記事設計 Dev'
        : '記事設計',
    locale: const Locale('ja', 'JP'),
    supportedLocales: const [Locale('ja', 'JP')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(colorSchemeSeed: const Color(0xFF365C51)),
    home: _home(),
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
  const _ArticleList({
    required this.database,
    required this.minimumStartupElapsed,
  });

  final ArticleDatabase database;
  final bool minimumStartupElapsed;

  @override
  State<_ArticleList> createState() => _ArticleListState();
}

class _ArticleListState extends State<_ArticleList> {
  late Future<List<ArticleDraft>> _drafts = _loadDrafts();
  bool _loadingInitially = true;

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

  String _normalizeSearch(String text) {
    return String.fromCharCodes(
      text.runes.map((character) {
        if (character >= 0xff01 && character <= 0xff5e) {
          return character - 0xfee0; // Full-width ASCII.
        }
        if (character >= 0x3041 && character <= 0x3096) {
          return character + 0x60; // Hiragana to katakana.
        }
        return character == 0x3000 ? 0x20 : character;
      }),
    ).toLowerCase();
  }

  bool _containsSearchKeyword(String field, String keyword) {
    if (field.contains(keyword)) return true;

    final characters = keyword.runes.toList();
    if (characters.length < 3) return false;

    final allowedDistance = characters.length ~/ 3;
    final distances = List.generate(characters.length + 1, (index) => index);
    for (final targetCharacter in field.runes) {
      var diagonal = distances[0];
      for (var index = 1; index < distances.length; index++) {
        final previous = distances[index];
        final insertion = distances[index - 1] + 1;
        final deletion = previous + 1;
        final substitution =
            diagonal + (targetCharacter == characters[index - 1] ? 0 : 1);
        distances[index] = min(min(insertion, deletion), substitution);
        diagonal = previous;
      }
      if (distances.last <= allowedDistance) return true;
    }
    return false;
  }

  List<ArticleDraft> _filterDrafts(List<ArticleDraft> drafts) {
    final query = _normalizeSearch(_search.text).trim();
    if (query.isEmpty) return drafts;
    final keywords = query.split(RegExp(r'\s+'));
    return drafts.where((draft) {
      final fields = [
        draft.title,
        draft.articleType,
        ...draft.questions,
        ...draft.answers.values,
        ...draft.tags,
      ].map(_normalizeSearch).toList();
      return keywords.every(
        (word) => fields.any((field) => _containsSearchKeyword(field, word)),
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
        .showSnackBar(const SnackBar(content: Text('バックアップを読み込みました。')));
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
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    final draft = await Navigator.of(context).push<ArticleDraft>(
      MaterialPageRoute(
        builder: (context) => NewArticlePage(
          database: widget.database,
          templates: [...ArticleTemplate.builtInTemplates, ...customTemplates],
        ),
      ),
    );
    if (mounted && draft != null) await _openEditor(draft);
  }

  Future<void> _openEditor(ArticleDraft draft) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) =>
            _ArticleEditor(database: widget.database, draft: draft),
      ),
    );
    if (mounted) _reload();
  }

  IconData _draftIcon(String articleType) {
    final templates = ArticleTemplate.builtInTemplates.where(
      (template) => template.name == articleType,
    );
    final iconName = templates.isEmpty ? null : templates.first.iconName;
    return switch (iconName) {
      'star.bubble' => Icons.rate_review_outlined,
      'arrow.left.arrow.right' => Icons.compare_arrows,
      'person.text.rectangle' => Icons.person_outline,
      'xmark.circle' => Icons.cancel_outlined,
      _ => Icons.description_outlined,
    };
  }

  String _formatUpdatedAt(DateTime updatedAt) {
    final local = updatedAt.toLocal();
    final date =
        '${local.year.toString().padLeft(4, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.day.toString().padLeft(2, '0')}';
    final time =
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
    return '$date $time';
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
                _draftIcon(draft.articleType),
                color: colors.onPrimaryContainer,
              ),
            ),
            title: LayoutBuilder(
              builder: (context, constraints) {
                final defaultStyle = DefaultTextStyle.of(context);
                final style = defaultStyle.style.merge(
                  theme.textTheme.titleMedium,
                );
                final title = draft.title.trim().isEmpty
                    ? '無題の記事'
                    : draft.title;
                final displayTitle = _fitArticleListTitle(
                  title,
                  maxWidth: constraints.maxWidth,
                  style: style,
                  textDirection: Directionality.of(context),
                  textScaler: MediaQuery.textScalerOf(context),
                  locale: Localizations.maybeLocaleOf(context),
                  textWidthBasis: defaultStyle.textWidthBasis,
                  textHeightBehavior: defaultStyle.textHeightBehavior,
                );
                return Text(
                  displayTitle,
                  style: theme.textTheme.titleMedium,
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                  textWidthBasis: defaultStyle.textWidthBasis,
                  textHeightBehavior: defaultStyle.textHeightBehavior,
                );
              },
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) => Wrap(
                    spacing: 8,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth,
                        ),
                        child: Text(
                          draft.articleType,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _formatUpdatedAt(draft.updatedAt),
                        maxLines: 1,
                        softWrap: false,
                        textAlign: TextAlign.end,
                      ),
                    ],
                  ),
                ),
                if (draft.tags.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ActionChip(
                        label: Text(draft.tags.first),
                        onPressed: () {
                          FocusManager.instance.primaryFocus?.unfocus();
                          _setSearch(draft.tags.first);
                        },
                      ),
                      if (draft.tags.length > 1)
                        Text(
                          '+${draft.tags.length - 1}件',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
            trailing: PopupMenuButton<void>(
              tooltip: '記事の操作',
              itemBuilder: (_) => [
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

  Widget _buildResults(
    AsyncSnapshot<List<ArticleDraft>> snapshot, {
    required bool wide,
  }) {
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
                child: Text('${searching ? '検索結果' : '記事数'}：${drafts.length}件'),
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
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          searching ? Icons.search : Icons.description_outlined,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          searching ? '検索結果がありません' : 'まだ記事がありません',
                          style: Theme.of(context).textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          searching
                              ? '別のキーワードで検索してみてください。'
                              : '記事を書く前のアイデアや構成を整理できます。\n'
                                    '最初の記事を作成してみましょう。',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : _buildDraftList(drafts, wide: wide),
        ),
      ],
    );
  }

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
  Widget build(BuildContext context) => FutureBuilder<List<ArticleDraft>>(
    future: _drafts,
    builder: (context, snapshot) {
      if (_loadingInitially &&
          (!widget.minimumStartupElapsed ||
              snapshot.connectionState != ConnectionState.done)) {
        return const StartupScreen();
      }
      _loadingInitially = false;
      return _buildPage(snapshot);
    },
  );

  Widget _buildPage(
    AsyncSnapshot<List<ArticleDraft>> snapshot,
  ) => LayoutBuilder(
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
                label: const Text('新しい記事を作成'),
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
                            label: const Text('新しい記事を作成'),
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
                        labelText: '検索',
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
                    Expanded(child: _buildResults(snapshot, wide: wide)),
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

String _fitArticleListTitle(
  String title, {
  required double maxWidth,
  required TextStyle style,
  required TextDirection textDirection,
  required TextScaler textScaler,
  required TextWidthBasis textWidthBasis,
  required TextHeightBehavior? textHeightBehavior,
  Locale? locale,
}) {
  bool fitsInTwoLines(String text) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: textDirection,
      textScaler: textScaler,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      locale: locale,
      maxLines: 2,
    )..layout(maxWidth: maxWidth);
    final fits =
        !painter.didExceedMaxLines &&
        painter.computeLineMetrics().every(
          (line) => line.width <= maxWidth + 0.01,
        );
    painter.dispose();
    return fits;
  }

  if (fitsInTwoLines(title)) return title;

  final graphemes = title.characters.toList();
  if (!fitsInTwoLines('…')) return '';

  var low = 0;
  var high = graphemes.length;
  while (low < high) {
    final middle = low + (high - low + 1) ~/ 2;
    final candidate = '${graphemes.take(middle).join()}…';
    if (fitsInTwoLines(candidate)) {
      low = middle;
    } else {
      high = middle - 1;
    }
  }
  return '${graphemes.take(low).join()}…';
}

class _ArticleEditor extends StatefulWidget {
  const _ArticleEditor({required this.database, required this.draft});

  final ArticleDatabase database;
  final ArticleDraft draft;

  @override
  State<_ArticleEditor> createState() => _ArticleEditorState();
}

class _ArticleEditorState extends State<_ArticleEditor> {
  late String _articleType = widget.draft.articleType;
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
  final _tagInputFocus = FocusNode();
  final _tagScrollController = ScrollController();

  ArticleDraft? _pendingDraft;
  Future<void>? _saving;
  bool _saveFailed = false;
  bool _closingEditor = false;
  bool _exporting = false;

  @override
  void dispose() {
    _title.dispose();
    _tagInput.dispose();
    _tagInputFocus.dispose();
    _tagScrollController.dispose();
    for (final controller in _answers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addTag() {
    final tag = _tagInput.text.trim();
    if (tag.isEmpty) return;
    final added = !_tags.contains(tag);
    setState(() {
      if (added) _tags.add(tag);
      _tagInput.clear();
    });
    if (added) _queueSave();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _tagInputFocus.requestFocus();
    });
  }

  Future<void> _changeTemplate() async {
    final List<ArticleTemplate> templates;
    try {
      templates = [
        ...ArticleTemplate.builtInTemplates,
        ...await widget.database.listCustomTemplates(),
      ];
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('テンプレートを読み込めませんでした。')));
      }
      return;
    }
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    final choice = await Navigator.of(context)
        .push<({ArticleTemplate template, bool keepAnswers})>(
          MaterialPageRoute(
            builder: (context) =>
                _ArticleTemplateSelection(templates: templates),
          ),
        );
    if (!mounted || choice == null) return;

    final answers = _currentDraft().answers;
    _articleType = choice.template.name;
    _extraAnswers.clear();
    _replaceQuestions([
      for (final question in choice.template.questions)
        (
          text: question,
          answer: choice.keepAnswers ? answers[question] ?? '' : '',
        ),
    ]);
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

    _replaceQuestions(edited);
  }

  void _replaceQuestions(List<ArticleQuestion> edited) {
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
    _queueSave();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final controller in previousControllers) {
        controller.dispose();
      }
    });
  }

  ArticleDraft _currentDraft() {
    final original = widget.draft;
    return ArticleDraft(
      id: original.id,
      title: _title.text,
      articleType: _articleType,
      questions: List.of(_questions),
      answers: {
        ..._extraAnswers,
        for (final entry in _answers.entries) entry.key: entry.value.text,
      },
      tags: List.of(_tags),
      updatedAt: DateTime.now(),
      status: original.status,
      deletedAt: original.deletedAt,
    );
  }

  void _queueSave() {
    _pendingDraft = _currentDraft();
    unawaited(_savePending());
  }

  Future<void> _savePending() {
    final inProgress = _saving;
    if (inProgress != null) return inProgress;
    if (_pendingDraft == null) return Future.value();

    final save = _drainSaves().whenComplete(() {
      _saving = null;
      if (mounted) setState(() {});
    });
    setState(() {
      _saveFailed = false;
      _saving = save;
    });
    return save;
  }

  Future<void> _drainSaves() async {
    // Finish the current write before saving the newest available snapshot.
    while (_pendingDraft != null) {
      final draft = _pendingDraft!;
      _pendingDraft = null;
      try {
        await widget.database.saveDraft(draft);
      } catch (_) {
        _pendingDraft ??= draft;
        _saveFailed = true;
        return;
      }
    }
  }

  Future<void> _closeEditor() async {
    if (_closingEditor) return;
    _closingEditor = true;
    try {
      await _savePending();
      if (!mounted) return;
      if (_pendingDraft != null) {
        final close = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('変更を保存できませんでした'),
            content: const Text('保存せずに閉じると、まだ保存されていない変更は失われます。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('編集に戻る'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('保存せずに閉じる'),
              ),
            ],
          ),
        );
        if (!mounted || close != true) return;
      }
      Navigator.of(context).pop();
    } finally {
      _closingEditor = false;
    }
  }

  Future<void> _export() async {
    if (_exporting) return;
    setState(() => _exporting = true);

    try {
      final draft = _currentDraft();
      final safeTitle = draft.title.replaceAll(
        RegExp(r'[<>:"/\\|?*\x00-\x1F]'),
        '_',
      );
      final shortTitle = String.fromCharCodes(safeTitle.trim().runes.take(40));
      final filename = shortTitle.isEmpty ? 'kiji.md' : 'kiji-$shortTitle.md';
      final saved = await _saveMarkdown(
        filename,
        utf8.encode(exportMarkdown(draft)),
      );
      if (!mounted || !saved) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(kIsWeb ? '記事ファイルのダウンロードを開始しました。' : '記事を書き出しました。'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('記事を書き出せませんでした。')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _preview() {
    FocusManager.instance.primaryFocus?.unfocus();
    final draft = _currentDraft();
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (context) => ArticlePreviewPage(draft: draft)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: colors.outlineVariant),
    );
    return PopScope(
      canPop: _pendingDraft == null && _saving == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_closeEditor());
      },
      child: ContentPageFrame(
        title: '記事の内容',
        actions: [
          if (_saveFailed)
            TextButton(onPressed: _savePending, child: const Text('保存を再試行'))
          else
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  _saving != null ? '保存中…' : '自動保存済み',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
        bottomAction: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 440;
            final save = OutlinedButton.icon(
              onPressed: _exporting ? null : _export,
              icon: const Icon(Icons.file_download_outlined),
              label: Text(_exporting ? '書き出し中…' : '記事を書き出す'),
              style: compact
                  ? OutlinedButton.styleFrom(minimumSize: const Size(0, 48))
                  : null,
            );
            final copy = FilledButton.icon(
              onPressed: _preview,
              icon: const Icon(Icons.description_outlined),
              label: const Text('記事構成を作成'),
              style: compact
                  ? FilledButton.styleFrom(minimumSize: const Size(0, 48))
                  : null,
            );
            if (compact) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [save, const SizedBox(height: 8), copy],
              );
            }
            return Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [save, copy],
            );
          },
        ),

        body: Theme(
          data: theme.copyWith(
            inputDecorationTheme: InputDecorationThemeData(
              filled: true,
              fillColor: colors.surface,
              border: border,
              enabledBorder: border,
            ),
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            children: [
              ContentCard(
                child: ListTile(
                  title: const Text('記事種類'),
                  subtitle: Text(_articleType),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _changeTemplate,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _title,
                onChanged: (_) => _queueSave(),
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                minLines: 1,
                maxLines: null,
                style: theme.textTheme.titleLarge,
                decoration: const InputDecoration(labelText: 'タイトル'),
              ),
              const SizedBox(height: 16),
              if (_tags.isNotEmpty) ...[
                Listener(
                  onPointerSignal: (event) {
                    if (event is! PointerScrollEvent ||
                        !_tagScrollController.hasClients) {
                      return;
                    }
                    final delta = event.scrollDelta;
                    final scrollDelta = delta.dx.abs() > delta.dy.abs()
                        ? delta.dx
                        : delta.dy;
                    final position = _tagScrollController.position;
                    _tagScrollController.jumpTo(
                      (position.pixels + scrollDelta)
                          .clamp(
                            position.minScrollExtent,
                            position.maxScrollExtent,
                          )
                          .toDouble(),
                    );
                  },
                  child: ScrollConfiguration(
                    behavior: const MaterialScrollBehavior().copyWith(
                      dragDevices: {
                        PointerDeviceKind.touch,
                        PointerDeviceKind.mouse,
                      },
                    ),
                    child: SingleChildScrollView(
                      controller: _tagScrollController,
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final (index, tag) in _tags.indexed) ...[
                            if (index > 0) const SizedBox(width: 8),
                            InputChip(
                              label: Text(tag),
                              deleteButtonTooltipMessage: '$tag のタグを削除',
                              onDeleted: () {
                                setState(() {
                                  _tags.removeAt(index);
                                });
                                _queueSave();
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              TextField(
                controller: _tagInput,
                focusNode: _tagInputFocus,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _addTag(),
                decoration: InputDecoration(
                  labelText: 'タグを追加',
                  suffixIcon: Tooltip(
                    message: 'タグを追加',
                    child: TextButton(
                      onPressed: _addTag,
                      child: const Text('追加'),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text('質問と回答', style: theme.textTheme.titleMedium),
                  ),
                  TextButton.icon(
                    onPressed: _editQuestions,
                    icon: const Icon(Icons.edit_note),
                    label: const Text('質問を編集'),
                  ),
                ],
              ),
              for (final (index, question) in _questions.indexed) ...[
                const SizedBox(height: 16),
                Text('【質問${index + 1}】', style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(question, style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text('【回答】', style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Semantics(
                  label: question,
                  child: TextFormField(
                    key: ValueKey(question),
                    controller: _answers[question]!,
                    onChanged: (_) => _queueSave(),
                    minLines: 3,
                    maxLines: 8,
                    decoration: const InputDecoration(hintText: '回答を入力'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
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

class _ArticleTemplateSelection extends StatelessWidget {
  const _ArticleTemplateSelection({required this.templates});

  final List<ArticleTemplate> templates;

  Future<void> _select(BuildContext context, ArticleTemplate template) async {
    final keepAnswers = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('テンプレートを変更しますか？'),
        content: const Text('変更後の質問と回答の扱いを選んでください。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('キャンセル'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('質問と回答をリセット'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('共通する質問・回答を引き継ぐ'),
          ),
        ],
      ),
    );
    if (context.mounted && keepAnswers != null) {
      Navigator.pop(context, (template: template, keepAnswers: keepAnswers));
    }
  }

  @override
  Widget build(BuildContext context) => ContentPageFrame(
    title: 'テンプレートを選択',
    body: ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: templates.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final template = templates[index];
        return ContentCard(
          child: ListTile(
            title: Text(template.name),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _select(context, template),
          ),
        );
      },
    ),
  );
}
