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

  /// Clé de site reCAPTCHA v3 pour App Check sur le Web.
  /// À fournir en production via --dart-define=RECAPTCHA_SITE_KEY=...
  static const String recaptchaSiteKey = String.fromEnvironment(
    'RECAPTCHA_SITE_KEY',
    defaultValue: 'dummy-key-for-now',
  );

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
