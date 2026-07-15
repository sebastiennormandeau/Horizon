/// Utilitaires de formatage/saisie de montants (style fr-CA), sans dépendance.
library;

/// Espace insécable utilisée comme séparateur de milliers.
const String _nbsp = ' ';

/// Formate un montant en dollars canadiens : `1234.5` -> `1 234,50 $`.
String formatCurrency(num amount) {
  final negative = amount < 0;
  final parts = amount.abs().toStringAsFixed(2).split('.');
  final intPart = parts[0];

  final buffer = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    buffer.write(intPart[i]);
    final remaining = intPart.length - 1 - i;
    if (remaining > 0 && remaining % 3 == 0) buffer.write(_nbsp);
  }

  return '${negative ? '-' : ''}$buffer,${parts[1]}$_nbsp\$';
}

/// Analyse une saisie utilisateur en acceptant la virgule décimale
/// et les espaces de milliers : `"1 234,56"` -> `1234.56`.
double parseAmount(String input) {
  final cleaned = input
      .replaceAll(RegExp(r'[\s $]'), '')
      .replaceAll(',', '.');
  return double.tryParse(cleaned) ?? 0.0;
}
