import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../services/revenuecat_service.dart';
import '../theme/app_colors.dart';

/// Écran d'abonnement Horizon Premium.
///
/// Les achats passent par RevenueCat (App Store / Play Store). Le statut
/// serveur (`subscription_tier` du foyer) est mis à jour par le webhook
/// RevenueCat — la synchronisation peut prendre quelques secondes.
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _busy = false;

  static const _features = [
    ('Comptes bancaires illimités', Icons.account_balance),
    ('Historique complet et illimité', Icons.history),
    ('Synchronisation en temps réel', Icons.sync),
    ('Soutien prioritaire', Icons.support_agent),
  ];

  Future<void> _purchase(Package package) async {
    setState(() => _busy = true);
    try {
      final success = await RevenueCatService.purchase(package);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Bienvenue dans Horizon Premium ! Activation en cours '
              '(quelques secondes)...',
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('L\'achat a échoué. Réessayez.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    setState(() => _busy = true);
    try {
      final restored = await RevenueCatService.restorePurchases();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            restored
                ? 'Achats restaurés avec succès !'
                : 'Aucun achat à restaurer.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Horizon Premium')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.workspace_premium,
                size: 64, color: AppColors.primary),
            const SizedBox(height: 16),
            const Text(
              'Passez à Horizon Premium',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ..._features.map(
              (f) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(f.$2, color: AppColors.primary),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(f.$1, style: const TextStyle(fontSize: 16)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            if (!RevenueCatService.isSupportedPlatform)
              _buildUnsupportedPlatformCard()
            else if (!RevenueCatService.isConfigured)
              _buildNotConfiguredCard()
            else
              _buildOfferings(),
          ],
        ),
      ),
    );
  }

  Widget _buildUnsupportedPlatformCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: const Text(
        'L\'abonnement s\'effectue depuis l\'application mobile Horizon '
        '(Android ou iPhone). Une fois abonné, votre statut Premium '
        's\'applique automatiquement à tout votre foyer, y compris sur le Web.',
        style: TextStyle(color: Colors.grey),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildNotConfiguredCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: const Text(
        'La boutique n\'est pas encore disponible. Réessayez plus tard.',
        style: TextStyle(color: Colors.grey),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildOfferings() {
    if (_busy) {
      return const Center(child: CircularProgressIndicator());
    }

    return FutureBuilder<Offering?>(
      future: RevenueCatService.getCurrentOffering(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final offering = snapshot.data;
        if (offering == null || offering.availablePackages.isEmpty) {
          return _buildNotConfiguredCard();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...offering.availablePackages.map(
              (package) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ElevatedButton(
                  onPressed: () => _purchase(package),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    '${package.storeProduct.title} — '
                    '${package.storeProduct.priceString}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: _restore,
              child: const Text('Restaurer mes achats'),
            ),
          ],
        );
      },
    );
  }
}
