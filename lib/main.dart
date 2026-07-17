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
import 'services/revenuecat_service.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/household_setup_screen.dart';
import 'screens/verify_email_screen.dart';
import 'theme/app_colors.dart';

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
    providerWeb: ReCaptchaV3Provider(AppEnv.recaptchaSiteKey),
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
    return MaterialApp(
      title: 'Horizon',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.primary,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surface,
          elevation: 0,
        ),
        fontFamily: 'Inter',
        useMaterial3: true,
      ),
      home: const AuthRouter(),
      routes: {'/home': (context) => const HomeScreen()},
      debugShowCheckedModeBanner: false,
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

        // Porte de sécurité : courriel vérifié obligatoire (les règles
        // Firestore l'exigent aussi côté serveur).
        if (user.email != null && !user.emailVerified) {
          return const VerifyEmailScreen();
        }

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
              return const Scaffold(
                body: Center(
                  child: Text('Erreur de chargement du profil.'),
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
      },
    );
  }
}
