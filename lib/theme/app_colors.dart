import 'package:flutter/material.dart';

/// Couleurs de marque d'Horizon.
///
/// Ne contient que ce qui ne dépend PAS du mode clair/sombre : la teinte de
/// marque et les accents des cagnottes, choisis pour rester lisibles sur fond
/// clair comme sur fond sombre. Tout le reste — fonds, surfaces, bordures,
/// couleurs de texte — vient du `ColorScheme` du thème actif
/// (`Theme.of(context).colorScheme`) ou de [HorizonPalette].
///
/// ⚠️ Ne jamais réintroduire ici une couleur de fond ou de texte : elle
/// casserait le mode clair.
class AppColors {
  AppColors._();

  /// Vert « horizon » : la teinte de marque. Suffisamment sombre pour rester
  /// lisible sur blanc, suffisamment saturée pour ressortir sur la nuit.
  static const Color primary = Color(0xFF12A181);

  /// Accent de la cagnotte personnelle.
  static const Color solo = Color(0xFFF59E0B);

  /// Accent de la cagnotte du/de la partenaire.
  static const Color partner = Color(0xFF7C6BF5);
}

/// Palette sémantique dépendant du thème actif.
///
/// Exposée en `ThemeExtension` plutôt qu'en constantes : les mêmes rôles
/// (succès, alerte, danger) demandent des teintes différentes selon qu'on
/// les pose sur un fond clair ou sombre.
@immutable
class HorizonPalette extends ThemeExtension<HorizonPalette> {
  final Color success;
  final Color warning;
  final Color danger;

  /// Dégradé signature, utilisé pour la cagnotte commune et l'en-tête.
  final List<Color> brandGradient;

  const HorizonPalette({
    required this.success,
    required this.warning,
    required this.danger,
    required this.brandGradient,
  });

  static const light = HorizonPalette(
    success: Color(0xFF15803D),
    warning: Color(0xFFB45309),
    danger: Color(0xFFBE123C),
    brandGradient: [Color(0xFF12A181), Color(0xFF0E7490)],
  );

  static const dark = HorizonPalette(
    success: Color(0xFF34D399),
    warning: Color(0xFFFBBF24),
    danger: Color(0xFFFB7185),
    brandGradient: [Color(0xFF14B8A6), Color(0xFF0E7490)],
  );

  /// Couleur d'un niveau d'alerte de cagnotte : 0 = ok, 1 = sous le seuil,
  /// 2 = négatif. `null` quand tout va bien, pour laisser la couleur de base.
  Color? alertColor(int level) {
    if (level == 2) return danger;
    if (level == 1) return warning;
    return null;
  }

  @override
  HorizonPalette copyWith({
    Color? success,
    Color? warning,
    Color? danger,
    List<Color>? brandGradient,
  }) {
    return HorizonPalette(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      brandGradient: brandGradient ?? this.brandGradient,
    );
  }

  @override
  HorizonPalette lerp(ThemeExtension<HorizonPalette>? other, double t) {
    if (other is! HorizonPalette) return this;
    return HorizonPalette(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      brandGradient: [
        Color.lerp(brandGradient[0], other.brandGradient[0], t)!,
        Color.lerp(brandGradient[1], other.brandGradient[1], t)!,
      ],
    );
  }
}

/// Raccourcis de lecture du thème, pour éviter `Theme.of(context)` répété.
extension HorizonThemeContext on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;
  HorizonPalette get palette => Theme.of(this).extension<HorizonPalette>()!;

  /// Fond des cartes.
  Color get cardColor => Theme.of(this).colorScheme.surfaceContainerHighest;

  /// Bordure discrète des cartes.
  Color get borderColor => Theme.of(this).colorScheme.outlineVariant;

  /// Texte secondaire (libellés, sous-titres).
  Color get mutedColor => Theme.of(this).colorScheme.onSurfaceVariant;
}
