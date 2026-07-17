import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../models/household.dart';
import '../theme/app_colors.dart';
import '../utils/categories.dart';
import '../utils/formatters.dart';
import '../widgets/household_loader.dart';
import 'paywall_screen.dart';

/// Bilan hebdomadaire / mensuel : chiffres calculés par le serveur
/// (moteur déterministe), conseils rédigés par le coach IA sur demande.
class BilanScreen extends StatefulWidget {
  const BilanScreen({super.key});

  @override
  State<BilanScreen> createState() => _BilanScreenState();
}

class _BilanScreenState extends State<BilanScreen> {
  String _periodType = 'monthly';
  String? _reportId;
  bool _loading = true;
  bool _generatingAdvice = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refreshReport();
  }

  Future<void> _refreshReport() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('generateReport');
      final result = await callable.call({'period_type': _periodType});
      if (!mounted) return;
      setState(() {
        _reportId = result.data['report_id'] as String?;
        _loading = false;
      });
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message ?? 'Erreur lors de la génération du bilan.';
        _loading = false;
      });
    } catch (e) {
      debugPrint('Erreur generateReport: $e');
      if (!mounted) return;
      setState(() {
        _error = 'Erreur lors de la génération du bilan.';
        _loading = false;
      });
    }
  }

  Future<void> _generateAdvice() async {
    if (_reportId == null) return;
    setState(() => _generatingAdvice = true);
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('generateCoachAdvice');
      await callable.call({'report_id': _reportId});
      // Le doc du bilan est mis à jour côté serveur; le stream rafraîchit l'UI.
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      if (e.code == 'permission-denied') {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PaywallScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Le coach IA est indisponible.')),
        );
      }
    } catch (e) {
      debugPrint('Erreur generateCoachAdvice: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le coach IA est indisponible.')),
      );
    } finally {
      if (mounted) setState(() => _generatingAdvice = false);
    }
  }

  Future<void> _addRecurring(String name, double monthlyAmount) async {
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('addRecurringToBudget');
      await callable.call({'name': name, 'amount': monthlyAmount});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '« $name » ajouté aux dépenses fixes '
            '(${formatCurrency(monthlyAmount)}/mois).',
          ),
        ),
      );
      _refreshReport();
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? "Erreur lors de l'ajout.")),
      );
    } catch (e) {
      debugPrint('Erreur addRecurringToBudget: $e');
    }
  }

  Future<void> _dismissRecurring(Household household, String name) async {
    try {
      await FirebaseFirestore.instance
          .collection('households')
          .doc(household.id)
          .update({
        'dismissed_recurring': FieldValue.arrayUnion([name]),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('« $name » ne sera plus suggéré.')),
      );
      _refreshReport();
    } catch (e) {
      debugPrint('Erreur dismissed_recurring: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bilan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Rafraîchir',
            onPressed: _loading ? null : _refreshReport,
          ),
        ],
      ),
      body: HouseholdLoader(
        builder: (context, household, uid) {
          return Column(
            children: [
              _buildPeriodChips(),
              Expanded(child: _buildBody(household)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPeriodChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('Ce mois-ci'),
            selected: _periodType == 'monthly',
            selectedColor: AppColors.primary.withValues(alpha: 0.3),
            onSelected: (_) {
              setState(() => _periodType = 'monthly');
              _refreshReport();
            },
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('Cette semaine'),
            selected: _periodType == 'weekly',
            selectedColor: AppColors.primary.withValues(alpha: 0.3),
            onSelected: (_) {
              setState(() => _periodType = 'weekly');
              _refreshReport();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBody(Household household) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null || _reportId == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error ?? 'Bilan indisponible.',
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _refreshReport,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('households')
          .doc(household.id)
          .collection('reports')
          .doc(_reportId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: CircularProgressIndicator());
        }
        final report = snapshot.data!.data() as Map<String, dynamic>;
        return _buildReport(household, report);
      },
    );
  }

  Widget _buildReport(Household household, Map<String, dynamic> report) {
    final total = (report['total_spent'] as num?)?.toDouble() ?? 0;
    final prevTotal = (report['prev_total_spent'] as num?)?.toDouble() ?? 0;
    final byCategory = Map<String, dynamic>.from(
        report['by_category'] as Map<dynamic, dynamic>? ?? {});
    final prevByCategory = Map<String, dynamic>.from(
        report['prev_by_category'] as Map<dynamic, dynamic>? ?? {});
    final topMerchants =
        List<Map<String, dynamic>>.from((report['top_merchants'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map)) ??
            []);
    final recurring =
        List<Map<String, dynamic>>.from((report['recurring_suggestions']
                    as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map)) ??
            []);
    final aiAdvice = report['ai_advice'] as String?;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        _buildTotalCard(total, prevTotal),
        const SizedBox(height: 16),
        if (byCategory.isNotEmpty) ...[
          _sectionTitle('Dépenses par catégorie'),
          _buildCategoryBars(byCategory, prevByCategory),
          const SizedBox(height: 16),
        ],
        if (topMerchants.isNotEmpty) ...[
          _sectionTitle('Principaux commerçants'),
          _card(
            topMerchants.map((m) {
              return ListTile(
                dense: true,
                title: Text(m['name'] as String? ?? ''),
                subtitle: Text('${m['count']} transaction(s)',
                    style: const TextStyle(fontSize: 12)),
                trailing: Text(
                  formatCurrency((m['amount'] as num?)?.toDouble() ?? 0),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],
        if (recurring.isNotEmpty) ...[
          _sectionTitle('Dépenses récurrentes détectées'),
          ...recurring.map((r) => _buildRecurringCard(household, r)),
          const SizedBox(height: 16),
        ],
        if (_periodType == 'monthly') ...[
          _buildEnvelopes(household, byCategory),
        ],
        _sectionTitle('Coach budgétaire IA'),
        _buildAiSection(aiAdvice),
      ],
    );
  }

  Widget _buildTotalCard(double total, double prevTotal) {
    final double? deltaPct =
        prevTotal > 0 ? ((total - prevTotal) / prevTotal) * 100 : null;
    final up = (deltaPct ?? 0) > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary),
      ),
      child: Column(
        children: [
          Text(
            _periodType == 'monthly'
                ? 'Dépenses du mois'
                : 'Dépenses de la semaine',
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 4),
          Text(
            formatCurrency(total),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          if (deltaPct != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  up ? Icons.trending_up : Icons.trending_down,
                  size: 16,
                  color: up ? Colors.redAccent : Colors.green,
                ),
                const SizedBox(width: 4),
                Text(
                  '${up ? '+' : ''}${deltaPct.toStringAsFixed(0)} % vs '
                  'période précédente (${formatCurrency(prevTotal)})',
                  style: TextStyle(
                    fontSize: 12,
                    color: up ? Colors.redAccent : Colors.green,
                  ),
                ),
              ],
            )
          else
            const Text(
              'Pas encore de période précédente à comparer.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryBars(
    Map<String, dynamic> byCategory,
    Map<String, dynamic> prevByCategory,
  ) {
    final entries = byCategory.entries
        .map((e) => MapEntry(e.key, (e.value as num).toDouble()))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxValue = entries.isEmpty ? 1.0 : entries.first.value;

    return _card(
      entries.map((entry) {
        final cat = categoryOf(entry.key);
        final prev = (prevByCategory[entry.key] as num?)?.toDouble() ?? 0;
        final delta = entry.value - prev;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(cat.icon, size: 16, color: cat.color),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(cat.label,
                        style: const TextStyle(fontSize: 13)),
                  ),
                  Text(
                    formatCurrency(entry.value),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  if (prev > 0) ...[
                    const SizedBox(width: 6),
                    Text(
                      '${delta >= 0 ? '+' : ''}${formatCurrency(delta)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: delta > 0 ? Colors.redAccent : Colors.green,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (entry.value / maxValue).clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: Colors.white10,
                  valueColor: AlwaysStoppedAnimation<Color>(cat.color),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecurringCard(Household household, Map<String, dynamic> r) {
    final name = r['merchant'] as String? ?? '';
    final amount = (r['amount'] as num?)?.toDouble() ?? 0;
    final monthly = (r['monthly_amount'] as num?)?.toDouble() ?? amount;
    final label = r['frequency_label'] as String? ?? '';
    final occurrences = r['occurrences'] ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.autorenew, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  formatCurrency(amount),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Dépense $label détectée ($occurrences fois) — '
              '≈ ${formatCurrency(monthly)}/mois',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _dismissRecurring(household, name),
                  child: const Text('Ignorer',
                      style: TextStyle(color: Colors.grey)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _addRecurring(name, monthly),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary),
                  child: const Text('Ajouter au budget'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Enveloppes : budgets par catégorie du mois courant vs dépenses réelles.
  Widget _buildEnvelopes(Household household, Map<String, dynamic> byCategory) {
    final now = DateTime.now();
    final monthId =
        "${now.year}-${now.month.toString().padLeft(2, '0')}";

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('households')
          .doc(household.id)
          .collection('monthly_budgets')
          .doc(monthId)
          .get(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final envelopes = List<Map<String, dynamic>>.from(
            (data?['category_budgets'] as List?)
                    ?.map((e) => Map<String, dynamic>.from(e as Map)) ??
                []);
        if (envelopes.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Enveloppes du mois'),
            _card(
              envelopes.map((e) {
                final cat = categoryOf(e['category'] as String?);
                final budget = (e['amount'] as num?)?.toDouble() ?? 0;
                final spent =
                    (byCategory[e['category']] as num?)?.toDouble() ?? 0;
                final ratio = budget > 0 ? spent / budget : 0.0;
                final over = ratio > 1.0;
                final warn = ratio > 0.8 && !over;
                final barColor = over
                    ? Colors.redAccent
                    : (warn ? Colors.orange : cat.color);

                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(cat.icon, size: 16, color: cat.color),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(cat.label,
                                style: const TextStyle(fontSize: 13)),
                          ),
                          Text(
                            '${formatCurrency(spent)} / '
                            '${formatCurrency(budget)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: over ? Colors.redAccent : Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio.clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor: Colors.white10,
                          valueColor: AlwaysStoppedAnimation<Color>(barColor),
                        ),
                      ),
                      if (over)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'Dépassement de '
                            '${formatCurrency(spent - budget)}',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.redAccent),
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildAiSection(String? aiAdvice) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (aiAdvice != null) ...[
            MarkdownBody(
              data: aiAdvice,
              styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)),
            ),
            const SizedBox(height: 12),
            const Text(
              'Ces suggestions sont générées par une IA à partir de vos '
              'agrégats de dépenses et ne constituent pas un conseil '
              'financier professionnel.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 12),
          ] else ...[
            const Icon(Icons.auto_awesome, color: AppColors.primary, size: 32),
            const SizedBox(height: 8),
            const Text(
              'Obtenez des observations et suggestions personnalisées, '
              'rédigées à partir des chiffres de ce bilan.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 12),
          ],
          _generatingAdvice
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(),
                  ),
                )
              : ElevatedButton.icon(
                  onPressed: _generateAdvice,
                  icon: const Icon(Icons.auto_awesome),
                  label: Text(
                    aiAdvice == null
                        ? 'Générer mes conseils IA'
                        : 'Régénérer les conseils',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _card(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(children: children),
    );
  }
}
