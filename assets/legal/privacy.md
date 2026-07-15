# Politique de Confidentialité

Dernière mise à jour : 15 juillet 2026

**Vibe Coding Mind** (le "Studio", "Nous") accorde une grande importance à la vie privée de ses utilisateurs. Cette Politique de confidentialité décrit la manière dont l'application **Horizon** collecte, utilise et protège vos données personnelles, en stricte conformité avec les normes nord-américaines, incluant la **Loi 25 du Québec**.

## 1. Données collectées

### A. Données d'Identification et de Compte
Pour créer votre compte ou un Foyer, nous collectons :
- Votre adresse courriel (chiffrée et sécurisée par Firebase Authentication).
- Un code de foyer alphanumérique (pour lier des comptes conjoints).

### B. Données Financières (Lecture seule)
Lorsque vous connectez votre banque, nous utilisons un fournisseur de confiance (Plaid). **Nous ne stockons JAMAIS vos identifiants bancaires.**
Nous collectons et stockons (sur Firebase Firestore) :
- Le nom de la transaction, le montant et la date.
- Des "Tokens" d'accès sécurisés nous permettant de rafraîchir la liste de vos transactions.

### C. Données d'Utilisation
Nous utilisons **Google Analytics** et **Firebase Crashlytics** pour détecter les bugs (crashs) et comprendre l'utilisation générale de l'application de façon anonymisée.

## 2. Utilisation des Données

Vos données sont utilisées exclusivement pour :
- Fournir le service central de l'application (le moteur de budget Zero-Based).
- Synchroniser les transactions avec vos appareils et ceux de votre conjoint (dans le cadre du "Foyer Partagé").
- Traiter l'abonnement Premium via notre partenaire **RevenueCat**.
- Assurer la sécurité des accès via **Firebase App Check**.

**Nous ne vendons AUCUNE donnée personnelle ou financière à des tiers.**

## 3. Fournisseurs Tiers

Pour fonctionner, l'application s'appuie sur l'infrastructure de tiers certifiés et hautement sécurisés :
- **Google Firebase (Firestore, Auth, Functions)** : Hébergement principal des données dans le cloud.
- **Plaid Inc.** : Agrégateur bancaire sécurisé. En liant votre banque, vous acceptez également la politique de confidentialité de Plaid (disponible sur plaid.com/legal).
- **RevenueCat** : Gestion des abonnements et des achats intégrés.

## 4. Sécurité et Rétention (Conformité Loi 25)

Conformément à la Loi 25 du Québec :
- **Sécurité** : Vos données sont chiffrées en transit (HTTPS) et au repos par les serveurs de Google. L'accès à la base de données est restreint par des Règles de Sécurité rigides (votre compte ne peut lire que les données de son propre foyer).
- **Rétention** : Vos données transactionnelles et budgétaires sont conservées tant que votre compte est actif.
- **Droit à l'oubli** : Vous avez le droit de demander la suppression intégrale de vos données. Cette demande supprimera votre compte, les tokens de connexion Plaid et toutes les transactions associées de nos serveurs.

## 5. Contact du Responsable de la Protection des Données

Si vous avez des questions sur vos données personnelles ou si vous souhaitez exercer vos droits, vous pouvez contacter notre responsable à la protection de la vie privée à : [Adresse Email Support].
