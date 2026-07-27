import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../l10n/app_localizations.dart';
import '../models/household.dart';
import '../theme/app_colors.dart';
import '../utils/categories.dart';
import '../utils/formatters.dart';
import '../utils/locale_controller.dart';
import '../widgets/category_donut.dart';
import '../widgets/household_loader.dart';
import 'category_transactions_screen.dart';
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

  AppLocalizations get _l10n => AppLocalizations.of(context)!;
  String get _lang => Localizations.localeOf(context).languageCode;

  @override
  void initState() {
    super.initState();
    _refreshReport();
  }

  /// Les libellés de fréquence sont produits en français par le serveur
  /// (moteur de bilans) ; on les traduit à l'affichage.
  String _frequencyLabel(String serverLabel) {
    switch (serverLabel) {
      case 'hebdomadaire':
        return _l10n.freqLabelWeekly;
      case 'aux 2 semaines':
        return _l10n.freqLabelBiweekly;
      case 'mensuelle':
        return _l10n.freqLabelMonthly;
      default:
        return serverLabel;
    }
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
        _error = e.message ?? _l10n.reportError;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Erreur generateReport: $e');
      if (!mounted) return;
      setState(() {
        _error = _l10n.reportError;
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
      // Le coach répond dans la langue active de l'app.
      await callable.call({
        'report_id': _reportId,
        'language': LocaleController.instance.effectiveLanguageCode,
      });
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
          SnackBar(content: Text(e.message ?? _l10n.coachUnavailable)),
        );
      }
    } catch (e) {
      debugPrint('Erreur generateCoachAdvice: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_l10n.coachUnavailable)),
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
            _l10n.addedToFixedExpenses(name, formatCurrency(monthlyAmount)),
          ),
        ),
      );
      _refreshReport();
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? _l10n.addError)),
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
        SnackBar(content: Text(_l10n.noLongerSuggested(name))),
      );
      _refreshReport();
    } catch (e) {
      debugPrint('Erreur dismissed_recurring: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.bilanTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.refreshTooltip,
            onPressed: _loading ? null : _refreshReport,
          ),
        ],
      ),
      body: HouseholdLoader(
        builder: (context, household, uid) {
          return Column(
            children: [
              _buildPeriodChips(),
              Expanded(child: _buildBody(household, uid)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPeriodChips() {
    final l10n = _l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          ChoiceChip(
            label: Text(l10n.thisMonth),
            selected: _periodType == 'monthly',
            selectedColor: AppColors.primary.withValues(alpha: 0.3),
            onSelected: (_) {
              setState(() => _periodType = 'monthly');
              _refreshReport();
            },
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: Text(l10n.thisWeek),
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

  Widget _buildBody(Household household, String uid) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null || _reportId == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error ?? _l10n.reportUnavailable,
                style: TextStyle(color: context.mutedColor)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _refreshReport,
              child: Text(_l10n.retry),
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
        return _buildReport(household, report, uid);
      },
    );
  }

  Widget _buildReport(
      Household household, Map<String, dynamic> report, String uid) {
    final l10n = _l10n;
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
    // Placements du membre connecté sur la période (compteur d'investissement).
    final invByUser = Map<String, dynamic>.from(
        report['investment_by_user'] as Map<dynamic, dynamic>? ?? {});
    final invested = (invByUser[uid] as num?)?.toDouble() ?? 0;
    final investGoal = household.myInvestmentGoal(uid);
    // Bornes de la période, pour ouvrir le détail d'une catégorie sur la même
    // sélection que le moteur de bilans. Absentes sur d'anciens bilans : les
    // barres restent alors non cliquables.
    final periodStart = (report['period_start'] as Timestamp?)?.toDate();
    final periodEnd = (report['period_end'] as Timestamp?)?.toDate();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        _buildTotalCard(total, prevTotal),
        if (invested > 0 || investGoal > 0) ...[
          const SizedBox(height: 12),
          _buildInvestmentThermometer(invested, investGoal, household, uid),
        ],
        const SizedBox(height: 16),
        if (byCategory.isNotEmpty) ...[
          _sectionTitle(l10n.spendingByCategory),
          // L'anneau donne le poids relatif de chaque poste ; les barres
          // qui suivent donnent l'évolution par rapport à la période
          // précédente. Les deux lectures sont complémentaires.
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 18),
            child: CategoryDonut(
              byCategory: byCategory,
              languageCode: Localizations.localeOf(context).languageCode,
              otherLabel: l10n.chartOtherCategories,
            ),
          ),
          if (periodStart != null && periodEnd != null)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                l10n.spendingByCategoryHint,
                style: TextStyle(fontSize: 12, color: context.mutedColor),
              ),
            ),
          _buildCategoryBars(
              byCategory, prevByCategory, household, periodStart, periodEnd),
          const SizedBox(height: 16),
        ],
        if (topMerchants.isNotEmpty) ...[
          _sectionTitle(l10n.topMerchants),
          _card(
            topMerchants.map((m) {
              return ListTile(
                dense: true,
                title: Text(m['name'] as String? ?? ''),
                subtitle: Text(
                  l10n.transactionCount('${m['count']}'),
                  style: const TextStyle(fontSize: 12),
                ),
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
          _sectionTitle(l10n.recurringDetected),
          ...recurring.map((r) => _buildRecurringCard(household, r)),
          const SizedBox(height: 16),
        ],
        if (_periodType == 'monthly') ...[
          _buildEnvelopes(household, byCategory),
        ],
        _sectionTitle(l10n.aiCoachSection),
        _buildAiSection(aiAdvice),
      ],
    );
  }

  /// Thermomètre d'investissement : progression vers l'objectif mensuel.
  /// Touchable pour définir/modifier l'objectif.
  Widget _buildInvestmentThermometer(
    double invested,
    double goal,
    Household household,
    String uid,
  ) {
    final l10n = _l10n;
    final success = context.palette.success;
    final hasGoal = goal > 0;
    final ratio = hasGoal ? (invested / goal).clamp(0.0, 1.0) : 0.0;
    final reached = hasGoal && invested >= goal;

    return GestureDetector(
      onTap: () => _editInvestmentGoal(goal),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: success.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: success),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.savings, color: success),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(l10n.investedThisPeriod,
                      style:
                          TextStyle(fontSize: 13, color: context.mutedColor)),
                ),
                Text(
                  hasGoal
                      ? '${formatCurrency(invested)} / ${formatCurrency(goal)}'
                      : formatCurrency(invested),
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: success),
                ),
                const SizedBox(width: 4),
                Icon(Icons.edit_outlined, size: 15, color: context.mutedColor),
              ],
            ),
            if (hasGoal) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 12,
                  backgroundColor: context.borderColor,
                  valueColor: AlwaysStoppedAnimation<Color>(success),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                reached
                    ? l10n.investmentGoalReached
                    : l10n.investmentProgress('${(ratio * 100).round()}'),
                style: TextStyle(
                  fontSize: 12,
                  color: reached ? success : context.mutedColor,
                  fontWeight: reached ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ] else ...[
              const SizedBox(height: 6),
              Text(l10n.investmentSetGoalHint,
                  style: TextStyle(fontSize: 12, color: context.mutedColor)),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _editInvestmentGoal(double current) async {
    final l10n = _l10n;
    final controller = TextEditingController(
        text: current > 0 ? current.toStringAsFixed(0) : '');
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.investmentGoalTitle),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.investmentGoalLabel),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context, parseAmount(controller.text)),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    if (result == null || !mounted) return;
    try {
      await FirebaseFunctions.instance
          .httpsCallable('setInvestmentGoal')
          .call({'amount': result});
      // Le stream du foyer rafraîchit le thermomètre.
    } catch (e) {
      debugPrint('setInvestmentGoal: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.addError)),
        );
      }
    }
  }

  Widget _buildTotalCard(double total, double prevTotal) {
    final l10n = _l10n;
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
            _periodType == 'monthly' ? l10n.monthSpending : l10n.weekSpending,
            style: TextStyle(color: context.mutedColor),
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
                  color: up ? context.palette.danger : context.palette.success,
                ),
                const SizedBox(width: 4),
                Text(
                  l10n.vsPreviousPeriod(
                    '${up ? '+' : ''}${deltaPct.toStringAsFixed(0)}',
                    formatCurrency(prevTotal),
                  ),
                  style: TextStyle(
                    fontSize: 12,
                    color: up ? context.palette.danger : context.palette.success,
                  ),
                ),
              ],
            )
          else
            Text(
              l10n.noPreviousPeriod,
              style: TextStyle(fontSize: 12, color: context.mutedColor),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryBars(
    Map<String, dynamic> byCategory,
    Map<String, dynamic> prevByCategory,
    Household household,
    DateTime? periodStart,
    DateTime? periodEnd,
  ) {
    final entries = byCategory.entries
        .map((e) => MapEntry(e.key, (e.value as num).toDouble()))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxValue = entries.isEmpty ? 1.0 : entries.first.value;
    final tappable = periodStart != null && periodEnd != null;

    return _card(
      entries.map((entry) {
        final cat = categoryOf(entry.key);
        final prev = (prevByCategory[entry.key] as num?)?.toDouble() ?? 0;
        final delta = entry.value - prev;

        return InkWell(
          onTap: tappable
              ? () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CategoryTransactionsScreen(
                        householdId: household.id,
                        categoryKey: entry.key,
                        periodStart: periodStart,
                        periodEnd: periodEnd,
                      ),
                    ),
                  )
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(cat.icon, size: 16, color: cat.color),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(cat.labelFor(_lang),
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
                          color: delta > 0 ? context.palette.danger : context.palette.success,
                        ),
                      ),
                    ],
                    if (tappable) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right,
                          size: 16, color: context.mutedColor),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (entry.value / maxValue).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: context.borderColor,
                    valueColor: AlwaysStoppedAnimation<Color>(cat.color),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecurringCard(Household household, Map<String, dynamic> r) {
    final l10n = _l10n;
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
          color: context.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.borderColor),
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
              l10n.recurringInfo(
                _frequencyLabel(label),
                '$occurrences',
                formatCurrency(monthly),
              ),
              style: TextStyle(fontSize: 12, color: context.mutedColor),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _dismissRecurring(household, name),
                  child: Text(
                    l10n.ignore,
                    style: TextStyle(color: context.mutedColor),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _addRecurring(name, monthly),
                  child: Text(l10n.addToBudget),
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
            _sectionTitle(_l10n.monthEnvelopes),
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
                    ? context.palette.danger
                    : (warn ? context.palette.warning : cat.color);

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
                            child: Text(cat.labelFor(_lang),
                                style: const TextStyle(fontSize: 13)),
                          ),
                          Text(
                            _l10n.spentOfBudget(
                              formatCurrency(spent),
                              formatCurrency(budget),
                            ),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: over ? context.palette.danger : Colors.white,
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
                          backgroundColor: context.borderColor,
                          valueColor: AlwaysStoppedAnimation<Color>(barColor),
                        ),
                      ),
                      if (over)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            _l10n.overBudgetBy(
                              formatCurrency(spent - budget),
                            ),
                            style: TextStyle(
                                fontSize: 11, color: context.palette.danger),
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
    final l10n = _l10n;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
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
            Text(
              l10n.aiDisclaimer,
              style: TextStyle(fontSize: 11, color: context.mutedColor),
            ),
            const SizedBox(height: 12),
          ] else ...[
            const Icon(Icons.auto_awesome, color: AppColors.primary, size: 32),
            const SizedBox(height: 8),
            Text(
              l10n.aiPitch,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.mutedColor, fontSize: 13),
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
                        ? l10n.generateAdvice
                        : l10n.regenerateAdvice,
                  ),
                  style: ElevatedButton.styleFrom(
                    
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
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: context.mutedColor,
        ),
      ),
    );
  }

  Widget _card(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(children: children),
    );
  }
}
