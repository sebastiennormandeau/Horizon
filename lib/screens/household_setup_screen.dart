import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  Future<void> _createHousehold() async {
    setState(() => _isLoading = true);
    try {
      HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
        'createHousehold',
      );
      final result = await callable.call();
      final joinCode = result.data['join_code'] as String? ?? '';

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text("Foyer créé !"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Voici votre code pour inviter votre conjoint(e) :",
                ),
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
                const Text(
                  "Il restera visible sur votre tableau de bord tant que votre partenaire n'a pas rejoint le foyer.",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
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
                child: const Text(
                  "Continuer",
                  style: TextStyle(color: AppColors.primary),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('Erreur createHousehold: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de la création du foyer.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _joinHousehold() async {
    final code = _codeController.text.trim().toUpperCase();
    final codeError = validateJoinCode(code);
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
          SnackBar(content: Text(e.message ?? 'Code invalide ou erreur.')),
        );
      }
    } catch (e) {
      debugPrint('Erreur joinHousehold: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Code invalide ou erreur.')),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuration du Foyer'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.home, size: 64, color: AppColors.primary),
                  const SizedBox(height: 16),
                  const Text(
                    "Bienvenue sur Horizon",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "L'application est conçue autour du Foyer. Voulez-vous créer le vôtre ou rejoindre votre partenaire ?",
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  ElevatedButton(
                    onPressed: _createHousehold,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Créer un nouveau foyer',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Row(
                    children: [
                      Expanded(child: Divider(color: Colors.white24)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text("OU", style: TextStyle(color: Colors.grey)),
                      ),
                      Expanded(child: Divider(color: Colors.white24)),
                    ],
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _codeController,
                    decoration: const InputDecoration(
                      labelText: 'Code de foyer (6 caractères)',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 6,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: _joinHousehold,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: AppColors.primary),
                    ),
                    child: const Text(
                      'Rejoindre',
                      style: TextStyle(fontSize: 16, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
