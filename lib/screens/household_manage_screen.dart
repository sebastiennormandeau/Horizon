import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:cloud_functions/cloud_functions.dart';

import '../l10n/app_localizations.dart';
import '../models/household.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/household_loader.dart';
import 'transition_advice_screen.dart';

/// Gestion du foyer : passage solo ↔ couple, invitation, séparation et
/// remise à zéro des données financières.
///
/// Tout ce qui change la composition du foyer est regroupé ici plutôt que
/// dispersé dans l'accueil : ce sont des actions rares, délibérées, et pour
/// certaines irréversibles.
class HouseholdManageScreen extends StatefulWidget {
  const HouseholdManageScreen({super.key});

  @override
  State<HouseholdManageScreen> createState() => _HouseholdManageScreenState();
}

class _HouseholdManageScreenState extends State<HouseholdManageScreen> {
  bool _busy = false;

  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Exécute une fonction serveur en gérant l'occupation et les erreurs.
  /// Retourne les données en cas de succès, `null` en cas d'échec.
  Future<Map<String, dynamic>?> _call(
    String name, [
    Map<String, dynamic>? params,
  ]) async {
    setState(() => _busy = true);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(name);
      final result = await callable.call(params);
      return Map<String, dynamic>.from(result.data as Map? ?? {});
    } on FirebaseFunctionsException catch (e) {
      _snack(e.message ?? _l10n.householdActionError);
      return null;
    } catch (e) {
      debugPrint('Erreur $name: $e');
      _snack(_l10n.householdActionError);
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Boîte de confirmation exigeant la saisie exacte d'un mot-clé.
  Future<bool> _confirmWithKeyword({
    required String title,
    required String body,
    required String keyword,
    required String actionLabel,
  }) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(body),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: keyword,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context, controller.text.trim() == keyword),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _enableCoupleMode() async {
    final l10n = _l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(l10n.invitePartnerTitle),
        content: Text(l10n.invitePartnerBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text(l10n.invitePartnerAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final result = await _call('enableCoupleMode');
    if (result == null || !mounted) return;
    _snack(l10n.invitePartnerDone);
    // Le foyer existe toujours : une simple pile par-dessus suffit.
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const TransitionAdviceScreen(transition: 'to_couple'),
      ),
    );
  }

  Future<void> _revertToSolo() async {
    final l10n = _l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(l10n.backToSoloTitle),
        content: Text(l10n.backToSoloBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text(l10n.backToSoloAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    if (await _call('revertToSolo') != null) _snack(l10n.backToSoloDone);
  }

  Future<void> _leaveHousehold(Household household, String uid) async {
    final l10n = _l10n;
    final partnerName = household.isUserA(uid) ? household.nameB : household.nameA;

    final confirmed = await _confirmWithKeyword(
      title: l10n.leaveHouseholdTitle,
      body: l10n.leaveHouseholdBody(partnerName, l10n.leaveKeyword),
      keyword: l10n.leaveKeyword,
      actionLabel: l10n.leaveHouseholdAction,
    );
    if (!confirmed || !mounted) return;

    if (await _call('leaveHousehold') == null || !mounted) return;
    _snack(l10n.leaveHouseholdDone);

    // Le foyer n'est plus accessible : on vide la pile jusqu'à AuthRouter
    // (qui affichera la création de foyer) et on pose les conseils par-dessus.
    await Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const TransitionAdviceScreen(transition: 'to_solo'),
      ),
      (route) => route.isFirst,
    );
  }

