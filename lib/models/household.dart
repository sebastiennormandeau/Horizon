import 'package:cloud_firestore/cloud_firestore.dart';

/// Représentation typée d'un document `households/{id}`.
class Household {
  final String id;
  final String? userAId;
  final String? userBId;
  final double safeToSpendCommon;
  final double safeToSpendSoloA;
  final double safeToSpendSoloB;
  final double internalDebtBalance;
  final int splitRatioUserA;
  final int splitRatioUserB;
  final String? joinCode;

  const Household({
    required this.id,
    required this.userAId,
    required this.userBId,
    required this.safeToSpendCommon,
    required this.safeToSpendSoloA,
    required this.safeToSpendSoloB,
    required this.internalDebtBalance,
    required this.splitRatioUserA,
    required this.splitRatioUserB,
    required this.joinCode,
  });

  factory Household.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>? ?? {};
    double numOf(String key) => (data[key] as num?)?.toDouble() ?? 0.0;

    return Household(
      id: snapshot.id,
      userAId: data['user_A_id'] as String?,
      userBId: data['user_B_id'] as String?,
      safeToSpendCommon: numOf('safe_to_spend_common'),
      safeToSpendSoloA: numOf('safe_to_spend_solo_A'),
      safeToSpendSoloB: numOf('safe_to_spend_solo_B'),
      internalDebtBalance: numOf('internal_debt_balance'),
      splitRatioUserA: (data['split_ratio_user_A'] as num?)?.toInt() ?? 50,
      splitRatioUserB: (data['split_ratio_user_B'] as num?)?.toInt() ?? 50,
      joinCode: data['join_code'] as String?,
    );
  }

  bool isUserA(String uid) => uid == userAId;

  /// Bucket "Solo" de l'utilisateur connecté.
  String soloBucketFor(String uid) => isUserA(uid) ? 'Solo_A' : 'Solo_B';

  /// Le foyer attend encore son second membre.
  bool get awaitingPartner => userBId == null;
}
