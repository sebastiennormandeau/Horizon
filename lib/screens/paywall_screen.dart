import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../l10n/app_localizations.dart';
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

  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  Future<void> _purchase(Package package) async {
    setState(() => _busy = true);
    try {
      final success = await RevenueCatService.purchase(package);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_l10n.purchaseWelcome)),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_l10n.purchaseFailed)),
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
            restored ? _l10n.purchasesRestored : _l10n.nothingToRestore,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n;
    final features = [
      (l10n.featUnlimitedBanks, Icons.account_balance),
      (l10n.featFullHistory, Icons.history),
      (l10n.featRealtimeSync, Icons.sync),
      (l10n.featPrioritySupport, Icons.support_agent),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.paywallTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.workspace_premium,
                size: 64, color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              l10n.goPremium,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ...features.map(
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
        color: context.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderColor),
      ),
      child: Text(
        _l10n.webNoPurchase,
        style: TextStyle(color: context.mutedColor),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildNotConfiguredCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderColor),
      ),
      child: Text(
        _l10n.storeUnavailable,
        style: TextStyle(color: context.mutedColor),
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
              child: Text(_l10n.restorePurchases),
            ),
          ],
        );
      },
    );
  }
}
