import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Thèmes clair et sombre d'Horizon.
///
/// Les deux partagent la même structure : seules les couleurs changent. Tout
/// écran doit puiser ses couleurs dans le `ColorScheme` ou dans
/// [HorizonPalette] — aucune couleur de fond ni de texte codée en dur, sans
/// quoi le mode clair devient illisible.
class AppTheme {
  AppTheme._();

  static const _radius = 16.0;

  static final ColorScheme _darkScheme = const ColorScheme.dark(
    primary: Color(0xFF2DD4A7),
    onPrimary: Color(0xFF00281E),
    primaryContainer: Color(0xFF0B3F33),
    onPrimaryContainer: Color(0xFFA7F3D9),
    secondary: Color(0xFF7C6BF5),
    onSecondary: Colors.white,
    error: Color(0xFFFB7185),
    onError: Color(0xFF3F0716),
    // Bleu nuit plutôt que noir pur : moins fatigant et plus chaleureux.
    surface: Color(0xFF0B1120),
    onSurface: Color(0xFFE8EDF7),
    surfaceContainerHighest: Color(0xFF1B2740),
    onSurfaceVariant: Color(0xFF94A3BC),
    outline: Color(0xFF3B4A66),
    outlineVariant: Color(0xFF2A3A57),
  );

  static final ColorScheme _lightScheme = const ColorScheme.light(
    primary: Color(0xFF0E8F70),
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFD3F5EA),
    onPrimaryContainer: Color(0xFF00382A),
    secondary: Color(0xFF5B4BD8),
    onSecondary: Colors.white,
    error: Color(0xFFBE123C),
    onError: Colors.white,
    surface: Color(0xFFF6F8FB),
    onSurface: Color(0xFF0F172A),
    surfaceContainerHighest: Colors.white,
    onSurfaceVariant: Color(0xFF5B6B84),
    outline: Color(0xFFB6C0CE),
    outlineVariant: Color(0xFFDDE3EC),
  );

  static ThemeData get dark => _build(_darkScheme, HorizonPalette.dark);
  static ThemeData get light => _build(_lightScheme, HorizonPalette.light);

  static ThemeData _build(ColorScheme scheme, HorizonPalette palette) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: scheme.surface,
    );

    return base.copyWith(
      extensions: [palette],
      textTheme: _textTheme(base.textTheme, scheme),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerHighest,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: scheme.primary),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.outline),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.surfaceContainerHighest,
        contentTextStyle: TextStyle(color: scheme.onSurface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: scheme.surfaceContainerHighest,
        side: BorderSide(color: scheme.outlineVariant),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
      ),
    );
  }

  /// Échelle typographique : titres serrés et affirmés, corps confortable,
  /// montants en chiffres tabulaires pour que les colonnes s'alignent.
  static TextTheme _textTheme(TextTheme base, ColorScheme scheme) {
    return base
        .copyWith(
          displaySmall: base.displaySmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.8,
          ),
          headlineSmall: base.headlineSmall?.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
          titleLarge: base.titleLarge?.copyWith(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
          titleMedium: base.titleMedium?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          bodyMedium: base.bodyMedium?.copyWith(fontSize: 14, height: 1.45),
          bodySmall: base.bodySmall?.copyWith(
            fontSize: 12.5,
            color: scheme.onSurfaceVariant,
          ),
          labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        )
        .apply(fontFamily: 'Inter');
  }
}
