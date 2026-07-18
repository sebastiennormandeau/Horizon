import 'package:flutter_test/flutter_test.dart';
import 'package:horizon/utils/categories.dart';

void main() {
  group('categoryOf', () {
    test('retourne la catégorie correspondant à la clé Plaid', () {
      expect(categoryOf('FOOD_AND_DRINK').label, 'Restauration & alcool');
      expect(categoryOf('TRANSPORTATION').label, 'Transport');
    });

    test('replie sur « Autre » pour les clés inconnues ou nulles', () {
      expect(categoryOf('CLE_INCONNUE').key, 'OTHER');
      expect(categoryOf(null).key, 'OTHER');
      expect(categoryOf('').key, 'OTHER');
    });

    test('les clés du référentiel sont uniques', () {
      final keys = kCategories.map((c) => c.key).toList();
      expect(keys.toSet().length, keys.length);
    });

    test('les catégories sélectionnables excluent les entrées d\'argent', () {
      final keys = kSelectableCategories.map((c) => c.key);
      expect(keys, isNot(contains('INCOME')));
      expect(keys, isNot(contains('TRANSFER_IN')));
      expect(keys, contains('FOOD_AND_DRINK'));
    });

    test('labelFor retourne le libellé selon la langue', () {
      final cat = categoryOf('FOOD_AND_DRINK');
      expect(cat.labelFor('fr'), 'Restauration & alcool');
      expect(cat.labelFor('en'), 'Food & drink');
      // Toutes les catégories ont un libellé anglais non vide.
      for (final c in kCategories) {
        expect(c.labelEn, isNotEmpty);
      }
    });
  });
}
