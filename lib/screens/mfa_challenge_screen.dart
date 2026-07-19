import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';

/// Défi TOTP à la connexion.
///
/// Poussé par `LoginScreen` quand `signInWithEmailAndPassword` lève une
/// `FirebaseAuthMultiFactorException`. Le `resolver` porte la session de
/// connexion en attente : tant que `resolveSignIn` n'a pas réussi,
/// l'utilisateur n'est pas connecté (`currentUser` reste nul).
class MfaChallengeScreen extends StatefulWidget {
  final MultiFactorResolver resolver;
  final String email;

  const MfaChallengeScreen({
    super.key,
    required this.resolver,
    required this.email,
  });

  @override
  State<MfaChallengeScreen> createState() => _MfaChallengeScreenState();
}

class _MfaChallengeScreenState extends State<MfaChallengeScreen> {
  final _codeController = TextEditingController();
  bool _submitting = false;
  String? _error;

  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final l10n = _l10n;
    final code = _codeController.text.trim();

    if (code.isEmpty) {
      setState(() => _error = l10n.mfaCodeRequired);
      return;
    }
    if (!RegExp(r'^[0-9]{6}$').hasMatch(code)) {
      setState(() => _error = l10n.mfaCodeInvalidFormat);
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      // Un seul facteur TOTP est enrôlé par compte : on prend le premier
      // indice fourni par le resolver.
      final hint = widget.resolver.hints.first;
      final assertion = await TotpMultiFactorGenerator.getAssertionForSignIn(
        hint.uid,
        code,
      );
      await widget.resolver.resolveSignIn(assertion);

      // Connexion complétée : AuthRouter prend le relais.
      if (mounted) Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      debugPrint('Erreur de défi MFA: ${e.code} ${e.message}');
      if (!mounted) return;
      setState(() => _error = e.code == 'invalid-verification-code' ||
              e.code == 'invalid-otp'
          ? l10n.mfaChallengeError
          : e.message ?? l10n.mfaChallengeError);
    } catch (e) {
      debugPrint('Erreur de défi MFA: $e');
      if (!mounted) return;
      setState(() => _error = l10n.mfaChallengeError);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showLostAccessHelp() {
    final l10n = _l10n;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(l10n.mfaLostAccessTitle),
        content: SelectableText(
          l10n.mfaLostAccessBody('sebastiennormandeau@gmail.com'),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.mfaChallengeTitle)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.phonelink_lock,
                    size: 56, color: AppColors.primary),
                const SizedBox(height: 20),
                Text(
                  l10n.mfaChallengeHeading,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.mfaChallengeIntro(widget.email),
                  style: const TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  autofocus: true,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    letterSpacing: 8,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.mfaCodeLabel,
                    border: const OutlineInputBorder(),
                    counterText: '',
                    errorText: _error,
                  ),
                  onSubmitted: (_) => _submitting ? null : _verify(),
                ),
                const SizedBox(height: 16),
                _submitting
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _verify,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          l10n.mfaVerify,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _showLostAccessHelp,
                  child: Text(
                    l10n.mfaLostAccess,
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
