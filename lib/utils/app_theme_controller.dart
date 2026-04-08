import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppThemeController {
  AppThemeController._();

  static final AppThemeController instance = AppThemeController._();
  static const String _prefKey = 'app_theme_mode';

  final ValueNotifier<ThemeMode> mode = ValueNotifier<ThemeMode>(
    ThemeMode.light,
  );

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString(_prefKey);

    if (savedMode == 'dark') {
      mode.value = ThemeMode.dark;
      return;
    }

    mode.value = ThemeMode.light;
  }

  Future<void> setDarkMode(bool enabled) async {
    mode.value = enabled ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, enabled ? 'dark' : 'light');
  }
}
