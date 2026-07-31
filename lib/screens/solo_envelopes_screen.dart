import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../l10n/app_localizations.dart';
import '../models/household.dart';
import '../theme/app_colors.dart';
import '../utils/categories.dart';
import '../utils/formatters.dart';

/// Budget variable d'UNE cagnotte : une enveloppe (montant mensuel) par
/// catégorie, qui en réserve une part. Les montants sont suggérés à partir des
/// moyennes des 3 derniers mois ; l'utilisateur ajuste.
///
/// Sert les trois cagnottes : `Solo_A`/`Solo_B` (personnelles, propres à
/// l'appelant) et `Common` (partagée). Seul le couple de callables change —
/// l'écran, lui, est identique, ce qui garde le même geste partout.
class SoloEnvelopesScreen extends StatefulWidget {
  final Household household;
  final String uid;

  /// Cagnotte visée. `null` = la cagnotte solo de l'utilisateur connecté.
  final String? bucket;

  const SoloEnvelopesScreen({
    super.key,
    required this.household,
    required this.uid,
    this.bucket,
  });

  @override
  State<SoloEnvelopesScreen> createState() => _SoloEnvelopesScreenState();
}

class _SoloEnvelopesScreenState extends State<SoloEnvelopesScreen> {
  final Map<String, TextEditingController> _controllers = {};
  Map<String, int> _suggestions = const {};
  bool _loadingSuggestions = true;
  bool _saving = false;

  AppLocalizations get _l10n => AppLocalizations.of(context)!;
  String get _lang => Localizations.localeOf(context).languageCode;

  /// Cagnotte visée, repli sur la cagnotte solo de l'appelant.
  String get _bucket =>
      widget.bucket ?? widget.household.soloBucketFor(widget.uid);
  bool get _isCommon => _bucket == 'Common';
  String get _suggestCallable =>
      _isCommon ? 'suggestCommonEnvelopes' : 'suggestSoloEnvelopes';
  String get _saveCallable =>
      _isCommon ? 'setCommonEnvelopes' : 'setSoloEnvelopes';
  Color get _accent => _isCommon ? AppColors.primary : AppColors.solo;

  @override
  void initState() {
    super.initState();
    final existing = widget.household.envelopesOf(_bucket);
    for (final c in kSelectableCategories) {
      final amt = existing[c.key];
      _controllers[c.key] = TextEditingController(
          text: amt != null && amt > 0 ? amt.toStringAsFixed(0) : '');
    }
    _loadSuggestions();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSuggestions() async {
    try {
      final res = await FirebaseFunctions.instance
          .httpsCallable(_suggestCallable)
          .call();
      final list = (res.data['suggestions'] as List?) ?? const [];
      final map = <String, int>{};
      for (final e in list) {
        final m = Map<String, dynamic>.from(e as Map);
        map[m['category'] as String] =
            (m['monthly_average'] as num?)?.toInt() ?? 0;
      }
      if (!mounted) return;
      setState(() {
        _suggestions = map;
        _loadingSuggestions = false;
      });
    } catch (e) {
      debugPrint('$_suggestCallable: $e');
      if (!mounted) return;
      setState(() => _loadingSuggestions = false);
    }
  }

  void _applyAllSuggestions() {
    _suggestions.forEach((cat, avg) {
      _controllers[cat]?.text = '$avg';
    });
    setState(() {});
  }

  double get _total {
    double sum = 0;
    for (final c in _controllers.values) {
      sum += parseAmount(c.text);
    }
    return sum;
  }

  Future<void> _save() async {
    final envelopes = <String, double>{};
    _controllers.forEach((cat, ctrl) {
      final v = parseAmount(ctrl.text);
      if (v > 0) envelopes[cat] = v;
    });
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await FirebaseFunctions.instance
          .httpsCallable(_saveCallable)
          .call({'envelopes': envelopes});
      messenger.showSnackBar(SnackBar(content: Text(_l10n.soloEnvelopesSaved)));
      navigator.pop();
    } catch (e) {
      debugPrint('$_saveCallable: $e');
      messenger.showSnackBar(SnackBar(content: Text(_l10n.addError)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isCommon
            ? l10n.commonEnvelopesTitle
            : l10n.soloEnvelopesTitle),
        actions: [
          _saving
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : TextButton(
                  onPressed: _save,
                  child: Text(l10n.save),
                ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
              _isCommon ? l10n.commonEnvelopesIntro : l10n.soloEnvelopesIntro,
              style: TextStyle(
                  fontSize: 13, color: context.mutedColor, height: 1.45)),
          const SizedBox(height: 12),
          if (_loadingSuggestions)
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator()))
          else if (_suggestions.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _applyAllSuggestions,
                icon: const Icon(Icons.auto_fix_high, size: 18),
                label: Text(l10n.soloEnvelopesApplyAll),
              ),
            ),
          const SizedBox(height: 8),
          ...kSelectableCategories.map(_buildRow),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _accent),
            ),
            child: Row(
              children: [
                Expanded(
                    child: Text(l10n.soloEnvelopesTotal,
                        style: const TextStyle(fontWeight: FontWeight.w600))),
                Text(formatCurrency(_total),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(TxCategory cat) {
    final suggestion = _suggestions[cat.key];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(cat.icon, size: 18, color: cat.color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cat.labelFor(_lang), style: const TextStyle(fontSize: 14)),
                if (suggestion != null && suggestion > 0)
                  GestureDetector(
                    onTap: () {
                      _controllers[cat.key]?.text = '$suggestion';
                      setState(() {});
                    },
                    child: Text(
                      _l10n.soloEnvelopesSuggestion(
                          formatCurrency(suggestion.toDouble())),
                      style:
                          TextStyle(fontSize: 11.5, color: context.mutedColor),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 96,
            child: TextField(
              controller: _controllers[cat.key],
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.right,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                isDense: true,
                hintText: '0',
                prefixText: '\$ ',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
