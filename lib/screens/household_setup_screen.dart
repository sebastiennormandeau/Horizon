import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HouseholdSetupScreen extends StatefulWidget {
  const HouseholdSetupScreen({Key? key}) : super(key: key);

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
      HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('createHousehold');
      final result = await callable.call();
      
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text("Foyer créé !"),
            content: Text("Voici votre code pour inviter votre conjoint(e) :\n\n${result.data['join_code']}\n\nNotez-le précieusement."),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  // The AuthRouter in main.dart will automatically rebuild and show HomeScreen 
                  // because household_id is now set in the user document.
                },
                child: const Text("Continuer", style: TextStyle(color: Color(0xFF6C63FF))),
              )
            ],
          )
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: \$e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _joinHousehold() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Le code doit contenir 6 caractères.')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('joinHousehold');
      await callable.call({'join_code': code});
      // Navigation is automatic via AuthRouter
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code invalide ou erreur.')));
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
                const Icon(Icons.home, size: 64, color: Color(0xFF6C63FF)),
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
                    backgroundColor: const Color(0xFF6C63FF),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Créer un nouveau foyer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                    side: const BorderSide(color: Color(0xFF6C63FF)),
                  ),
                  child: const Text('Rejoindre', style: TextStyle(fontSize: 16, color: Color(0xFF6C63FF))),
                ),
              ],
            ),
          ),
    );
  }
}
