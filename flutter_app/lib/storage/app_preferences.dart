import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

/// Serializes access to the legacy store, including its Windows file cache.
class AppPreferences {
  AppPreferences({this._store});

  static final shared = AppPreferences();
  static const draftSortOrderKey = 'flutter.draftSortOrder';
  final SharedPreferencesStorePlatform? _store;
  Future<void>? _pending;

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = _pending?.then((_) => operation()) ?? operation();
    late final Future<void> tail;
    tail = result
        .then<void>((_) {}, onError: (Object _, StackTrace _) {})
        .whenComplete(() {
          if (identical(_pending, tail)) _pending = null;
        });
    _pending = tail;
    return result;
  }

  Future<Object?> _read(
    SharedPreferencesStorePlatform store,
    String key,
  ) async {
    final values = await store.getAllWithParameters(
      GetAllParameters(
        filter: PreferencesFilter(prefix: '', allowList: {key}),
      ),
    );
    return values[key];
  }

  Future<String?> load(String key, {Future<String?> Function()? fallback}) =>
      _serialize(() async {
        final value = await _read(
          _store ?? SharedPreferencesStorePlatform.instance,
          key,
        );
        return value is String ? value : await fallback?.call();
      });

  Future<void> save(String key, String value) => _serialize(() async {
    final store = _store ?? SharedPreferencesStorePlatform.instance;
    final previous = await _read(store, key);
    try {
      if (!await store.setValue('String', key, value)) {
        throw StateError('Could not save preference: $key');
      }
    } catch (_) {
      // The Windows backend mutates its cache before reporting a failed write.
      // Put back the old value before any other operation can use that cache.
      try {
        switch (previous) {
          case null:
            await store.remove(key);
          case String():
            await store.setValue('String', key, previous);
          case bool():
            await store.setValue('Bool', key, previous);
          case int():
            await store.setValue('Int', key, previous);
          case double():
            await store.setValue('Double', key, previous);
          case List<String>():
            await store.setValue('StringList', key, previous);
        }
      } catch (_) {
        // Preserve the original failure if the backend is still unavailable.
      }
      rethrow;
    }
  });
}
