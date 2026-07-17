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

1. Inscription (prénom + courriel **vérifié obligatoirement**) → création ou
   adhésion à un **Foyer** via un code à 6 caractères
   (Cloud Functions `createHousehold` / `joinHousehold`).
2. Connexion bancaire Plaid (`generatePlaidLinkToken` → `exchangePublicToken`) ;
   les `access_token` restent côté serveur (`bank_connections`, interdit aux clients).
3. Les transactions arrivent par `/transactions/sync` (webhook Plaid **signé
   JWT**) et sont rangées par swipe ; le trigger `onTransactionAssigned` met à
   jour les cagnottes et la dette interne (avec support de l'annulation et de
   la re-catégorisation depuis l'Historique).
4. L'écran Budget configure revenus, dépenses fixes, ratio de partage et le
   calendrier des **Mois Magiques** ; le rollover mensuel (`monthlyRollover`)
   reconduit le budget le 1ᵉʳ de chaque mois.
5. La dette interne se règle d'un bouton (« RÉGLER ») ; les règlements sont
   archivés dans `households/{id}/settlements`.
6. Monétisation : plan gratuit (1 compte bancaire, 30 jours d'historique) vs
   **Premium** via RevenueCat ; le webhook `revenueCatWebhook` synchronise le
   statut serveur.

### Sécurité

- Courriel vérifié exigé par l'app, les Cloud Functions **et** les règles Firestore
- Rate limiting par utilisateur sur toutes les fonctions appelables
- Validation des entrées client et serveur
- App Check (anti-bot) — enforcement activable via `ENFORCE_APP_CHECK`
- Webhooks Plaid signés (JWT ES256) et RevenueCat authentifiés
- Suppression de compte et export de données (Loi 25) dans les Réglages

### Environnements

- **Dev** : projet `horizon-dbba0`, Plaid sandbox (par défaut)
- **Prod** : `flutter build --dart-define=APP_ENV=prod` +
  `lib/firebase_options_prod.dart` (voir [PRODUCTION_CHECKLIST.md](PRODUCTION_CHECKLIST.md))

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

Voir **[PRODUCTION_CHECKLIST.md](PRODUCTION_CHECKLIST.md)** : la liste complète
et à jour (paiements réels, SSL/domaine, environnements séparés, sauvegardes,
App Check, Plaid production, conformité Loi 25).
