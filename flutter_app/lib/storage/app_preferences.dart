import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  Future<String?> load(
    String key, {
    Future<String?> Function()? fallback,
    Duration? timeout,
  }) => _serialize(() {
    var expired = false;

    Future<String?> read() async {
      // The Windows and Linux legacy plugins populate a mutable cache on their
      // first read. Their async plugins read the same default file and raw keys
      // with a separate cache. Use that cache only for the bounded startup read,
      // so a late read cannot replace the cache used by a later write.
      final useSeparateCache =
          timeout != null &&
          !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.windows ||
              defaultTargetPlatform == TargetPlatform.linux);
      final value = useSeparateCache
          ? await SharedPreferencesAsync().getString(key)
          : await _read(_store ?? SharedPreferencesStorePlatform.instance, key);
      if (value is String) return value;
      return expired ? null : await fallback?.call();
    }

    final result = read();
    if (timeout == null) return result;
    // Bound the read inside the queue. The source future can still finish, but
    // its result or error is ignored and it never releases a queued write.
    return result.timeout(
      timeout,
      onTimeout: () {
        expired = true;
        return null;
      },
    );
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
