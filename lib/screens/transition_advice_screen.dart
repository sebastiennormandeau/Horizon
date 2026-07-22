import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../utils/locale_controller.dart';

/// Conseils du coach lors d'un changement de situation (mise en couple ou
/// retour au solo).
///
/// La génération est déclenchée par l'utilisateur, jamais à l'ouverture :
/// chaque appel coûte de l'argent et le quota est de 3 par jour.
class TransitionAdviceScreen extends StatefulWidget {
  /// `to_couple` ou `to_solo`.
  final String transition;

  const TransitionAdviceScreen({super.key, required this.transition});

  @override
  State<TransitionAdviceScreen> createState() => _TransitionAdviceScreenState();
}

class _TransitionAdviceScreenState extends State<TransitionAdviceScreen> {
  bool _loading = false;
  String? _advice;
  String? _error;

  bool get _toCouple => widget.transition == 'to_couple';

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'generateTransitionAdvice',
      );
      final result = await callable.call({
        'transition': widget.transition,
        'language': LocaleController.instance.effectiveLanguageCode,
      });
      if (!mounted) return;
      setState(() => _advice = result.data['advice'] as String?);
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(
        () => _error = e.message ?? AppLocalizations.of(context)!.transitionAdviceError,
      );
    } catch (e) {
      debugPrint('Erreur generateTransitionAdvice: $e');
      if (!mounted) return;
      setState(() => _error = AppLocalizations.of(context)!.transitionAdviceError);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _toCouple ? l10n.transitionToCoupleTitle : l10n.transitionToSoloTitle,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _toCouple ? Icons.favorite_outline : Icons.self_improvement,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(l10n.transitionAdviceIntro)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (_advice == null)
            Center(
              child: _loading
                  ? Column(
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          l10n.transitionAdviceLoading,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    )
                  : ElevatedButton.icon(
                      onPressed: _generate,
                      icon: const Icon(Icons.auto_awesome),
                      label: Text(l10n.transitionAdviceGenerate),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                      ),
                    ),
            )
          else
            MarkdownBody(
              data: _advice!,
              styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)),
            ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: Colors.orange),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
