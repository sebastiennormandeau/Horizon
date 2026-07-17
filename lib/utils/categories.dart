import 'package:flutter/material.dart';

/// Référentiel des catégories de dépenses (clés `personal_finance_category`
/// de Plaid), avec libellés français, icônes et couleurs.
class TxCategory {
  final String key;
  final String label;
  final IconData icon;
  final Color color;

  const TxCategory(this.key, this.label, this.icon, this.color);
}

const List<TxCategory> kCategories = [
  TxCategory('FOOD_AND_DRINK', 'Restauration & alcool', Icons.restaurant,
      Color(0xFFEF6C57)),
  TxCategory('GENERAL_MERCHANDISE', 'Magasinage', Icons.shopping_bag,
      Color(0xFFB07BDC)),
  TxCategory('TRANSPORTATION', 'Transport', Icons.directions_car,
      Color(0xFF4FA3E3)),
  TxCategory('RENT_AND_UTILITIES', 'Logement & services', Icons.home,
      Color(0xFF58B99A)),
  TxCategory('ENTERTAINMENT', 'Divertissement', Icons.movie,
      Color(0xFFE3A64F)),
  TxCategory('TRAVEL', 'Voyages', Icons.flight, Color(0xFF5FC7CE)),
  TxCategory('MEDICAL', 'Santé', Icons.medical_services, Color(0xFFE05C7A)),
  TxCategory('PERSONAL_CARE', 'Soins personnels', Icons.spa,
      Color(0xFFDB8BC0)),
  TxCategory('GENERAL_SERVICES', 'Services', Icons.build, Color(0xFF9AA6B2)),
  TxCategory('HOME_IMPROVEMENT', 'Rénovation & maison', Icons.handyman,
      Color(0xFFB08968)),
  TxCategory('LOAN_PAYMENTS', 'Remboursements de prêts', Icons.account_balance,
      Color(0xFF7D8CC4)),
  TxCategory('BANK_FEES', 'Frais bancaires', Icons.receipt_long,
      Color(0xFFC46A6A)),
  TxCategory('GOVERNMENT_AND_NON_PROFIT', 'Gouvernement & dons',
      Icons.account_balance_outlined, Color(0xFF8FA37E)),
  TxCategory('TRANSFER_OUT', 'Virements sortants', Icons.north_east,
      Color(0xFF8899AA)),
  TxCategory('TRANSFER_IN', 'Virements entrants', Icons.south_west,
      Color(0xFF6FBF8F)),
  TxCategory('INCOME', 'Revenus', Icons.payments, Color(0xFF6FBF8F)),
  TxCategory('OTHER', 'Autre', Icons.category, Color(0xFF9E9E9E)),
];

const TxCategory kOtherCategory =
    TxCategory('OTHER', 'Autre', Icons.category, Color(0xFF9E9E9E));

final Map<String, TxCategory> _byKey = {
  for (final c in kCategories) c.key: c,
};

/// Retourne la catégorie correspondant à la clé, avec repli sur « Autre ».
TxCategory categoryOf(String? key) => _byKey[key] ?? kOtherCategory;

/// Catégories proposées pour la correction manuelle (sans les entrées d'argent).
List<TxCategory> get kSelectableCategories => kCategories
    .where((c) => c.key != 'INCOME' && c.key != 'TRANSFER_IN')
    .toList();
