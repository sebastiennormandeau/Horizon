import 'package:flutter/material.dart';

/// Référentiel des catégories de dépenses (clés `personal_finance_category`
/// de Plaid), avec libellés français/anglais, icônes et couleurs.
class TxCategory {
  final String key;

  /// Libellé français (langue par défaut de l'app).
  final String label;

  /// Libellé anglais.
  final String labelEn;

  final IconData icon;
  final Color color;

  const TxCategory(this.key, this.label, this.labelEn, this.icon, this.color);

  /// Libellé selon la langue active ('fr' ou 'en').
  String labelFor(String languageCode) =>
      languageCode == 'en' ? labelEn : label;
}

const List<TxCategory> kCategories = [
  TxCategory('FOOD_AND_DRINK', 'Restauration & alcool', 'Food & drink',
      Icons.restaurant, Color(0xFFEF6C57)),
  TxCategory('GENERAL_MERCHANDISE', 'Magasinage', 'Shopping',
      Icons.shopping_bag, Color(0xFFB07BDC)),
  TxCategory('TRANSPORTATION', 'Transport', 'Transportation',
      Icons.directions_car, Color(0xFF4FA3E3)),
  TxCategory('RENT_AND_UTILITIES', 'Logement & services', 'Rent & utilities',
      Icons.home, Color(0xFF58B99A)),
  TxCategory('ENTERTAINMENT', 'Divertissement', 'Entertainment', Icons.movie,
      Color(0xFFE3A64F)),
  TxCategory('TRAVEL', 'Voyages', 'Travel', Icons.flight, Color(0xFF5FC7CE)),
  TxCategory('MEDICAL', 'Santé', 'Health', Icons.medical_services,
      Color(0xFFE05C7A)),
  TxCategory('PERSONAL_CARE', 'Soins personnels', 'Personal care', Icons.spa,
      Color(0xFFDB8BC0)),
  TxCategory('GENERAL_SERVICES', 'Services', 'Services', Icons.build,
      Color(0xFF9AA6B2)),
  TxCategory('HOME_IMPROVEMENT', 'Rénovation & maison', 'Home improvement',
      Icons.handyman, Color(0xFFB08968)),
  TxCategory('LOAN_PAYMENTS', 'Remboursements de prêts', 'Loan payments',
      Icons.account_balance, Color(0xFF7D8CC4)),
  TxCategory('BANK_FEES', 'Frais bancaires', 'Bank fees', Icons.receipt_long,
      Color(0xFFC46A6A)),
  TxCategory('GOVERNMENT_AND_NON_PROFIT', 'Gouvernement & dons',
      'Government & donations', Icons.account_balance_outlined,
      Color(0xFF8FA37E)),
  TxCategory('TRANSFER_OUT', 'Virements sortants', 'Outgoing transfers',
      Icons.north_east, Color(0xFF8899AA)),
  TxCategory('TRANSFER_IN', 'Virements entrants', 'Incoming transfers',
      Icons.south_west, Color(0xFF6FBF8F)),
  TxCategory('INCOME', 'Revenus', 'Income', Icons.payments, Color(0xFF6FBF8F)),
  TxCategory('OTHER', 'Autre', 'Other', Icons.category, Color(0xFF9E9E9E)),
];

const TxCategory kOtherCategory =
    TxCategory('OTHER', 'Autre', 'Other', Icons.category, Color(0xFF9E9E9E));

final Map<String, TxCategory> _byKey = {
  for (final c in kCategories) c.key: c,
};

/// Retourne la catégorie correspondant à la clé, avec repli sur « Autre ».
TxCategory categoryOf(String? key) => _byKey[key] ?? kOtherCategory;

/// Catégories proposées pour la correction manuelle (sans les entrées d'argent).
List<TxCategory> get kSelectableCategories => kCategories
    .where((c) => c.key != 'INCOME' && c.key != 'TRANSFER_IN')
    .toList();
