import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../l10n/app_localizations.dart';
import '../services/plaid_service.dart';
import '../theme/app_colors.dart';

/// Comptes bancaires reliés au foyer : état, synchronisation manuelle,
/// déconnexion et ajout.
///
/// Les données viennent d'une fonction serveur et non de Firestore : la
/// collection `bank_connections` contient les jetons d'accès Plaid et son
/// accès client est interdit par les règles. `listBankConnections` n'en
/// renvoie que la part affichable.
class BankConnectionsScreen extends StatefulWidget {
  const BankConnectionsScreen({super.key});

  @override
  State<BankConnectionsScreen> createState() => _BankConnectionsScreenState();
}

class _BankConnectionsScreenState extends State<BankConnectionsScreen> {
  bool _loading = true;
  bool _busy = false;
  String? _error;
  List<Map<String, dynamic>> _connections = [];

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
          FirebaseFunctions.instance.httpsCallable('listBankConnections');
      final result = await callable.call();
      final raw = (result.data['connections'] as List?) ?? [];
      if (!mounted) return;
      setState(() {
        _connections =
            raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
      });
    } catch (e) {
      debugPrint('Erreur listBankConnections: $e');
      if (!mounted) return;
      setState(() {
        _error = _l10n.loadingError;
        _loading = false;
      });
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _syncNow() async {
    setState(() => _busy = true);
    _snack(_l10n.bankSyncing);
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('syncBankConnections');
      final result = await callable.call();
      final imported = (result.data['imported'] as num?)?.toInt() ?? 0;
      // Zéro n'est pas une erreur : après une première connexion, Plaid livre
      // l'historique de façon différée, par webhook.
      _snack(imported > 0
          ? _l10n.bankSyncDone(imported)
          : _l10n.bankSyncNothing);
      await _load();
    } on FirebaseFunctionsException catch (e) {
      _snack(e.message ?? _l10n.syncError);
    } catch (e) {
      debugPrint('Erreur syncBankConnections: $e');
      _snack(_l10n.syncError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disconnect(Map<String, dynamic> connection) async {
    final l10n = _l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.bankDisconnectTitle),
        content: Text(l10n.bankDisconnectBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.palette.danger,
            ),
            child: Text(l10n.bankDisconnect),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('removeBankConnection');
      await callable.call({'item_id': connection['item_id']});
      _snack(l10n.bankDisconnected);
      await _load();
    } on FirebaseFunctionsException catch (e) {
      _snack(e.message ?? l10n.householdActionError);
    } catch (e) {
      debugPrint('Erreur removeBankConnection: $e');
      _snack(l10n.householdActionError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Marque un compte comme conjoint ou personnel.
  ///
  /// Sans ce réglage, un compte conjoint relié par une seule personne ferait
  /// grossir la dette interne indéfiniment : Plaid attribue toutes ses
  /// transactions à l'identifiant qui a établi la connexion.
  Future<void> _setJoint(
    Map<String, dynamic> connection,
    String accountId,
    bool isJoint,
  ) async {
    setState(() => _busy = true);
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('setBankConnectionJoint');
      await callable.call({
        'item_id': connection['item_id'],
        'account_id': accountId,
        'is_joint': isJoint,
      });
      // La bascule ne rejoue pas l'historique des assignations : on le dit
      // plutôt que de laisser croire à une correction rétroactive.
      _snack(isJoint
          ? '${_l10n.bankJointUpdated} ${_l10n.bankJointDebtNote}'
          : _l10n.bankJointUpdated);
      await _load();
    } on FirebaseFunctionsException catch (e) {
      _snack(e.message ?? _l10n.householdActionError);
    } catch (e) {
      debugPrint('Erreur setBankConnectionJoint: $e');
      _snack(_l10n.householdActionError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addBank() async {
    try {
      await PlaidService.open();
    } catch (e) {
      debugPrint('Erreur Plaid: $e');
      _snack(_l10n.plaidError);
    }
  }

  /// Date lisible, sans dépendance à intl : l'app formate déjà ses montants
  /// à la main pour la même raison.
  String _formatDate(String? iso) {
    if (iso == null) return _l10n.bankNeverSynced;
    final date = DateTime.tryParse(iso)?.toLocal();
    if (date == null) return _l10n.bankNeverSynced;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} '
        '${two(date.hour)}:${two(date.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.bankManageTitle)),
      body: _loading || _busy
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null)
                    Text(
                      _error!,
                      style: TextStyle(color: context.palette.danger),
                    )
                  else if (_connections.isEmpty)
                    _buildEmpty()
                  else
                    ..._connections.map(_buildConnectionCard),
                  const SizedBox(height: 20),
                  if (_connections.isNotEmpty) ...[
                    OutlinedButton.icon(
                      onPressed: _syncNow,
                      icon: const Icon(Icons.sync),
                      label: Text(l10n.bankSyncNow),
                    ),
                    const SizedBox(height: 10),
                  ],
                  ElevatedButton.icon(
                    onPressed: _addBank,
                    icon: const Icon(Icons.add),
                    label: Text(
                      _connections.isEmpty
                          ? l10n.connectMyBank
                          : l10n.bankAddAnother,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l10n.bankFreePlanLimit,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: context.mutedColor),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildEmpty() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        children: [
          Icon(Icons.account_balance_outlined, color: context.mutedColor),
          const SizedBox(width: 12),
          Expanded(child: Text(_l10n.bankNone)),
        ],
      ),
    );
  }

  Widget _buildConnectionCard(Map<String, dynamic> connection) {
    final l10n = _l10n;
    final isMine = connection['is_mine'] == true;
    final name =
        (connection['institution_name'] as String?)?.trim().isNotEmpty == true
            ? connection['institution_name'] as String
            : l10n.bankUnknownInstitution;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.account_balance,
                size: 21, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  l10n.bankLastSync(
                    _formatDate(connection['last_synced_at'] as String?),
                  ),
                  style: TextStyle(fontSize: 12, color: context.mutedColor),
                ),
                if (!isMine)
                  Text(
                    l10n.bankPartnerAccount,
                    style: TextStyle(fontSize: 12, color: context.mutedColor),
                  ),
              ],
            ),
          ),
          // Seule la personne qui a relié la banque peut la déconnecter :
          // couper l'accès bancaire de son partenaire n'appartient à personne.
          if (isMine)
            IconButton(
              tooltip: l10n.bankDisconnect,
              icon: Icon(Icons.link_off, color: context.palette.danger),
              onPressed: () => _disconnect(connection),
            ),
            ],
          ),
          // Réglage par COMPTE et non par connexion : une même banque héberge
          // couramment le compte personnel et le compte conjoint, qui
          // n'appellent pas le même traitement de la dette interne.
          ..._buildAccountToggles(connection),
        ],
      ),
    );
  }

  List<Widget> _buildAccountToggles(Map<String, dynamic> connection) {
    final l10n = _l10n;
    final accounts = (connection['accounts'] as List?) ?? [];
    if (accounts.isEmpty) return const [];
    final jointIds =
        ((connection['joint_account_ids'] as List?) ?? []).cast<String>();

    return [
      const Divider(height: 20),
      Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          l10n.bankJointLabel,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
      for (final raw in accounts)
        Builder(builder: (context) {
          final a = Map<String, dynamic>.from(raw as Map);
          final id = a['account_id'] as String? ?? '';
          final isJoint = jointIds.contains(id);
          final mask = a['mask'] as String?;
          return SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: isJoint,
            onChanged: (v) => _setJoint(connection, id, v),
            title: Text(
              mask == null || mask.isEmpty
                  ? (a['name'] as String? ?? '—')
                  : '${a['name'] ?? '—'} ••$mask',
              style: const TextStyle(fontSize: 13.5),
            ),
            subtitle: Text(
              isJoint ? l10n.bankJointHint : l10n.bankPersonalHint,
              style: TextStyle(fontSize: 11.5, color: context.mutedColor),
            ),
          );
        }),
    ];
  }
}
