import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../l10n/app_localizations.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../widgets/household_loader.dart';

/// Réglages des notifications : activation par appareil, préférences par type,
/// délai de rappel et échéances de carte (automatiques ou saisies à la main).
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _authorized = false;
  bool _busy = false;

  // Préférences locales, synchronisées avec le document utilisateur.
  final Map<String, bool> _prefs = {
    'card_reminder': true,
    'pot_alert': true,
    'to_sort': true,
    'partner': true,
    'overspend': true,
  };
  int _leadDays = 3;
  bool _loaded = false;

  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _authorized = await NotificationService.isAuthorized();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final snap =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = snap.data() ?? {};
      final prefs = (data['notif_prefs'] as Map?) ?? {};
      for (final key in _prefs.keys) {
        if (prefs[key] is bool) _prefs[key] = prefs[key] as bool;
      }
      _leadDays = (data['notif_card_lead_days'] as num?)?.toInt() ?? 3;
    }
    if (mounted) setState(() => _loaded = true);
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _toggleDevice(bool enable) async {
    setState(() => _busy = true);
    if (enable) {
      final ok = await NotificationService.enable();
      _authorized = ok;
      _snack(ok ? _l10n.notifEnabled : _l10n.notifRefused);
    } else {
      await NotificationService.disable();
      _authorized = false;
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _savePrefs() async {
    try {
      await FirebaseFunctions.instance.httpsCallable('setNotifPrefs').call({
        'prefs': _prefs,
        'card_lead_days': _leadDays,
      });
      _snack(_l10n.notifSaved);
    } catch (e) {
      debugPrint('setNotifPrefs: $e');
      _snack(_l10n.householdActionError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.notifManageTitle)),
      body: !_loaded || _busy
          ? const Center(child: CircularProgressIndicator())
          : HouseholdLoader(
              builder: (context, household, uid) {
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildDeviceCard(),
                    const SizedBox(height: 16),
                    _sectionTitle(l10n.notifTypesTitle),
                    _buildTypesCard(),
                    const SizedBox(height: 16),
                    _sectionTitle(l10n.notifCardsTitle),
                    _buildCards(household.id),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildDeviceCard() {
    final l10n = _l10n;
    return _card([
      SwitchListTile(
        value: _authorized,
        onChanged: (v) => _toggleDevice(v),
        title: Text(l10n.notifEnableTitle),
        subtitle: Text(l10n.notifEnableBody),
        activeThumbColor: AppColors.primary,
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Text(
          l10n.notifIosHint,
          style: TextStyle(fontSize: 12, color: context.mutedColor),
        ),
      ),
    ]);
  }

  Widget _buildTypesCard() {
    final l10n = _l10n;
    final entries = <(String, String, String)>[
      ('card_reminder', l10n.notifCardReminder, l10n.notifCardReminderSub),
      ('overspend', l10n.notifOverspend, l10n.notifOverspendSub),
      ('pot_alert', l10n.notifPotAlert, l10n.notifPotAlertSub),
      ('to_sort', l10n.notifToSort, l10n.notifToSortSub),
      ('partner', l10n.notifPartner, l10n.notifPartnerSub),
    ];

    return _card([
      for (final e in entries)
        SwitchListTile(
          value: _prefs[e.$1] ?? true,
          onChanged: (v) {
            setState(() => _prefs[e.$1] = v);
            _savePrefs();
          },
          title: Text(e.$2, style: const TextStyle(fontSize: 14.5)),
          subtitle: Text(
            e.$3,
            style: TextStyle(fontSize: 12, color: context.mutedColor),
          ),
          activeThumbColor: AppColors.primary,
          dense: true,
        ),
      const Divider(height: 1),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(l10n.notifLeadDays(_leadDays),
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
      ),
      Slider(
        value: _leadDays.toDouble(),
        min: 1,
        max: 14,
        divisions: 13,
        label: '$_leadDays',
        activeColor: AppColors.primary,
        onChanged: (v) => setState(() => _leadDays = v.round()),
        onChangeEnd: (_) => _savePrefs(),
      ),
    ]);
  }

  /// Cartes de crédit du foyer : échéance automatique (liabilities) ou saisie
  /// manuelle du jour d'échéance.
  Widget _buildCards(String householdId) {
    final l10n = _l10n;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('households')
          .doc(householdId)
          .collection('cards')
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _card([
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.notifCardNone,
                style: TextStyle(fontSize: 13, color: context.mutedColor),
              ),
            ),
          ]);
        }
        return _card([
          for (final doc in docs) _buildCardTile(doc),
        ]);
      },
    );
  }

  Widget _buildCardTile(QueryDocumentSnapshot doc) {
    final l10n = _l10n;
    final c = doc.data() as Map<String, dynamic>;
    final mask = c['mask'] as String?;
    final title = mask == null
        ? (c['name'] as String? ?? 'Carte')
        : '${c['name'] ?? 'Carte'} ••$mask';
    final autoDue = c['due_date'] as String?;
    final manualDay = (c['manual_due_day'] as num?)?.toInt();

    return ListTile(
      leading: const Icon(Icons.credit_card, color: AppColors.primary),
      title: Text(title, style: const TextStyle(fontSize: 14.5)),
      subtitle: autoDue != null
          ? Text('${l10n.notifCardDueAuto} ($autoDue)',
              style: TextStyle(fontSize: 12, color: context.mutedColor))
          : Text(
              manualDay != null
                  ? '${l10n.notifCardDueDay} : $manualDay'
                  : l10n.notifCardManualHint,
              style: TextStyle(fontSize: 12, color: context.mutedColor),
            ),
      trailing: autoDue != null
          ? null
          : TextButton(
              onPressed: () => _editDueDay(c['account_id'] as String, manualDay),
              child: Text(manualDay?.toString() ?? '—'),
            ),
    );
  }

  Future<void> _editDueDay(String accountId, int? current) async {
    final controller = TextEditingController(text: current?.toString() ?? '');
    final l10n = _l10n;
    final day = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.notifCardDueDay),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context, int.tryParse(controller.text.trim())),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    if (day == null || day < 1 || day > 28) return;

    try {
      await FirebaseFunctions.instance.httpsCallable('setCardDueDay').call({
        'account_id': accountId,
        'due_day': day,
      });
      _snack(l10n.notifSaved);
    } catch (e) {
      debugPrint('setCardDueDay: $e');
      _snack(l10n.householdActionError);
    }
  }

  Widget _sectionTitle(String title) => Padding(
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

  Widget _card(List<Widget> children) => Container(
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.borderColor),
        ),
        child: Column(children: children),
      );
}
