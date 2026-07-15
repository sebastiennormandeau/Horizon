import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class RevenueCatService {
  // TODO: remplacer par les vraies clés RevenueCat avant le lancement.
  static const String _appleApiKey = 'appl_YOUR_API_KEY_HERE';
  static const String _googleApiKey = 'goog_YOUR_API_KEY_HERE';

  static Future<void> initialize() async {
    // RevenueCat n'est généralement pas initialisé sur le Web de cette manière.
    if (kIsWeb) return;

    await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.info);

    PurchasesConfiguration? configuration;
    if (defaultTargetPlatform == TargetPlatform.android) {
      configuration = PurchasesConfiguration(_googleApiKey);
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      configuration = PurchasesConfiguration(_appleApiKey);
    }

    if (configuration != null) {
      await Purchases.configure(configuration);
    }
  }

  static Future<bool> isPremiumUser() async {
    if (kIsWeb) return false;
    
    try {
      CustomerInfo customerInfo = await Purchases.getCustomerInfo();
      // On assume que 'premium' est l'identifiant de l'entitlement dans RevenueCat
      if (customerInfo.entitlements.all['premium'] != null && 
          customerInfo.entitlements.all['premium']!.isActive) {
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Erreur RevenueCat (isPremium): $e");
      return false;
    }
  }

  static Future<void> purchasePremium() async {
    if (kIsWeb) return;

    try {
      Offerings offerings = await Purchases.getOfferings();
      if (offerings.current != null && offerings.current!.availablePackages.isNotEmpty) {
        await Purchases.purchasePackage(offerings.current!.availablePackages.first);
      }
    } catch (e) {
      debugPrint("Erreur d'achat RevenueCat: $e");
    }
  }
}
