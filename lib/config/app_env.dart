/// Configuration d'environnement (dev / prod), injectée à la compilation :
///
///   flutter run --dart-define=APP_ENV=prod --dart-define=RECAPTCHA_SITE_KEY=...
///
/// Sans --dart-define, l'app tourne en DEV sur le projet Firebase actuel.
class AppEnv {
  AppEnv._();

  static const String name = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'dev',
  );

  static bool get isProd => name == 'prod';

  /// Clé de **site** reCAPTCHA **Enterprise** pour App Check sur le Web.
  ///
  /// ⚠️ Enterprise, pas v3 classique : les deux familles de clés commencent
  /// par « 6L » et ne se distinguent pas visuellement. Pour trancher :
  /// `gcloud recaptcha keys list --project=horizon-dbba0` ne liste que les
  /// clés Enterprise. Le fournisseur dans `main.dart`
  /// (`ReCaptchaEnterpriseProvider`) et l'enregistrement de l'app Web dans
  /// la console Firebase doivent s'accorder avec cette clé.
  ///
  /// Ce n'est pas un secret : une clé de site est visible dans le HTML de
  /// tout site qui utilise reCAPTCHA, et c'est la clé **secrète** — déposée
  /// dans la console Firebase, jamais ici — qui protège la vérification.
  /// Elle est donc en valeur par défaut plutôt qu'en `--dart-define` : un
  /// seul `flutter build web` qui oublierait le paramètre casserait
  /// l'attestation en silence, sans erreur visible.
  ///
  /// Le futur projet de production aura sa propre clé, à passer par
  /// `--dart-define=RECAPTCHA_SITE_KEY=...` avec `APP_ENV=prod`.
  static const String recaptchaSiteKey = String.fromEnvironment(
    'RECAPTCHA_SITE_KEY',
    defaultValue: '6Ld42l8tAAAAACKeHK_OpdxUC2jJ7NMnJyDGzy62',
  );

  /// Clé publique VAPID pour les notifications push sur le Web (FCM).
  ///
  /// À récupérer dans Console Firebase → Paramètres du projet → Cloud
  /// Messaging → « Certificats push Web » → générer une paire de clés, puis
  /// coller la clé publique ici. Sans elle, les notifications web sont
  /// simplement inactives (l'app fonctionne normalement).
  static const String vapidKey = String.fromEnvironment(
    'VAPID_KEY',
    defaultValue: 'REPLACE_WITH_VAPID_PUBLIC_KEY',
  );

  static bool get hasVapidKey =>
      vapidKey.isNotEmpty && vapidKey != 'REPLACE_WITH_VAPID_PUBLIC_KEY';

  /// Clés SDK publiques RevenueCat (ce ne sont pas des secrets, mais on les
  /// garde configurables pour séparer dev et prod).
  static const String revenueCatAppleKey = String.fromEnvironment(
    'RC_APPLE_KEY',
    defaultValue: 'appl_YOUR_API_KEY_HERE',
  );
  static const String revenueCatGoogleKey = String.fromEnvironment(
    'RC_GOOGLE_KEY',
    defaultValue: 'goog_YOUR_API_KEY_HERE',
  );
}
