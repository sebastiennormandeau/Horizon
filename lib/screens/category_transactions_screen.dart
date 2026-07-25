import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../l10n/app_localizations.dart';
import '../models/app_transaction.dart';
import '../theme/app_colors.dart';
import '../utils/categories.dart';
import '../utils/formatters.dart';

/// Transactions d'une catégorie pour la période du bilan, avec correction de
/// la catégorie au besoin.
///
/// La même sélection que le moteur de bilans : bornée par la **date réelle**,
/// montants positifs, hors mouvements internes (`Transfer`). La correction
/// écrit `category` — l'un des deux seuls champs qu'un client peut modifier.
class CategoryTransactionsScreen extends StatelessWidget {
  final String householdId;
  final String categoryKey;
  final DateTime periodStart;
  final DateTime periodEnd;

  const CategoryTransactionsScreen({
    super.key,
    required this.householdId,
    required this.categoryKey,
    required this.periodStart,
    required this.periodEnd,
  });

  /// Date `AAAA-MM-JJ` en UTC, comme Plaid l'inscrit et comme le serveur borne.
  static String _isoDay(DateTime d) {
    final u = d.toUtc();
    return '${u.year}-${u.month.toString().padLeft(2, '0')}-'
        '${u.day.toString().padLeft(2, '0')}';
  }

  Future<void> _recategorize(
    BuildContext context,
    AppTransaction tx,
    String lang,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(l10n.categoryTxPickTitle,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: kSelectableCategories.map((c) {
                    final current = c.key == tx.category;
                    return ListTile(
                      leading: Icon(c.icon, color: c.color),
                      title: Text(c.labelFor(lang)),
                      trailing: current
                          ? const Icon(Icons.check, color: AppColors.primary)
                          : null,
                      onTap: () => Navigator.pop(context, c.key),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selected == null || selected == tx.category) return;
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await FirebaseFirestore.instance
          .collection('transactions')
          .doc(tx.id)
          .update({'category': selected});
      messenger.showSnackBar(SnackBar(content: Text(l10n.categoryTxUpdated)));
    } catch (e) {
      debugPrint('Erreur recatégorisation: $e');
      messenger.showSnackBar(SnackBar(content: Text(l10n.categoryTxError)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final lang = Localizations.localeOf(context).languageCode;
    final cat = categoryOf(categoryKey);

    final query = FirebaseFirestore.instance
        .collection('transactions')
        .where('household_id', isEqualTo: householdId)
        .where('date', isGreaterThanOrEqualTo: _isoDay(periodStart))
        .where('date', isLessThan: _isoDay(periodEnd))
        .orderBy('date', descending: true)
        .limit(500);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(cat.icon, color: cat.color, size: 20),
            const SizedBox(width: 8),
            Flexible(child: Text(cat.labelFor(lang))),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(l10n.loadingError));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // Même filtre que le moteur de bilans (reports.ts) pour que la liste
          // corresponde exactement à la barre touchée.
          final txs = snapshot.data!.docs
              .map(AppTransaction.fromSnapshot)
              .where((t) =>
                  t.category == categoryKey &&
                  t.amount > 0 &&
                  t.assignedToBucket != 'Transfer')
              .toList();

          if (txs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  l10n.categoryTxEmpty,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.mutedColor),
                ),
              ),
            );
          }

          final total = txs.fold<double>(0, (s, t) => s + t.amount);

          return Column(
            children: [
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: cat.color.withValues(alpha: 0.10),
                child: Text(
                  l10n.categoryTxTotal(formatCurrency(total)),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: txs.length,
                  separatorBuilder: (_, _) => Divider(
                      height: 1, indent: 16, endIndent: 16,
                      color: context.borderColor),
                  itemBuilder: (context, i) {
                    final t = txs[i];
                    final subtitle = [
                      if (t.shortDate != null) t.shortDate!,
                      if (t.institutionName != null) t.institutionName!,
                    ].join('  ·  ');
                    return ListTile(
                      title: Text(t.merchantName,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: subtitle.isEmpty
                          ? null
                          : Text(subtitle,
                              style: TextStyle(
                                  fontSize: 12, color: context.mutedColor)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            formatCurrency(t.amount),
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.edit_outlined,
                              size: 18, color: context.mutedColor),
                        ],
                      ),
                      onTap: () => _recategorize(context, t, lang),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
