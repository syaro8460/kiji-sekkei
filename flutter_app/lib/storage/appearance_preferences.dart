import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_preferences.dart';

enum AppearanceMode {
  system('システム'),
  light('ライト'),
  dark('ダーク');

  const AppearanceMode(this.label);

  final String label;
}

class AppearancePreferences {
  AppearancePreferences({AppPreferences? preferences})
    : _preferences = preferences ?? AppPreferences.shared;

  final AppPreferences _preferences;
  static const _key = 'appearanceMode';

  Future<AppearanceMode> load({Duration? timeout}) async {
    try {
      final saved = await _preferences.load(
        _key,
        timeout: timeout,
        // The earlier appearance implementation used Android DataStore.
        fallback: !kIsWeb && defaultTargetPlatform == TargetPlatform.android
            ? () => SharedPreferencesAsync().getString(_key)
            : null,
      );
      return AppearanceMode.values
              .where((mode) => mode.name == saved)
              .firstOrNull ??
          AppearanceMode.system;
    } catch (_) {
      return AppearanceMode.system;
    }
  }

  Future<void> save(AppearanceMode mode) => _preferences.save(_key, mode.name);
}
