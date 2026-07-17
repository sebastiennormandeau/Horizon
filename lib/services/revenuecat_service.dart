import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:purchases_flutter/purchases_flutter.dart';

import '../config/app_env.dart';

/// Intégration RevenueCat (abonnements Premium).
///
/// Le statut d'abonnement « source de vérité » est le champ
/// `subscription_tier` du foyer, mis à jour par le webhook serveur
/// (`revenueCatWebhook`). Le SDK sert à afficher les offres et effectuer
/// les achats sur mobile.
class RevenueCatService {
  static bool _configured = false;

  static bool get isConfigured => _configured;

  /// Les achats intégrés ne sont disponibles que sur Android/iOS.
  static bool get isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static String get _apiKey =>
      defaultTargetPlatform == TargetPlatform.android
          ? AppEnv.revenueCatGoogleKey
          : AppEnv.revenueCatAppleKey;

  static bool get _hasRealKey => !_apiKey.contains('YOUR_API_KEY_HERE');

  static Future<void> initialize() async {
    if (!isSupportedPlatform || !_hasRealKey) return;

    try {
      await Purchases.setLogLevel(
        kDebugMode ? LogLevel.debug : LogLevel.info,
      );
      await Purchases.configure(PurchasesConfiguration(_apiKey));
      _configured = true;
    } catch (e) {
      debugPrint('Erreur d\'initialisation RevenueCat: $e');
    }
  }

  /// Lie l'utilisateur RevenueCat à l'UID Firebase : indispensable pour que
  /// le webhook serveur retrouve l'utilisateur (app_user_id == uid).
  static Future<void> logIn(String uid) async {
    if (!_configured) return;
    try {
      await Purchases.logIn(uid);
    } catch (e) {
      debugPrint('Erreur RevenueCat logIn: $e');
    }
  }

  static Future<void> logOut() async {
    if (!_configured) return;
    try {
      await Purchases.logOut();
    } catch (e) {
      // logOut échoue si l'utilisateur est déjà anonyme : sans gravité.
      debugPrint('RevenueCat logOut: $e');
    }
  }

  /// Offre courante configurée dans le tableau de bord RevenueCat.
  static Future<Offering?> getCurrentOffering() async {
    if (!_configured) return null;
    try {
      final offerings = await Purchases.getOfferings();
      return offerings.current;
    } catch (e) {
      debugPrint('Erreur RevenueCat getOfferings: $e');
      return null;
    }
  }

  /// Achète un forfait. Retourne true si l'entitlement `premium` est actif.
  /// Lance une exception en cas d'échec (sauf annulation par l'utilisateur,
  /// qui retourne false).
  static Future<bool> purchase(Package package) async {
    if (!_configured) return false;
    try {
      final result = await Purchases.purchase(PurchaseParams.package(package));
      return result.customerInfo.entitlements.all['premium']?.isActive ??
          false;
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        return false;
      }
      rethrow;
    }
  }

  /// Restaure les achats précédents (changement d'appareil, réinstallation).
  static Future<bool> restorePurchases() async {
    if (!_configured) return false;
    try {
      final customerInfo = await Purchases.restorePurchases();
      return customerInfo.entitlements.all['premium']?.isActive ?? false;
    } catch (e) {
      debugPrint('Erreur RevenueCat restore: $e');
      return false;
    }
  }
}
