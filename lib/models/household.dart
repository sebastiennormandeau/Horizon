import 'package:cloud_firestore/cloud_firestore.dart';

/// Représentation typée d'un document `households/{id}`.
class Household {
  final String id;
  final String? userAId;
  final String? userBId;
  final String? userAName;
  final String? userBName;
  final double safeToSpendCommon;
  final double safeToSpendSoloA;
  final double safeToSpendSoloB;
  final double internalDebtBalance;
  final int splitRatioUserA;
  final int splitRatioUserB;
  final String? joinCode;
  final String subscriptionTier;

  const Household({
    required this.id,
    required this.userAId,
    required this.userBId,
    required this.userAName,
    required this.userBName,
    required this.safeToSpendCommon,
    required this.safeToSpendSoloA,
    required this.safeToSpendSoloB,
    required this.internalDebtBalance,
    required this.splitRatioUserA,
    required this.splitRatioUserB,
    required this.joinCode,
    required this.subscriptionTier,
  });

  factory Household.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>? ?? {};
    double numOf(String key) => (data[key] as num?)?.toDouble() ?? 0.0;

    return Household(
      id: snapshot.id,
      // Rétrocompatibilité : les anciens foyers n'ont pas user_A_id.
      userAId: (data['user_A_id'] ?? data['created_by']) as String?,
      userBId: data['user_B_id'] as String?,
      userAName: data['user_A_name'] as String?,
      userBName: data['user_B_name'] as String?,
      safeToSpendCommon: numOf('safe_to_spend_common'),
      safeToSpendSoloA: numOf('safe_to_spend_solo_A'),
      safeToSpendSoloB: numOf('safe_to_spend_solo_B'),
      internalDebtBalance: numOf('internal_debt_balance'),
      splitRatioUserA: (data['split_ratio_user_A'] as num?)?.toInt() ?? 50,
      splitRatioUserB: (data['split_ratio_user_B'] as num?)?.toInt() ?? 50,
      joinCode: data['join_code'] as String?,
      subscriptionTier: (data['subscription_tier'] as String?) ?? 'free',
    );
  }

  bool isUserA(String uid) => uid == userAId;

  bool get isPremium => subscriptionTier == 'premium';

  /// Bucket "Solo" de l'utilisateur connecté.
  String soloBucketFor(String uid) => isUserA(uid) ? 'Solo_A' : 'Solo_B';

  /// Prénom du membre A (repli sur « A »).
  String get nameA =>
      (userAName?.trim().isNotEmpty ?? false) ? userAName!.trim() : 'A';

  /// Prénom du membre B (repli sur « B »).
  String get nameB =>
      (userBName?.trim().isNotEmpty ?? false) ? userBName!.trim() : 'B';

  /// Libellé d'un bucket pour affichage.
  String bucketLabel(String bucket) {
    switch (bucket) {
      case 'Solo_A':
        return 'Solo $nameA';
      case 'Solo_B':
        return 'Solo $nameB';
      case 'Common':
        return 'Commun';
      default:
        return 'À trier';
    }
  }

  /// Le foyer attend encore son second membre.
  bool get awaitingPartner => userBId == null;
}
