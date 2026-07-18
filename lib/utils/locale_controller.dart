import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'formatters.dart';

/// Gestion de la langue de l'application (français par défaut, anglais en
/// option). Le choix est persisté localement (SharedPreferences) pour être
/// disponible dès l'écran de connexion, avant toute authentification.
///
/// `value == null` signifie « suivre la langue de l'appareil » (repli sur le
/// français si l'appareil n'est ni en français ni en anglais).
class LocaleController extends ValueNotifier<Locale?> {
  LocaleController._() : super(null);

  static final LocaleController instance = LocaleController._();

  static const _prefKey = 'app_locale';
  static const supportedLocales = [Locale('fr'), Locale('en')];

  /// À appeler avant runApp : recharge le choix persisté.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved == 'fr' || saved == 'en') {
      value = Locale(saved!);
    }
    _syncCurrencyLocale();
  }

  /// `code` : 'fr', 'en', ou null pour suivre l'appareil.
  Future<void> setLocale(String? code) async {
    final prefs = await SharedPreferences.getInstance();
    if (code == null) {
      await prefs.remove(_prefKey);
      value = null;
    } else {
      await prefs.setString(_prefKey, code);
      value = Locale(code);
    }
    _syncCurrencyLocale();
  }

  /// Langue effective ('fr' ou 'en') en tenant compte du repli sur l'appareil.
  String get effectiveLanguageCode {
    if (value != null) return value!.languageCode;
    final device = WidgetsBinding.instance.platformDispatcher.locale;
    return device.languageCode == 'en' ? 'en' : 'fr';
  }

  /// Résolution de langue pour MaterialApp : appareil si supporté, sinon fr.
  static Locale resolveLocale(Locale? device, Iterable<Locale> supported) {
    if (device != null) {
      for (final locale in supported) {
        if (locale.languageCode == device.languageCode) return locale;
      }
    }
    return const Locale('fr');
  }

  void _syncCurrencyLocale() {
    // Le formatage monétaire (fr-CA « 1 234,56 $ » vs en-CA « $1,234.56 »)
    // suit la langue de l'app sans devoir passer un contexte partout.
    currencyLanguageCode = effectiveLanguageCode;
  }
}
