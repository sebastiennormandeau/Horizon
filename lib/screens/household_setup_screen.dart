import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../utils/validators.dart';

class HouseholdSetupScreen extends StatefulWidget {
  const HouseholdSetupScreen({super.key});

  @override
  State<HouseholdSetupScreen> createState() => _HouseholdSetupScreenState();
}

class _HouseholdSetupScreenState extends State<HouseholdSetupScreen> {
  final _codeController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  /// Crée le foyer dans le mode choisi.
  ///
  /// En couple, on affiche le code d'invitation à transmettre au partenaire.
  /// En solo, ce code existe aussi côté serveur (il permettra d'inviter
  /// quelqu'un plus tard) mais il n'est pas montré : il n'aurait aucun sens
  /// à cette étape.
  Future<void> _createHousehold(String mode) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);
    try {
      HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
        'createHousehold',
      );
      final result = await callable.call({'mode': mode});
      final joinCode = result.data['join_code'] as String? ?? '';

      if (!mounted) return;
      final isSolo = mode == 'solo';

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text(
            isSolo ? l10n.householdCreatedSolo : l10n.householdCreated,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: isSolo
                ? [Text(l10n.householdCreatedSoloBody)]
                : [
                    Text(l10n.inviteCodeIntro),
                    const SizedBox(height: 16),
                    SelectableText(
                      joinCode,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.inviteCodeNote,
                      style: TextStyle(fontSize: 12, color: context.mutedColor),
                    ),
                  ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                // The AuthRouter in main.dart will automatically rebuild and show HomeScreen
                // because household_id is now set in the user document.
              },
              child: Text(
                l10n.continueLabel,
                style: const TextStyle(color: AppColors.primary),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Erreur createHousehold: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.householdCreateError)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _joinHousehold() async {
    final l10n = AppLocalizations.of(context)!;
    final code = _codeController.text.trim().toUpperCase();
    final codeError = validateJoinCode(code, l10n);
    if (codeError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(codeError)),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
        'joinHousehold',
      );
      await callable.call({'join_code': code});
      // Navigation is automatic via AuthRouter
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? l10n.invalidCodeError)),
        );
      }
    } catch (e) {
      debugPrint('Erreur joinHousehold: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.invalidCodeError)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.householdSetupTitle),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.home,
                          size: 64, color: AppColors.primary),
                      const SizedBox(height: 16),
                      Text(
                        l10n.welcomeTitle,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.welcomeBody,
                        style: TextStyle(color: context.mutedColor),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      _buildModeCard(
                        icon: Icons.person,
                        title: l10n.modeSoloTitle,
                        description: l10n.modeSoloDescription,
                        onTap: () => _createHousehold('solo'),
                      ),
                      const SizedBox(height: 12),
                      _buildModeCard(
                        icon: Icons.people,
                        title: l10n.modeCoupleTitle,
                        description: l10n.modeCoupleDescription,
                        onTap: () => _createHousehold('couple'),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.modeChangeNote,
                        style: TextStyle(
                            color: context.mutedColor, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(child: Divider(color: context.borderColor)),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              l10n.orSeparator,
                              style: TextStyle(color: context.mutedColor),
                            ),
                          ),
                          Expanded(child: Divider(color: context.borderColor)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        l10n.joinExistingTitle,
                        style: TextStyle(
                            color: context.mutedColor, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _codeController,
                        decoration: InputDecoration(
                          labelText: l10n.joinCodeFieldLabel,
                          border: const OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 6,
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: _joinHousehold,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: AppColors.primary),
                        ),
                        child: Text(
                          l10n.joinButton,
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  /// Carte de choix du mode d'utilisation (solo ou couple).
  Widget _buildModeCard({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return Material(
      color: context.cardColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                          color: context.mutedColor, fontSize: 12.5, height: 1.35),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: context.mutedColor),
            ],
          ),
        ),
      ),
    );
  }
}
