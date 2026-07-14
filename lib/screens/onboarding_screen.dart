import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _isLoading = false;

  Future<void> _createProfile(String type) async {
    setState(() {
      _isLoading = true;
    });
    try {
      // 1. Authenticate anonymously
      UserCredential userCred = await FirebaseAuth.instance.signInAnonymously();
      String uid = userCred.user!.uid;

      // 2. Create household
      DocumentReference householdRef = await FirebaseFirestore.instance
          .collection('households')
          .add({
            'household_type': type,
            'subscription_tier': 'free',
            'safe_to_spend_common': 1000.0,
            'safe_to_spend_solo_A': 500.0,
            'safe_to_spend_solo_B': 500.0,
            'internal_debt_balance': 0.0,
            'split_ratio_user_A': type == 'single' ? 100 : 50,
            'split_ratio_user_B': type == 'single' ? 0 : 50,
            'user_A_id': uid,
          });

      // 3. Create user profile
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'household_id': householdRef.id,
        'safety_cushion': 500.0,
        'name': 'Utilisateur Anonyme',
      });

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      print("Erreur: $e");
    } finally {
      if (mounted)
        setState(() {
          _isLoading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.blur_on, size: 80, color: Color(0xFF6C63FF)),
              const SizedBox(height: 24),
              const Text(
                'Horizon Black',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Neutralisez vos dépenses.\nReprenez le contrôle.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
              const SizedBox(height: 48),
              if (_isLoading)
                const Center(
                  child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
                )
              else ...[
                _buildProfileCard(
                  title: 'Je gère mon argent seul(e)',
                  icon: Icons.person,
                  onTap: () => _createProfile('single'),
                ),
                const SizedBox(height: 16),
                _buildProfileCard(
                  title: 'Nous gérons à deux',
                  icon: Icons.people,
                  onTap: () => _createProfile('couple_joint'),
                ),
              ],
              const Spacer(),
              const Text(
                'Plan Free : 1 compte, 30 jours d\'historique.\nHorizon Premium : Comptes illimités, Sync temps réel.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.white54),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 32, color: const Color(0xFF6C63FF)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
