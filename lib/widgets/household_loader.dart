import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/household.dart';

/// Charge le foyer de l'utilisateur connecté (profil -> household) et le
/// fournit au `builder`. Centralise la chaîne de StreamBuilders utilisée par
/// l'accueil, l'historique et les réglages.
class HouseholdLoader extends StatelessWidget {
  final Widget Function(BuildContext context, Household household, String uid)
      builder;

  const HouseholdLoader({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Veuillez vous reconnecter'));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final userData =
            userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
        final householdId = userData['household_id'] as String?;

        if (householdId == null) {
          return const Center(child: Text('Foyer introuvable'));
        }

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('households')
              .doc(householdId)
              .snapshots(),
          builder: (context, householdSnapshot) {
            if (!householdSnapshot.hasData || !householdSnapshot.data!.exists) {
              return const Center(child: CircularProgressIndicator());
            }

            final household = Household.fromSnapshot(householdSnapshot.data!);
            return builder(context, household, user.uid);
          },
        );
      },
    );
  }
}
