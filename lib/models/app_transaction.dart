import 'package:cloud_firestore/cloud_firestore.dart';

/// Représentation typée d'un document `transactions/{id}`.
class AppTransaction {
  final String id;
  final double amount;
  final String merchantName;
  final String assignedToBucket;
  final String? paidByUserId;
  final DateTime? createdAt;
  final String? date;
  final String category;

  /// Institution d'origine, copiée sur la transaction à l'import : les règles
  /// interdisent au client de lire `bank_connections`, qui contient les
  /// jetons d'accès.
  final String? institutionName;

  const AppTransaction({
    required this.id,
    required this.amount,
    required this.merchantName,
    required this.assignedToBucket,
    required this.paidByUserId,
    required this.createdAt,
    required this.date,
    required this.category,
    required this.institutionName,
  });

  /// Date lisible `JJ/MM`, sans dépendance à intl — l'app formate déjà ses
  /// montants à la main pour la même raison.
  String? get shortDate {
    final parts = date?.split('-');
    if (parts == null || parts.length != 3) return null;
    return '${parts[2]}/${parts[1]}';
  }

  /// La transaction appartient-elle à un mois déjà clos ?
  ///
  /// Les cagnottes sont re-provisionnées le 1er de chaque mois : trier une
  /// dépense d'un mois révolu ne les touche donc plus (garde-fou côté
  /// `onTransactionAssigned`). Elle compte toujours dans le bilan de SON mois.
  bool get isPastMonth {
    final d = date;
    if (d == null || d.length < 7) return false;
    final now = DateTime.now();
    final monthStart =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
    return d.compareTo(monthStart) < 0;
  }

  factory AppTransaction.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>? ?? {};
    return AppTransaction(
      id: snapshot.id,
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      merchantName: (data['merchant_name'] as String?) ?? 'Inconnu',
      assignedToBucket: (data['assigned_to_bucket'] as String?) ?? '',
      paidByUserId: data['paid_by_user_id'] as String?,
      createdAt: (data['created_at'] as Timestamp?)?.toDate(),
      date: data['date'] as String?,
      category: (data['category'] as String?) ?? 'OTHER',
      institutionName: data['institution_name'] as String?,
    );
  }
}
