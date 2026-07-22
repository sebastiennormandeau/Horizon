import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/categories.dart';
import '../utils/formatters.dart';

/// Anneau de répartition des dépenses par catégorie.
///
/// Complète les barres de [_buildCategoryBars] : les barres comparent chaque
/// catégorie à la période précédente, l'anneau montre d'un coup d'œil le
/// poids relatif de chacune dans le total.
///
/// Les couleurs viennent du référentiel de catégories
/// (`lib/utils/categories.dart`) pour rester cohérentes avec le reste de
/// l'app. Les parts sous 3 % sont regroupées : en dessous, l'arc devient
/// illisible et le libellé se chevauche.
class CategoryDonut extends StatelessWidget {
  final Map<String, dynamic> byCategory;
  final String languageCode;

  /// Libellé de la tranche « Autres ».
  final String otherLabel;

  const CategoryDonut({
    super.key,
    required this.byCategory,
    required this.languageCode,
    required this.otherLabel,
  });

  @override
  Widget build(BuildContext context) {
    final entries = <_Slice>[];
    double total = 0;

    for (final e in byCategory.entries) {
      final value = (e.value as num?)?.toDouble() ?? 0;
      if (value > 0) total += value;
    }
    if (total <= 0) return const SizedBox.shrink();

    double grouped = 0;
    for (final e in byCategory.entries) {
      final value = (e.value as num?)?.toDouble() ?? 0;
      if (value <= 0) continue;
      if (value / total < 0.03) {
        grouped += value;
        continue;
      }
      final cat = categoryOf(e.key);
      entries.add(_Slice(cat.labelFor(languageCode), value, cat.color));
    }
    entries.sort((a, b) => b.value.compareTo(a.value));
    if (grouped > 0) {
      entries.add(_Slice(otherLabel, grouped, context.mutedColor));
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 132,
          height: 132,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 750),
            curve: Curves.easeOutCubic,
            builder: (context, progress, _) => CustomPaint(
              painter: _DonutPainter(
                slices: entries,
                total: total,
                progress: progress,
                trackColor: context.borderColor,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formatCurrency(total * progress),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                        color: context.colors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final slice in entries.take(6))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: slice.color,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          slice.label,
                          style: const TextStyle(fontSize: 12.5),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${(slice.value / total * 100).round()} %',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: context.mutedColor,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Slice {
  final String label;
  final double value;
  final Color color;

  const _Slice(this.label, this.value, this.color);
}

class _DonutPainter extends CustomPainter {
  final List<_Slice> slices;
  final double total;
  final double progress;
  final Color trackColor;

  _DonutPainter({
    required this.slices,
    required this.total,
    required this.progress,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.17;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: (size.width - stroke) / 2,
    );

    canvas.drawCircle(
      rect.center,
      rect.width / 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = trackColor,
    );

    // Départ à midi plutôt qu'à trois heures : la lecture commence en haut.
    var start = -math.pi / 2;
    // Petit écart entre les arcs pour qu'ils se distinguent sans bordure.
    const gap = 0.02;

    for (final slice in slices) {
      final sweep = (slice.value / total) * 2 * math.pi * progress;
      if (sweep <= gap) continue;
      canvas.drawArc(
        rect,
        start,
        sweep - gap,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.butt
          ..color = slice.color,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.slices != slices ||
      oldDelegate.trackColor != trackColor;
}