  Future<void> _resetData() async {
    final l10n = _l10n;
    final confirmed = await _confirmWithKeyword(
      title: l10n.resetDataTitle,
      body: l10n.resetDataBody(l10n.resetKeyword),
      keyword: l10n.resetKeyword,
      actionLabel: l10n.resetDataAction,
    );
    if (!confirmed || !mounted) return;

    final result = await _call('resetHouseholdData');
    if (result == null) return;
    _snack(l10n.resetDataDone((result['transactions_deleted'] as num?)?.toInt() ?? 0));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.householdManageTitle)),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : HouseholdLoader(
              builder: (context, household, uid) {
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildStatusCard(household, uid),
                    const SizedBox(height: 24),
                    ..._buildModeSection(household, uid),
                    const SizedBox(height: 24),
                    _buildDangerZone(household, uid),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildStatusCard(Household household, String uid) {
    final l10n = _l10n;
    final String status;
    final IconData icon;

    if (household.isSolo) {
      status = l10n.householdStatusSolo;
      icon = Icons.person;
    } else if (household.awaitingPartner) {
      status = l10n.householdStatusWaiting;
      icon = Icons.hourglass_empty;
    } else {
      final partner = household.isUserA(uid) ? household.nameB : household.nameA;
      status = l10n.householdStatusCouple(partner);
      icon = Icons.people;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(status, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }

  /// Actions disponibles selon la composition actuelle du foyer.
  List<Widget> _buildModeSection(Household household, String uid) {
    final l10n = _l10n;

    // Seul(e) : proposer d'ouvrir le foyer.
    if (household.isSolo) {
      return [
        _sectionTitle(l10n.invitePartnerTitle),
        _card([
          ListTile(
            leading: const Icon(Icons.group_add, color: AppColors.primary),
            title: Text(l10n.invitePartnerAction),
            subtitle: Text(l10n.invitePartnerBody),
            isThreeLine: true,
            onTap: _enableCoupleMode,
          ),
        ]),
      ];
    }

    // Mode couple sans partenaire : afficher le code et permettre le retour.
    if (household.awaitingPartner) {
      return [
        _sectionTitle(l10n.shareCodeTitle),
        _card([
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(l10n.shareCodeBody),
          ),
          Center(
            child: SelectableText(
              household.joinCode ?? '——————',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 6,
                color: AppColors.primary,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: household.joinCode ?? ''),
              );
              _snack(l10n.codeCopied);
            },
            icon: const Icon(Icons.copy, size: 18),
            label: Text(l10n.copyCode),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.undo, color: Colors.grey),
            title: Text(l10n.backToSoloTitle),
            subtitle: Text(l10n.backToSoloBody),
            isThreeLine: true,
            onTap: _revertToSolo,
          ),
        ]),
      ];
    }

    // Foyer complet : seule la personne concernée peut partir.
    return [
      _sectionTitle(l10n.householdSection),
      _card([
        ListTile(
          leading: const Icon(Icons.info_outline, color: Colors.grey),
          title: Text(
            l10n.cannotRemovePartner,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ),
      ]),
    ];
  }

  Widget _buildDangerZone(Household household, String uid) {
    final l10n = _l10n;
    final debt = household.internalDebtBalance;
    // La réinitialisation efface aussi les données du partenaire : réservée
    // au premier membre, comme côté serveur.
    final canReset = household.isSolo || household.isUserA(uid);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(l10n.accountSection),
        _card([
          if (canReset)
            ListTile(
              leading: const Icon(Icons.restart_alt, color: Colors.orange),
              title: Text(
                l10n.resetDataTitle,
                style: const TextStyle(color: Colors.orange),
              ),
              subtitle: Text(l10n.resetDataSubtitle),
              onTap: _resetData,
            ),
          if (!household.awaitingPartner) ...[
            if (canReset) const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.heart_broken, color: Colors.redAccent),
              title: Text(
                l10n.leaveHouseholdTitle,
                style: const TextStyle(color: Colors.redAccent),
              ),
              subtitle: Text(
                debt.abs() >= 0.01
                    ? l10n.leaveDebtWarning(formatCurrency(debt.abs()))
                    : l10n.leaveHouseholdSubtitle,
              ),
              onTap: () => _leaveHousehold(household, uid),
            ),
          ],
        ]),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
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
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(children: children),
    );
  }
}
