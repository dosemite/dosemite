import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { english, turkish }

class LanguageController extends ValueNotifier<AppLanguage> {
  LanguageController._internal() : super(AppLanguage.english);

  static final LanguageController instance = LanguageController._internal();

  static const _kLanguageKey = 'app_language';

  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = prefs.getInt(_kLanguageKey) ?? 0;
    value = AppLanguage.values[idx.clamp(0, AppLanguage.values.length - 1)];
    notifyListeners();
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLanguageKey, value.index);
  }

  void setLanguage(AppLanguage language) {
    value = language;
    _saveToPrefs();
    notifyListeners();
  }

  Locale get locale {
    switch (value) {
      case AppLanguage.turkish:
        return const Locale('tr', 'TR');
      case AppLanguage.english:
        return const Locale('en', 'US');
    }
  }

  String get languageName {
    switch (value) {
      case AppLanguage.turkish:
        return 'Türkçe';
      case AppLanguage.english:
        return 'English';
    }
  }
}
