import 'package:cloud_firestore/cloud_firestore.dart';

import '../l10n/app_localizations.dart';

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
  final double alertThreshold;

  /// Nombre de banques reliées au foyer.
  ///
  /// Maintenu par le serveur : les règles interdisent aux clients de lire
  /// `bank_connections`, qui contient les jetons d'accès. Sans ce compteur,
  /// l'accueil ne pourrait pas distinguer « aucune banque connectée » de
  /// « tout est trié » — les deux donnent une liste vide.
  final int bankConnectionsCount;

  /// Logo et couleur de marque de chaque institution reliée, indexés par nom.
  ///
  /// Stocké sur le foyer plutôt que sur chaque transaction : un logo pèse
  /// ~10 Ko et le recopier sur des milliers de documents les alourdirait.
  final Map<String, ({String? logo, String? color})> institutionLogos;

  /// Mode d'utilisation : `solo` (une seule personne) ou `couple`.
  /// Les foyers créés avant l'ajout de cette option n'ont pas le champ et
  /// sont traités comme `couple` (comportement historique).
  final String householdMode;

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
    required this.alertThreshold,
    required this.bankConnectionsCount,
    required this.institutionLogos,
    required this.householdMode,
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
      alertThreshold: (data['alert_threshold'] as num?)?.toDouble() ?? 100.0,
      householdMode: (data['household_mode'] as String?) ?? 'couple',
      bankConnectionsCount:
          (data['bank_connections_count'] as num?)?.toInt() ?? 0,
      institutionLogos: _parseLogos(data['institution_logos']),
    );
  }

  static Map<String, ({String? logo, String? color})> _parseLogos(
    dynamic raw,
  ) {
    if (raw is! Map) return const {};
    final out = <String, ({String? logo, String? color})>{};
    raw.forEach((key, value) {
      if (value is Map) {
        out[key as String] = (
          logo: value['logo'] as String?,
          color: value['color'] as String?,
        );
      }
    });
    return out;
  }

  /// Logo (data URI) et couleur d'une institution, `null` si non fournis.
  ({String? logo, String? color}) institutionBranding(String? name) =>
      (name != null ? institutionLogos[name] : null) ??
      (logo: null, color: null);

  /// Foyer utilisé par une seule personne : pas de seconde cagnotte solo,
  /// pas de dette interne, pas d'invitation.
  ///
  /// On teste les deux sièges plutôt que le seul siège B : après une
  /// séparation, c'est parfois le membre **A** qui part et le membre B qui
  /// reste seul. Promouvoir B en A aurait exigé de réécrire le bucket de
  /// toutes ses transactions (`Solo_B` → `Solo_A`), donc de refaire passer le
  /// grand livre — laisser chacun sur son siège est plus sûr.
  bool get isSolo =>
      householdMode == 'solo' && (userAId == null || userBId == null);

  /// État d'alerte d'une cagnotte : 0 = ok, 1 = sous le seuil, 2 = négatif.
  int alertLevel(double balance) {
    if (balance < 0) return 2;
    if (balance < alertThreshold) return 1;
    return 0;
  }

  /// Solde actuel d'un bucket.
  double bucketBalance(String bucket) {
    switch (bucket) {
      case 'Solo_A':
        return safeToSpendSoloA;
      case 'Solo_B':
        return safeToSpendSoloB;
      case 'Common':
        return safeToSpendCommon;
      default:
        return 0;
    }
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

  /// Libellé d'un bucket pour affichage, dans la langue active.
  ///
  /// En solo, « Commun » n'a pas de sens (commun avec qui ?) : la cagnotte
  /// garde la même valeur stockée (`Common`) mais s'affiche « Essentiel »,
  /// ce qui préserve la logique ZBB dépenses fixes / argent personnel.
  String bucketLabel(String bucket, AppLocalizations l10n) {
    switch (bucket) {
      // En solo les deux cagnottes personnelles portent le même libellé :
      // une seule est alimentée, celle du siège occupé.
      case 'Solo_A':
        return isSolo ? l10n.bucketPersonal : 'Solo $nameA';
      case 'Solo_B':
        return isSolo ? l10n.bucketPersonal : 'Solo $nameB';
      case 'Common':
        return isSolo ? l10n.bucketEssential : l10n.bucketCommon;
      case 'Transfer':
        return l10n.bucketTransfer;
      case 'Archived':
        return l10n.bucketArchived;
      default:
        return l10n.bucketToSort;
    }
  }

  /// Au moins une banque est reliée au foyer.
  bool get hasBankConnection => bankConnectionsCount > 0;

  /// Un siège est libre : le foyer peut accueillir quelqu'un.
  ///
  /// On teste les deux sièges pour la même raison que [isSolo] : après une
  /// séparation, le siège libéré peut être le A comme le B.
  bool get awaitingPartner => userAId == null || userBId == null;

  /// Solde de la cagnotte personnelle de l'utilisateur connecté.
  double mySoloBalance(String uid) => bucketBalance(soloBucketFor(uid));

  /// Cagnottes qui existent réellement pour ce foyer, dans l'ordre
  /// d'affichage. En solo il n'y en a que deux, et la personnelle est celle
  /// du siège occupé — pas forcément `Solo_A`.
  List<String> visibleBuckets(String uid) => isSolo
      ? [soloBucketFor(uid), 'Common']
      : const ['Solo_A', 'Common', 'Solo_B'];

  /// Cagnottes visibles dans l'historique.
  ///
  /// Inclut les mouvements internes (paiement de carte, virement entre ses
  /// comptes) : ils n'entament aucune cagnotte, mais doivent rester visibles
  /// et reclassables — la détection automatique par catégorie Plaid n'est pas
  /// infaillible.
  List<String> historyBuckets(String uid) => [
        ...visibleBuckets(uid),
        'Transfer',
        'Archived',
      ];

  /// Niveau d'alerte le plus grave parmi les cagnottes qui existent vraiment.
  ///
  /// En solo, la cagnotte du siège vide reste à zéro : l'inclure
  /// déclencherait une alerte « sous le seuil » permanente et trompeuse.
  int worstAlertLevel(String uid) {
    final levels = isSolo
        ? [alertLevel(mySoloBalance(uid)), alertLevel(safeToSpendCommon)]
        : [
            alertLevel(safeToSpendSoloA),
            alertLevel(safeToSpendCommon),
            alertLevel(safeToSpendSoloB),
          ];
    return levels.reduce((a, b) => a > b ? a : b);
  }
}
