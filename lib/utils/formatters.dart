/// Utilitaires de formatage/saisie de montants (fr-CA et en-CA), sans
/// dépendance au package intl.
library;

/// Espace insécable (U+00A0) utilisée comme séparateur de milliers (fr-CA).
const String _nbsp = ' ';

/// Langue courante du formatage monétaire ('fr' ou 'en'). Mise à jour par
/// [LocaleController] quand l'utilisateur change la langue de l'app ;
/// 'fr' par défaut pour préserver le comportement historique (et les tests).
String currencyLanguageCode = 'fr';

/// Formate un montant en dollars canadiens selon la langue active :
/// fr : `1234.5` -> `1 234,50 $` — en : `1234.5` -> `$1,234.50`.
String formatCurrency(num amount, {String? languageCode}) {
  final lang = languageCode ?? currencyLanguageCode;
  final negative = amount < 0;
  final parts = amount.abs().toStringAsFixed(2).split('.');
  final intPart = parts[0];

  final thousandsSep = lang == 'en' ? ',' : _nbsp;
  final buffer = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    buffer.write(intPart[i]);
    final remaining = intPart.length - 1 - i;
    if (remaining > 0 && remaining % 3 == 0) buffer.write(thousandsSep);
  }

  if (lang == 'en') {
    return '${negative ? '-' : ''}\$$buffer.${parts[1]}';
  }
  return '${negative ? '-' : ''}$buffer,${parts[1]}$_nbsp\$';
}

/// Analyse une saisie utilisateur dans les deux conventions :
/// `"1 234,56"` (fr) -> `1234.56` et `"1,234.56"` (en) -> `1234.56`.
/// Quand les deux séparateurs sont présents, le dernier est la décimale.
double parseAmount(String input) {
  var cleaned = input.replaceAll(RegExp(r'[\s $]'), '');

  final lastComma = cleaned.lastIndexOf(',');
  final lastDot = cleaned.lastIndexOf('.');
  if (lastComma >= 0 && lastDot >= 0) {
    if (lastComma > lastDot) {
      // "1.234,56" : le point sépare les milliers.
      cleaned = cleaned.replaceAll('.', '').replaceAll(',', '.');
    } else {
      // "1,234.56" : la virgule sépare les milliers.
      cleaned = cleaned.replaceAll(',', '');
    }
  } else {
    cleaned = cleaned.replaceAll(',', '.');
  }

  return double.tryParse(cleaned) ?? 0.0;
}
