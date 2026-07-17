# Horizon — Checklist de mise en production

> Dernière mise à jour : 16 juillet 2026
>
> Légende : ✅ fait dans le code (rien à faire) · 🔧 action manuelle requise
> (console/compte) · 🧪 à tester une fois l'infrastructure en place

---

## 1. Sécurité applicative

### ✅ Vérification du courriel (fait)
- L'app bloque sur `VerifyEmailScreen` tant que le courriel n'est pas vérifié.
- Les Cloud Functions rejettent les appels sans `email_verified`.
- Les règles Firestore exigent `email_verified == true` pour toutes les
  données financières.
- ⚠️ **Vos comptes existants (toi et ta femme) devront vérifier leur courriel
  à la prochaine connexion.**
- 🔧 Personnaliser les gabarits de courriels **en français** :
  Console Firebase → Authentication → Templates (vérification, réinitialisation).

### ✅ Rate limiting (fait)
Limites par utilisateur (fenêtre glissante, Firestore `rate_limits`) :
| Fonction | Limite |
| --- | --- |
| joinHousehold (anti force brute des codes) | 10 / heure |
| createHousehold | 5 / heure |
| generatePlaidLinkToken | 20 / heure |
| exchangePublicToken | 10 / heure |
| settleDebt | 20 / heure |
| exportMyData | 5 / jour |
| deleteAccount | 3 / jour |

### ✅ Validation des entrées (fait)
- Client : formulaires avec validateurs (courriel, mot de passe fort 8+
  caractères avec lettres et chiffres, prénom, code de foyer).
- Serveur : chaque fonction valide types, longueurs et formats
  (`assertString`, motifs regex pour join_code et public_token Plaid).

### 🔧 Protection anti-bot (App Check)
Le code est prêt ; il faut activer les attestations réelles :
1. Console Firebase → App Check → enregistrer les apps :
   - Android : **Play Integrity**
   - iOS : **App Attest**
   - Web : **reCAPTCHA v3** → créer une clé sur
     https://www.google.com/recaptcha/admin → passer la clé de site via
     `--dart-define=RECAPTCHA_SITE_KEY=<clé>` au build web.
2. Console Firebase → App Check → appliquer (« Enforce ») sur Firestore,
   Functions et Auth.
3. Dans `functions/.env` (ou `.env.<projet-prod>`) : `ENFORCE_APP_CHECK=true`
   puis redéployer les fonctions.
4. En dev, enregistrer les jetons de débogage affichés dans la console de
   l'app (App Check → Debug tokens).

### ✅ Webhooks signés (fait)
- Plaid : signature JWT ES256 vérifiée (clé récupérée via
  `/webhook_verification_key/get`, hachage SHA-256 du corps comparé,
  fraîcheur ≤ 5 min).
- RevenueCat : en-tête `Authorization` comparé au secret
  `REVENUECAT_WEBHOOK_AUTH` (déjà créé dans Secret Manager — voir §4).

---

## 2. Authentification 🧪

- [x] Connexion / inscription avec validation (testé localement)
- [ ] 🧪 Tester la réception réelle du courriel de vérification (vérifier les
      indésirables ; personnaliser le gabarit d'abord)
- [ ] 🧪 Tester « Mot de passe oublié » de bout en bout (envoi → lien → nouveau
      mot de passe → reconnexion)
- [ ] 🔧 Console Firebase → Authentication → Settings : activer la
      **protection contre l'énumération de courriels** et les
      **quotas d'inscription** (anti-abus supplémentaire)

---

## 3. Paiements réels (RevenueCat) 🔧🧪

Le code est prêt (paywall, achats, restauration, webhook, gating serveur).
Étapes restantes :

1. **Comptes marchands** :
   - Google Play Console (25 $ US une fois) + profil de paiement
   - Apple Developer Program (99 $ US/an) + contrats « Paid Apps » signés
2. **Produits** : créer l'abonnement (ex. `horizon_premium_monthly`) dans
   Play Console et App Store Connect.
3. **RevenueCat** (https://app.revenuecat.com) :
   - Créer le projet, lier les 2 stores
   - Créer l'**entitlement `premium`** (identifiant exact — le code s'y fie)
   - Créer une offre (« offering ») par défaut avec les forfaits
   - Récupérer les clés SDK publiques et builder avec
     `--dart-define=RC_GOOGLE_KEY=goog_xxx --dart-define=RC_APPLE_KEY=appl_xxx`
   - **Webhook** : URL
     `https://us-central1-horizon-dbba0.cloudfunctions.net/revenueCatWebhook`
     avec l'en-tête Authorization = la valeur du secret (affichée via
     `firebase functions:secrets:access REVENUECAT_WEBHOOK_AUTH`)
4. 🧪 Tester en **sandbox** (testeurs de licence Play / comptes Sandbox
   App Store) : achat → le foyer passe `premium` en quelques secondes.
5. 🧪 Tester avec une **vraie carte** après publication : acheter, vérifier le
   webhook (logs de `revenueCatWebhook`), annuler, vérifier le retour à
   `free` à l'expiration.
6. ⚠️ Le Web n'a pas d'achats intégrés (le paywall l'explique à l'utilisateur).
   Option future : RevenueCat Web Billing ou Stripe.

---

## 4. Secrets et clés API ✅🔧

**Audit effectué : aucun secret dans le dépôt.**
- Clés Firebase (`firebase_options.dart`, `google-services.json`) : ce sont
  des **identifiants publics**, pas des secrets — c'est normal et documenté
  par Google.
