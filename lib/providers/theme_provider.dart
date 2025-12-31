import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/theme.dart';
import '../utils/theme.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'selected_theme';
  AppThemeType _themeType = AppThemeType.defaultDark;

  AppThemeType get themeType => _themeType;
  
  // Easter egg state
  int _easterEggTapCount = 0;
  bool _showParksideEasterEgg = false;
  
  int get easterEggTapCount => _easterEggTapCount;
  bool get showParksideEasterEgg => _showParksideEasterEgg;
  
  // Keep compatibility with existing code that might check isDarkMode
  bool get isDarkMode => true;

  Future<void> setThemeType(AppThemeType type) async {
    if (_themeType == type) return;
    
    _themeType = type;
    
    // Reset easter egg when theme changes
    _easterEggTapCount = 0;
    _showParksideEasterEgg = false;
    
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, type.name);
    
    // Update app icon - removed
  }

  void incrementEasterEggTap() {
    if (_themeType == AppThemeType.parkside) {
      _easterEggTapCount++;
      if (_easterEggTapCount >= 5) {
        _showParksideEasterEgg = true;
      }
      notifyListeners();
    }
  }

  Future<void> loadThemeMode({String? userEmail}) async {
    final prefs = await SharedPreferences.getInstance();
    final themeName = prefs.getString(_themeKey);
    
    if (themeName != null) {
      try {
        _themeType = AppThemeType.values.byName(themeName);
        notifyListeners();
        // Ensure icon matches saved theme on load - removed
      } catch (_) {
        // Fallback to default if invalid theme name
        _setDefaultThemeForUser(userEmail);
      }
    } else {
      // No saved preference, use user-specific default
      _setDefaultThemeForUser(userEmail);
    }
  }

  void _setDefaultThemeForUser(String? userEmail) {
    // Set Parkside as default for luci.priv@andreimuntean.dev
    if (userEmail?.toLowerCase() == 'luci.priv@andreimuntean.dev') {
      _themeType = AppThemeType.parkside;
    } else {
      _themeType = AppThemeType.defaultDark;
    }
    notifyListeners();
    // Update icon for the default theme - removed
  }


  // Keep compatibility with existing code
  Future<void> setThemeMode(ThemeMode themeMode) async {
    // No-op for now as we focus on theme types within dark mode
  }
}