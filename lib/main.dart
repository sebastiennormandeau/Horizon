import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'config/app_env.dart';
import 'firebase_options.dart';
import 'firebase_options_prod.dart' as prod_options;
import 'l10n/app_localizations.dart';
import 'services/notification_service.dart';
import 'services/revenuecat_service.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/household_setup_screen.dart';
import 'screens/mfa_enroll_screen.dart';
import 'screens/verify_email_screen.dart';
import 'theme/app_theme.dart';
import 'utils/locale_controller.dart';
import 'utils/theme_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Séparation des environnements : `--dart-define=APP_ENV=prod` pointe vers
  // le projet Firebase de production (voir PRODUCTION_CHECKLIST.md).
  final firebaseOptions = AppEnv.isProd
      ? prod_options.DefaultFirebaseOptions.currentPlatform
      : DefaultFirebaseOptions.currentPlatform;
  await Firebase.initializeApp(options: firebaseOptions);

  await FirebaseAppCheck.instance.activate(
    // Les providers de production exigent la configuration Play Integrity /
    // App Attest dans la console Firebase avant le lancement.
    providerAndroid: kDebugMode
        ? const AndroidDebugProvider()
        : const AndroidPlayIntegrityProvider(),
    providerApple: kDebugMode
        ? const AppleDebugProvider()
        : const AppleAppAttestProvider(),
    // reCAPTCHA **Enterprise**, et non v3 classique : la clé du projet est
    // une clé Enterprise (visible via `gcloud recaptcha keys list`). Les
    // deux familles de clés commencent par « 6L » et sont indiscernables à
    // l'œil, mais le fournisseur doit correspondre — sinon App Check
    // n'échoue pas bruyamment, il classe simplement 100 % des requêtes en
    // « non vérifiées ».
    // L'enregistrement de l'app Web dans la console Firebase doit lui aussi
    // être en reCAPTCHA Enterprise avec cette même clé.
    providerWeb: ReCaptchaEnterpriseProvider(AppEnv.recaptchaSiteKey),
  );

  if (!kIsWeb) {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    // Capture aussi les erreurs asynchrones hors du framework Flutter.
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  await RevenueCatService.initialize();

  // Gestionnaire de notifications en arrière-plan (natif Android/iOS ;
  // sur le Web, c'est le service worker qui s'en charge).
  NotificationService.registerBackgroundHandler();

  // Langue et mode d'affichage, persistés localement : disponibles dès
  // l'écran de connexion, avant toute authentification.
  await LocaleController.instance.init();
  await ThemeController.instance.init();

  // Garde l'identité RevenueCat alignée sur l'utilisateur Firebase : le
  // webhook serveur retrouve l'abonné via app_user_id == uid.
  FirebaseAuth.instance.authStateChanges().listen((user) {
    if (user != null) {
      RevenueCatService.logIn(user.uid);
    } else {
      RevenueCatService.logOut();
    }
  });

  runApp(const HorizonApp());
}

class HorizonApp extends StatelessWidget {
  const HorizonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale?>(
      valueListenable: LocaleController.instance,
      builder: (context, locale, _) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: ThemeController.instance,
          builder: (context, themeMode, _) {
            return MaterialApp(
              title: 'Horizon',
              locale: locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              // Appareil non pris en charge (ni fr ni en) : repli sur le
              // français.
              localeResolutionCallback: (device, supported) =>
                  LocaleController.resolveLocale(device, supported),
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: themeMode,
              home: const AuthRouter(),
              routes: {'/home': (context) => const HomeScreen()},
              debugShowCheckedModeBanner: false,
            );
          },
        );
      },
    );
  }
}

class AuthRouter extends StatelessWidget {
  const AuthRouter({super.key});

  @override
  Widget build(BuildContext context) {
    // userChanges() (et non authStateChanges) : émet aussi lors du
    // rafraîchissement du jeton, ce qui permet de sortir de l'écran de
    // vérification dès que le courriel est confirmé.
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = authSnapshot.data;
        if (user == null) {
          return const LoginScreen();
        }

        // Porte de sécurité 1 : courriel vérifié obligatoire (les règles
        // Firestore l'exigent aussi côté serveur). Firebase exige aussi un
        // courriel vérifié avant tout enrôlement MFA : cette porte doit
        // donc rester AVANT la suivante.
        if (user.email != null && !user.emailVerified) {
          return const VerifyEmailScreen();
        }

        // Porte de sécurité 2 : double authentification obligatoire.
        return _MfaGate(user: user);
      },
    );
  }
}

/// Bloque l'accès tant qu'aucun second facteur n'est enrôlé.
///
/// Le MFA est imposé côté serveur (Identity Platform, politique « MFA
/// obligatoire ») : sans facteur enrôlé, l'utilisateur ne pourrait de toute
/// façon plus se reconnecter. Cette porte le lui fait faire tout de suite,
/// pendant qu'il est encore authentifié.
class _MfaGate extends StatelessWidget {
  final User user;

  const _MfaGate({required this.user});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<MultiFactorInfo>>(
      future: user.multiFactor.getEnrolledFactors(),
      builder: (context, mfaSnapshot) {
        if (mfaSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Échec de lecture : on ferme la porte plutôt que de l'ouvrir.
        // Au pire l'utilisateur voit l'écran d'enrôlement alors qu'il a déjà
        // un facteur ; Firebase refusera alors un doublon, ce qui est moins
        // grave que de laisser passer un compte non protégé.
        final factors = mfaSnapshot.data;
        if (factors == null || factors.isEmpty) {
          return const MfaEnrollScreen();
        }

        return _HouseholdGate(user: user);
      },
    );
  }
}

/// Aiguille vers la configuration du foyer ou l'accueil.
class _HouseholdGate extends StatelessWidget {
  final User user;

  const _HouseholdGate({required this.user});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (userSnapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text(AppLocalizations.of(context)!.profileLoadingError),
            ),
          );
        }

        final data = userSnapshot.data?.data() as Map<String, dynamic>?;

        if (data == null || data['household_id'] == null) {
          return const HouseholdSetupScreen();
        }

        return const HomeScreen();
      },
    );
  }
}
