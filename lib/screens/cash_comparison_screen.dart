import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../l10n/app_localizations.dart';
import '../models/household.dart';
import '../services/plaid_service.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';

/// Comparaison entre le **vrai solde** des comptes de dépôt personnels de
/// l'utilisateur (chèque/épargne, hors conjoint) et sa cagnotte solo.
///
/// But : voir d'un coup d'œil ce qu'il y a réellement à la banque en regard de
/// ce que l'app dit « disponible ». Les soldes viennent d'un callable, jamais
/// de Firestore : `bank_connections` est interdit de lecture cliente.
class CashComparisonScreen extends StatefulWidget {
  final Household household;
  final String uid;

  const CashComparisonScreen({
    super.key,
    required this.household,
    required this.uid,
  });

  @override
  State<CashComparisonScreen> createState() => _CashComparisonScreenState();
}

class _CashAccount {
  final String name;
  final String? mask;
  final String? subtype;
  final double balance;
  final String? institutionName;
  final bool isJoint;

  const _CashAccount({
    required this.name,
    required this.mask,
    required this.subtype,
    required this.balance,
    required this.institutionName,
    required this.isJoint,
  });
}

class _CashComparisonScreenState extends State<CashComparisonScreen> {
  bool _loading = true;
  String? _error;
  List<_CashAccount> _accounts = const [];
  List<Map<String, dynamic>> _reauth = const [];

  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('getMyCashBalances');
      final res = await callable.call();
      final raw = (res.data['accounts'] as List?) ?? const [];
      final accounts = raw.map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return _CashAccount(
          name: (m['name'] as String?) ?? _l10n.acctDeposit,
          mask: m['mask'] as String?,
          subtype: m['subtype'] as String?,
          balance: (m['balance'] as num?)?.toDouble() ?? 0,
          institutionName: m['institution_name'] as String?,
          isJoint: m['is_joint'] == true,
        );
      }).toList();
      final reauth = ((res.data['reauth'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _reauth = reauth;
        _loading = false;
      });
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message ?? _l10n.realBalanceError;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Erreur getMyCashBalances: $e');
      if (!mounted) return;
      setState(() {
        _error = _l10n.realBalanceError;
        _loading = false;
      });
    }
  }

  String _subtypeLabel(String? subtype) {
    switch (subtype) {
      case 'checking':
        return _l10n.acctChecking;
      case 'savings':
        return _l10n.acctSavings;
      default:
        return _l10n.acctDeposit;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.realBalanceTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.realBalanceRefresh,
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.mutedColor)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _load,
                child: Text(_l10n.realBalanceRefresh),
              ),
            ],
          ),
        ),
      );
    }

    final l10n = _l10n;
    final mine = _accounts.where((a) => !a.isJoint).toList();
    final joint = _accounts.where((a) => a.isJoint).toList();
    final total = mine.fold<double>(0, (s, a) => s + a.balance);
    final solo = widget.household.mySoloBalance(widget.uid);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        if (_reauth.isNotEmpty) ...[
          _reauthCard(_reauth.first),
          const SizedBox(height: 12),
        ],
        _comparisonCard(total, solo),
        const SizedBox(height: 12),
        Text(
          l10n.realBalanceNote,
          style: TextStyle(
              fontSize: 12.5, color: context.mutedColor, height: 1.45),
        ),
        const SizedBox(height: 20),
        Text(l10n.realBalanceMyAccounts,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: context.mutedColor)),
        const SizedBox(height: 8),
        if (mine.isEmpty)
          Text(l10n.realBalanceEmpty,
              style: TextStyle(color: context.mutedColor, fontSize: 13))
        else
          ...mine.map((a) => _accountTile(a, muted: false)),
        if (joint.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(l10n.realBalanceJoint,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: context.mutedColor)),
          const SizedBox(height: 8),
          ...joint.map((a) => _accountTile(a, muted: true)),
        ],
      ],
    );
  }

  Widget _reauthCard(Map<String, dynamic> item) {
    final l10n = _l10n;
    final inst = (item['institution_name'] as String?)?.trim() ?? '';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.palette.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.palette.warning),
      ),
      child: Row(
        children: [
          Icon(Icons.link_off, color: context.palette.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              inst.isEmpty
                  ? l10n.bankReauthNeeded
                  : l10n.bankReauthNeededNamed(inst),
              style: TextStyle(color: context.palette.warning, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: () => PlaidService.open(
                updateItemId: item['item_id'] as String),
            child: Text(l10n.bankReconnect),
          ),
        ],
      ),
    );
  }

  Widget _comparisonCard(double real, double solo) {
    final l10n = _l10n;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary),
      ),
      child: Column(
        children: [
          _amountRow(l10n.realBalanceAvailable, real, AppColors.primary),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: context.borderColor),
          ),
          _amountRow(l10n.realBalanceSoloPot, solo, AppColors.solo),
        ],
      ),
    );
  }

  Widget _amountRow(String label, double amount, Color accent) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: TextStyle(fontSize: 14, color: context.mutedColor)),
        ),
        Text(
          formatCurrency(amount),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: amount < 0 ? context.palette.danger : context.colors.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _accountTile(_CashAccount a, {required bool muted}) {
    final subtitle = [
      _subtypeLabel(a.subtype),
      if (a.mask != null) '••${a.mask}',
      if (a.institutionName != null) a.institutionName!,
    ].join('  ·  ');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        children: [
          Icon(
            a.subtype == 'savings'
                ? Icons.savings_outlined
                : Icons.account_balance_wallet_outlined,
            size: 20,
            color: muted ? context.mutedColor : AppColors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14.5)),
                const SizedBox(height: 2),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(fontSize: 12, color: context.mutedColor)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            formatCurrency(a.balance),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              color: muted ? context.mutedColor : context.colors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
