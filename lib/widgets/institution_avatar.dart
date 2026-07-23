import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Pastille d'une institution : son logo si Plaid en fournit un, sinon une
/// initiale sur sa couleur de marque, sinon une icône de banque générique.
///
/// Le logo arrive en data URI (`data:image/png;base64,...`) depuis le foyer.
/// Le décodage est mis en cache par data URI : `Image.memory` reconstruirait
/// sinon les octets à chaque rebuild d'une liste défilante.
class InstitutionAvatar extends StatelessWidget {
  final String? name;
  final String? logoDataUri;
  final String? colorHex;
  final double size;

  const InstitutionAvatar({
    super.key,
    required this.name,
    this.logoDataUri,
    this.colorHex,
    this.size = 42,
  });

  static final Map<String, Uint8List?> _cache = {};

  Uint8List? get _bytes {
    final uri = logoDataUri;
    if (uri == null) return null;
    return _cache.putIfAbsent(uri, () {
      final comma = uri.indexOf(',');
      if (comma < 0) return null;
      try {
        return base64Decode(uri.substring(comma + 1));
      } catch (_) {
        return null;
      }
    });
  }

  Color? get _brandColor {
    final hex = colorHex?.replaceFirst('#', '');
    if (hex == null || hex.length != 6) return null;
    final v = int.tryParse(hex, radix: 16);
    return v == null ? null : Color(0xFF000000 | v);
  }

  @override
  Widget build(BuildContext context) {
    final radius = size * 0.29;
    final bytes = _bytes;

    if (bytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (context, _, _) => _fallback(context),
        ),
      );
    }
    return _fallback(context);
  }

  Widget _fallback(BuildContext context) {
    final radius = size * 0.29;
    final base = _brandColor ?? AppColors.primary;
    final initial = (name ?? '').trim().isNotEmpty
        ? (name ?? '').trim()[0].toUpperCase()
        : null;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: initial != null
          ? Text(
              initial,
              style: TextStyle(
                fontSize: size * 0.42,
                fontWeight: FontWeight.w700,
                color: base,
              ),
            )
          : Icon(Icons.account_balance, size: size * 0.5, color: base),
    );
  }
}
