import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_colors.dart';
import '../utils/budget_calculator.dart';
import '../utils/categories.dart';
import '../utils/formatters.dart';

class BudgetSetupScreen extends StatefulWidget {
  const BudgetSetupScreen({super.key});

  @override
  State<BudgetSetupScreen> createState() => _BudgetSetupScreenState();
}

class _BudgetSetupScreenState extends State<BudgetSetupScreen> {
  final _incomeAController = TextEditingController(text: '0');
  final _incomeBController = TextEditingController(text: '0');

  String _payFrequency = 'Bi-hebdomadaire';
  DateTime? _nextPayDate;

  List<Map<String, dynamic>> _fixedExpenses = [];
  List<Map<String, dynamic>> _deductions = [];
  List<Map<String, dynamic>> _categoryBudgets = [];

  double _splitRatioA = 60.0;
  final _alertThresholdController = TextEditingController(text: '100');
  bool _isLoading = false;
  bool _isInitializing = true;

  final List<String> _frequencies = [
    'Mensuel',
    'Bi-hebdomadaire',
    'Hebdomadaire',
  ];
  final List<String> _months = [
    'J',
    'F',
    'M',
    'A',
    'M',
    'J',
    'J',
    'A',
    'S',
    'O',
    'N',
    'D',
  ];

  double get _totalExpenses => _fixedExpenses.fold(
      0.0, (acc, item) => acc + ((item['amount'] as num?)?.toDouble() ?? 0.0));
  double get _totalDeductions => _deductions.fold(
      0.0, (acc, item) => acc + ((item['amount'] as num?)?.toDouble() ?? 0.0));
  double get _netCommunalExpenses => _totalExpenses - _totalDeductions;

  double get _contributionA => _netCommunalExpenses * (_splitRatioA / 100);
  double get _contributionB =>
      _netCommunalExpenses * ((100 - _splitRatioA) / 100);

  @override
  void initState() {
    super.initState();
    _loadCurrentBudget();
  }

  Future<void> _loadCurrentBudget() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final householdId = userDoc.data()?['household_id'];

