import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/formatters.dart';

/// Montant qui glisse jusqu'à sa nouvelle valeur au lieu de sauter.
///
/// Le solde change à chaque transaction triée : l'animation rend visible
/// *ce que le geste vient de coûter*, ce qu'un remplacement instantané ne
/// montre pas.
class AnimatedAmount extends StatelessWidget {
  final double amount;
  final TextStyle? style;

  const AnimatedAmount({super.key, required this.amount, this.style});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: amount, end: amount),
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => Text(
        formatCurrency(value),
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Carte de cagnotte : libellé, solde animé et état d'alerte.
///
/// [featured] remplit la carte du dégradé de marque — réservé à la cagnotte
/// commune, qui est le cœur du budget partagé. Le niveau d'alerte prime
/// toujours sur l'habillage : une cagnotte dans le rouge doit se voir.
class BalanceCard extends StatelessWidget {
  final String title;
  final double amount;

  /// 0 = ok, 1 = sous le seuil, 2 = négatif.
  final int alert;

  /// Teinte d'accent de la cagnotte (perso, partenaire…).
  final Color accent;

  final bool featured;

  const BalanceCard({
    super.key,
    required this.title,
    required this.amount,
    required this.accent,
    this.alert = 0,
    this.featured = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final alertColor = palette.alertColor(alert);
    final useGradient = featured && alertColor == null;

    final Color foreground;
    final Color labelColor;
    if (useGradient) {
      foreground = Colors.white;
      labelColor = Colors.white.withValues(alpha: 0.82);
    } else {
      foreground = alertColor ?? context.colors.onSurface;
      labelColor = context.mutedColor;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color: useGradient ? null : context.cardColor,
        gradient: useGradient
            ? LinearGradient(
                colors: palette.brandGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: alertColor ?? (useGradient ? Colors.transparent : context.borderColor),
          width: alertColor != null ? 1.5 : 1,
        ),
        boxShadow: useGradient
            ? [
                BoxShadow(
                  color: palette.brandGradient.first.withValues(alpha: 0.28),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!useGradient) ...[
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: alertColor ?? accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: labelColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AnimatedAmount(
            amount: amount,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}
