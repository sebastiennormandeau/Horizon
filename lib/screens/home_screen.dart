import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:plaid_flutter/plaid_flutter.dart';

import '../models/app_transaction.dart';
import '../models/household.dart';
import '../theme/app_colors.dart';
import '../utils/categories.dart';
import '../utils/formatters.dart';
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

  @override
  void initState() {
    super.initState();

    _successSubscription = PlaidLink.onSuccess.listen((event) async {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Synchronisation des transactions en cours...'),
        ),
      );

      try {
        final callable = FirebaseFunctions.instance.httpsCallable(
          'exchangePublicToken',
        );
        await callable.call({'public_token': event.publicToken});

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Banque connectée et synchronisée !')),
        );
      } on FirebaseFunctionsException catch (e) {
        debugPrint("Erreur d'échange de token: ${e.code} ${e.message}");
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'Erreur lors de la synchronisation.'),
          ),
        );
      } catch (e) {
        debugPrint("Erreur d'échange de token: $e");
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la synchronisation.')),
        );
      }
    });

    _eventSubscription = PlaidLink.onEvent.listen((event) {
      debugPrint('Plaid Event: ${event.name}');
    });

    _exitSubscription = PlaidLink.onExit.listen((event) {
      debugPrint('Plaid Exit: ${event.error?.message ?? 'User cancelled'}');
    });
  }

  @override
  void dispose() {
    _successSubscription?.cancel();
    _eventSubscription?.cancel();
    _exitSubscription?.cancel();
    super.dispose();
  }

  Future<void> _openPlaid() async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'generatePlaidLinkToken',
      );
      final result = await callable();
      final linkToken = result.data['link_token'];

      final linkTokenConfiguration = LinkTokenConfiguration(token: linkToken);

      PlaidLink.create(configuration: linkTokenConfiguration);
      PlaidLink.open();
    } catch (e) {
      debugPrint('Erreur Plaid: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors de la connexion à Plaid.')),
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
        content: Text('Assigné à ${household.bucketLabel(bucket)}'),
        action: SnackBarAction(
          label: 'ANNULER',
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

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Row(
          children: const [
            Icon(Icons.warning_amber, color: Colors.orange),
            SizedBox(width: 8),
            Expanded(child: Text('Attention au négatif')),
          ],
        ),
        content: Text(
          'Assigner « ${transaction.merchantName} » '
          '(${formatCurrency(transaction.amount)}) mettra la cagnotte '
          '${household.bucketLabel(bucket)} à ${formatCurrency(after)}.\n\n'
          'Continuer quand même ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Assigner quand même'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _settleDebt(Household household) async {
    final debt = household.internalDebtBalance;
    final debtor = debt > 0 ? household.nameB : household.nameA;
    final creditor = debt > 0 ? household.nameA : household.nameB;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Régler la dette interne'),
        content: Text(
          '$debtor doit ${formatCurrency(debt.abs())} à $creditor.\n\n'
          'Confirmez-vous que ce montant a été remboursé (virement, argent '
          'comptant, etc.) ? La balance sera remise à zéro.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Confirmer le règlement'),
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
        SnackBar(
          content: Text('Dette de ${formatCurrency(amount)} réglée !'),
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Erreur lors du règlement.')),
      );
    } catch (e) {
      debugPrint('Erreur settleDebt: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors du règlement.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Horizon',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.insights),
            tooltip: 'Bilan',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BilanScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Historique',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HistoryScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Configuration du budget',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BudgetSetupScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Réglages',
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
              _buildAlertBanner(household),
              if (household.awaitingPartner && household.joinCode != null)
                _buildInviteCard(household.joinCode!),
              _buildDebtBanner(household),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Transactions à neutraliser',
                    style: TextStyle(
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
    final isA = household.isUserA(uid);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: _buildBucketCard(
              isA ? '${household.nameA} (moi)' : household.nameA,
              household.safeToSpendSoloA,
              alert: household.alertLevel(household.safeToSpendSoloA),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildBucketCard(
              'Commun',
              household.safeToSpendCommon,
              color: AppColors.primary,
              alert: household.alertLevel(household.safeToSpendCommon),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildBucketCard(
              !isA ? '${household.nameB} (moi)' : household.nameB,
              household.safeToSpendSoloB,
              alert: household.alertLevel(household.safeToSpendSoloB),
            ),
          ),
        ],
      ),
    );
  }

  /// Bannière d'avertissement quand une cagnotte est basse ou dans le négatif.
  Widget _buildAlertBanner(Household household) {
    final levels = [
      household.alertLevel(household.safeToSpendSoloA),
      household.alertLevel(household.safeToSpendCommon),
      household.alertLevel(household.safeToSpendSoloB),
    ];
    final worst = levels.reduce((a, b) => a > b ? a : b);
    if (worst == 0) return const SizedBox.shrink();

    final isNegative = worst == 2;
    final color = isNegative ? Colors.redAccent : Colors.orange;
    final text = isNegative
        ? 'Une cagnotte est dans le négatif — consultez le Bilan pour ajuster.'
        : 'Une cagnotte approche de zéro (seuil : '
            '${formatCurrency(household.alertThreshold)}).';

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
            const Expanded(
              child: Text(
                'Invitez votre conjoint(e) avec ce code :',
                style: TextStyle(fontSize: 13),
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
    final debt = household.internalDebtBalance;
    final bool isSettled = debt.abs() < 0.01;
    final String text;
    if (isSettled) {
      text = 'Balance interne : équilibrée';
    } else if (debt > 0) {
      text =
          '${household.nameB} doit ${formatCurrency(debt)} à ${household.nameA}';
    } else {
      text =
          '${household.nameA} doit ${formatCurrency(-debt)} à ${household.nameB}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            const Icon(Icons.swap_horiz, color: Colors.grey, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text, style: const TextStyle(color: Colors.grey)),
            ),
            if (!isSettled)
              TextButton(
                onPressed: () => _settleDebt(household),
                child: const Text(
                  'RÉGLER',
                  style: TextStyle(
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

  Widget _buildBucketCard(String title, num amount,
      {Color? color, int alert = 0}) {
    // Le niveau d'alerte prime sur la couleur de base de la carte.
    final Color? alertColor =
        alert == 2 ? Colors.redAccent : (alert == 1 ? Colors.orange : null);
    final borderColor = alertColor ?? color ?? Colors.white12;
    final amountColor = alertColor ?? color ?? Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      decoration: BoxDecoration(
        color: (alertColor ?? color)?.withValues(alpha: 0.15) ??
            AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
          width: (alertColor ?? color) != null ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, color: Colors.grey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            formatCurrency(amount),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: amountColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionSwipeList(Household household, String uid) {
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
          return const Center(child: Text('Erreur de chargement'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Aucune transaction à trier.',
                  style: TextStyle(color: Colors.grey, fontSize: 18),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _openPlaid,
                  icon: const Icon(Icons.account_balance),
                  label: const Text('Connecter ma banque'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final soloBucket = household.soloBucketFor(uid);
        final soloLabel = household.bucketLabel(soloBucket);

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
                  Icons.people,
                  'Commun',
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
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    title: Text(
                      transaction.merchantName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    subtitle: Builder(builder: (context) {
                      final cat = categoryOf(transaction.category);
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(cat.icon, size: 14, color: cat.color),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              cat.label,
                              style: TextStyle(
                                fontSize: 12,
                                color: cat.color,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      );
                    }),
                    trailing: Text(
                      '-${formatCurrency(transaction.amount)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSwipeBackground(
    Color color,
    IconData icon,
    String text,
    Alignment alignment,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      alignment: alignment,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 32),
          const SizedBox(height: 4),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
