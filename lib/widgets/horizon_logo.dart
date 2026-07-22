import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Marque d'Horizon : un soleil levant coupé par la ligne d'horizon.
///
/// Dessinée plutôt qu'importée en image : elle suit le dégradé de marque du
/// thème actif, reste nette à toute taille et n'ajoute aucun actif binaire.
class HorizonLogo extends StatelessWidget {
  final double size;

  /// Affiche le nom sous la marque.
  final bool showWordmark;

  const HorizonLogo({super.key, this.size = 72, this.showWordmark = false});

  @override
  Widget build(BuildContext context) {
    final gradient = context.palette.brandGradient;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _HorizonPainter(
              gradient: gradient,
              lineColor: context.colors.onSurface,
            ),
          ),
        ),
        if (showWordmark) ...[
          SizedBox(height: size * 0.22),
          Text(
            'Horizon',
            style: TextStyle(
              fontSize: size * 0.34,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              color: context.colors.onSurface,
            ),
          ),
        ],
      ],
    );
  }
}

class _HorizonPainter extends CustomPainter {
  final List<Color> gradient;
  final Color lineColor;

  _HorizonPainter({required this.gradient, required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // La ligne d'horizon coupe le soleil aux deux tiers de sa hauteur : le
    // disque paraît se lever plutôt que flotter.
    final horizonY = h * 0.72;
    final center = Offset(w / 2, horizonY);
    final radius = w * 0.34;

    // Disque, tronqué par la ligne d'horizon.
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, 0, w, horizonY));
    final sunRect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(sunRect),
    );
    canvas.restore();

    // Halo : un arc plus large, en retrait, qui donne de la profondeur.
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 1.52),
      math.pi,
      math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.045
        ..strokeCap = StrokeCap.round
        ..color = gradient.first.withValues(alpha: 0.28),
    );

    // Ligne d'horizon : pleine au centre, estompée aux extrémités.
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.05
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        colors: [
          lineColor.withValues(alpha: 0.0),
          lineColor.withValues(alpha: 0.85),
          lineColor.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, horizonY, w, 1));
    canvas.drawLine(
      Offset(w * 0.06, horizonY),
      Offset(w * 0.94, horizonY),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(_HorizonPainter oldDelegate) =>
      oldDelegate.gradient != gradient || oldDelegate.lineColor != lineColor;
}
