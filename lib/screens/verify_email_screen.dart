import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';

/// Bloque l'accès à l'application tant que l'adresse courriel n'est pas
/// vérifiée. Les règles Firestore exigent aussi `email_verified` côté
/// serveur : cet écran n'est donc pas seulement cosmétique.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  Timer? _pollTimer;
  Timer? _cooldownTimer;
  int _resendCooldown = 0;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // Vérifie régulièrement si le courriel a été confirmé entre-temps.
    _pollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _checkVerified(),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkVerified() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await user.reload();
      final refreshed = FirebaseAuth.instance.currentUser;
      if (refreshed != null && refreshed.emailVerified) {
        // Force un rafraîchissement du jeton : userChanges() émet et
        // l'AuthRouter laisse passer.
        await refreshed.getIdToken(true);
      }
    } catch (_) {
      // Réseau momentanément indisponible : on réessaiera au prochain tick.
    }
  }

  Future<void> _resendEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _resendCooldown > 0 || _sending) return;
    final l10n = AppLocalizations.of(context)!;

    setState(() => _sending = true);
    try {
      await user.sendEmailVerification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.verificationSent)),
      );
      setState(() => _resendCooldown = 60);
      _cooldownTimer?.cancel();
      _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return t.cancel();
        setState(() {
          _resendCooldown--;
          if (_resendCooldown <= 0) t.cancel();
        });
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? l10n.sendError)),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final email = FirebaseAuth.instance.currentUser?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.verifyEmailTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: l10n.signOut,
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.mark_email_unread,
                  size: 72, color: AppColors.primary),
              const SizedBox(height: 24),
              Text(
                l10n.confirmYourEmail,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.verificationBody(email),
                style: TextStyle(color: context.mutedColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed:
                    (_resendCooldown > 0 || _sending) ? null : _resendEmail,
                icon: const Icon(Icons.send),
                label: Text(
                  _resendCooldown > 0
                      ? l10n.resendIn('$_resendCooldown')
                      : l10n.resendEmail,
                ),
                style: ElevatedButton.styleFrom(
                  
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _checkVerified,
                child: Text(l10n.iConfirmedMyEmail),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
