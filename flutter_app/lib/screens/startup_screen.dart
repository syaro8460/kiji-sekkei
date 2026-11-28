import 'package:material_ui/material_ui.dart';

class StartupScreen extends StatelessWidget {
  const StartupScreen({super.key, this.showMigrationProgress = false});

  final bool showMigrationProgress;

  static const _foreground = Color(0xFF103D20);

  @override
  Widget build(BuildContext context) {
    final background = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF30D158)
        : const Color(0xFF34C759);

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showMigrationProgress) const SizedBox(height: 40),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      'assets/startup_logo.png',
                      width: 120,
                      height: 120,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '記事設計',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: _foreground,
                    ),
                  ),
                  if (showMigrationProgress) ...[
                    const SizedBox(height: 16),
                    const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(
                        color: _foreground,
                        semanticsLabel: '旧版のデータを移行しています',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
