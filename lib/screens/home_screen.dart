import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:plaid_flutter/plaid_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
      print("Plaid Success! Public Token: ${event.publicToken}");

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Synchronisation des transactions en cours...'),
        ),
      );

      try {
        HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
          'exchangePublicToken',
        );
        await callable.call({'public_token': event.publicToken});

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Banque connectée et synchronisée !')),
        );
      } catch (e) {
        print("Erreur d'échange de token: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la synchronisation.')),
        );
      }
    });

    _eventSubscription = PlaidLink.onEvent.listen((event) {
      print("Plaid Event: ${event.name}");
    });

    _exitSubscription = PlaidLink.onExit.listen((event) {
      print("Plaid Exit: ${event.error?.message ?? 'User cancelled'}");
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
      HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
        'generatePlaidLinkToken',
      );
      final result = await callable();
      final linkToken = result.data['link_token'];

      LinkTokenConfiguration linkTokenConfiguration = LinkTokenConfiguration(
        token: linkToken,
      );

      PlaidLink.create(configuration: linkTokenConfiguration);
      PlaidLink.open();
    } catch (e) {
      print("Erreur Plaid: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors de la connexion à Plaid.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Horizon Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BudgetSetupScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildBucketsOverview(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Transactions à neutraliser',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Expanded(child: _buildTransactionSwipeList()),
        ],
      ),
    );
  }

  Widget _buildBucketsOverview() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const SizedBox(
        height: 120,
        child: Center(child: Text('Veuillez vous reconnecter')),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
          return const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final userData = userSnapshot.data!.data() as Map<String, dynamic>;
        final householdId = userData['household_id'];

        if (householdId == null) {
          return const SizedBox(
            height: 120,
            child: Center(child: Text("Foyer introuvable")),
          );
        }

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('households')
              .doc(householdId)
              .snapshots(),
          builder: (context, householdSnapshot) {
            if (!householdSnapshot.hasData || !householdSnapshot.data!.exists) {
              return const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final data = householdSnapshot.data!.data() as Map<String, dynamic>;

            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildBucketCard(
                      'Solo A',
                      data['safe_to_spend_solo_A'] ?? 0,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildBucketCard(
                      'Commun',
                      data['safe_to_spend_common'] ?? 0,
                      color: const Color(0xFF6C63FF),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildBucketCard(
                      'Solo B',
                      data['safe_to_spend_solo_B'] ?? 0,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBucketCard(String title, num amount, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      decoration: BoxDecoration(
        color: color?.withValues(alpha: 0.2) ?? const Color(0xFF1E1E1E),
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
            '\$${amount.toStringAsFixed(2)}',
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

  Widget _buildTransactionSwipeList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('transactions')
          .where('assigned_to_bucket', isEqualTo: '')
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return const Center(child: Text('Erreur de chargement'));
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());

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
                    backgroundColor: const Color(0xFF6C63FF),
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

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;

            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Dismissible(
                key: Key(doc.id),
                background: _buildSwipeBackground(
                  Colors.orange,
                  Icons.person,
                  'Solo',
                  Alignment.centerLeft,
                ),
                secondaryBackground: _buildSwipeBackground(
                  const Color(0xFF6C63FF),
                  Icons.people,
                  'Commun',
                  Alignment.centerRight,
                ),
                onDismissed: (direction) {
                  String bucket = direction == DismissDirection.startToEnd
                      ? 'Solo_A'
                      : 'Common';

                  FirebaseFirestore.instance
                      .collection('transactions')
                      .doc(doc.id)
                      .update({'assigned_to_bucket': bucket});

                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Assigné à $bucket')));
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    title: Text(
                      data['merchant_name'] ?? 'Inconnu',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    subtitle: const Text('Glissez gauche/droite'),
                    trailing: Text(
                      '-\$${data['amount']}',
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
