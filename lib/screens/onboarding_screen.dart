import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../widgets/horizon_logo.dart';

/// Guide de démarrage, montré une seule fois.
///
/// Horizon repose sur deux idées qui ne vont pas de soi : la cagnotte commune
/// est une **provision** pour les charges (elle doit descendre vers zéro),
/// et un achat par carte se compte à l'achat, pas au paiement. Sans un mot
/// d'explication, ces comportements passent pour des anomalies.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  static const _prefKey = 'onboarding_seen';

  /// Vrai si le guide n'a jamais été vu sur cet appareil.
  static Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_prefKey) ?? false);
  }

  static Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, true);
  }

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await OnboardingScreen.markSeen();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final pages = <({IconData icon, String title, String body})>[
      (
        icon: Icons.flag_outlined,
        title: l10n.tutorial1Title,
        body: l10n.tutorial1Body,
      ),
      (
        icon: Icons.savings_outlined,
        title: l10n.tutorial2Title,
        body: l10n.tutorial2Body,
      ),
      (
        icon: Icons.swipe_outlined,
        title: l10n.tutorial3Title,
        body: l10n.tutorial3Body,
      ),
      (
        icon: Icons.sync_alt,
        title: l10n.tutorial4Title,
        body: l10n.tutorial4Body,
      ),
      (
        icon: Icons.playlist_remove,
        title: l10n.tutorial5Title,
        body: l10n.tutorial5Body,
      ),
      (
        icon: Icons.account_balance_outlined,
        title: l10n.tutorial6Title,
        body: l10n.tutorial6Body,
      ),
    ];
    final isLast = _page == pages.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _finish,
                child: Text(l10n.tutorialSkip),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) {
                  final p = pages[i];
                  return Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (i == 0)
                              const HorizonLogo(size: 96, showWordmark: true)
                            else
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.14),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(p.icon,
                                    size: 40, color: AppColors.primary),
                              ),
                            const SizedBox(height: 32),
                            Text(
                              p.title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 23,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              p.body,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                height: 1.55,
                                color: context.mutedColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < pages.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i == _page ? 22 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: i == _page
                                ? AppColors.primary
                                : context.borderColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isLast
                          ? _finish
                          : () => _controller.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut,
                              ),
                      child: Text(
                        isLast ? l10n.tutorialDone : l10n.tutorialNext,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
