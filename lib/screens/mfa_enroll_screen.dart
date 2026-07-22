import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';

/// Enrôlement TOTP obligatoire.
///
/// La double authentification est exigée pour TOUS les comptes (Identity
/// Platform, politique « MFA obligatoire »). Cet écran est une porte : tant
/// qu'aucun facteur n'est enrôlé, `AuthRouter` le montre et l'application
/// reste inaccessible. La seule sortie possible est la déconnexion.
///
/// Contrainte Firebase : le courriel doit être vérifié AVANT de pouvoir
/// enrôler un second facteur — d'où le placement de cette porte après
/// `VerifyEmailScreen` dans `AuthRouter`.
class MfaEnrollScreen extends StatefulWidget {
  const MfaEnrollScreen({super.key});

  @override
  State<MfaEnrollScreen> createState() => _MfaEnrollScreenState();
}

class _MfaEnrollScreenState extends State<MfaEnrollScreen> {
  final _codeController = TextEditingController();

  TotpSecret? _secret;
  String? _qrCodeUrl;
  bool _preparing = true;
  bool _submitting = false;

  /// Erreur de génération de la clé TOTP (étape de préparation, avant même
  /// d'afficher un code QR) — distincte de [_codeError] pour ne pas afficher
  /// un message de préparation sous le champ de saisie du code.
  String? _prepareError;

