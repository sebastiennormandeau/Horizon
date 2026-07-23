import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../config/app_env.dart';

/// Gestionnaire des messages reçus quand l'app est en arrière-plan (natif).
///
/// Doit être une fonction de premier niveau : Firebase l'appelle dans un
/// isolate séparé. Sur le Web, ce rôle est tenu par `firebase-messaging-sw.js`.
/// Les messages de type « notification » sont affichés automatiquement par le
/// système Android ; ce handler existe surtout pour éviter l'avertissement du
/// plugin et servira si l'on ajoute un traitement des messages « data ».
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Notification en arrière-plan: ${message.messageId}');
}

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
    // La clé VAPID n'est nécessaire que sur le Web. En natif (Android, iOS),
    // FCM utilise le jeton de la plateforme — passer la clé serait inutile.
    if (kIsWeb && !AppEnv.hasVapidKey) {
      debugPrint('VAPID absente : notifications web désactivées.');
      return false;
    }
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        return false;
      }

      final token = await messaging.getToken(
        vapidKey: kIsWeb ? AppEnv.vapidKey : null,
      );
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

  /// Enregistre le gestionnaire de messages d'arrière-plan (natif).
  /// À appeler une fois au démarrage, avant tout usage de FirebaseMessaging.
  static void registerBackgroundHandler() {
    if (kIsWeb) return; // géré par le service worker sur le Web.
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  /// Retire le jeton de cet appareil (l'utilisateur coupe les notifications).
  static Future<void> disable() async {
    try {
      final token = await FirebaseMessaging.instance.getToken(
        vapidKey: kIsWeb ? AppEnv.vapidKey : null,
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
