// Options Firebase du projet de PRODUCTION.
//
// Ce fichier est un gabarit : pour le générer, créez d'abord le projet
// Firebase de production (ex. « horizon-prod ») puis exécutez :
//
//   flutterfire configure --project=horizon-prod --out=lib/firebase_options_prod.dart
//
// (voir PRODUCTION_CHECKLIST.md, section « Environnements séparés »)

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    throw UnsupportedError(
      'Le projet Firebase de PRODUCTION n\'est pas encore configuré. '
      'Exécutez : flutterfire configure --project=<projet-prod> '
      '--out=lib/firebase_options_prod.dart',
    );
  }
}
