import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:plaid_flutter/plaid_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../models/app_transaction.dart';
import '../models/household.dart';
import '../theme/app_colors.dart';
import '../utils/categories.dart';
import '../utils/formatters.dart';
import '../utils/locale_controller.dart';
import '../widgets/balance_card.dart';
import '../widgets/horizon_logo.dart';
import '../widgets/household_loader.dart';
import 'bilan_screen.dart';
import 'budget_setup_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  StreamSubscription<LinkSuccess>? _successSubscription;
  StreamSubscription<LinkEvent>? _eventSubscription;
  StreamSubscription<LinkExit>? _exitSubscription;

  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();

    _successSubscription = PlaidLink.onSuccess.listen((event) async {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_l10n.syncingTransactions)),
      );

      try {
        final callable = FirebaseFunctions.instance.httpsCallable(
          'exchangePublicToken',
        );
        await callable.call({'public_token': event.publicToken});

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_l10n.bankConnected)),
        );
      } on FirebaseFunctionsException catch (e) {
        debugPrint("Erreur d'échange de token: ${e.code} ${e.message}");
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? _l10n.syncError)),
        );
      } catch (e) {
        debugPrint("Erreur d'échange de token: $e");
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_l10n.syncError)),
        );
      }
    });

    _eventSubscription = PlaidLink.onEvent.listen((event) {
      debugPrint('Plaid Event: ${event.name}');
    });

    _exitSubscription = PlaidLink.onExit.listen((event) {
      debugPrint('Plaid Exit: ${event.error?.message ?? 'User cancelled'}');
    });

    if (kIsWeb) _resumePlaidOAuth();
  }

  @override
  void dispose() {
    _successSubscription?.cancel();
    _eventSubscription?.cancel();
    _exitSubscription?.cancel();
    super.dispose();
  }

  /// Plateforme transmise au serveur : Plaid revient vers une URL sur le Web
  /// et iOS, mais vers un nom de paquet sur Android.
  static String get _plaidPlatform {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform == TargetPlatform.android ? 'android' : 'ios';
  }

  /// Clé du jeton mis de côté le temps d'un aller-retour OAuth sur le Web.
  static const _linkTokenKey = 'plaid_pending_link_token';

  /// Reprend une connexion bancaire interrompue par une authentification
  /// OAuth (Web uniquement).
  ///
  /// Les institutions canadiennes authentifient chez elles puis rechargent
  /// l'app à l'URL de redirection avec un paramètre `oauth_state_id`. Plaid
  /// exige alors de rouvrir Link avec le **même** jeton et l'URL reçue —
  /// d'où la mise de côté du jeton avant l'ouverture.
  Future<void> _resumePlaidOAuth() async {
    final url = Uri.base;
    if (!url.queryParameters.containsKey('oauth_state_id')) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_linkTokenKey);
    // Consommé dans tous les cas : un jeton périmé ne doit pas rouvrir Link
    // au prochain démarrage.
    await prefs.remove(_linkTokenKey);
    if (token == null) return;

    PlaidLink.create(
      configuration: LinkTokenConfiguration(
        token: token,
        receivedRedirectUri: url.toString(),
      ),
    );
    PlaidLink.open();
  }

  Future<void> _openPlaid() async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'generatePlaidLinkToken',
      );
      // Plaid Link s'affiche dans la langue active de l'app.
      final result = await callable.call({
        'language': LocaleController.instance.effectiveLanguageCode,
        'platform': _plaidPlatform,
      });
      final linkToken = result.data['link_token'] as String;

      if (kIsWeb) {
        // Survit au rechargement de page provoqué par l'OAuth.
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_linkTokenKey, linkToken);
      }

      final linkTokenConfiguration = LinkTokenConfiguration(token: linkToken);

      PlaidLink.create(configuration: linkTokenConfiguration);
      PlaidLink.open();
    } catch (e) {
      debugPrint('Erreur Plaid: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_l10n.plaidError)),
      );
    }
  }

  void _assignTransaction(
    AppTransaction transaction,
    String bucket,
    Household household,
  ) {
    final docRef = FirebaseFirestore.instance
        .collection('transactions')
        .doc(transaction.id);

    docRef.update({'assigned_to_bucket': bucket}).catchError((e) {
      debugPrint("Erreur d'assignation: $e");
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_l10n.assignedTo(household.bucketLabel(bucket, _l10n))),
        action: SnackBarAction(
          label: _l10n.undoAction,
          onPressed: () {
            // La Cloud Function annule l'effet sur les cagnottes.
            docRef.update({'assigned_to_bucket': ''}).catchError((e) {
              debugPrint("Erreur d'annulation: $e");
            });
          },
        ),
      ),
    );
  }

  /// Avertit AVANT d'assigner si la dépense ferait passer la cagnotte
  /// dans le négatif. Retourne true si l'utilisateur confirme.
  Future<bool> _confirmIfGoesNegative(
    AppTransaction transaction,
    String bucket,
    Household household,
  ) async {
    final after = household.bucketBalance(bucket) - transaction.amount;
    if (after >= 0) return true;
    final l10n = _l10n;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: context.palette.warning),
            const SizedBox(width: 8),
            Expanded(child: Text(l10n.negativeWarningTitle)),
          ],
        ),
        content: Text(
          l10n.negativeWarningBody(
            transaction.merchantName,
            formatCurrency(transaction.amount),
            household.bucketLabel(bucket, l10n),
            formatCurrency(after),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: context.palette.warning),
            child: Text(l10n.assignAnyway),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _settleDebt(Household household) async {
    final l10n = _l10n;
    final debt = household.internalDebtBalance;
    final debtor = debt > 0 ? household.nameB : household.nameA;
    final creditor = debt > 0 ? household.nameA : household.nameB;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.settleDebtTitle),
        content: Text(
          l10n.settleDebtBody(debtor, formatCurrency(debt.abs()), creditor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.confirmSettlement),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('settleDebt');
      final result = await callable.call();
      final amount = (result.data['amount_settled'] as num?)?.toDouble() ?? 0;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_l10n.debtSettled(formatCurrency(amount)))),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? _l10n.settleError)),
      );
    } catch (e) {
      debugPrint('Erreur settleDebt: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_l10n.settleError)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const HorizonLogo(size: 26),
            const SizedBox(width: 9),
            Text(
              'Horizon',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: context.colors.onSurface,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.insights),
            tooltip: l10n.bilanTooltip,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BilanScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: l10n.historyTooltip,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HistoryScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: l10n.budgetConfigTooltip,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BudgetSetupScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: l10n.settingsTooltip,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: HouseholdLoader(
        builder: (context, household, uid) {
          return Column(
            children: [
              _buildBucketsOverview(household, uid),
              _buildAlertBanner(household, uid),
              // En solo : ni invitation, ni dette interne — il n'y a
              // personne à inviter ni avec qui s'équilibrer.
              if (!household.isSolo) ...[
                if (household.awaitingPartner && household.joinCode != null)
                  _buildInviteCard(household.joinCode!),
                _buildDebtBanner(household),
              ],
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.transactionsToNeutralize,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _buildTransactionSwipeList(household, uid),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBucketsOverview(Household household, String uid) {
    final l10n = _l10n;
    final isA = household.isUserA(uid);

    // En solo, la cagnotte du partenaire n'existe pas : deux cartes
    // (« Perso » et « Essentiel ») au lieu de trois. On lit la cagnotte du
    // siège réellement occupé — après une séparation, ce n'est pas
    // forcément le siège A.
    if (household.isSolo) {
      final mine = household.mySoloBalance(uid);
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Row(
          children: [
            Expanded(
              child: BalanceCard(
                title: l10n.bucketPersonal,
                amount: mine,
                accent: AppColors.solo,
                alert: household.alertLevel(mine),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: BalanceCard(
                title: l10n.bucketEssential,
                amount: household.safeToSpendCommon,
                accent: AppColors.primary,
                featured: true,
                alert: household.alertLevel(household.safeToSpendCommon),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: BalanceCard(
              title: isA ? l10n.bucketMe(household.nameA) : household.nameA,
              amount: household.safeToSpendSoloA,
              accent: isA ? AppColors.solo : AppColors.partner,
              alert: household.alertLevel(household.safeToSpendSoloA),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: BalanceCard(
              title: l10n.bucketCommon,
              amount: household.safeToSpendCommon,
              accent: AppColors.primary,
              featured: true,
              alert: household.alertLevel(household.safeToSpendCommon),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: BalanceCard(
              title: !isA ? l10n.bucketMe(household.nameB) : household.nameB,
              amount: household.safeToSpendSoloB,
              accent: !isA ? AppColors.solo : AppColors.partner,
              alert: household.alertLevel(household.safeToSpendSoloB),
            ),
          ),
        ],
      ),
    );
  }

  /// Bannière d'avertissement quand une cagnotte est basse ou dans le négatif.
  Widget _buildAlertBanner(Household household, String uid) {
    final worst = household.worstAlertLevel(uid);
    if (worst == 0) return const SizedBox.shrink();

    final isNegative = worst == 2;
    final color = isNegative ? context.palette.danger : context.palette.warning;
    final text = isNegative
        ? _l10n.alertNegativeBanner
        : _l10n.alertLowBanner(formatCurrency(household.alertThreshold));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color),
        ),
        child: Row(
          children: [
            Icon(isNegative ? Icons.error : Icons.warning_amber,
                color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text,
                  style: TextStyle(color: color, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInviteCard(String joinCode) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary),
        ),
        child: Row(
          children: [
            const Icon(Icons.group_add, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _l10n.inviteWithCode,
                style: const TextStyle(fontSize: 13),
              ),
            ),
            SelectableText(
              joinCode,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDebtBanner(Household household) {
    final l10n = _l10n;
    final debt = household.internalDebtBalance;
    final bool isSettled = debt.abs() < 0.01;
    final String text;
    if (isSettled) {
      text = l10n.internalBalanceSettled;
    } else if (debt > 0) {
      text = l10n.internalDebtOwes(
          household.nameB, formatCurrency(debt), household.nameA);
    } else {
      text = l10n.internalDebtOwes(
          household.nameA, formatCurrency(-debt), household.nameB);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.borderColor),
        ),
        child: Row(
          children: [
            Icon(Icons.swap_horiz, color: context.mutedColor, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text, style: TextStyle(color: context.mutedColor)),
            ),
            if (!isSettled)
              TextButton(
                onPressed: () => _settleDebt(household),
                child: Text(
                  l10n.settleButton,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionSwipeList(Household household, String uid) {
    final l10n = _l10n;
    final lang = Localizations.localeOf(context).languageCode;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('transactions')
          .where('household_id', isEqualTo: household.id)
          .where('assigned_to_bucket', isEqualTo: '')
          .orderBy('created_at', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('Erreur transactions: ${snapshot.error}');
          return Center(child: Text(l10n.loadingError));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Opacity(opacity: 0.55, child: const HorizonLogo(size: 88)),
                  const SizedBox(height: 28),
                  Text(
                    l10n.noTransactionsToSort,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.mutedColor,
                      fontSize: 17,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _openPlaid,
                    icon: const Icon(Icons.account_balance),
                    label: Text(l10n.connectMyBank),
                  ),
                ],
              ),
            ),
          );
        }

        final soloBucket = household.soloBucketFor(uid);
        final soloLabel = household.bucketLabel(soloBucket, l10n);

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final transaction = AppTransaction.fromSnapshot(docs[index]);

            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Dismissible(
                key: Key(transaction.id),
                background: _buildSwipeBackground(
                  AppColors.solo,
                  Icons.person,
                  soloLabel,
                  Alignment.centerLeft,
                ),
                secondaryBackground: _buildSwipeBackground(
                  AppColors.primary,
                  // En solo, la cagnotte « Commun » devient « Essentiel » :
                  // une icône de dépenses parle mieux que deux personnes.
                  household.isSolo ? Icons.receipt_long : Icons.people,
                  household.bucketLabel('Common', l10n),
                  Alignment.centerRight,
                ),
                confirmDismiss: (direction) {
                  final bucket = direction == DismissDirection.startToEnd
                      ? soloBucket
                      : 'Common';
                  return _confirmIfGoesNegative(
                    transaction,
                    bucket,
                    household,
                  );
                },
                onDismissed: (direction) {
                  final bucket = direction == DismissDirection.startToEnd
                      ? soloBucket
                      : 'Common';
                  _assignTransaction(transaction, bucket, household);
                },
                child: _buildTransactionCard(transaction, lang),
              ),
            );
          },
        );
      },
    );
  }

  /// Carte d'une transaction à trier : pastille de catégorie, commerçant,
  /// montant. C'est l'objet que l'utilisateur manipule le plus — il porte
  /// donc la hiérarchie typographique la plus marquée de l'app.
  Widget _buildTransactionCard(AppTransaction transaction, String lang) {
    final cat = categoryOf(transaction.category);

    return Container(
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.borderColor),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: cat.color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(cat.icon, size: 21, color: cat.color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  transaction.merchantName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16.5,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  cat.labelFor(lang),
                  style: TextStyle(fontSize: 12.5, color: context.mutedColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '-${formatCurrency(transaction.amount)}',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              letterSpacing: -0.4,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: context.colors.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  /// Fond révélé pendant le glissement, du côté de la cagnotte visée.
  Widget _buildSwipeBackground(
    Color color,
    IconData icon,
    String text,
    Alignment alignment,
  ) {
    final toLeft = alignment == Alignment.centerLeft;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.85), color],
          begin: toLeft ? Alignment.centerLeft : Alignment.centerRight,
          end: toLeft ? Alignment.centerRight : Alignment.centerLeft,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 26),
      alignment: alignment,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 30),
          const SizedBox(height: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