  /// Erreur liée à la saisie/soumission du code à 6 chiffres.
  String? _codeError;

  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    _prepareSecret();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  /// Génère la clé TOTP côté Firebase et l'URL `otpauth://` du code QR.
  ///
  /// Peut échouer sur un jeton d'authentification pas encore à jour (p. ex.
  /// juste après une vérification de courriel très récente) — d'où le
  /// bouton « Réessayer » affiché en cas d'échec plutôt qu'un blocage sans
  /// issue (voir `_buildPrepareError`).
  Future<void> _prepareSecret() async {
    setState(() {
      _preparing = true;
      _prepareError = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final session = await user.multiFactor.getSession();
      final secret = await TotpMultiFactorGenerator.generateSecret(session);
      final url = await secret.generateQrCodeUrl(
        accountName: user.email ?? user.uid,
        issuer: 'Horizon',
      );

      if (!mounted) return;
      setState(() {
        _secret = secret;
        _qrCodeUrl = url;
        _preparing = false;
      });
    } catch (e) {
      debugPrint('Erreur de génération du secret TOTP: $e');
      if (!mounted) return;
      setState(() {
        _preparing = false;
        _prepareError = _l10n.mfaSecretError;
      });
    }
  }

  Future<void> _copyKey() async {
    final key = _secret?.secretKey;
    if (key == null) return;
    await Clipboard.setData(ClipboardData(text: key));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_l10n.mfaKeyCopied)),
    );
  }

  Future<void> _enroll() async {
    final l10n = _l10n;
    final code = _codeController.text.trim();
    final secret = _secret;
    if (secret == null) return;

    if (code.isEmpty) {
      setState(() => _codeError = l10n.mfaCodeRequired);
      return;
    }
    if (!RegExp(r'^[0-9]{6}$').hasMatch(code)) {
      setState(() => _codeError = l10n.mfaCodeInvalidFormat);
      return;
    }

    setState(() {
      _submitting = true;
      _codeError = null;
    });

    try {
      final assertion =
          await TotpMultiFactorGenerator.getAssertionForEnrollment(
        secret,
        code,
      );
      // displayName est obligatoire pour TOTP côté SDK.
      await FirebaseAuth.instance.currentUser!.multiFactor.enroll(
        assertion,
        displayName: l10n.mfaDeviceNameDefault,
      );

      // Rafraîchit le jeton : AuthRouter réévalue la porte MFA et laisse
      // passer vers la configuration du foyer.
      await FirebaseAuth.instance.currentUser?.reload();
      await FirebaseAuth.instance.currentUser?.getIdToken(true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.mfaEnrollSuccess)),
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('Erreur d\'enrôlement MFA: ${e.code} ${e.message}');
      if (!mounted) return;
      setState(() {
        _codeError = switch (e.code) {
          'invalid-verification-code' ||
          'invalid-otp' =>
            l10n.mfaCodeRejected,
          'requires-recent-login' => l10n.mfaRecentLoginRequired,
          _ => e.message ?? l10n.mfaEnrollError,
        };
      });
    } catch (e) {
      debugPrint('Erreur d\'enrôlement MFA: $e');
      if (!mounted) return;
      setState(() => _codeError = l10n.mfaEnrollError);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.mfaEnrollTitle),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: l10n.signOut,
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: _preparing
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    l10n.mfaPreparing,
                    style: TextStyle(color: context.mutedColor),
                  ),
                ],
              ),
            )
          : Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.shield,
                          size: 56, color: AppColors.primary),
                      const SizedBox(height: 16),
                      Text(
                        l10n.mfaEnrollHeading,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.mfaEnrollIntro,
                        style: TextStyle(color: context.mutedColor),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),
                      _stepTitle(l10n.mfaStep1),
                      Text(
                        l10n.mfaStep1Detail,
                        style: TextStyle(
                            color: context.mutedColor, fontSize: 13),
                      ),
                      const SizedBox(height: 24),
                      if (_qrCodeUrl == null) ...[
                        // La génération de la clé a échoué : les étapes 2 et
                        // 3 sont inutilisables sans elle. On offre un
                        // réessai plutôt qu'un écran bloqué sans issue.
                        _buildPrepareError(l10n),
                      ] else ...[
                        _stepTitle(l10n.mfaStep2),
                        const SizedBox(height: 12),
                        _buildQrCode(_qrCodeUrl!),
                        const SizedBox(height: 16),
                        _buildManualKey(l10n),
                        const SizedBox(height: 24),
                        _stepTitle(l10n.mfaStep3),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _codeController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
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
                            errorText: _codeError,
                          ),
                          onSubmitted: (_) => _submitting ? null : _enroll(),
                        ),
                        const SizedBox(height: 16),
                        _submitting
                            ? const Center(child: CircularProgressIndicator())
                            : ElevatedButton(
                                onPressed: _enroll,
                                style: ElevatedButton.styleFrom(
                                  
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 16),
                                ),
                                child: Text(
                                  l10n.mfaActivate,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                        const SizedBox(height: 24),
                        _buildBackupWarning(l10n),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  /// Affiché quand `_prepareSecret()` a échoué (p. ex. jeton d'authentification
  /// pas encore à jour) : un bouton « Réessayer » plutôt qu'un écran bloqué,
  /// puisque le bouton « Activer » ne peut rien faire sans clé générée.
  Widget _buildPrepareError(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.palette.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.palette.danger),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline,
                  color: context.palette.danger, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _prepareError ?? l10n.mfaSecretError,
                  style: TextStyle(color: context.palette.danger),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _prepareSecret,
            style:
                ElevatedButton.styleFrom(),
            child: Text(l10n.retry),
          ),
        ],
      ),
    );
  }

  Widget _stepTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  /// Le code QR doit rester lisible : fond blanc imposé même en thème sombre.
  Widget _buildQrCode(String url) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: QrImageView(
          data: url,
          version: QrVersions.auto,
          size: 200,
          backgroundColor: Colors.white,
          errorStateBuilder: (context, error) => SizedBox(
            width: 200,
            height: 200,
            child: Center(
              child: Text(
                _l10n.mfaSecretError,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildManualKey(AppLocalizations l10n) {
    final key = _secret?.secretKey ?? '';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.mfaStep2Manual,
            style: TextStyle(fontSize: 12, color: context.mutedColor),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  key,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 18),
                tooltip: l10n.mfaCopyKey,
                onPressed: _copyKey,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBackupWarning(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.palette.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.palette.warning),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber, color: context.palette.warning, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.mfaBackupWarning,
              style: TextStyle(fontSize: 12, color: context.palette.warning),
            ),
          ),
        ],
      ),
    );
  }
}
