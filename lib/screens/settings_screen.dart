import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/household.dart';
import '../theme/app_colors.dart';
import '../utils/validators.dart';
import '../widgets/household_loader.dart';
import '../widgets/legal_documents.dart';
import 'paywall_screen.dart';

/// Réglages : profil, abonnement, données personnelles (export/suppression —
/// Loi 25), documents légaux et déconnexion.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _busy = false;

  Future<void> _editDisplayName(Household household, String uid) async {
    final controller = TextEditingController();
    final isA = household.isUserA(uid);
    controller.text = isA ? household.nameA : household.nameB;

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Modifier mon prénom'),
        content: TextField(
          controller: controller,
          maxLength: 40,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Prénom',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (newName == null || !mounted) return;
    final error = validateDisplayName(newName);
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
        const SnackBar(content: Text('Prénom mis à jour.')),
      );
    } catch (e) {
      debugPrint('Erreur de mise à jour du prénom: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors de la mise à jour.')),
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
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Mes données (JSON)'),
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
                    const SnackBar(
                      content: Text('Données copiées dans le presse-papiers.'),
                    ),
                  );
                }
              },
              child: const Text('Copier'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Fermer'),
            ),
          ],
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Erreur lors de l\'export.')),
      );
    } catch (e) {
      debugPrint('Erreur exportMyData: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors de l\'export.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteAccount() async {
    final controller = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Supprimer mon compte'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cette action est IRRÉVERSIBLE :\n\n'
              '• Vos connexions bancaires seront révoquées\n'
              '• Vos transactions seront supprimées\n'
              '• Votre compte sera définitivement effacé\n\n'
              'Tapez SUPPRIMER pour confirmer :',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'SUPPRIMER',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context, controller.text.trim() == 'SUPPRIMER'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Supprimer définitivement'),
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
        SnackBar(content: Text(e.message ?? 'Erreur lors de la suppression.')),
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
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Réglages')),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : HouseholdLoader(
              builder: (context, household, uid) {
                final myName =
                    household.isUserA(uid) ? household.nameA : household.nameB;

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _sectionTitle('Profil'),
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
                              ? 'Courriel vérifié'
                              : 'Courriel non vérifié',
                        ),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    _sectionTitle('Abonnement'),
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
                              ? 'Horizon Premium'
                              : 'Plan gratuit',
                        ),
                        subtitle: Text(
                          household.isPremium
                              ? 'Gérez votre abonnement depuis l\'App Store / '
                                  'Play Store.'
                              : '1 compte bancaire, 30 jours d\'historique',
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
                    _sectionTitle('Mes données (Loi 25)'),
                    _card([
                      ListTile(
                        leading: const Icon(Icons.download,
                            color: AppColors.primary),
                        title: const Text('Exporter mes données'),
                        subtitle:
                            const Text('Copie JSON de toutes vos données'),
                        onTap: _exportData,
                      ),
                      ListTile(
                        leading: const Icon(Icons.description,
                            color: AppColors.primary),
                        title: const Text('Conditions d\'utilisation'),
                        onTap: () => showLegalDocument(
                          context,
                          'terms.md',
                          'Conditions d\'Utilisation',
                        ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.privacy_tip,
                            color: AppColors.primary),
                        title: const Text('Politique de confidentialité'),
                        onTap: () => showLegalDocument(
                          context,
                          'privacy.md',
                          'Politique de Confidentialité',
                        ),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    _sectionTitle('Compte'),
                    _card([
                      ListTile(
                        leading: const Icon(Icons.logout, color: Colors.grey),
                        title: const Text('Se déconnecter'),
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
                        title: const Text(
                          'Supprimer mon compte',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                        subtitle: const Text(
                          'Suppression définitive de toutes vos données',
                        ),
                        onTap: _deleteAccount,
                      ),
                    ]),
                  ],
                );
              },
            ),
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
