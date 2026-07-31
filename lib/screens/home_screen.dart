import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:plaid_flutter/plaid_flutter.dart';

import '../l10n/app_localizations.dart';
import '../models/app_transaction.dart';
import '../models/household.dart';
import '../theme/app_colors.dart';
import '../utils/categories.dart';
import '../utils/formatters.dart';
import '../services/plaid_service.dart';
import '../widgets/balance_card.dart';
import '../widgets/institution_avatar.dart';
import '../widgets/horizon_logo.dart';
import '../widgets/household_loader.dart';
import 'bank_connections_screen.dart';
import 'bilan_screen.dart';
import 'cash_comparison_screen.dart';
import 'solo_envelopes_screen.dart';
import 'onboarding_screen.dart';
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

  /// Solde réel du compte chèque perso (sous-type « checking », hors conjoint),
  /// affiché sous les cagnottes pour comparaison. `null` = pas encore chargé ou
  /// aucun compte chèque.
  double? _checkingBalance;

  /// Solde réel du compte chèque CONJOINT du foyer, affiché sous la cagnotte
  /// commune. `null` = aucun compte conjoint marqué comme tel.
  double? _jointCheckingBalance;

  /// Connexions à ré-authentifier (ITEM_LOGIN_REQUIRED) signalées par le
  /// serveur : chaque entrée porte `item_id` et `institution_name`.
  List<Map<String, dynamic>> _cashReauth = const [];

  /// Charge les soldes réels via Plaid (callable). Détecte aussi les
  /// connexions à reconnecter.
  ///
  /// Deux soldes distincts, et la séparation est délibérée : le compte chèque
  /// PERSO ne vient que des connexions de l'appelant (le serveur ne renvoie
  /// jamais celles du partenaire), le compte CONJOINT peut venir de l'un ou
  /// l'autre puisqu'il est partagé par définition.
  Future<void> _loadCash() async {
    try {
      final res = await FirebaseFunctions.instance
          .httpsCallable('getMyCashBalances')
          .call();
      final accounts = ((res.data['accounts'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map));
      double sum = 0;
      var hasChecking = false;
      double joint = 0;
      var hasJoint = false;
      for (final a in accounts) {
        if (a['kind'] != 'checking') continue; // ni épargne, ni placement
        if (a['is_joint'] == true) {
          joint += (a['balance'] as num?)?.toDouble() ?? 0;
          hasJoint = true;
        } else {
          sum += (a['balance'] as num?)?.toDouble() ?? 0;
          hasChecking = true;
        }
      }
      // Comptes conjoints reliés par le partenaire : ils complètent le solde
      // commun sans jamais exposer un compte perso.
      final jointAccounts = ((res.data['joint_accounts'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map));
      for (final a in jointAccounts) {
        if (a['kind'] != 'checking') continue;
        joint += (a['balance'] as num?)?.toDouble() ?? 0;
        hasJoint = true;
      }
      final reauth = ((res.data['reauth'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (!mounted) return;
      setState(() {
        _checkingBalance = hasChecking ? sum : null;
        _jointCheckingBalance = hasJoint ? joint : null;
        _cashReauth = reauth;
      });
      _maybePromptReauth();
    } catch (e) {
      debugPrint('Erreur getMyCashBalances: $e');
    }
  }

  /// Une fois par session, invite d'emblée à reconnecter les banques passées
  /// en ITEM_LOGIN_REQUIRED : la banque coupe l'accès après un temps
  /// d'inactivité, et l'utilisateur ne devrait pas avoir à y penser lui-même.
  static bool _reauthPromptShown = false;
  void _maybePromptReauth() {
    if (_reauthPromptShown || _cashReauth.isEmpty || !mounted) return;
    _reauthPromptShown = true;
    final l10n = _l10n;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.bankReauthNeeded),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.bankReauthDialogBody),
            const SizedBox(height: 8),
            ..._cashReauth.map((r) {
              final inst = (r['institution_name'] as String?)?.trim() ?? '';
              return ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading:
                    Icon(Icons.link_off, color: context.palette.warning),
                title: Text(inst.isEmpty ? l10n.bankReauthNeeded : inst),
                trailing: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _reconnect(r['item_id'] as String);
                  },
                  child: Text(l10n.bankReconnect),
                ),
              );
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.later),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadCash();

    _successSubscription = PlaidLink.onSuccess.listen((event) async {
      // Update mode : l'item existe déjà, aucun public_token à échanger — sinon
      // on recréerait/déduplierait une connexion pourtant saine. On relance
      // simplement la synchro et on recharge les soldes.
      final wasUpdate = await PlaidService.consumePendingUpdate();
      if (!mounted) return;
      if (wasUpdate) {
        // Le solde se rafraîchit tout de suite (getMyCashBalances est en
        // direct). La synchro des transactions tourne EN ARRIÈRE-PLAN pour ne
        // pas faire attendre — le webhook la rattrape de toute façon.
        () async {
          try {
            await FirebaseFunctions.instance
                .httpsCallable('syncBankConnections')
                .call();
            if (mounted) await _loadCash();
          } catch (e) {
            debugPrint('Sync après reconnexion: $e');
          }
        }();
        await _loadCash();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_l10n.bankReconnected)),
        );
        return;
      }

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
        await _loadCash();
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
      debugPrint('Plaid Event: ${event.name} — ${event.metadata.description()}');
      // Mémorisé pour l'afficher si la session se termine mal : c'est cet
      // événement qui nomme l'échec (institution indisponible, OAuth refusé),
      // là où l'objet de sortie reste souvent muet.
      final name = event.name.toLowerCase();
      if (name.contains('error') || name.contains('failoauth')) {
        _lastPlaidEvent = '${event.name} — ${event.metadata.description()}';
      }
    });

    _exitSubscription = PlaidLink.onExit.listen((event) {
      // Un update annulé ne doit pas laisser le marqueur fausser le prochain
      // succès (qui sauterait alors l'échange d'une nouvelle connexion).
      PlaidService.consumePendingUpdate();
      debugPrint('Plaid Exit: ${event.error?.message ?? 'User cancelled'}');
      _showPlaidExitDiagnostic(event);
    });

    // Reprise d une connexion interrompue par un OAuth (Web) : c est ici,
    // et nulle part ailleurs, car la page a ete rechargee entre-temps.
    PlaidService.resumeOAuthIfNeeded();

    // Guide de démarrage au premier lancement. Après le premier rendu :
    // l'accueil doit exister derrière, sinon la fermeture du guide laisse
    // un écran vide.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (await OnboardingScreen.shouldShow() && mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const OnboardingScreen(),
            fullscreenDialog: true,
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _successSubscription?.cancel();
    _eventSubscription?.cancel();
    _exitSubscription?.cancel();
    super.dispose();
  }

  /// Dernier événement Plaid en erreur, conservé pour le diagnostic.
  String? _lastPlaidEvent;

  /// Restreint la file de tri au mois courant.
  bool _thisMonthOnly = false;

  bool _archiving = false;

  /// Premier jour du mois courant, au format de Plaid (`AAAA-MM-JJ`).
  static String _startOfMonth() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
  }

  /// Écarte de la file les transactions non triées des mois révolus.
  Future<void> _archivePast() async {
    final l10n = _l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.archivePastTitle),
        content: Text(l10n.archivePastBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.archivePastAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _archiving = true);
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('archivePastTransactions');
      final result = await callable.call();
      final n = (result.data['archived'] as num?)?.toInt() ?? 0;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            n > 0 ? l10n.archivePastDone(n) : l10n.archivePastNothing,
          ),
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? l10n.householdActionError)),
      );
    } catch (e) {
      debugPrint('Erreur archivePastTransactions: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.householdActionError)),
      );
    } finally {
      if (mounted) setState(() => _archiving = false);
    }
  }

  /// Rend visible l'échec d'une session Plaid.
  ///
  /// Sans ça, une sortie en erreur ne laissait qu'une trace dans la console
  /// de débogage : côté utilisateur, la fenêtre se fermait et « rien ne se
  /// passait ». Les codes sont sélectionnables parce qu'ils servent à ouvrir
  /// un billet chez Plaid — `linkSessionId` et `requestId` sont exactement ce
  /// que leur soutien demande.
  void _showPlaidExitDiagnostic(LinkExit event) {
    if (!mounted) return;
    final l10n = _l10n;
    final error = event.error;
    final meta = event.metadata;

    // Abandon volontaire, sans erreur : une simple note suffit.
    if (error == null && _lastPlaidEvent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.plaidExitCancelled(meta.status ?? '—')),
        ),
      );
      return;
    }

    final details = [
      if (error != null) 'code: ${error.code}',
      if (error != null) 'type: ${error.type}',
      if (error != null) 'message: ${error.message}',
      if (error?.displayMessage != null) 'display: ${error!.displayMessage}',
      if (_lastPlaidEvent != null) 'event: $_lastPlaidEvent',
      'status: ${meta.status ?? '—'}',
      'institution: ${meta.institution?.name ?? '—'} (${meta.institution?.id ?? '—'})',
      'linkSessionId: ${meta.linkSessionId ?? '—'}',
      'requestId: ${meta.requestId ?? '—'}',
    ].join('\n');
    _lastPlaidEvent = null;

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.plaidExitTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (error?.displayMessage != null) ...[
                Text(error!.displayMessage!),
                const SizedBox(height: 12),
              ],
              SelectableText(
                details,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.plaidExitHint,
                style: TextStyle(fontSize: 12, color: context.mutedColor),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: details));
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(l10n.copy),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }

  Future<void> _openPlaid() async {
    try {
      await PlaidService.open();
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

    // Une SnackBar par transaction triée s'EMPILE : ScaffoldMessenger les
    // affiche l'une après l'autre (4 s chacune par défaut), si bien qu'un tri
    // rapide de dix transactions masque le bas de l'écran pendant 40 s. On
    // remplace donc la précédente et on raccourcit l'affichage — le temps de
    // lire la cagnotte et d'annuler au besoin, pas plus.
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(_l10n.assignedTo(household.bucketLabel(bucket, _l10n))),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
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

  /// Propose une règle « toujours classer ce marchand » dans une cagnotte,
  /// appliquée aussi aux transactions du même marchand déjà en file.
  Future<void> _showRuleDialog(
    AppTransaction transaction,
    Household household,
    String uid,
  ) async {
    final l10n = _l10n;
    final buckets = [
      ...household.visibleBuckets(uid),
      'Transfer',
      'Archived',
    ];
    final chosen = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.rulePickTitle(transaction.merchantName)),
        children: buckets
            .map(
              (b) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, b),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(household.bucketLabel(b, l10n)),
                ),
              ),
            )
            .toList(),
      ),
    );
    if (chosen == null || !mounted) return;
    await _createRule(transaction.merchantName, chosen);
  }

  Future<void> _createRule(String merchant, String bucket) async {
    final l10n = _l10n;
    try {
      final res = await FirebaseFunctions.instance
          .httpsCallable('setSortRule')
          .call({'merchant': merchant, 'bucket': bucket});
      final n = (res.data['applied'] as num?)?.toInt() ?? 0;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.ruleCreated(merchant, '$n'))),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? l10n.ruleError)),
      );
    } catch (e) {
      debugPrint('Erreur setSortRule: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.ruleError)),
      );
    }
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
              _buildReauthBanners(household),
              _buildAlertBanner(household, uid),
              // En solo : ni invitation, ni dette interne — il n'y a
              // personne à inviter ni avec qui s'équilibrer.
              if (!household.isSolo) ...[
                if (household.awaitingPartner && household.joinCode != null)
                  _buildInviteCard(household.joinCode!),
                _buildDebtBanner(household),
              ],
              _buildSortHeader(),
              Expanded(
                child: _buildTransactionSwipeList(household, uid),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Ouvre la comparaison entre la cagnotte solo et le vrai solde du compte.
  void _openCashComparison(Household household, String uid) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CashComparisonScreen(household: household, uid: uid),
      ),
    );
  }

  /// Ré-authentifie une connexion bancaire (Plaid update mode).
  Future<void> _reconnect(String itemId) async {
    try {
      await PlaidService.open(updateItemId: itemId);
    } catch (e) {
      debugPrint('Reconnexion Plaid: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_l10n.plaidError)),
      );
    }
  }

  /// Bannières « banque à reconnecter ».
  ///
  /// Indépendantes des soldes affichés sous les cagnottes : une banque à
  /// reconnecter (souvent la carte) ne doit pas masquer le solde d'une autre
  /// banque saine.
  Widget _buildReauthBanners(Household household) {
    if (!household.hasBankConnection || _cashReauth.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(children: [for (final r in _cashReauth) _reauthBanner(r)]);
  }

  Widget _reauthBanner(Map<String, dynamic> item) {
    final l10n = _l10n;
    final inst = (item['institution_name'] as String?)?.trim() ?? '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: context.palette.warning.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.palette.warning),
        ),
        child: Row(
          children: [
            Icon(Icons.link_off, color: context.palette.warning, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                inst.isEmpty
                    ? l10n.bankReauthNeeded
                    : l10n.bankReauthNeededNamed(inst),
                style:
                    TextStyle(color: context.palette.warning, fontSize: 12.5),
              ),
            ),
            TextButton(
              onPressed: () => _reconnect(item['item_id'] as String),
              child: Text(l10n.bankReconnect),
            ),
          ],
        ),
      ),
    );
  }

  /// Les cagnottes, chacune surmontant son propre pied de colonne : solde réel
  /// du compte associé, puis Réservé / Libre.
  ///
  /// Une seule requête alimente les trois colonnes (les transactions du mois
  /// du foyer, réparties ensuite par cagnotte) plutôt qu'un flux par cagnotte.
  Widget _buildBucketsOverview(Household household, String uid) {
    final monthStart = _startOfMonth();
    return StreamBuilder<QuerySnapshot>(
      // `orderBy` explicite : sans lui, Firestore trierait par `date`
      // ASCENDANT et réclamerait un index qui n'existe pas. Descendant, la
      // requête s'appuie sur l'index (household_id, date DESC) déjà déployé.
      stream: FirebaseFirestore.instance
          .collection('transactions')
          .where('household_id', isEqualTo: household.id)
          .where('date', isGreaterThanOrEqualTo: monthStart)
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (context, snap) {
        final spent = <String, Map<String, double>>{};
        for (final d in snap.data?.docs ?? const <QueryDocumentSnapshot>[]) {
          final m = d.data() as Map<String, dynamic>;
          // Un placement n'est pas une dépense : il vide la cagnotte solo mais
          // ne consomme aucune enveloppe.
          if (m['is_investment'] == true) continue;
          final a = (m['amount'] as num?)?.toDouble() ?? 0;
          if (a <= 0) continue; // remboursements et entrées d'argent
          final bucket = (m['assigned_to_bucket'] as String?) ?? '';
          if (bucket.isEmpty) continue;
          final cat = (m['category'] as String?) ?? 'OTHER';
          (spent[bucket] ??= <String, double>{})
              .update(cat, (v) => v + a, ifAbsent: () => a);
        }
        return _bucketsRow(household, uid, spent);
      },
    );
  }

  Widget _bucketsRow(
    Household household,
    String uid,
    Map<String, Map<String, double>> spent,
  ) {
    final l10n = _l10n;
    final isA = household.isUserA(uid);

    // En solo, la cagnotte du partenaire n'existe pas : deux cartes
    // (« Perso » et « Essentiel ») au lieu de trois. On lit la cagnotte du
    // siège réellement occupé — après une séparation, ce n'est pas
    // forcément le siège A.
    if (household.isSolo) {
      final soloBucket = household.soloBucketFor(uid);
      final mine = household.mySoloBalance(uid);
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _potColumn(
                household,
                uid,
                bucket: soloBucket,
                spent: spent,
                card: BalanceCard(
                  title: l10n.bucketPersonal,
                  amount: mine,
                  accent: AppColors.solo,
                  alert: household.alertLevel(mine),
                  onTap: household.hasBankConnection
                      ? () => _openCashComparison(household, uid)
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _potColumn(
                household,
                uid,
                bucket: 'Common',
                spent: spent,
                card: BalanceCard(
                  title: l10n.bucketEssential,
                  amount: household.safeToSpendCommon,
                  accent: AppColors.primary,
                  featured: true,
                  alert: household.alertLevel(household.safeToSpendCommon),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _potColumn(
              household,
              uid,
              bucket: 'Solo_A',
              spent: spent,
              card: BalanceCard(
                title: isA ? l10n.bucketMe(household.nameA) : household.nameA,
                amount: household.safeToSpendSoloA,
                accent: isA ? AppColors.solo : AppColors.partner,
                alert: household.alertLevel(household.safeToSpendSoloA),
                // Le solde réel n'a de sens que pour ses propres comptes.
                onTap: isA && household.hasBankConnection
                    ? () => _openCashComparison(household, uid)
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _potColumn(
              household,
              uid,
              bucket: 'Common',
              spent: spent,
              card: BalanceCard(
                title: l10n.bucketCommon,
                amount: household.safeToSpendCommon,
                accent: AppColors.primary,
                featured: true,
                alert: household.alertLevel(household.safeToSpendCommon),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _potColumn(
              household,
              uid,
              bucket: 'Solo_B',
              spent: spent,
              card: BalanceCard(
                title: !isA ? l10n.bucketMe(household.nameB) : household.nameB,
                amount: household.safeToSpendSoloB,
                accent: !isA ? AppColors.solo : AppColors.partner,
                alert: household.alertLevel(household.safeToSpendSoloB),
                onTap: !isA && household.hasBankConnection
                    ? () => _openCashComparison(household, uid)
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Une cagnotte : sa carte, le solde réel du compte associé, puis
  /// Réservé / Libre.
  Widget _potColumn(
    Household household,
    String uid, {
    required String bucket,
    required Map<String, Map<String, double>> spent,
    required Widget card,
  }) {
    final children = <Widget>[card];

    final balance = _potBalanceLine(household, uid, bucket);
    if (balance != null) children.add(balance);

    final envelopes = household.envelopesOf(bucket);
    final isMine = bucket == household.soloBucketFor(uid) || bucket == 'Common';
    if (envelopes.isNotEmpty) {
      // Réservé : ce qui reste engagé dans les enveloppes du mois. L'argent
      // ne bouge pas — on ne montre que la répartition de la cagnotte.
      final s = spent[bucket] ?? const <String, double>{};
      double reserved = 0;
      envelopes.forEach((cat, budget) {
        final rem = budget - (s[cat] ?? 0);
        if (rem > 0) reserved += rem;
      });
      final free = household.bucketBalance(bucket) - reserved;
      children.add(_reservedFreeMini(
        household,
        uid,
        bucket,
        reserved,
        free,
        tappable: isMine,
      ));
    } else if (isMine) {
      // Sans enveloppe, rien à répartir : on offre plutôt l'entrée pour en
      // définir, sans quoi la fonction resterait invisible.
      children.add(_envelopesConfigureLink(household, uid, bucket));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  /// Solde réel du compte associé à une cagnotte.
  ///
  /// Cloisonnement : le compte chèque perso n'est montré qu'à son propriétaire
  /// (le serveur ne renvoie jamais celui du partenaire), le compte conjoint
  /// est visible des deux, et la cagnotte solo de l'autre affiche « Privé ».
  Widget? _potBalanceLine(Household household, String uid, String bucket) {
    if (!household.hasBankConnection) return null;

    if (bucket == household.soloBucketFor(uid)) {
      if (_checkingBalance == null) return null;
      return _miniBalance(
        Icons.account_balance_wallet_outlined,
        _l10n.checkingBalanceShort,
        _checkingBalance!,
        onTap: () => _openCashComparison(household, uid),
      );
    }
    if (bucket == 'Common') {
      if (_jointCheckingBalance == null) return null;
      return _miniBalance(
        Icons.account_balance_outlined,
        _l10n.checkingBalanceJointShort,
        _jointCheckingBalance!,
      );
    }
    return _miniPrivate();
  }

  Widget _miniBalance(IconData icon, String label, double amount,
      {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: context.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 12, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(fontSize: 10.5, color: context.mutedColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  formatCurrency(amount),
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Cagnotte solo du partenaire : le solde de son compte perso reste privé.
  Widget _miniPrivate() {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Tooltip(
        message: _l10n.checkingBalancePrivateHint,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: context.borderColor),
          ),
          child: Row(
            children: [
              Icon(Icons.lock_outline, size: 12, color: context.mutedColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _l10n.checkingBalancePrivate,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10.5, color: context.mutedColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reservedFreeMini(
    Household household,
    String uid,
    String bucket,
    double reserved,
    double free, {
    required bool tappable,
  }) {
    final accent = bucket == 'Common' ? AppColors.primary : AppColors.solo;
    final freeColor =
        free < 0 ? context.palette.danger : context.palette.success;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: GestureDetector(
        onTap: tappable ? () => _openEnvelopes(household, uid, bucket) : null,
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            _homeReservedPill(
                _l10n.soloEnvelopesReservedShort, reserved, accent),
            const SizedBox(height: 4),
            _homeReservedPill(
                _l10n.soloEnvelopesFreeShort, free, freeColor),
          ],
        ),
      ),
    );
  }

  Widget _envelopesConfigureLink(
      Household household, String uid, String bucket) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: GestureDetector(
        onTap: () => _openEnvelopes(household, uid, bucket),
        behavior: HitTestBehavior.opaque,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline,
                size: 12, color: context.mutedColor),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                _l10n.soloEnvelopesConfigure,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10.5, color: context.mutedColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openEnvelopes(Household household, String uid, String bucket) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SoloEnvelopesScreen(
          household: household,
          uid: uid,
          bucket: bucket,
        ),
      ),
    );
  }

  Widget _homeReservedPill(String label, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color),
      ),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(fontSize: 10.5, color: context.mutedColor)),
          const SizedBox(width: 4),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(formatCurrency(amount),
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: color)),
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
    // Tri par date réelle de l'opération plutôt que par ordre d'import : un
    // rattrapage d'historique arrive en bloc et l'ordre d'import n'a alors
    // aucun sens pour l'utilisateur.
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('transactions')
        .where('household_id', isEqualTo: household.id)
        .where('assigned_to_bucket', isEqualTo: '');
    if (_thisMonthOnly) {
      query = query.where('date', isGreaterThanOrEqualTo: _startOfMonth());
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query
          .orderBy('date', descending: true)
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
          // Deux situations très différentes donnent une liste vide : aucune
          // banque reliée, ou tout est déjà trié. Proposer « Connecter ma
          // banque » dans le second cas laissait croire que la connexion
          // n'avait pas fonctionné.
          return _buildEmptyState(household);
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
                child:
                    _buildTransactionCard(transaction, lang, household, uid),
              ),
            );
          },
        );
      },
    );
  }

  /// En-tête de la file de tri : titre, filtre par période et écartement des
  /// mois révolus.
  Widget _buildSortHeader() {
    final l10n = _l10n;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.transactionsToNeutralize,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ),
          // Le filtre porte sur la date réelle : relier une banque rapatrie
          // des mois d'historique qui n'ont pas à encombrer le tri courant.
          ChoiceChip(
            label: Text(
              _thisMonthOnly ? l10n.sortFilterThisMonth : l10n.sortFilterAll,
              style: const TextStyle(fontSize: 12),
            ),
            selected: _thisMonthOnly,
            onSelected: (v) => setState(() => _thisMonthOnly = v),
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            tooltip: l10n.archivePastTitle,
            icon: _archiving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.playlist_remove),
            onPressed: _archiving ? null : _archivePast,
          ),
        ],
      ),
    );
  }

  /// Écran vide de la file de tri.
  ///
  /// Distingue « aucune banque reliée » de « tout est trié » : sans le
  /// compteur porté par le foyer, les deux cas seraient indiscernables côté
  /// client, `bank_connections` étant interdite de lecture.
  Widget _buildEmptyState(Household household) {
    final l10n = _l10n;
    final connected = household.hasBankConnection;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (connected)
              Icon(
                Icons.check_circle_outline,
                size: 68,
                color: context.palette.success,
              )
            else
              Opacity(opacity: 0.55, child: const HorizonLogo(size: 88)),
            const SizedBox(height: 24),
            Text(
              connected ? l10n.allSortedTitle : l10n.noBankTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              connected ? l10n.allSortedBody : l10n.noBankBody,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.mutedColor,
                fontSize: 14,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            if (connected)
              OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BankConnectionsScreen(),
                  ),
                ),
                icon: const Icon(Icons.account_balance),
                label: Text(l10n.bankManageTitle),
              )
            else
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

  /// Carte d'une transaction à trier : pastille de catégorie, commerçant,
  /// montant. C'est l'objet que l'utilisateur manipule le plus — il porte
  /// donc la hiérarchie typographique la plus marquée de l'app.
  Widget _buildTransactionCard(
    AppTransaction transaction,
    String lang,
    Household household,
    String uid,
  ) {
    final cat = categoryOf(transaction.category);
    final branding =
        household.institutionBranding(transaction.institutionName);
    // Un montant négatif est une entrée d'argent (remboursement, dépôt) : on
    // l'affiche « +X » en vert, jamais « --X ».
    final isCredit = transaction.amount < 0;

    return Container(
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.borderColor),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          // Logo de la banque : c'est la provenance qu'on veut identifier au
          // premier coup d'œil quand plusieurs institutions sont reliées. La
          // catégorie reste indiquée par sa petite icône colorée en légende.
          InstitutionAvatar(
            name: transaction.institutionName,
            logoDataUri: branding.logo,
            colorHex: branding.color,
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
                // Icône de catégorie · catégorie · date · provenance. Le logo
                // à gauche porte déjà la provenance ; l'icône de catégorie
                // garde son repère visuel malgré le déplacement.
                Row(
                  children: [
                    Icon(cat.icon, size: 13, color: cat.color),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        [
                          cat.labelFor(lang),
                          if (transaction.shortDate != null)
                            transaction.shortDate!,
                          if (transaction.institutionName != null)
                            transaction.institutionName!,
                        ].join('  ·  '),
                        style: TextStyle(
                            fontSize: 12.5, color: context.mutedColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            isCredit
                ? '+${formatCurrency(-transaction.amount)}'
                : '-${formatCurrency(transaction.amount)}',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              letterSpacing: -0.4,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: isCredit
                  ? context.palette.success
                  : context.colors.onSurface,
            ),
          ),
          // Le glissement ne propose que les cagnottes réelles. Un mouvement
          // interne ou une dépense d'un mois révolu n'a pas de geste dédié :
          // sans ce menu, rien ne permettait de les sortir de la file.
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, size: 18, color: context.mutedColor),
            padding: EdgeInsets.zero,
            onSelected: (value) {
              if (value == '__rule__') {
                _showRuleDialog(transaction, household, uid);
              } else {
                _assignTransaction(transaction, value, household);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'Transfer',
                child: Text(_l10n.bucketTransfer),
              ),
              PopupMenuItem(
                value: 'Archived',
                child: Text(_l10n.bucketArchived),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: '__rule__',
                child: Text(_l10n.ruleAlwaysSort),
              ),
            ],
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
