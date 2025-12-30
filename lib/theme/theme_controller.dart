import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppTheme { light, darkGray, amoled }

class ThemeController extends ValueNotifier<AppTheme> {
  ThemeController._internal() : materialYou = false, super(AppTheme.light);

  static final ThemeController instance = ThemeController._internal();

  // independent flag for Material You
  bool materialYou;

  // Custom color and font settings
  Color? customSeedColor;
  String? customFontFamily;
  double customFontSize = 1.0;

  static const _kThemeKey = 'theme_selected';
  static const _kMaterialYouKey = 'material_you_enabled';
  static const _kSeenIntroKey = 'seen_intro';
  static const _kCustomColorKey = 'custom_seed_color';
  static const _kCustomFontFamilyKey = 'custom_font_family';
  static const _kCustomFontSizeKey = 'custom_font_size';

  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = prefs.getInt(_kThemeKey) ?? 0;
    final mat = prefs.getBool(_kMaterialYouKey) ?? false;
    materialYou = mat;
    value = AppTheme.values[idx.clamp(0, AppTheme.values.length - 1)];

    // Load custom color
    final colorValue = prefs.getInt(_kCustomColorKey);
    customSeedColor = colorValue != null ? Color(colorValue) : null;

    // Load custom font
    customFontFamily = prefs.getString(_kCustomFontFamilyKey);
    customFontSize = prefs.getDouble(_kCustomFontSizeKey) ?? 1.0;

    notifyListeners();
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kThemeKey, value.index);
    await prefs.setBool(_kMaterialYouKey, materialYou);

    // Save custom color
    if (customSeedColor != null) {
      await prefs.setInt(_kCustomColorKey, customSeedColor!.value);
    } else {
      await prefs.remove(_kCustomColorKey);
    }

    // Save custom font
    if (customFontFamily != null) {
      await prefs.setString(_kCustomFontFamilyKey, customFontFamily!);
    } else {
      await prefs.remove(_kCustomFontFamilyKey);
    }

    await prefs.setDouble(_kCustomFontSizeKey, customFontSize);
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

  void setCustomColor(Color? color) {
    customSeedColor = color;
    _saveToPrefs();
    notifyListeners();
  }

  void setFontFamily(String? family) {
    customFontFamily = family;
    _saveToPrefs();
    notifyListeners();
  }

  void setFontSize(double size) {
    customFontSize = size.clamp(0.8, 1.3);
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
