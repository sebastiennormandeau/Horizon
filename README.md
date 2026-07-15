# Horizon

**Le Zero-Based Budgeting simplifié pour les foyers.**

Horizon est une application Flutter de gestion de finances pour les couples.
Chaque foyer connecte ses comptes bancaires (via Plaid), puis « neutralise »
ses transactions en les glissant façon Tinder vers un des trois buckets :
**Solo A**, **Commun** ou **Solo B**. L'application maintient les cagnottes
*safe-to-spend* de chacun ainsi qu'une **balance de dette interne** entre les
deux partenaires, calculée au pro-rata configuré (ex. 60/40 selon les revenus).

## Architecture

| Couche | Technologie |
| --- | --- |
| Application | Flutter (Android, iOS, Web, desktop) |
| Authentification | Firebase Auth (email / mot de passe) |
| Données | Cloud Firestore (`users`, `households`, `transactions`, `bank_connections`) |
| Backend | Cloud Functions (TypeScript, Node 20) — `functions/` |
| Banques | Plaid (sandbox pour le moment) |
| Abonnements | RevenueCat (clés à configurer) |
| Qualité | App Check, Crashlytics |

### Flux principal

1. Inscription → création ou adhésion à un **Foyer** via un code à 6 caractères
   (Cloud Functions `createHousehold` / `joinHousehold`).
2. Connexion bancaire Plaid (`generatePlaidLinkToken` → `exchangePublicToken`) ;
   les `access_token` restent côté serveur (`bank_connections`, interdit aux clients).
3. Les transactions arrivent par `/transactions/sync` (webhook Plaid) et sont
   rangées par swipe ; le trigger `onTransactionAssigned` met à jour les
   cagnottes et la dette interne (avec support de l'annulation).
4. L'écran Budget configure revenus, dépenses fixes, ratio de partage et le
   calendrier des **Mois Magiques** (mois à paie supplémentaire).

## Développement

```bash
flutter pub get
flutter run

# Backend
cd functions
npm install
npm run build
firebase emulators:start --only functions,firestore
```

Tests : `flutter test`

Déploiement des règles/index/fonctions : `firebase deploy --only firestore,functions`

## Avant la mise en production

- [ ] Passer Plaid de `sandbox` à `production` (`functions/src/index.ts`)
- [ ] Vérifier la signature JWT des webhooks Plaid
- [ ] Renseigner les clés RevenueCat (`lib/services/revenuecat_service.dart`)
- [ ] Configurer Play Integrity / App Attest et une vraie clé reCAPTCHA (App Check)
- [ ] Dater et faire valider les documents légaux (`assets/legal/`)
