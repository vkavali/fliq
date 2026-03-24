import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../network/api_client.dart';
import '../constants/api_constants.dart';
import 'app_strings.dart';

const _kLocaleKey = 'fliq_locale';

/// Provides the current locale string (e.g. 'en', 'hi', 'ta').
/// Persists to SharedPreferences and syncs to backend on change.
final localeProvider = StateNotifierProvider<LocaleNotifier, String>((ref) {
  return LocaleNotifier(ref);
});

class LocaleNotifier extends StateNotifier<String> {
  final Ref _ref;

  LocaleNotifier(this._ref) : super('en') {
    _loadSavedLocale();
  }

  /// Load the persisted locale from SharedPreferences.
  Future<void> _loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kLocaleKey);
    if (saved != null && AppStrings.supportedLocales.contains(saved)) {
      state = saved;
    }
  }

  /// Initialize from a user's languagePreference (call after login).
  void initFromUser(String? languagePreference) {
    if (languagePreference != null &&
        AppStrings.supportedLocales.contains(languagePreference)) {
      state = languagePreference;
      _persist(languagePreference);
    }
  }

  /// Change the locale, persist locally, and update the backend.
  Future<void> setLocale(String locale) async {
    if (!AppStrings.supportedLocales.contains(locale)) return;
    if (state == locale) return;

    state = locale;
    await _persist(locale);
    await _syncToBackend(locale);
  }

  Future<void> _persist(String locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLocaleKey, locale);
  }

  Future<void> _syncToBackend(String locale) async {
    try {
      final dio = _ref.read(dioProvider);
      await dio.patch(ApiConstants.userProfile, data: {
        'languagePreference': locale,
      });
    } catch (_) {
      // Silently fail — the locale is already saved locally.
      // It will sync next time settings are saved.
    }
  }
}

/// Extension on [BuildContext] for easy string lookups when you have a [WidgetRef].
///
/// Usage inside a ConsumerWidget:
/// ```dart
/// Text(context.tr('scan_to_tip', ref))
/// ```
extension LocalizedBuildContext on BuildContext {
  String tr(String key, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    return AppStrings.get(key, locale);
  }
}

/// Standalone helper for use outside widgets (e.g. in notifiers).
///
/// Usage:
/// ```dart
/// final label = tr('scan_to_tip', ref);
/// ```
String tr(String key, Ref ref) {
  final locale = ref.read(localeProvider);
  return AppStrings.get(key, locale);
}