        if (householdId != null) {
          final now = DateTime.now();
          final monthStr =
              "${now.year}-${now.month.toString().padLeft(2, '0')}";

          final budgetDoc = await FirebaseFirestore.instance
              .collection('households')
              .doc(householdId)
              .collection('monthly_budgets')
              .doc(monthStr)
              .get();

          if (budgetDoc.exists) {
            final data = budgetDoc.data()!;
            setState(() {
              _incomeAController.text = (data['income_A'] ?? 0).toString();
              _incomeBController.text = (data['income_B'] ?? 0).toString();
              _payFrequency = data['pay_frequency'] ?? 'Bi-hebdomadaire';
              if (data['next_pay_date'] != null) {
                _nextPayDate = DateTime.tryParse(data['next_pay_date']);
              }

              if (data['fixed_expenses'] != null) {
                _fixedExpenses =
                    List<Map<String, dynamic>>.from(data['fixed_expenses'])
                        .map(
                          (e) => {
                            'id':
                                DateTime.now().microsecondsSinceEpoch
                                    .toString() +
                                e['name'].toString(),
                            'name': e['name'],
                            // Firestore renvoie les entiers en int : cast sûr.
                            'amount':
                                (e['amount'] as num?)?.toDouble() ?? 0.0,
                          },
                        )
                        .toList();
              }

              if (data['deductions'] != null) {
                _deductions =
                    List<Map<String, dynamic>>.from(data['deductions'])
                        .map(
                          (e) => {
                            'id':
                                DateTime.now().microsecondsSinceEpoch
                                    .toString() +
                                e['name'].toString(),
                            'name': e['name'],
                            'amount':
                                (e['amount'] as num?)?.toDouble() ?? 0.0,
                          },
                        )
                        .toList();
              }

              if (data['category_budgets'] != null) {
                _categoryBudgets =
                    List<Map<String, dynamic>>.from(data['category_budgets'])
                        .map(
                          (e) => {
                            'id': DateTime.now()
                                    .microsecondsSinceEpoch
                                    .toString() +
                                e['category'].toString(),
                            'category': e['category'] ?? 'OTHER',
                            'amount':
                                (e['amount'] as num?)?.toDouble() ?? 0.0,
                          },
                        )
                        .toList();
              }

              _splitRatioA = (data['split_ratio_A'] ?? 60).toDouble();
            });
          }

          // Seuil d'alerte des cagnottes (document du foyer).
          final householdDoc = await FirebaseFirestore.instance
              .collection('households')
              .doc(householdId)
              .get();
          final threshold =
              (householdDoc.data()?['alert_threshold'] as num?)?.toDouble();
          if (threshold != null && mounted) {
            setState(() =>
                _alertThresholdController.text = threshold.toStringAsFixed(0));
          }
        }
      }
    } catch (e) {
      debugPrint('Erreur de chargement du budget: $e');
    } finally {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  @override
  void dispose() {
    _incomeAController.dispose();
    _incomeBController.dispose();
    _alertThresholdController.dispose();
    super.dispose();
  }

  void _addCategoryBudget() {
    setState(() {
      _categoryBudgets.add({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'category': 'FOOD_AND_DRINK',
        'amount': 0.0,
      });
    });
  }

  void _addExpense() {
    setState(() {
      _fixedExpenses.add({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'name': 'Nouvelle dépense',
        'amount': 0.0,
      });
    });
  }

  void _addDeduction() {
    setState(() {
      _deductions.add({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'name': 'Nouvelle allocation',
        'amount': 0.0,
      });
    });
  }

  Future<void> _selectNextPayDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _nextPayDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (mounted && picked != null && picked != _nextPayDate) {
      setState(() {
        _nextPayDate = picked;
      });
    }
  }

  Future<void> _saveBudget() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Non connecté");

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final householdId = userDoc.data()?['household_id'];
      if (householdId == null) throw Exception("Foyer introuvable");

      final now = DateTime.now();
      final monthStr = "${now.year}-${now.month.toString().padLeft(2, '0')}";

      // Suppression de la clé 'id' avant sauvegarde
      final cleanExpenses = _fixedExpenses
          .map((e) => {'name': e['name'], 'amount': e['amount']})
          .toList();
      final cleanDeductions = _deductions
          .map((e) => {'name': e['name'], 'amount': e['amount']})
          .toList();

      final incA = parseAmount(_incomeAController.text);
      final incB = parseAmount(_incomeBController.text);

      await FirebaseFirestore.instance
          .collection('households')
          .doc(householdId)
          .collection('monthly_budgets')
          .doc(monthStr)
          .set({
            'income_A': incA,
            'income_B': incB,
            'pay_frequency': _payFrequency,
            'next_pay_date': _nextPayDate?.toIso8601String(),
            'fixed_expenses': cleanExpenses,
            'deductions': cleanDeductions,
            'category_budgets': _categoryBudgets
                .map((e) => {
                      'category': e['category'],
                      'amount': e['amount'],
                    })
                .toList(),
            'split_ratio_A': _splitRatioA.round(),
            'split_ratio_B': (100 - _splitRatioA).round(),
            'updated_at': FieldValue.serverTimestamp(),
          });

      // Mise à jour des cagnottes (Safe-to-Spend) dans le document parent
      final safeSoloA = incA - _contributionA;
      final safeSoloB = incB - _contributionB;

      await FirebaseFirestore.instance
          .collection('households')
          .doc(householdId)
          .update({
            'safe_to_spend_common': _netCommunalExpenses,
            'safe_to_spend_solo_A': safeSoloA,
            'safe_to_spend_solo_B': safeSoloB,
            // Ratio utilisé par la Cloud Function pour la dette interne.
            'split_ratio_user_A': _splitRatioA.round(),
            'split_ratio_user_B': (100 - _splitRatioA).round(),
            // Seuil sous lequel les cagnottes passent en alerte.
            'alert_threshold': parseAmount(_alertThresholdController.text),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Budget mensuel sauvegardé !')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Erreur de sauvegarde du budget: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la sauvegarde.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Éditeur des enveloppes : un budget mensuel par catégorie de dépense
  /// variable (épicerie, restos…), suivi dans l'écran Bilan.
  Widget _buildCategoryBudgetsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Enveloppes par catégorie',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle, color: AppColors.primary),
              onPressed: _addCategoryBudget,
            ),
          ],
        ),
        const Text(
          'Budgets mensuels pour vos dépenses variables — le Bilan suit '
          'leur progression.',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 8),
        ..._categoryBudgets.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          return Padding(
            key: ValueKey(item['id']),
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    initialValue: item['category'] as String?,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Catégorie',
                      border: OutlineInputBorder(),
                    ),
                    items: kSelectableCategories
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.key,
                            child: Row(
                              children: [
                                Icon(c.icon, size: 16, color: c.color),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    c.label,
                                    style: const TextStyle(fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _categoryBudgets[idx]['category'] = v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    initialValue: (item['amount'] as double).toString(),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Budget',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) =>
                        _categoryBudgets[idx]['amount'] = parseAmount(val),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: () =>
                      setState(() => _categoryBudgets.removeAt(idx)),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildMagicMonths() {
    List<int> magicMonths = [];
    if (_nextPayDate != null) {
      magicMonths = BudgetCalculator.calculateMagicMonths(
        _payFrequency,
        _nextPayDate!,
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Calendrier des Mois Magiques 🌟',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Un mois magique contient une paie supplémentaire.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(12, (index) {
              bool isMagic = magicMonths.contains(index + 1);
              return Column(
                children: [
                  Text(
                    _months[index],
                    style: TextStyle(
                      color: isMagic ? Colors.amber : Colors.grey,
                      fontWeight: isMagic ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (isMagic)
                    const Icon(Icons.star, color: Colors.amber, size: 16)
                  else
                    const SizedBox(height: 16),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildListSection(
    String title,
    List<Map<String, dynamic>> items,
    VoidCallback onAdd,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle, color: AppColors.primary),
              onPressed: onAdd,
            ),
          ],
        ),
        ...items.asMap().entries.map((entry) {
          int idx = entry.key;
          var item = entry.value;
          return Padding(
            key: ValueKey(item['id']),
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    initialValue: item['name'],
                    decoration: const InputDecoration(
                      labelText: 'Nom',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) => items[idx]['name'] =
                        val, // No setState to prevent focus loss
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    initialValue: item['amount'].toString(),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Montant',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      items[idx]['amount'] = parseAmount(val);
                      setState(() {}); // Minimal setState to update totals
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: () => setState(() => items.removeAt(idx)),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuration Budget ZBB')),
      body: _isLoading || _isInitializing
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // REVENUS
                  const Text(
                    'Revenus',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _incomeAController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Revenu A',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _incomeBController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Revenu B',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _payFrequency,
                    decoration: const InputDecoration(
                      labelText: 'Fréquence de paie',
                      border: OutlineInputBorder(),
                    ),
                    items: _frequencies
                        .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                        .toList(),
                    onChanged: (v) => setState(() => _payFrequency = v!),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: const Text('Prochaine date de paie'),
                    subtitle: Text(
                      _nextPayDate == null
                          ? 'Sélectionner une date'
                          : "${_nextPayDate!.day}/${_nextPayDate!.month}/${_nextPayDate!.year}",
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: Colors.white12),
                    ),
                    onTap: () => _selectNextPayDate(context),
                  ),
                  const SizedBox(height: 24),

                  // MAGIC MONTHS
                  _buildMagicMonths(),
                  const SizedBox(height: 24),

                  // DEDUCTIONS (ALLOCATIONS)
                  _buildListSection(
                    'Allocations & Déductions',
                    _deductions,
                    _addDeduction,
                  ),
                  const SizedBox(height: 24),

                  // DEPENSES FIXES
                  _buildListSection(
                    'Dépenses Fixes Communes',
                    _fixedExpenses,
                    _addExpense,
                  ),
                  const SizedBox(height: 24),

                  // ENVELOPPES PAR CATÉGORIE
                  _buildCategoryBudgetsSection(),
                  const SizedBox(height: 24),

                  // SEUIL D'ALERTE
                  const Text(
                    'Seuil d\'alerte des cagnottes',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'En dessous de ce montant, une cagnotte passe en orange '
                    'sur le tableau de bord.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _alertThresholdController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Seuil (\$)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // SLIDER RATIO
                  const Text(
                    'Répartition pro-rata',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('User A: ${_splitRatioA.round()}%'),
                      Text('User B: ${(100 - _splitRatioA).round()}%'),
                    ],
                  ),
                  Slider(
                    value: _splitRatioA,
                    min: 0,
                    max: 100,
                    activeColor: AppColors.primary,
                    onChanged: (val) => setState(() => _splitRatioA = val),
                  ),
                  const SizedBox(height: 140), // Espace pour la bottom bar
                ],
              ),
            ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: Colors.white12)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Dépenses nettes communes :',
                  style: TextStyle(color: Colors.grey),
                ),
                Text(
                  formatCurrency(_netCommunalExpenses),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'A paie : ${formatCurrency(_contributionA)}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'B paie : ${formatCurrency(_contributionB)}',
                  style: const TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveBudget,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Sauvegarder le Budget',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