- Plaid `client_id`/`secret` : **Google Secret Manager** ✅
- Secret webhook RevenueCat : **Google Secret Manager** ✅ (créé le
  16 juillet 2026)
- Clés SDK RevenueCat : publiques, injectées par `--dart-define`
- Jeton d'accès bancaire Plaid : Firestore `bank_connections`, **interdit de
  lecture aux clients** (règles `allow read, write: if false`)

Durcissement recommandé :
- [ ] 🔧 Console Google Cloud → APIs & Services → Credentials → restreindre
      la clé API Android au package `com.vibecodingmind.horizon` + empreinte
      SHA-1, et la clé Web aux domaines autorisés (référents HTTP).

---

## 5. Environnements séparés dev / production 🔧

Le code est prêt (`--dart-define=APP_ENV=prod` + `lib/firebase_options_prod.dart`).

1. Créer le projet Firebase **horizon-prod** (plan Blaze).
2. `flutterfire configure --project=horizon-prod --out=lib/firebase_options_prod.dart`
3. Secrets de prod :
   ```
   firebase functions:secrets:set PLAID_CLIENT_ID --project horizon-prod
   firebase functions:secrets:set PLAID_SECRET --project horizon-prod   # clé PRODUCTION Plaid
   firebase functions:secrets:set REVENUECAT_WEBHOOK_AUTH --project horizon-prod
   ```
4. Créer `functions/.env.horizon-prod` :
   ```
   PLAID_ENV=production
   ENFORCE_APP_CHECK=true
   PLAID_SKIP_WEBHOOK_VERIFICATION=false
   ```
5. Déployer : `firebase deploy --project horizon-prod`
6. Builds de prod : `flutter build <plateforme> --dart-define=APP_ENV=prod ...`
7. Règle d'or : **horizon-dbba0 = dev/test uniquement** ; aucune vraie donnée
   bancaire n'y transite (Plaid sandbox).

### Plaid production 🔧
- [ ] Demander l'accès Production sur https://dashboard.plaid.com
  (questionnaire de sécurité — les réponses : chiffrement Firestore au repos,
  tokens côté serveur uniquement, App Check, règles d'accès par foyer)
- [ ] Vérifier le webhook configuré automatiquement par `linkTokenCreate`

---

## 6. SSL et domaine réel 🔧🧪

Firebase Hosting fournit et renouvelle le TLS automatiquement :
1. Acheter le domaine (ex. `horizonapp.ca`).
2. `firebase init hosting` (dossier `build/web`), puis
   `flutter build web --dart-define=APP_ENV=prod` et `firebase deploy --only hosting`.
3. Console Firebase → Hosting → « Ajouter un domaine personnalisé » → suivre
   les enregistrements DNS (le certificat est émis en ~24 h).
4. 🧪 Vérifier le cadenas + note A sur https://www.ssllabs.com/ssltest/
5. 🔧 Ajouter le domaine dans : Authentication → Authorized domains, et dans
   les domaines autorisés de la clé reCAPTCHA.

---

## 7. Sauvegardes de la base de données 🔧🧪

Firestore est répliqué, mais **répliqué ≠ sauvegardé** (une suppression se
réplique aussi). Deux protections à activer :

1. **PITR** (récupération à un instant dans le passé, 7 jours) :
   ```
   gcloud firestore databases update --database="(default)" \
     --enable-pitr --project=horizon-prod
   ```
2. **Sauvegardes planifiées** (rétention indépendante) :
   ```
   gcloud firestore backups schedules create --database="(default)" \
     --recurrence=daily --retention=14w --project=horizon-prod
   ```
3. 🧪 **Tester une restauration réelle** (c'est le point qui compte) :
   ```
   gcloud firestore backups list --project=horizon-prod
   gcloud firestore databases restore \
     --source-backup=<backup> --destination-database=restore-test
   ```
   Vérifier les données restaurées, puis supprimer `restore-test`.
   À refaire une fois par trimestre.

---

## 8. Conformité (Loi 25) ✅🔧

- ✅ Export des données (Réglages → « Exporter mes données »)
- ✅ Suppression de compte complète (révocation Plaid, effacement Firestore
  et Auth) avec confirmation forte
- ✅ Consentement aux conditions à l'inscription
- [ ] 🔧 Faire réviser conditions + politique par un juriste avant
      commercialisation (les gabarits actuels sont un point de départ)
- [ ] 🔧 Désigner un responsable de la protection des renseignements
      personnels (obligatoire au Québec, même pour un studio solo)

---

## 9. Publication des apps 🔧

- [ ] Icônes/splash finaux, captures d'écran, fiches Play Store & App Store
- [ ] Android : bundle signé (`flutter build appbundle --dart-define=APP_ENV=prod`),
      Play App Signing
- [ ] iOS : profil de distribution, TestFlight d'abord
- [ ] Déclarer la collecte de données financières dans les questionnaires
      « Data safety » (Play) et « App Privacy » (Apple)
- [ ] Activer Crashlytics dans la console (déjà branché côté code)

---

## Suivi des déploiements (dev — horizon-dbba0)

| Date | Quoi | Statut |
| --- | --- | --- |
| 2026-07-16 | Règles + index Firestore | ✅ déployé |
| 2026-07-16 | Secret REVENUECAT_WEBHOOK_AUTH | ✅ créé |
| 2026-07-16 | Cloud Functions v2 (sécurité, settle, delete, export, rollover, webhooks) | voir journal de déploiement |
