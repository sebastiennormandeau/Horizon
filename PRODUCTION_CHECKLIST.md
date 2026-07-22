# Horizon — Checklist de mise en production

> Dernière mise à jour : 19 juillet 2026
>
> Légende : ✅ fait dans le code (rien à faire) · 🔧 action manuelle requise
> (console/compte) · 🧪 à tester une fois l'infrastructure en place

---

## 0. Gouvernance de sécurité

### ✅ Politique de sécurité documentée (fait)
- **[SECURITY_POLICY.md](SECURITY_POLICY.md)** : politique formelle (contrôle
  d'accès, chiffrement, secrets, postes de travail, réponse aux incidents,
  cycle de vie des données), version 1.1 du 19 juillet 2026, **revue
  annuelle obligatoire** (prochaine : juillet 2027). C'est ce document qu'on
  référence dans les questionnaires de sécurité (Plaid, stores).
- **[ACCESS_CONTROL_POLICY.md](ACCESS_CONTROL_POLICY.md)** : politique de
  contrôle d'accès dédiée (rôles, moindre privilège, octroi/retrait,
  revue trimestrielle des accès) — c'est ce document précis qu'on référence
  pour la **question 3 du questionnaire de sécurité Plaid** (contrôle
  d'accès aux données).
- **[DATA_RETENTION_DISPOSAL_POLICY.md](DATA_RETENTION_DISPOSAL_POLICY.md)** :
  politique de rétention et de disposition (durée de conservation et
  déclencheur de suppression par catégorie de données, séquence réelle de
  `deleteAccount`, rétention des sauvegardes, fondement Loi 25) — document
  à référencer pour la **question 11 du questionnaire de sécurité Plaid**
  (rétention et destruction des données).
- **Versions PDF** prêtes à transmettre à côté de chaque politique
  (`*.pdf`). **Les régénérer après toute modification du Markdown** :
  ```
  node tools/md2html.js SECURITY_POLICY.md "$env:TEMP\p.html"
  & "C:\Program Files\Google\Chrome\Application\chrome.exe" --headless `
    --disable-gpu --no-pdf-header-footer `
    --print-to-pdf="SECURITY_POLICY.pdf" "file:///$($env:TEMP -replace '\\','/')/p.html"
  ```

### 🔧 MFA sur les accès internes (obligatoire — voir politique §1)

**Groupe A — comptes existants.** ✅ **Fait le 19 juillet 2026**
(Google, GitHub, Plaid, Anthropic).

**Groupe B — comptes pas encore créés : MFA à activer dès l'inscription.**
- [ ] **RevenueCat** (app.revenuecat.com) : Account → Security → 2FA —
      *seulement si tu commercialises* (voir §3) ; l'app fonctionne
      parfaitement sans, le paywall affiche « boutique non disponible »

### ✅ MFA obligatoire pour les utilisateurs de l'app (fait)
Identity Platform est activé avec **MFA obligatoire (TOTP)** pour tous les
comptes, et l'application implémente le cycle complet :

- **Enrôlement forcé** (`lib/screens/mfa_enroll_screen.dart`) : porte dans
  `AuthRouter`, placée **après** la vérification du courriel — Firebase exige
  un courriel vérifié avant d'accepter un second facteur. Code QR + clé
  manuelle + confirmation par code à 6 chiffres. Seule sortie : déconnexion.
- **Défi à la connexion** (`lib/screens/mfa_challenge_screen.dart`) :
  `LoginScreen` intercepte `FirebaseAuthMultiFactorException` et résout la
  session via le `resolver`.
- L'ordre des portes est : courriel vérifié → **MFA enrôlé** → foyer → accueil.

### 🔧 Récupération d'accès MFA (procédure administrateur)
Firebase n'offre **aucune récupération intégrée** pour le TOTP : un
utilisateur qui perd son application d'authentification est bloqué. Le
pouvoir de réinitialisation est volontairement **hors de l'application**
(une fonction déployée « admin » serait une porte dérobée exposée) :

1. **Prérequis, une seule fois** — installer Google Cloud CLI
   (https://cloud.google.com/sdk/docs/install ; il sert aussi aux
   sauvegardes du §7), puis :
   ```
   gcloud auth application-default login
   ```
2. **Consulter** les facteurs d'un compte :
   ```
   cd functions
   node scripts/mfa-admin.js list quelquun@example.com
   ```
3. **Réinitialiser** (retire les facteurs et révoque les sessions) :
   ```
   node scripts/mfa-admin.js reset quelquun@example.com
   ```
   L'utilisateur peut alors se reconnecter avec son mot de passe seul, et la
   porte MFA le force immédiatement à ré-enrôler une application.
- ⚠️ **Vérifier l'identité du demandeur par un canal indépendant du
  courriel** (appel téléphonique) avant toute réinitialisation : une boîte
  courriel compromise est précisément le scénario contre lequel le MFA
  protège. Consigner la demande (registre — SECURITY_POLICY.md §6).
- Le script n'est jamais déployé (exclusion `scripts` dans `firebase.json`)
  et exige les identifiants Google administrateur, eux-mêmes sous MFA.

### ✅ Gestion des vulnérabilités (fait côté code)
- **Dependabot** actif (`.github/dependabot.yml`) : npm (fonctions), pub
  (Flutter) et GitHub Actions, vérification hebdomadaire.
- **`npm audit --audit-level=high` bloque le CI** (vulnérabilités élevées
  et critiques). État au 18 juillet 2026 : 0 élevée/critique ; 7 modérées
  restantes, toutes transitives dans firebase-admin (uuid < 11.1.1, chemin
  Storage non utilisé par Horizon) — se résorberont via Dependabot.
- **firebase-admin 14 + firebase-functions 6 + runtime Node 22** (Node 20
  était déprécié, décommission le 2026-10-30).
- [ ] 🔧 Poste de travail : mises à jour automatiques de Windows activées,
      **BitLocker** activé (Paramètres → Confidentialité et sécurité →
      Chiffrement de l'appareil), Microsoft Defender actif.

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
- 🔧🐛 **Problème confirmé le 19 juillet 2026 : courriel de vérification non
  livré aux adresses @icloud.com** (ni boîte de réception, ni indésirables).
  Diagnostic : le domaine d'envoi par défaut de Firebase
  (`noreply@<projet>.firebaseapp.com`) est partagé par des milliers de
  projets et a une réputation inégale ; les serveurs iCloud rejettent
  silencieusement plutôt que de mettre en indésirables. Ce n'est pas un bug
  du code — `sendEmailVerification()` est bien appelé et ne lève aucune
  erreur. Solution durable (à faire avant le lancement, pas seulement en
  prod — peut se faire dès maintenant avec un sous-domaine) : configurer un
  **SMTP personnalisé** dans Console Firebase → Authentication → Templates
  → paramètres SMTP, avec un fournisseur (SendGrid, Postmark, Mailgun) et
  les enregistrements SPF/DKIM sur un domaine possédé. Isoler la cause :
  tester avec une adresse Gmail/Outlook (si elle reçoit normalement, le
  diagnostic iCloud est confirmé). **Confirmé le 19 juillet 2026** :
  Gmail reçoit normalement, iCloud non — diagnostic iCloud avéré.
  Contournement temporaire pour débloquer un compte précis sans attendre
  la livraison (`functions/scripts/verify-email.js`, même prérequis gcloud
  que `mfa-admin.js`) :
  ```
  cd functions
  node scripts/verify-email.js verify quelquun@icloud.com
  ```
  ⚠️ À utiliser seulement pour un compte dont on est certain qu'il
  appartient réellement au demandeur (voir l'en-tête du script).

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
- [x] 🧪 **Enrôlement MFA d'un compte existant** — testé le 19 juillet 2026 :
      Identity Platform laisse un compte sans facteur se connecter, la porte
      d'enrôlement s'affiche, le code QR est scannable et l'accès aboutit à
      l'accueil. Facteur confirmé côté serveur via
      `node scripts/mfa-admin.js list`. **Pas de blocage œuf-poule** : nul
      besoin de repasser le MFA en optionnel pour enrôler les comptes
      existants.
- [ ] 🧪 **Défi MFA à la connexion** — chemin `FirebaseAuthMultiFactorException`
      → `MfaChallengeScreen` encore non exercé. Se déconnecter puis se
      reconnecter pour le valider (le code enrôlé sert de test).
- [ ] 🧪 Enrôler le second compte du foyer (conjointe) — même parcours
- [x] 🧪 Tester la réception réelle du courriel de vérification — **problème
      trouvé** (@icloud.com non livré, voir §1 ci-dessus). À revalider avec
      Gmail/Outlook, puis une fois le SMTP personnalisé configuré.
- [ ] 🧪 Tester « Mot de passe oublié » de bout en bout (envoi → lien → nouveau
      mot de passe → reconnexion). ⚠️ Vérifier que le défi MFA s'applique
      bien **après** la réinitialisation : un mot de passe seul ne doit
      jamais suffire à ouvrir une session.
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
- Clé API Anthropic : **Google Secret Manager** ✅ (vraie clé posée le
  19 juillet 2026 — voir §7 bis)
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
7. ⚠️ **La règle d'or a changé le 22 juillet 2026.** Elle disait
   « horizon-dbba0 = dev/test uniquement, aucune vraie donnée bancaire ».
   Ce n'est plus vrai : voir §5 bis. Le projet `horizon-prod` reste requis
   **avant toute ouverture au public**, et les données du pilote ne seront
   pas migrées.

---

## 5 bis. Pilote avec données bancaires réelles (horizon-dbba0) 🔧🧪

Plaid a accordé un **accès production limité** (pas la production complète,
dont le questionnaire est encore en revue). Objectif : valider l'app au
quotidien à deux comptes nommés, avec de vraies transactions.

**Conséquence assumée** : `horizon-dbba0` cesse d'être un bac à sable. Il
devient un *environnement de pilote restreint* soumis à toutes les mesures de
SECURITY_POLICY.md — laquelle a été mise à jour en conséquence (v1.2 §4),
ainsi que DATA_RETENTION_DISPOSAL_POLICY.md (v1.1 §4). Ces deux documents
étant transmis à Plaid, leur contenu doit rester exact.

### Ordre des opérations (l'ordre compte)

1. **Vider les données de test d'abord**, tant que Plaid est encore en
   sandbox : app → Réglages → Gérer mon foyer → « Réinitialiser les données
   du foyer » → taper `REINITIALISER`. La révocation des items sandbox
   réussit tant qu'on n'a pas basculé ; après bascule elle échouerait (les
   jetons sandbox n'existent pas en production) et l'erreur serait seulement
   consignée. À faire **sur chaque foyer de test**.
2. **Poser le secret de production Plaid** (le `client_id` est le même pour
   tous les environnements, seul le **secret** diffère — le récupérer dans
   https://dashboard.plaid.com → Developers → Keys → *Production*) :
   ```
   firebase functions:secrets:set PLAID_SECRET --project horizon-dbba0
   ```
   Coller la valeur au prompt. ⚠️ **Ne pas détruire l'ancienne version avant
   d'avoir redéployé** (leçon du 19 juillet : une version détruite alors
   qu'elle était encore liée casse les fonctions).
3. **Basculer l'environnement** dans `functions/.env` : `PLAID_ENV=production`.
4. **Redéployer** les fonctions qui utilisent Plaid :
   ```
   firebase deploy --only "functions:generatePlaidLinkToken,functions:exchangePublicToken,functions:plaidWebhookHandler,functions:deleteAccount,functions:leaveHousehold,functions:resetHouseholdData" --project horizon-dbba0
   ```
5. **Activer les sauvegardes** — obligatoire maintenant qu'il y a de vraies
   données (voir §7, en remplaçant `horizon-prod` par `horizon-dbba0`).

### OAuth : le point qui bloque en pratique 🔧

En production, la quasi-totalité des institutions **canadiennes** impose
l'OAuth : la banque authentifie chez elle puis renvoie vers l'app. Le code
est prêt et piloté par deux variables facultatives de `functions/.env` — à
vide, le comportement actuel est inchangé.

| Plateforme | Variable à définir | À enregistrer dans le tableau de bord Plaid |
| --- | --- | --- |
| **Web / iOS** (retenu) | `PLAID_REDIRECT_URI=https://horizon-dbba0.web.app/` | Team Settings → API → *Allowed redirect URIs* |
| Android natif (non retenu) | `PLAID_ANDROID_PACKAGE=com.vibecodingmind.horizon` | Team Settings → API → *Allowed Android package names* |

**Décision du 22 juillet 2026 : ce sera le Web**, pour les deux membres du
foyer. Motif : un iPhone sans compte Apple Developer (99 $ US/an) ne peut pas
installer d'app native ; le Web s'ajoute à l'écran d'accueil et s'ouvre en
plein écran. L'app est donc hébergée (§6) sur https://horizon-dbba0.web.app.

⚠️ **`flutter run -d chrome` ne pourra jamais terminer un parcours OAuth** :
Plaid refuse `localhost`. Pour tester une vraie banque, il faut passer par
l'URL hébergée. Le développement local reste possible pour tout le reste.

**Ordre impératif** — Plaid rejette `link/token/create` si l'URL de
redirection n'est pas déjà dans l'allowlist. Définir `PLAID_REDIRECT_URI`
avant de l'enregistrer casserait **toute** connexion bancaire, y compris en
sandbox :
1. Tableau de bord Plaid → Team Settings → API → *Allowed redirect URIs* →
   ajouter exactement `https://horizon-dbba0.web.app/` (barre oblique finale
   comprise).
2. Seulement ensuite, ajouter dans `functions/.env` :
   `PLAID_REDIRECT_URI=https://horizon-dbba0.web.app/`
3. Redéployer `generatePlaidLinkToken`.
- Côté client, la reprise après redirection est implémentée
  (`_resumePlaidOAuth` dans `home_screen.dart` : le jeton est mis de côté
  avant l'ouverture et Link est rouvert avec `receivedRedirectUri`).
  ⚠️ **Non testé de bout en bout** — impossible sans clés de production et
  sans app hébergée. À valider au premier parcours réel.

### Vérifications 🧪
- [ ] Le webhook est bien celui de `linkTokenCreate`
      (`https://us-central1-horizon-dbba0.cloudfunctions.net/plaidWebhookHandler`)
      et la signature JWT est vérifiée (`PLAID_SKIP_WEBHOOK_VERIFICATION=false`)
- [ ] Une vraie banque se connecte et importe des transactions réelles
- [ ] Le plan gratuit bloque bien la 2ᵉ connexion bancaire du foyer
- [ ] La suppression de compte révoque réellement l'item côté Plaid
      (vérifier dans le tableau de bord que l'item disparaît)
- [ ] 🔧 Activer App Check en application réelle (§1) : avec de vraies
      données bancaires, `ENFORCE_APP_CHECK=false` devient difficile à
      justifier

---

## 6. Hébergement, SSL et domaine réel ✅🔧🧪

### ✅ App web en ligne (22 juillet 2026)
https://horizon-dbba0.web.app sert l'application Flutter, avec TLS fourni et
renouvelé automatiquement par Firebase. Les pages légales restent servies aux
mêmes adresses (`/privacy`, `/terms`, `/privacy-en`, `/terms-en`).
**Republier après toute modification du code :**
```
flutter build web
firebase deploy --only hosting --project horizon-dbba0
```
- ⚠️ **L'inscription est désormais publique** : n'importe qui atteignant
  l'URL peut créer un compte. Les protections en place restent le courriel
  vérifié, le MFA obligatoire, le cloisonnement par foyer et le rate
  limiting. C'est l'argument principal pour activer **App Check en
  application réelle** (§1) maintenant que la base contient de vraies
  données bancaires.
- 🔧 Pour ajouter l'app à l'écran d'accueil d'un iPhone : Safari → Partager →
  « Sur l'écran d'accueil ». Elle s'ouvre alors en plein écran, sans barre
  d'adresse (metas iOS dans `web/index.html`).

### 🔧 Domaine réel
1. Acheter le domaine (ex. `horizonapp.ca`).
2. Builder en prod : `flutter build web --dart-define=APP_ENV=prod`.
3. Console Firebase → Hosting → « Ajouter un domaine personnalisé » → suivre
   les enregistrements DNS (le certificat est émis en ~24 h).
4. 🧪 Vérifier le cadenas + note A sur https://www.ssllabs.com/ssltest/
5. 🔧 Ajouter le domaine dans : Authentication → Authorized domains, et dans
   les domaines autorisés de la clé reCAPTCHA.

---

## 7. Sauvegardes de la base de données 🔧🧪

⚠️ **Devenu urgent le 22 juillet 2026** : `horizon-dbba0` héberge maintenant
de vraies données bancaires (§5 bis). Exécuter les commandes ci-dessous en
remplaçant `horizon-prod` par **`horizon-dbba0`** dès maintenant, puis de
nouveau sur le projet de production le jour où il existera.

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

## 7 bis. Coach budgétaire IA 🔧

Le code est prêt (fonction `generateCoachAdvice`, écran Bilan). À faire :

1. ✅ **Clé API Anthropic — configurée le 19 juillet 2026** (version 2 du
   secret ; la version 1 `REPLACE_ME` a été détruite, fonction redéployée).
   Marche à suivre conservée pour la **rotation** et pour le futur projet
   de production, qui aura son propre secret :
   1. Créer un compte sur https://console.anthropic.com
      (**activer le MFA immédiatement** : Settings → Security — groupe B du §0).
   2. Ajouter un moyen de paiement / des crédits : Settings → **Billing**.
      L'API est prépayée et distincte d'un abonnement Claude.ai — un
      abonnement Pro ne donne **pas** de crédits API. 5 $ US suffisent
      largement pour tester (~100 bilans à ~5 ¢).
   3. Créer la clé : Settings → **API keys** → *Create key*. Elle commence
      par `sk-ant-`. **Elle ne s'affiche qu'une seule fois** — copie-la.
   4. Enregistrer le secret **dans ton propre terminal** (la commande
      demande la valeur de façon interactive : la clé n'apparaît ni dans
      l'historique du shell ni dans une conversation) :
      ```
      firebase functions:secrets:set ANTHROPIC_API_KEY --project horizon-dbba0
      ```
      Coller la clé au prompt `? Enter a value for ANTHROPIC_API_KEY`, Entrée.
   5. Redéployer la fonction pour qu'elle prenne la nouvelle version du
      secret (obligatoire — sans ça elle continue de lire `REPLACE_ME`) :
      ```
      firebase deploy --only functions:generateCoachAdvice --project horizon-dbba0
      ```
   6. 🧪 Tester : app → Bilan → « Générer mes conseils IA ».
   - ⚠️ **Ne jamais** mettre la clé dans le code, dans `functions/.env`, ni
     dans un message — uniquement Secret Manager (politique de sécurité §3).
   - Rotation : refaire les étapes 3 à 5 (l'ancienne clé se révoque depuis
     la console Anthropic).
2. **En production** : dans `functions/.env.<projet-prod>`, mettre
   `AI_COACH_REQUIRE_PREMIUM=true` — le coach devient un argument Premium.
   En dev (`functions/.env`), il est ouvert à tous pour tester.
3. **Coûts** : ~5 ¢ par bilan (Claude Opus 4.8 avec réflexion adaptative,
   ~2 500 tokens d'entrée / ~1 500 de sortie incluant la réflexion), limité
   à 5 générations/jour/utilisateur par le rate limiting. Surveiller la
   consommation sur console.anthropic.com.
4. **Confidentialité** : seuls des agrégats anonymisés sont transmis —
   totaux par catégorie, commerçants, cagnottes, et montants budgétaires
   agrégés (revenus totaux, dépenses fixes, objectifs d'enveloppes) —
   documenté dans la politique de confidentialité, §3 (fr **et** en).
   Ne jamais élargir la charge utile sans mettre à jour les deux politiques.
5. **Langue** : le coach répond dans la langue active de l'app (fr/en) ;
   le conseil est partagé par le foyer — le bouton « Régénérer » permet à
   l'autre partenaire de l'obtenir dans sa langue.

## 8. Conformité (Loi 25) ✅🔧

- ✅ Export des données (Réglages → « Exporter mes données »)
- ✅ Suppression de compte complète (révocation Plaid, effacement Firestore
  et Auth) avec confirmation forte
- ✅ Consentement aux conditions à l'inscription
- ✅ Responsable de la protection des renseignements personnels désigné
  (obligation Loi 25) : **Sébastien Normandeau**, contact indiqué dans la
  politique de confidentialité (§5) — le placeholder a été remplacé.
- ✅ **Politique publiée sur une URL publique** (exigence Plaid) :
  https://horizon-dbba0.web.app/privacy (+ /terms, /privacy-en, /terms-en).
  Depuis le 22 juillet 2026, Firebase Hosting sert **l'application elle-même**
  (`build/web`) ; les pages légales vivent dans `web/` pour que
  `flutter build web` les recopie dans le bundle. ⚠️ Toute modification de
  `assets/legal/*.md` doit être répercutée dans `web/*.html` (et
  vice-versa). **Déploiement en deux temps obligatoire** — sans le build,
  on republie l'ancien bundle :
  ```
  flutter build web
  firebase deploy --only hosting --project horizon-dbba0
  ``` Quand le domaine réel existera (§6),
  mettre à jour l'URL dans les politiques et sur le dashboard Plaid.
- [ ] 🔧 Remplacer le courriel personnel par une adresse dédiée
      (ex. confidentialite@horizonapp.ca) quand le domaine existera.
- [ ] 🔧 Faire réviser conditions + politique par un juriste avant
      commercialisation (les gabarits actuels sont un point de départ) —
      y compris les traductions anglaises de courtoisie

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
