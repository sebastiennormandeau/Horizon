/// Validation des saisies utilisateur (formulaires d'authentification, etc.).
///
/// Chaque validateur accepte un `AppLocalizations` optionnel pour retourner
/// le message dans la langue active ; sans lui, le français est utilisé
/// (ce qui garde les tests purs, sans contexte Flutter).
library;

import '../l10n/app_localizations.dart';
import '../l10n/app_localizations_fr.dart';

final RegExp _emailPattern = RegExp(
  r"^[\w.!#$%&'*+/=?^`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)+$",
);

final RegExp joinCodePattern = RegExp(r'^[A-Z0-9]{6}$');

AppLocalizations _strings(AppLocalizations? l10n) => l10n ?? AppLocalizationsFr();

/// Retourne un message d'erreur, ou null si l'adresse est valide.
String? validateEmail(String? value, [AppLocalizations? l10n]) {
  final s = _strings(l10n);
  final email = value?.trim() ?? '';
  if (email.isEmpty) return s.vEmailRequired;
  if (email.length > 254 || !_emailPattern.hasMatch(email)) {
    return s.vEmailInvalid;
  }
  return null;
}

/// Mot de passe : au moins 8 caractères, avec au moins une lettre et un chiffre.
String? validatePassword(String? value, [AppLocalizations? l10n]) {
  final s = _strings(l10n);
  final password = value ?? '';
  if (password.isEmpty) return s.vPasswordRequired;
  if (password.length < 8) {
    return s.vPasswordTooShort;
  }
  if (!password.contains(RegExp(r'[A-Za-z]')) ||
      !password.contains(RegExp(r'[0-9]'))) {
    return s.vPasswordNeedsLetterDigit;
  }
  return null;
}

String? validatePasswordConfirmation(
  String? value,
  String original, [
  AppLocalizations? l10n,
]) {
  if (value != original) return _strings(l10n).vPasswordMismatch;
  return null;
}

/// Prénom / nom affiché : 2 à 40 caractères.
String? validateDisplayName(String? value, [AppLocalizations? l10n]) {
  final s = _strings(l10n);
  final name = value?.trim() ?? '';
  if (name.length < 2) return s.vNameTooShort;
  if (name.length > 40) return s.vNameTooLong;
  return null;
}

/// Code de foyer : exactement 6 caractères alphanumériques.
String? validateJoinCode(String? value, [AppLocalizations? l10n]) {
  final code = value?.trim().toUpperCase() ?? '';
  if (!joinCodePattern.hasMatch(code)) {
    return _strings(l10n).vJoinCodeInvalid;
  }
  return null;
}
