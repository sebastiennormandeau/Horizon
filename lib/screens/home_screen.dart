import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:plaid_flutter/plaid_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_transaction.dart';
import '../models/household.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import 'budget_setup_screen.dart';

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

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  void _assignTransaction(AppTransaction transaction, String bucket) {
    final docRef = FirebaseFirestore.instance
        .collection('transactions')
        .doc(transaction.id);

    docRef.update({'assigned_to_bucket': bucket}).catchError((e) {
      debugPrint("Erreur d'assignation: $e");
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Assigné à ${bucket == 'Common' ? 'Commun' : 'Solo'}'),
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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Veuillez vous reconnecter')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Horizon Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance),
            tooltip: 'Connecter ma banque',
            onPressed: _openPlaid,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Configuration du budget',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BudgetSetupScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Se déconnecter',
            onPressed: _logout,
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData =
              userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
          final householdId = userData['household_id'] as String?;

          if (householdId == null) {
            return const Center(child: Text('Foyer introuvable'));
          }

          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('households')
                .doc(householdId)
                .snapshots(),
            builder: (context, householdSnapshot) {
              if (!householdSnapshot.hasData ||
                  !householdSnapshot.data!.exists) {
                return const Center(child: CircularProgressIndicator());
              }

              final household = Household.fromSnapshot(
                householdSnapshot.data!,
              );

              return Column(
                children: [
                  _buildBucketsOverview(household, user.uid),
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
                    child: _buildTransactionSwipeList(household, user.uid),
                  ),
                ],
              );
            },
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
              isA ? 'Solo A (moi)' : 'Solo A',
              household.safeToSpendSoloA,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildBucketCard(
              'Commun',
              household.safeToSpendCommon,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildBucketCard(
              !isA ? 'Solo B (moi)' : 'Solo B',
              household.safeToSpendSoloB,
            ),
          ),
        ],
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
    final String text;
    if (debt.abs() < 0.01) {
      text = 'Balance interne : équilibrée';
    } else if (debt > 0) {
      text = 'Balance interne : B doit ${formatCurrency(debt)} à A';
    } else {
      text = 'Balance interne : A doit ${formatCurrency(-debt)} à B';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            const Icon(Icons.swap_horiz, color: Colors.grey, size: 20),
            const SizedBox(width: 8),
            Text(text, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildBucketCard(String title, num amount, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      decoration: BoxDecoration(
        color: color?.withValues(alpha: 0.2) ?? AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color ?? Colors.white12,
          width: color != null ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 8),
          Text(
            formatCurrency(amount),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color ?? Colors.white,
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
                  'Aucune transaction.',
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
        final soloLabel = soloBucket == 'Solo_A' ? 'Solo A' : 'Solo B';

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
                onDismissed: (direction) {
                  final bucket = direction == DismissDirection.startToEnd
                      ? soloBucket
                      : 'Common';
                  _assignTransaction(transaction, bucket);
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
                    subtitle: const Text('Glissez gauche/droite'),
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
