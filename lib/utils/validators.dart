/// Validation des saisies utilisateur (formulaires d'authentification, etc.).
library;

final RegExp _emailPattern = RegExp(
  r"^[\w.!#$%&'*+/=?^`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)+$",
);

final RegExp joinCodePattern = RegExp(r'^[A-Z0-9]{6}$');

/// Retourne un message d'erreur, ou null si l'adresse est valide.
String? validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return 'Veuillez entrer votre adresse courriel.';
  if (email.length > 254 || !_emailPattern.hasMatch(email)) {
    return 'Adresse courriel invalide.';
  }
  return null;
}

/// Mot de passe : au moins 8 caractères, avec au moins une lettre et un chiffre.
String? validatePassword(String? value) {
  final password = value ?? '';
  if (password.isEmpty) return 'Veuillez entrer un mot de passe.';
  if (password.length < 8) {
    return 'Le mot de passe doit contenir au moins 8 caractères.';
  }
  if (!password.contains(RegExp(r'[A-Za-z]')) ||
      !password.contains(RegExp(r'[0-9]'))) {
    return 'Le mot de passe doit contenir au moins une lettre et un chiffre.';
  }
  return null;
}

String? validatePasswordConfirmation(String? value, String original) {
  if (value != original) return 'Les mots de passe ne correspondent pas.';
  return null;
}

/// Prénom / nom affiché : 2 à 40 caractères.
String? validateDisplayName(String? value) {
  final name = value?.trim() ?? '';
  if (name.length < 2) return 'Veuillez entrer votre prénom (2 lettres min.).';
  if (name.length > 40) return 'Prénom trop long (40 caractères max.).';
  return null;
}

/// Code de foyer : exactement 6 caractères alphanumériques.
String? validateJoinCode(String? value) {
  final code = value?.trim().toUpperCase() ?? '';
  if (!joinCodePattern.hasMatch(code)) {
    return 'Le code doit contenir 6 lettres ou chiffres.';
  }
  return null;
}
