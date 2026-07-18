import 'package:flutter_test/flutter_test.dart';
import 'package:horizon/utils/budget_calculator.dart';
import 'package:horizon/utils/formatters.dart';

const nbsp = ' ';

void main() {
  group('BudgetCalculator.calculateMagicMonths', () {
    test('fréquence mensuelle : aucun mois magique', () {
      final result = BudgetCalculator.calculateMagicMonths(
        'Mensuel',
        DateTime(2026, 7, 17),
      );
      expect(result, isEmpty);
    });

    test('bi-hebdomadaire en 2026 (paie le 17 juillet) : janvier et juillet',
        () {
      // Paies aux 14 jours à partir du vendredi 2 janvier 2026 :
      // janvier (2, 16, 30) et juillet (3, 17, 31) comptent 3 paies.
      final result = BudgetCalculator.calculateMagicMonths(
        'Bi-hebdomadaire',
        DateTime(2026, 7, 17),
      );
      expect(result, [1, 7]);
    });

    test('hebdomadaire en 2026 (paie le 17 juillet) : mois à 5 paies', () {
      // Paies chaque vendredi à partir du 2 janvier 2026 :
      // janvier, mai, juillet et octobre comptent 5 vendredis de paie.
      final result = BudgetCalculator.calculateMagicMonths(
        'Hebdomadaire',
        DateTime(2026, 7, 17),
      );
      expect(result, [1, 5, 7, 10]);
    });

    test('fréquence inconnue : aucun mois magique et pas de boucle infinie',
        () {
      final result = BudgetCalculator.calculateMagicMonths(
        'Quotidien',
        DateTime(2026, 7, 17),
      );
      expect(result, isEmpty);
    });
  });

  group('formatters', () {
    test('formatCurrency : style fr-CA avec espaces insécables', () {
      expect(formatCurrency(1234.5), '1${nbsp}234,50$nbsp\$');
      expect(formatCurrency(0), '0,00$nbsp\$');
      expect(formatCurrency(-42.5), '-42,50$nbsp\$');
      expect(
        formatCurrency(1000000),
        '1${nbsp}000${nbsp}000,00$nbsp\$',
      );
    });

    test('parseAmount : virgule décimale et séparateurs de milliers', () {
      expect(parseAmount('1${nbsp}234,56'), 1234.56);
      expect(parseAmount('1 234,56'), 1234.56);
      expect(parseAmount('12.5'), 12.5);
      expect(parseAmount('250'), 250.0);
      expect(parseAmount(''), 0.0);
      expect(parseAmount('abc'), 0.0);
    });

    test('formatCurrency : style en-CA quand la langue est en', () {
      expect(formatCurrency(1234.5, languageCode: 'en'), r'$1,234.50');
      expect(formatCurrency(0, languageCode: 'en'), r'$0.00');
      expect(formatCurrency(-42.5, languageCode: 'en'), r'-$42.50');
      expect(
        formatCurrency(1000000, languageCode: 'en'),
        r'$1,000,000.00',
      );
    });

    test('parseAmount : accepte aussi la convention anglaise', () {
      // "1,234.56" : la virgule est un séparateur de milliers.
      expect(parseAmount('1,234.56'), 1234.56);
      expect(parseAmount(r'$1,234.56'), 1234.56);
      // "1.234,56" : le point est un séparateur de milliers.
      expect(parseAmount('1.234,56'), 1234.56);
    });
  });
}
