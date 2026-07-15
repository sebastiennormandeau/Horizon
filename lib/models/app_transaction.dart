import 'package:cloud_firestore/cloud_firestore.dart';

/// Représentation typée d'un document `transactions/{id}`.
class AppTransaction {
  final String id;
  final double amount;
  final String merchantName;
  final String assignedToBucket;
  final String? paidByUserId;

  const AppTransaction({
    required this.id,
    required this.amount,
    required this.merchantName,
    required this.assignedToBucket,
    required this.paidByUserId,
  });

  factory AppTransaction.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>? ?? {};
    return AppTransaction(
      id: snapshot.id,
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      merchantName: (data['merchant_name'] as String?) ?? 'Inconnu',
      assignedToBucket: (data['assigned_to_bucket'] as String?) ?? '',
      paidByUserId: data['paid_by_user_id'] as String?,
    );
  }
}
