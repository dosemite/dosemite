import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppTheme { light, darkGray, amoled }

class ThemeController extends ValueNotifier<AppTheme> {
  ThemeController._internal()
      : materialYou = false,
        super(AppTheme.light);

  static final ThemeController instance = ThemeController._internal();

  // independent flag for Material You
  bool materialYou;

  static const _kThemeKey = 'theme_selected';
  static const _kMaterialYouKey = 'material_you_enabled';
  static const _kSeenIntroKey = 'seen_intro';

  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = prefs.getInt(_kThemeKey) ?? 0;
    final mat = prefs.getBool(_kMaterialYouKey) ?? false;
    materialYou = mat;
    value = AppTheme.values[idx.clamp(0, AppTheme.values.length - 1)];
    notifyListeners();
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kThemeKey, value.index);
    await prefs.setBool(_kMaterialYouKey, materialYou);
  }

  void setTheme(AppTheme theme) {
    value = theme;
    _saveToPrefs();
    notifyListeners();
  }

  void setMaterialYou(bool enabled) {
    materialYou = enabled;
    _saveToPrefs();
    notifyListeners();
  }

  // helper for intro persistence
  static Future<bool> hasSeenIntro() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kSeenIntroKey) ?? false;
  }

  static Future<void> setSeenIntro() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSeenIntroKey, true);
  }
}
