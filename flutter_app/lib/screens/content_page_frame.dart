import 'package:material_ui/material_ui.dart';

/// A shared width and action placement for app pages.
class ContentPageFrame extends StatelessWidget {
  const ContentPageFrame({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
    this.bottomAction,
  });

  final String title;
  final Widget body;
  final List<Widget> actions;
  final Widget? bottomAction;

  static const contentWidth = 800.0;

  Widget _centered(Widget child) => Align(
    alignment: Alignment.topCenter,
    heightFactor: 1,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: contentWidth),
      child: SizedBox(width: double.infinity, child: child),
    ),
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final colors = Theme.of(context).colorScheme;
      final gutter = constraints.maxWidth > contentWidth
          ? (constraints.maxWidth - contentWidth) / 2
          : 0.0;
      final canGoBack = ModalRoute.of(context)?.impliesAppBarDismissal ?? false;
      final action = bottomAction;
      return Scaffold(
        backgroundColor: colors.surfaceContainerLow,
        appBar: AppBar(
          backgroundColor: colors.surface,
          surfaceTintColor: Colors.transparent,
          shape: Border(bottom: BorderSide(color: colors.outlineVariant)),
          automaticallyImplyLeading: false,
          leadingWidth: gutter + 56,
          leading: canGoBack
              ? const Align(
                  alignment: Alignment.centerRight,
                  child: BackButton(),
                )
              : null,
          titleSpacing: canGoBack ? 8 : gutter + 20,
          actionsPadding: EdgeInsets.only(right: gutter + 12),
          title: Text(title),
          actions: actions,
        ),
        body: SafeArea(bottom: action == null, child: _centered(body)),
        bottomNavigationBar: action == null
            ? null
            : Material(
                color: colors.surface,
                child: SafeArea(
                  top: false,
                  child: _centered(
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [action],
                      ),
                    ),
                  ),
                ),
              ),
      );
    },
  );
}

/// A surface for lists of settings or management actions.
class ContentCard extends StatelessWidget {
  const ContentCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
