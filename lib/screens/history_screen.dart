import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_transaction.dart';
import '../models/household.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/household_loader.dart';
import 'paywall_screen.dart';

/// Historique des transactions déjà catégorisées, avec possibilité de les
/// re-catégoriser (la Cloud Function ajuste les cagnottes automatiquement).
/// Plan gratuit : 30 jours d'historique.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historique')),
      body: HouseholdLoader(
        builder: (context, household, uid) {
          return Column(
            children: [
              if (!household.isPremium) _buildFreePlanBanner(context),
              _buildFilterChips(household),
              Expanded(child: _buildList(household, uid)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFreePlanBanner(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.lock_clock, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Plan gratuit : 30 jours d\'historique.',
                style: TextStyle(fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PaywallScreen()),
                );
              },
              child: const Text('PREMIUM'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips(Household household) {
    final filters = <String, String>{
      'all': 'Tous',
      'Solo_A': household.bucketLabel('Solo_A'),
      'Common': 'Commun',
      'Solo_B': household.bucketLabel('Solo_B'),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.entries.map((entry) {
            final selected = _filter == entry.key;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(entry.value),
                selected: selected,
                selectedColor: AppColors.primary.withValues(alpha: 0.3),
                onSelected: (_) => setState(() => _filter = entry.key),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildList(Household household, String uid) {
    Query query = FirebaseFirestore.instance
        .collection('transactions')
        .where('household_id', isEqualTo: household.id)
        .where(
          'assigned_to_bucket',
          whereIn: const ['Solo_A', 'Common', 'Solo_B'],
        );

    // Plan gratuit : profondeur d'historique limitée à 30 jours.
    if (!household.isPremium) {
      final cutoff = DateTime.now().subtract(const Duration(days: 30));
      query = query.where(
        'created_at',
        isGreaterThan: Timestamp.fromDate(cutoff),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.orderBy('created_at', descending: true).limit(200).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('Erreur historique: ${snapshot.error}');
          return const Center(child: Text('Erreur de chargement'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var transactions = snapshot.data!.docs
            .map(AppTransaction.fromSnapshot)
            .toList();
        if (_filter != 'all') {
          transactions = transactions
              .where((t) => t.assignedToBucket == _filter)
              .toList();
        }

        if (transactions.isEmpty) {
          return const Center(
            child: Text(
              'Aucune transaction catégorisée.',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        final total =
            transactions.fold<double>(0, (acc, t) => acc + t.amount);

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${transactions.length} transaction(s)',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  Text(
                    'Total : ${formatCurrency(total)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: transactions.length,
                itemBuilder: (context, index) {
                  final t = transactions[index];
                  return _buildTransactionTile(t, household);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTransactionTile(AppTransaction t, Household household) {
    final isCommon = t.assignedToBucket == 'Common';
    final chipColor = isCommon ? AppColors.primary : AppColors.solo;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: ListTile(
          title: Text(
            t.merchantName,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Row(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: chipColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  household.bucketLabel(t.assignedToBucket),
                  style: TextStyle(fontSize: 12, color: chipColor),
                ),
              ),
              if (t.date != null) ...[
                const SizedBox(width: 8),
                Text(
                  t.date!,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '-${formatCurrency(t.amount)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.grey),
                color: AppColors.surface,
                onSelected: (bucket) => _recategorize(t, bucket, household),
                itemBuilder: (context) => [
                  for (final bucket in const ['Solo_A', 'Common', 'Solo_B'])
                    if (bucket != t.assignedToBucket)
                      PopupMenuItem(
                        value: bucket,
                        child: Text(
                          'Déplacer vers ${household.bucketLabel(bucket)}',
                        ),
                      ),
                  const PopupMenuItem(
                    value: '',
                    child: Text('Renvoyer dans « À trier »'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _recategorize(
    AppTransaction t,
    String bucket,
    Household household,
  ) {
    // Le trigger serveur annule l'ancien effet et applique le nouveau.
    FirebaseFirestore.instance
        .collection('transactions')
        .doc(t.id)
        .update({'assigned_to_bucket': bucket}).catchError((e) {
      debugPrint('Erreur de re-catégorisation: $e');
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          bucket.isEmpty
              ? 'Transaction renvoyée dans « À trier ».'
              : 'Déplacée vers ${household.bucketLabel(bucket)}.',
        ),
      ),
    );
  }
}
