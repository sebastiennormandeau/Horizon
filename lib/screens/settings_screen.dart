import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../l10n/app_localizations.dart';
import '../models/household.dart';
import '../theme/app_colors.dart';
import '../utils/locale_controller.dart';
import '../utils/validators.dart';
import '../widgets/household_loader.dart';
import '../widgets/legal_documents.dart';
import 'household_manage_screen.dart';
import 'paywall_screen.dart';

/// Réglages : profil, langue, abonnement, données personnelles
/// (export/suppression — Loi 25), documents légaux et déconnexion.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _busy = false;

  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  Future<void> _editDisplayName(Household household, String uid) async {
    final l10n = _l10n;
    final controller = TextEditingController();
    final isA = household.isUserA(uid);
    controller.text = isA ? household.nameA : household.nameB;

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(l10n.editMyName),
        content: TextField(
          controller: controller,
          maxLength: 40,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: l10n.firstNameLabel,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text(l10n.save),
          ),
        ],
      ),
    );

    if (newName == null || !mounted) return;
    final error = validateDisplayName(newName, _l10n);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }

    try {
      final batch = FirebaseFirestore.instance.batch();
      batch.set(
        FirebaseFirestore.instance.collection('users').doc(uid),
        {'display_name': newName},
        SetOptions(merge: true),
      );
      batch.update(
        FirebaseFirestore.instance
            .collection('households')
            .doc(household.id),
        {(isA ? 'user_A_name' : 'user_B_name'): newName},
      );
      await batch.commit();
      await FirebaseAuth.instance.currentUser?.updateDisplayName(newName);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_l10n.nameUpdated)),
      );
    } catch (e) {
      debugPrint('Erreur de mise à jour du prénom: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_l10n.updateError)),
      );
    }
  }

  Future<void> _exportData() async {
    setState(() => _busy = true);
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('exportMyData');
      final result = await callable.call();
      final json = const JsonEncoder.withIndent('  ')
          .convert(jsonDecode(jsonEncode(result.data)));

      if (!mounted) return;
      final l10n = _l10n;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(l10n.myDataJson),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: SingleChildScrollView(
              child: SelectableText(
                json,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: json));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.copiedToClipboard)),
                  );
                }
              },
              child: Text(l10n.copy),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: Text(l10n.close),
            ),
          ],
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? _l10n.exportError)),
      );
    } catch (e) {
      debugPrint('Erreur exportMyData: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_l10n.exportError)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteAccount() async {
    final l10n = _l10n;
    final controller = TextEditingController();
    final keyword = l10n.deleteKeyword;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(l10n.deleteAccountTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.deleteAccountBody(keyword)),
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context, controller.text.trim() == keyword),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: Text(l10n.deleteForever),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('deleteAccount');
      await callable.call();
      // Le compte Auth n'existe plus : on force la déconnexion locale.
      await FirebaseAuth.instance.signOut();
      if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? _l10n.deleteError)),
      );
    } catch (e) {
      debugPrint('Erreur deleteAccount: $e');
      // Si le compte a été supprimé côté serveur, la session locale devient
      // invalide : on se déconnecte quand même.
      await FirebaseAuth.instance.signOut();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n;
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : HouseholdLoader(
              builder: (context, household, uid) {
                final myName =
                    household.isUserA(uid) ? household.nameA : household.nameB;

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _sectionTitle(l10n.profileSection),
                    _card([
                      ListTile(
                        leading:
                            const Icon(Icons.person, color: AppColors.primary),
                        title: Text(myName),
                        subtitle: Text(user?.email ?? ''),
                        trailing: const Icon(Icons.edit, size: 18),
                        onTap: () => _editDisplayName(household, uid),
                      ),
                      ListTile(
                        leading: Icon(
                          user?.emailVerified == true
                              ? Icons.verified
                              : Icons.warning_amber,
                          color: user?.emailVerified == true
                              ? Colors.green
                              : Colors.orange,
                        ),
                        title: Text(
                          user?.emailVerified == true
                              ? l10n.emailVerified
                              : l10n.emailNotVerified,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    _sectionTitle(l10n.householdSection),
                    _card([
                      ListTile(
                        leading: Icon(
                          household.isSolo ? Icons.person : Icons.people,
                          color: AppColors.primary,
                        ),
                        title: Text(l10n.householdManageTitle),
                        subtitle: Text(l10n.householdManageSubtitle),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const HouseholdManageScreen(),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    _sectionTitle(l10n.languageSection),
                    _buildLanguageCard(),
                    const SizedBox(height: 16),
                    _sectionTitle(l10n.subscriptionSection),
                    _card([
                      ListTile(
                        leading: Icon(
                          household.isPremium
                              ? Icons.workspace_premium
                              : Icons.star_border,
                          color: household.isPremium
                              ? Colors.amber
                              : AppColors.primary,
                        ),
                        title: Text(
                          household.isPremium
                              ? l10n.premiumPlanTitle
                              : l10n.freePlanTitle,
                        ),
                        subtitle: Text(
                          household.isPremium
                              ? l10n.manageSubscription
                              : l10n.freePlanLimits,
                        ),
                        trailing: household.isPremium
                            ? null
                            : const Icon(Icons.chevron_right),
                        onTap: household.isPremium
                            ? null
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const PaywallScreen(),
                                  ),
                                );
                              },
                      ),
                    ]),
                    const SizedBox(height: 16),
                    _sectionTitle(l10n.myDataSection),
                    _card([
                      ListTile(
                        leading: const Icon(Icons.download,
                            color: AppColors.primary),
                        title: Text(l10n.exportMyData),
                        subtitle: Text(l10n.exportSubtitle),
                        onTap: _exportData,
                      ),
                      ListTile(
                        leading: const Icon(Icons.description,
                            color: AppColors.primary),
                        title: Text(l10n.termsLinkLabel),
                        onTap: () => showLegalDocument(
                          context,
                          'terms',
                          l10n.termsDocTitle,
                        ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.privacy_tip,
                            color: AppColors.primary),
                        title: Text(l10n.privacyLinkLabel),
                        onTap: () => showLegalDocument(
                          context,
                          'privacy',
                          l10n.privacyDocTitle,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    _sectionTitle(l10n.accountSection),
                    _card([
                      ListTile(
                        leading: const Icon(Icons.logout, color: Colors.grey),
                        title: Text(l10n.signOut),
                        onTap: () async {
                          await FirebaseAuth.instance.signOut();
                          if (context.mounted) {
                            Navigator.popUntil(
                              context,
                              (route) => route.isFirst,
                            );
                          }
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.delete_forever,
                            color: Colors.redAccent),
                        title: Text(
                          l10n.deleteAccountTitle,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                        subtitle: Text(l10n.deleteAccountSubtitle),
                        onTap: _deleteAccount,
                      ),
                    ]),
                  ],
                );
              },
            ),
    );
  }

  /// Choix de la langue : français, anglais, ou automatique (appareil).
  Widget _buildLanguageCard() {
    final l10n = _l10n;
    final current = LocaleController.instance.value?.languageCode;

    RadioListTile<String?> option(String? code, String label) {
      return RadioListTile<String?>(
        value: code,
        // ignore: deprecated_member_use
        groupValue: current,
        // ignore: deprecated_member_use
        onChanged: (selected) async {
          await LocaleController.instance.setLocale(selected);
          if (mounted) setState(() {});
        },
        title: Text(label),
        activeColor: AppColors.primary,
        dense: true,
      );
    }

    return _card([
      option('fr', l10n.languageFrench),
      option('en', l10n.languageEnglish),
      option(null, l10n.languageSystem),
    ]);
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
