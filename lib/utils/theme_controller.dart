import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gestion du mode d'affichage (clair, sombre, ou celui du système).
///
/// Même principe que [LocaleController] : le choix est persisté localement
/// pour s'appliquer dès l'écran de connexion, avant toute authentification —
/// un réglage stocké côté serveur ferait clignoter l'app au démarrage.
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController._() : super(ThemeMode.system);

  static final ThemeController instance = ThemeController._();

  static const _prefKey = 'app_theme_mode';

  /// À appeler avant runApp : recharge le choix persisté.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    value = _decode(prefs.getString(_prefKey));
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    if (mode == ThemeMode.system) {
      await prefs.remove(_prefKey);
    } else {
      await prefs.setString(_prefKey, mode == ThemeMode.dark ? 'dark' : 'light');
    }
    value = mode;
  }

  static ThemeMode _decode(String? saved) {
    switch (saved) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      default:
        return ThemeMode.system;
    }
  }
}
