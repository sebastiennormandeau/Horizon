import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../config/app_env.dart';

/// Notifications push (Firebase Cloud Messaging).
///
/// ⚠️ Sur iOS, le push web n'existe **que** si l'app a été ajoutée à l'écran
/// d'accueil (iOS 16.4+). Dans Safari en onglet, la permission ne peut même
/// pas être demandée — la méthode échoue alors silencieusement, ce qui est le
/// comportement voulu : l'app reste pleinement utilisable sans notifications.
class NotificationService {
  NotificationService._();

  /// Demande la permission et enregistre le jeton de l'appareil.
  ///
  /// À appeler uniquement sur un geste explicite de l'utilisateur (bouton
  /// « Activer les notifications ») : demander la permission au démarrage est
  /// intrusif et souvent refusé par réflexe.
  ///
  /// Retourne `true` si un jeton a été enregistré.
  static Future<bool> enable() async {
    if (!AppEnv.hasVapidKey) {
      debugPrint('VAPID absente : notifications désactivées.');
      return false;
    }
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        return false;
      }

      final token = await messaging.getToken(vapidKey: AppEnv.vapidKey);
      if (token == null) return false;

      await FirebaseFunctions.instance
          .httpsCallable('registerPushToken')
          .call({'token': token});

      // Un jeton peut tourner : on garde le serveur à jour.
      FirebaseMessaging.instance.onTokenRefresh.listen((t) async {
        try {
          await FirebaseFunctions.instance
              .httpsCallable('registerPushToken')
              .call({'token': t});
        } catch (e) {
          debugPrint('Rafraîchissement du jeton FCM échoué: $e');
        }
      });
      return true;
    } catch (e) {
      debugPrint('Activation des notifications échouée: $e');
      return false;
    }
  }

  /// Retire le jeton de cet appareil (l'utilisateur coupe les notifications).
  static Future<void> disable() async {
    try {
      final token = await FirebaseMessaging.instance.getToken(
        vapidKey: AppEnv.vapidKey,
      );
      if (token != null) {
        await FirebaseFunctions.instance
            .httpsCallable('unregisterPushToken')
            .call({'token': token});
      }
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      debugPrint('Désactivation des notifications échouée: $e');
    }
  }

  /// Permission déjà accordée sur cet appareil ?
  static Future<bool> isAuthorized() async {
    try {
      final s = await FirebaseMessaging.instance.getNotificationSettings();
      return s.authorizationStatus == AuthorizationStatus.authorized ||
          s.authorizationStatus == AuthorizationStatus.provisional;
    } catch (_) {
      return false;
    }
  }
}
