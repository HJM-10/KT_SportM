import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  ThemeProvider() {
    _loadTheme();
  }

  void toggleTheme(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('theme', mode.toString());
  }

  void _loadTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? theme = prefs.getString('theme');
    if (theme != null) {
      if (theme == ThemeMode.light.toString()) {
        _themeMode = ThemeMode.light;
      } else if (theme == ThemeMode.dark.toString()) {
        _themeMode = ThemeMode.dark;
      }
      notifyListeners();
    }
  }
}
