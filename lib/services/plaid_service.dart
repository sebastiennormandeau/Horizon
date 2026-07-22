import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:plaid_flutter/plaid_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/locale_controller.dart';

/// Ouverture de Plaid Link, partagée par l'accueil et l'écran des comptes
/// bancaires.
///
/// ⚠️ Le **résultat** (`PlaidLink.onSuccess`) n'est volontairement pas traité
/// ici : il l'est une seule fois, dans `HomeScreen`. Sur le Web, une
/// authentification OAuth recharge la page — l'écran qui a lancé la connexion
/// n'existe donc plus au retour, et seul l'accueil est garanti d'être monté.
class PlaidService {
  PlaidService._();

  /// Jeton mis de côté le temps d'un aller-retour OAuth sur le Web.
  static const _pendingTokenKey = 'plaid_pending_link_token';

  /// Plaid revient vers une URL sur le Web et iOS, mais vers un nom de paquet
  /// sur Android : le serveur a besoin de savoir lequel préparer.
  static String get platform {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform == TargetPlatform.android ? 'android' : 'ios';
  }

  /// Demande un jeton au serveur et ouvre Plaid Link.
  ///
  /// Lève l'exception d'origine en cas d'échec : l'appelant décide du
  /// message à afficher.
  static Future<void> open() async {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'generatePlaidLinkToken',
    );
    final result = await callable.call({
      // Plaid Link s'affiche dans la langue active de l'app.
      'language': LocaleController.instance.effectiveLanguageCode,
      'platform': platform,
    });
    final linkToken = result.data['link_token'] as String;

    if (kIsWeb) {
      // Doit survivre au rechargement de page provoqué par l'OAuth.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingTokenKey, linkToken);
    }

    PlaidLink.create(configuration: LinkTokenConfiguration(token: linkToken));
    PlaidLink.open();
  }

  /// Reprend une connexion interrompue par une authentification OAuth (Web).
  ///
  /// Les institutions canadiennes authentifient chez elles puis rechargent
  /// l'app à l'URL de redirection avec un paramètre `oauth_state_id`. Plaid
  /// exige alors de rouvrir Link avec le **même** jeton et l'URL reçue.
  static Future<void> resumeOAuthIfNeeded() async {
    if (!kIsWeb) return;
    final url = Uri.base;
    if (!url.queryParameters.containsKey('oauth_state_id')) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_pendingTokenKey);
    // Consommé dans tous les cas : un jeton périmé ne doit pas rouvrir Link
    // au prochain démarrage.
    await prefs.remove(_pendingTokenKey);
    if (token == null) return;

    PlaidLink.create(
      configuration: LinkTokenConfiguration(
        token: token,
        receivedRedirectUri: url.toString(),
      ),
    );
    PlaidLink.open();
  }
}
