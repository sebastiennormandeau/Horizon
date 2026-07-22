import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../l10n/app_localizations.dart';
import '../models/app_transaction.dart';
import '../models/household.dart';
import '../theme/app_colors.dart';
import '../utils/categories.dart';
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
  String _categoryFilter = 'all';

  AppLocalizations get _l10n => AppLocalizations.of(context)!;
  String get _lang => Localizations.localeOf(context).languageCode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_l10n.historyTitle)),
      body: HouseholdLoader(
        builder: (context, household, uid) {
          return Column(
            children: [
              if (!household.isPremium) _buildFreePlanBanner(context),
              _buildFilterChips(household, uid),
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
            Expanded(
              child: Text(
                _l10n.freePlanBanner,
                style: const TextStyle(fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PaywallScreen()),
                );
              },
              child: Text(_l10n.premiumButton),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips(Household household, String uid) {
    final l10n = _l10n;
    // En solo, la cagnotte du partenaire n'existe pas : pas de filtre pour
    // elle.
    final filters = <String, String>{
      'all': l10n.filterAll,
      for (final bucket in household.visibleBuckets(uid))
        bucket: household.bucketLabel(bucket, l10n),
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
          return Center(child: Text(_l10n.loadingError));
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

        // Catégories réellement présentes (avant filtre de catégorie).
        final presentCategories =
            transactions.map((t) => t.category).toSet().toList()..sort();

        if (_categoryFilter != 'all') {
          transactions = transactions
              .where((t) => t.category == _categoryFilter)
              .toList();
        }

        if (transactions.isEmpty && _categoryFilter == 'all') {
          return Center(
            child: Text(
              _l10n.noCategorizedTransactions,
              style: TextStyle(color: context.mutedColor),
            ),
          );
        }

        final total =
            transactions.fold<double>(0, (acc, t) => acc + t.amount);

        return Column(
          children: [
            if (presentCategories.length > 1)
              _buildCategoryChips(presentCategories),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _l10n.transactionCount('${transactions.length}'),
                    style: TextStyle(color: context.mutedColor),
                  ),
                  Text(
                    _l10n.totalAmount(formatCurrency(total)),
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
                  return _buildTransactionTile(t, household, uid);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategoryChips(List<String> presentCategories) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(_l10n.allCategories),
                selected: _categoryFilter == 'all',
                selectedColor: AppColors.primary.withValues(alpha: 0.3),
                onSelected: (_) => setState(() => _categoryFilter = 'all'),
              ),
            ),
            ...presentCategories.map((key) {
              final cat = categoryOf(key);
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  avatar: Icon(cat.icon, size: 16, color: cat.color),
                  label: Text(
                    cat.labelFor(_lang),
                    style: const TextStyle(fontSize: 12),
                  ),
                  selected: _categoryFilter == key,
                  selectedColor: cat.color.withValues(alpha: 0.3),
                  onSelected: (_) => setState(() => _categoryFilter = key),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _changeCategory(AppTransaction t) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(_l10n.changeCategory),
        children: kSelectableCategories.map((cat) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(context, cat.key),
            child: Row(
              children: [
                Icon(cat.icon, size: 20, color: cat.color),
                const SizedBox(width: 12),
                Text(cat.labelFor(_lang)),
                if (cat.key == t.category) ...[
                  const Spacer(),
                  const Icon(Icons.check, size: 18, color: AppColors.primary),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );

    if (selected == null || selected == t.category || !mounted) return;
    FirebaseFirestore.instance
        .collection('transactions')
        .doc(t.id)
        .update({'category': selected}).catchError((e) {
      debugPrint('Erreur de changement de catégorie: $e');
    });
  }

  Widget _buildTransactionTile(AppTransaction t, Household household, String uid) {
    final l10n = _l10n;
    final isCommon = t.assignedToBucket == 'Common';
    final chipColor = isCommon ? AppColors.primary : AppColors.solo;
    final cat = categoryOf(t.category);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.borderColor),
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
                  household.bucketLabel(t.assignedToBucket, l10n),
                  style: TextStyle(fontSize: 12, color: chipColor),
                ),
              ),
              const SizedBox(width: 6),
              Icon(cat.icon, size: 14, color: cat.color),
              const SizedBox(width: 2),
              Flexible(
                child: Text(
                  cat.labelFor(_lang),
                  style: TextStyle(fontSize: 11, color: cat.color),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (t.date != null) ...[
                const SizedBox(width: 6),
                Text(
                  t.date!,
                  style: TextStyle(fontSize: 11, color: context.mutedColor),
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
                icon: Icon(Icons.more_vert, color: context.mutedColor),
                color: context.cardColor,
                onSelected: (value) {
                  if (value == '__category__') {
                    _changeCategory(t);
                  } else {
                    _recategorize(t, value, household);
                  }
                },
                itemBuilder: (context) => [
                  for (final bucket in household.visibleBuckets(uid))
                    if (bucket != t.assignedToBucket)
                      PopupMenuItem(
                        value: bucket,
                        child: Text(
                          l10n.moveTo(household.bucketLabel(bucket, l10n)),
                        ),
                      ),
                  PopupMenuItem(
                    value: '__category__',
                    child: Text(l10n.changeCategory),
                  ),
                  PopupMenuItem(
                    value: '',
                    child: Text(l10n.sendBackToSort),
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
              ? _l10n.sentBackToSort
              : _l10n.movedTo(household.bucketLabel(bucket, _l10n)),
        ),
      ),
    );
  }
}
