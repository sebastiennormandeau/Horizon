// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTagline => 'Le ZBB simplifié pour les foyers';

  @override
  String get cancel => 'Annuler';

  @override
  String get save => 'Enregistrer';

  @override
  String get close => 'Fermer';

  @override
  String get copy => 'Copier';

  @override
  String get retry => 'Réessayer';

  @override
  String get continueLabel => 'Continuer';

  @override
  String get loadingError => 'Erreur de chargement';

  @override
  String get profileLoadingError => 'Erreur de chargement du profil.';

  @override
  String get pleaseReconnect => 'Veuillez vous reconnecter';

  @override
  String get householdNotFound => 'Foyer introuvable';

  @override
  String get bucketCommon => 'Commun';

  @override
  String get bucketEssential => 'Essentiel';

  @override
  String get bucketPersonal => 'Perso';

  @override
  String get bucketToSort => 'À trier';

  @override
  String bucketMe(String name) {
    return '$name (moi)';
  }

  @override
  String get loginError => 'Erreur de connexion';

  @override
  String get resetPasswordInvalidEmail =>
      'Entrez une adresse courriel valide pour réinitialiser le mot de passe.';

  @override
  String get resetPasswordSent =>
      'Email de réinitialisation envoyé. Vérifiez votre boîte de réception.';

  @override
  String get sendError => 'Erreur lors de l\'envoi.';

  @override
  String get emailLabel => 'Email';

  @override
  String get passwordLabel => 'Mot de passe';

  @override
  String get passwordRequired => 'Veuillez entrer votre mot de passe.';

  @override
  String get signIn => 'Se connecter';

  @override
  String get forgotPassword => 'Mot de passe oublié ?';

  @override
  String get createAccount => 'Créer un compte';

  @override
  String get registerTitle => 'Inscription';

  @override
  String get mustAcceptTerms =>
      'Vous devez accepter les conditions d\'utilisation.';

  @override
  String get registerError => 'Erreur d\'inscription';

  @override
  String get firstNameLabel => 'Prénom';

  @override
  String get firstNameHelper => 'Affiché à votre partenaire dans le foyer';

  @override
  String get passwordHelper => '8 caractères min., avec lettres et chiffres';

  @override
  String get confirmPasswordLabel => 'Confirmer le mot de passe';

  @override
  String get iAcceptThe => 'J\'accepte les ';

  @override
  String get termsLinkLabel => 'Conditions d\'utilisation';

  @override
  String get andThe => ' et la ';

  @override
  String get privacyLinkLabel => 'Politique de confidentialité';

  @override
  String get sentencePeriod => '.';

  @override
  String get termsDocTitle => 'Conditions d\'Utilisation';

  @override
  String get privacyDocTitle => 'Politique de Confidentialité';

  @override
  String get verifyEmailTitle => 'Vérification du courriel';

  @override
  String get signOut => 'Se déconnecter';

  @override
  String get verificationSent =>
      'Courriel de vérification envoyé. Vérifiez vos courriels (et vos indésirables).';

  @override
  String get confirmYourEmail => 'Confirmez votre adresse courriel';

  @override
  String verificationBody(String email) {
    return 'Un lien de vérification a été envoyé à\n$email\n\nHorizon gère des données financières : la vérification de votre adresse est obligatoire.';
  }

  @override
  String resendIn(String seconds) {
    return 'Renvoyer dans $seconds s';
  }

  @override
  String get resendEmail => 'Renvoyer le courriel';

  @override
  String get iConfirmedMyEmail => 'J\'ai confirmé mon adresse';

  @override
  String get mfaEnrollTitle => 'Sécurisez votre compte';

  @override
  String get mfaEnrollHeading => 'Double authentification obligatoire';

  @override
  String get mfaEnrollIntro =>
      'Horizon gère des données financières : un deuxième facteur est exigé pour tous les comptes. Cette étape prend deux minutes et ne se fait qu\'une seule fois.';

  @override
  String get mfaStep1 => '1. Installez une application d\'authentification';

  @override
  String get mfaStep1Detail =>
      'Google Authenticator, Microsoft Authenticator, Authy, ou le gestionnaire de mots de passe de votre téléphone.';

  @override
  String get mfaStep2 => '2. Scannez ce code QR';

  @override
  String get mfaStep2Manual =>
      'Impossible de scanner ? Entrez cette clé manuellement dans l\'application :';

  @override
  String get mfaCopyKey => 'Copier la clé';

  @override
  String get mfaKeyCopied => 'Clé copiée dans le presse-papiers.';

  @override
  String get mfaStep3 => '3. Entrez le code affiché';

  @override
  String get mfaCodeLabel => 'Code à 6 chiffres';

  @override
  String get mfaCodeRequired => 'Entrez le code à 6 chiffres.';

  @override
  String get mfaCodeInvalidFormat =>
      'Le code doit contenir exactement 6 chiffres.';

  @override
  String get mfaActivate => 'Activer la double authentification';

  @override
  String get mfaDeviceNameDefault => 'Application d\'authentification';

  @override
  String get mfaEnrollSuccess =>
      'Double authentification activée. Votre compte est protégé.';

  @override
  String get mfaEnrollError => 'L\'activation a échoué. Réessayez.';

  @override
  String get mfaCodeRejected =>
      'Code refusé. Vérifiez l\'heure de votre téléphone et entrez le code affiché en ce moment.';

  @override
  String get mfaRecentLoginRequired =>
      'Par sécurité, reconnectez-vous avant d\'activer la double authentification.';

  @override
  String get mfaPreparing => 'Préparation de la clé de sécurité...';

  @override
  String get mfaSecretError =>
      'Impossible de générer la clé de sécurité. Réessayez.';

  @override
  String get mfaBackupWarning =>
      'Important : gardez l\'accès à cette application d\'authentification. Sans elle, vous ne pourrez plus vous connecter et il faudra nous écrire pour réinitialiser votre accès.';

  @override
  String get mfaOpenInApp => 'Ouvrir dans mon application d\'authentification';

  @override
  String get mfaChallengeTitle => 'Vérification en deux étapes';

  @override
  String get mfaChallengeHeading => 'Entrez votre code de sécurité';

  @override
  String mfaChallengeIntro(String email) {
    return 'Ouvrez votre application d\'authentification et entrez le code à 6 chiffres affiché pour $email.';
  }

  @override
  String get mfaVerify => 'Vérifier';

  @override
  String get mfaChallengeError =>
      'Code refusé. Réessayez avec le code affiché en ce moment.';

  @override
  String get mfaLostAccess => 'J\'ai perdu l\'accès à mon application';

  @override
  String get mfaLostAccessTitle => 'Accès perdu ?';

  @override
  String mfaLostAccessBody(String email) {
    return 'Pour votre sécurité, seul un administrateur peut réinitialiser la double authentification. Écrivez à $email depuis l\'adresse courriel de votre compte en précisant votre nom. Nous vérifierons votre identité avant toute réinitialisation.';
  }

  @override
  String get householdSetupTitle => 'Configuration du Foyer';

  @override
  String get householdCreated => 'Foyer créé !';

  @override
  String get inviteCodeIntro =>
      'Voici votre code pour inviter votre conjoint(e) :';

  @override
  String get inviteCodeNote =>
      'Il restera visible sur votre tableau de bord tant que votre partenaire n\'a pas rejoint le foyer.';

  @override
  String get householdCreateError => 'Erreur lors de la création du foyer.';

  @override
  String get invalidCodeError => 'Code invalide ou erreur.';

  @override
  String get welcomeTitle => 'Bienvenue sur Horizon';

  @override
  String get welcomeBody => 'Comment comptez-vous utiliser Horizon ?';

  @override
  String get modeSoloTitle => 'Seul(e)';

  @override
  String get modeSoloDescription =>
      'Vos dépenses essentielles et votre argent personnel, gérés pour vous seul(e).';

  @override
  String get modeCoupleTitle => 'En couple';

  @override
  String get modeCoupleDescription =>
      'Deux personnes, un budget partagé : dépenses communes, argent perso de chacun et équilibre entre vous.';

  @override
  String get modeChangeNote => 'Vous pourrez inviter un partenaire plus tard.';

  @override
  String get joinExistingTitle => 'Votre partenaire a déjà créé un foyer ?';

  @override
  String get createHouseholdButton => 'Créer un nouveau foyer';

  @override
  String get householdCreatedSolo => 'Votre foyer est prêt !';

  @override
  String get householdCreatedSoloBody =>
      'Vous pouvez commencer à configurer votre budget et connecter votre banque.';

  @override
  String get orSeparator => 'OU';

  @override
  String get joinCodeFieldLabel => 'Code de foyer (6 caractères)';

  @override
  String get joinButton => 'Rejoindre';

  @override
  String get syncingTransactions =>
      'Synchronisation des transactions en cours...';

  @override
  String get bankConnected => 'Banque connectée et synchronisée !';

  @override
  String get syncError => 'Erreur lors de la synchronisation.';

  @override
  String get plaidError => 'Erreur lors de la connexion à Plaid.';

  @override
  String assignedTo(String bucket) {
    return 'Assigné à $bucket';
  }

  @override
  String get undoAction => 'ANNULER';

  @override
  String get negativeWarningTitle => 'Attention au négatif';

  @override
  String negativeWarningBody(
    String merchant,
    String amount,
    String bucket,
    String after,
  ) {
    return 'Assigner « $merchant » ($amount) mettra la cagnotte $bucket à $after.\n\nContinuer quand même ?';
  }

  @override
  String get assignAnyway => 'Assigner quand même';

  @override
  String get settleDebtTitle => 'Régler la dette interne';

  @override
  String settleDebtBody(String debtor, String amount, String creditor) {
    return '$debtor doit $amount à $creditor.\n\nConfirmez-vous que ce montant a été remboursé (virement, argent comptant, etc.) ? La balance sera remise à zéro.';
  }

  @override
  String get confirmSettlement => 'Confirmer le règlement';

  @override
  String debtSettled(String amount) {
    return 'Dette de $amount réglée !';
  }

  @override
  String get settleError => 'Erreur lors du règlement.';

  @override
  String get bilanTooltip => 'Bilan';

  @override
  String get historyTooltip => 'Historique';

  @override
  String get budgetConfigTooltip => 'Configuration du budget';

  @override
  String get settingsTooltip => 'Réglages';

  @override
  String get transactionsToNeutralize => 'Transactions à neutraliser';

  @override
  String get alertNegativeBanner =>
      'Une cagnotte est dans le négatif — consultez le Bilan pour ajuster.';

  @override
  String alertLowBanner(String threshold) {
    return 'Une cagnotte approche de zéro (seuil : $threshold).';
  }

  @override
  String get inviteWithCode => 'Invitez votre conjoint(e) avec ce code :';

  @override
  String get internalBalanceSettled => 'Balance interne : équilibrée';

  @override
  String internalDebtOwes(String debtor, String amount, String creditor) {
    return '$debtor doit $amount à $creditor';
  }

  @override
  String get settleButton => 'RÉGLER';

  @override
  String get noTransactionsToSort => 'Aucune transaction à trier.';

  @override
  String get connectMyBank => 'Connecter ma banque';

  @override
  String get historyTitle => 'Historique';

  @override
  String get freePlanBanner => 'Plan gratuit : 30 jours d\'historique.';

  @override
  String get premiumButton => 'PREMIUM';

  @override
  String get filterAll => 'Tous';

  @override
  String get noCategorizedTransactions => 'Aucune transaction catégorisée.';

  @override
  String transactionCount(String count) {
    return '$count transaction(s)';
  }

  @override
  String totalAmount(String amount) {
    return 'Total : $amount';
  }

  @override
  String get allCategories => 'Toutes catégories';

  @override
  String get changeCategory => 'Changer la catégorie';

  @override
  String moveTo(String bucket) {
    return 'Déplacer vers $bucket';
  }

  @override
  String get sendBackToSort => 'Renvoyer dans « À trier »';

  @override
  String get sentBackToSort => 'Transaction renvoyée dans « À trier ».';

  @override
  String movedTo(String bucket) {
    return 'Déplacée vers $bucket.';
  }

  @override
  String get bilanTitle => 'Bilan';

  @override
  String get refreshTooltip => 'Rafraîchir';

  @override
  String get reportError => 'Erreur lors de la génération du bilan.';

  @override
  String get coachUnavailable => 'Le coach IA est indisponible.';

  @override
  String addedToFixedExpenses(String name, String amount) {
    return '« $name » ajouté aux dépenses fixes ($amount/mois).';
  }

  @override
  String get addError => 'Erreur lors de l\'ajout.';

  @override
  String noLongerSuggested(String name) {
    return '« $name » ne sera plus suggéré.';
  }

  @override
  String get thisMonth => 'Ce mois-ci';

  @override
  String get thisWeek => 'Cette semaine';

  @override
  String get reportUnavailable => 'Bilan indisponible.';

  @override
  String get spendingByCategory => 'Dépenses par catégorie';

  @override
  String get topMerchants => 'Principaux commerçants';

  @override
  String get recurringDetected => 'Dépenses récurrentes détectées';

  @override
  String get aiCoachSection => 'Coach budgétaire IA';

  @override
  String get monthSpending => 'Dépenses du mois';

  @override
  String get weekSpending => 'Dépenses de la semaine';

  @override
  String vsPreviousPeriod(String delta, String amount) {
    return '$delta % vs période précédente ($amount)';
  }

  @override
  String get noPreviousPeriod => 'Pas encore de période précédente à comparer.';

  @override
  String recurringInfo(String frequency, String occurrences, String monthly) {
    return 'Dépense $frequency détectée ($occurrences fois) — ≈ $monthly/mois';
  }

  @override
  String get freqLabelWeekly => 'hebdomadaire';

  @override
  String get freqLabelBiweekly => 'aux 2 semaines';

  @override
  String get freqLabelMonthly => 'mensuelle';

  @override
  String get ignore => 'Ignorer';

  @override
  String get addToBudget => 'Ajouter au budget';

  @override
  String get monthEnvelopes => 'Enveloppes du mois';

  @override
  String overBudgetBy(String amount) {
    return 'Dépassement de $amount';
  }

  @override
  String spentOfBudget(String spent, String budget) {
    return '$spent / $budget';
  }

  @override
  String get aiDisclaimer =>
      'Ces suggestions sont générées par une IA à partir de vos agrégats de dépenses et ne constituent pas un conseil financier professionnel.';

  @override
  String get aiPitch =>
      'Obtenez des observations et suggestions personnalisées, rédigées à partir des chiffres de ce bilan.';

  @override
  String get generateAdvice => 'Générer mes conseils IA';

  @override
  String get regenerateAdvice => 'Régénérer les conseils';

  @override
  String get budgetSetupTitle => 'Configuration Budget ZBB';

  @override
  String get freqMonthly => 'Mensuel';

  @override
  String get freqBiweekly => 'Bi-hebdomadaire';

  @override
  String get freqWeekly => 'Hebdomadaire';

  @override
  String get newExpenseDefault => 'Nouvelle dépense';

  @override
  String get newAllocationDefault => 'Nouvelle allocation';

  @override
  String get budgetSaved => 'Budget mensuel sauvegardé !';

  @override
  String get budgetSaveError => 'Erreur lors de la sauvegarde.';

  @override
  String get envelopesTitle => 'Enveloppes par catégorie';

  @override
  String get envelopesSubtitle =>
      'Budgets mensuels pour vos dépenses variables — le Bilan suit leur progression.';

  @override
  String get categoryFieldLabel => 'Catégorie';

  @override
  String get budgetFieldLabel => 'Budget';

  @override
  String get magicMonthsTitle => 'Calendrier des Mois Magiques 🌟';

  @override
  String get magicMonthsSubtitle =>
      'Un mois magique contient une paie supplémentaire.';

  @override
  String get nameFieldLabel => 'Nom';

  @override
  String get amountFieldLabel => 'Montant';

  @override
  String get incomeSection => 'Revenus';

  @override
  String get incomeALabel => 'Revenu A';

  @override
  String get incomeBLabel => 'Revenu B';

  @override
  String get incomeSoloLabel => 'Mon revenu';

  @override
  String get netEssentialExpenses => 'Dépenses essentielles nettes :';

  @override
  String get payFrequencyLabel => 'Fréquence de paie';

  @override
  String get nextPayDateLabel => 'Prochaine date de paie';

  @override
  String get selectADate => 'Sélectionner une date';

  @override
  String get allocationsSection => 'Allocations & Déductions';

  @override
  String get fixedExpensesSection => 'Dépenses Fixes Communes';

  @override
  String get alertThresholdTitle => 'Seuil d\'alerte des cagnottes';

  @override
  String get alertThresholdSubtitle =>
      'En dessous de ce montant, une cagnotte passe en orange sur le tableau de bord.';

  @override
  String get thresholdFieldLabel => 'Seuil (\$)';

  @override
  String get proRataTitle => 'Répartition pro-rata';

  @override
  String userAShare(String pct) {
    return 'User A : $pct%';
  }

  @override
  String userBShare(String pct) {
    return 'User B : $pct%';
  }

  @override
  String get netCommonExpenses => 'Dépenses nettes communes :';

  @override
  String aPays(String amount) {
    return 'A paie : $amount';
  }

  @override
  String bPays(String amount) {
    return 'B paie : $amount';
  }

  @override
  String get saveBudgetButton => 'Sauvegarder le Budget';

  @override
  String get settingsTitle => 'Réglages';

  @override
  String get editMyName => 'Modifier mon prénom';

  @override
  String get nameUpdated => 'Prénom mis à jour.';

  @override
  String get updateError => 'Erreur lors de la mise à jour.';

  @override
  String get myDataJson => 'Mes données (JSON)';

  @override
  String get copiedToClipboard => 'Données copiées dans le presse-papiers.';

  @override
  String get exportError => 'Erreur lors de l\'export.';

  @override
  String get deleteAccountTitle => 'Supprimer mon compte';

  @override
  String deleteAccountBody(String keyword) {
    return 'Cette action est IRRÉVERSIBLE :\n\n• Vos connexions bancaires seront révoquées\n• Vos transactions seront supprimées\n• Votre compte sera définitivement effacé\n\nTapez $keyword pour confirmer :';
  }

  @override
  String get deleteKeyword => 'SUPPRIMER';

  @override
  String get deleteForever => 'Supprimer définitivement';

  @override
  String get deleteError => 'Erreur lors de la suppression.';

  @override
  String get profileSection => 'Profil';

  @override
  String get emailVerified => 'Courriel vérifié';

  @override
  String get emailNotVerified => 'Courriel non vérifié';

  @override
  String get subscriptionSection => 'Abonnement';

  @override
  String get premiumPlanTitle => 'Horizon Premium';

  @override
  String get freePlanTitle => 'Plan gratuit';

  @override
  String get manageSubscription =>
      'Gérez votre abonnement depuis l\'App Store / Play Store.';

  @override
  String get freePlanLimits => '1 compte bancaire, 30 jours d\'historique';

  @override
  String get myDataSection => 'Mes données (Loi 25)';

  @override
  String get exportMyData => 'Exporter mes données';

  @override
  String get exportSubtitle => 'Copie JSON de toutes vos données';

  @override
  String get accountSection => 'Compte';

  @override
  String get deleteAccountSubtitle =>
      'Suppression définitive de toutes vos données';

  @override
  String get languageSection => 'Langue / Language';

  @override
  String get languageTile => 'Langue de l\'application';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSystem => 'Automatique (langue de l\'appareil)';

  @override
  String get paywallTitle => 'Horizon Premium';

  @override
  String get featUnlimitedBanks => 'Comptes bancaires illimités';

  @override
  String get featFullHistory => 'Historique complet et illimité';

  @override
  String get featRealtimeSync => 'Synchronisation en temps réel';

  @override
  String get featPrioritySupport => 'Soutien prioritaire';

  @override
  String get purchaseWelcome =>
      'Bienvenue dans Horizon Premium ! Activation en cours (quelques secondes)...';

  @override
  String get purchaseFailed => 'L\'achat a échoué. Réessayez.';

  @override
  String get purchasesRestored => 'Achats restaurés avec succès !';

  @override
  String get nothingToRestore => 'Aucun achat à restaurer.';

  @override
  String get goPremium => 'Passez à Horizon Premium';

  @override
  String get webNoPurchase =>
      'L\'abonnement s\'effectue depuis l\'application mobile Horizon (Android ou iPhone). Une fois abonné, votre statut Premium s\'applique automatiquement à tout votre foyer, y compris sur le Web.';

  @override
  String get storeUnavailable =>
      'La boutique n\'est pas encore disponible. Réessayez plus tard.';

  @override
  String get restorePurchases => 'Restaurer mes achats';

  @override
  String get vEmailRequired => 'Veuillez entrer votre adresse courriel.';

  @override
  String get vEmailInvalid => 'Adresse courriel invalide.';

  @override
  String get vPasswordRequired => 'Veuillez entrer un mot de passe.';

  @override
  String get vPasswordTooShort =>
      'Le mot de passe doit contenir au moins 8 caractères.';

  @override
  String get vPasswordNeedsLetterDigit =>
      'Le mot de passe doit contenir au moins une lettre et un chiffre.';

  @override
  String get vPasswordMismatch => 'Les mots de passe ne correspondent pas.';

  @override
  String get vNameTooShort => 'Veuillez entrer votre prénom (2 lettres min.).';

  @override
  String get vNameTooLong => 'Prénom trop long (40 caractères max.).';

  @override
  String get vJoinCodeInvalid => 'Le code doit contenir 6 lettres ou chiffres.';

  @override
  String get householdSection => 'Foyer';

  @override
  String get householdManageTitle => 'Gérer mon foyer';

  @override
  String get householdManageSubtitle => 'Mode, invitation, séparation';

  @override
  String get householdStatusSolo => 'Vous utilisez Horizon seul(e).';

  @override
  String get householdStatusWaiting => 'En attente d\'un second membre.';

  @override
  String householdStatusCouple(String name) {
    return 'Foyer partagé avec $name.';
  }

  @override
  String get invitePartnerTitle => 'Inviter un partenaire';

  @override
  String get invitePartnerBody =>
      'Votre foyer passera en mode couple : une cagnotte personnelle pour chacun, une cagnotte commune, et le suivi des avances entre vous. Les dépenses communes seront partagées 50/50 par défaut — vous pourrez ajuster la répartition dans la configuration du budget.';

  @override
  String get invitePartnerAction => 'Passer en mode couple';

  @override
  String get invitePartnerDone => 'Mode couple activé.';

  @override
  String get shareCodeTitle => 'Code d\'invitation';

  @override
  String get shareCodeBody =>
      'Votre partenaire crée son compte Horizon, puis choisit « Rejoindre un foyer » et saisit ce code.';

  @override
  String get copyCode => 'Copier le code';

  @override
  String get codeCopied => 'Code copié.';

  @override
  String get backToSoloTitle => 'Revenir en mode solo';

  @override
  String get backToSoloBody =>
      'Le code d\'invitation sera annulé et vous assumerez de nouveau seul(e) les dépenses communes. Possible tant que personne n\'a rejoint votre foyer.';

  @override
  String get backToSoloAction => 'Revenir en solo';

  @override
  String get backToSoloDone => 'Mode solo réactivé.';

  @override
  String get leaveHouseholdTitle => 'Quitter le foyer';

  @override
  String get leaveHouseholdSubtitle => 'En cas de séparation';

  @override
  String leaveHouseholdBody(String name, String keyword) {
    return 'Cette action est IRRÉVERSIBLE :\n\n• Vos connexions bancaires seront révoquées\n• Vos transactions seront supprimées de ce foyer\n• Les bilans du foyer seront effacés (ils mêlent vos dépenses)\n• La dette interne sera annulée — réglez-la avant si nécessaire\n• $name se retrouvera seul(e) dans le foyer\n\nVotre compte Horizon est conservé : vous pourrez créer un nouveau foyer.\n\nTapez $keyword pour confirmer :';
  }

  @override
  String get leaveKeyword => 'QUITTER';

  @override
  String get leaveHouseholdAction => 'Quitter définitivement';

  @override
  String get leaveHouseholdDone => 'Vous avez quitté le foyer.';

  @override
  String leaveDebtWarning(String amount) {
    return 'Dette interne en cours : $amount. Elle sera annulée sans compensation.';
  }

  @override
  String get cannotRemovePartner =>
      'Vous ne pouvez pas retirer votre partenaire : il doit quitter le foyer lui-même, depuis son propre appareil.';

  @override
  String get householdActionError => 'L\'opération a échoué. Réessayez.';

  @override
  String get resetDataTitle => 'Réinitialiser les données du foyer';

  @override
  String get resetDataSubtitle => 'Repartir à zéro sans supprimer les comptes';

  @override
  String resetDataBody(String keyword) {
    return 'Tout l\'historique financier du foyer sera effacé :\n\n• Connexions bancaires révoquées\n• Toutes les transactions supprimées\n• Budgets, règlements et bilans effacés\n• Cagnottes et dette remises à zéro\n\nLes comptes, le foyer et votre double authentification sont conservés.\n\nTapez $keyword pour confirmer :';
  }

  @override
  String get resetKeyword => 'REINITIALISER';

  @override
  String get resetDataAction => 'Tout réinitialiser';

  @override
  String resetDataDone(int count) {
    return '$count transaction(s) supprimée(s). Le foyer repart à zéro.';
  }

  @override
  String get resetDataOwnerOnly =>
      'Seul le membre qui a créé le foyer peut réinitialiser ses données.';

  @override
  String get transitionAdviceCta => 'Conseils du coach pour cette étape';

  @override
  String get transitionToCoupleTitle => 'Passage en mode couple';

  @override
  String get transitionToSoloTitle => 'Retour en mode solo';

  @override
  String get transitionAdviceIntro =>
      'Un changement de situation bouscule un budget. Le coach vous propose des bonnes pratiques pour aborder cette étape sereinement.';

  @override
  String get transitionAdviceGenerate => 'Obtenir mes conseils';

  @override
  String get transitionAdviceLoading => 'Le coach rédige vos conseils...';

  @override
  String get transitionAdviceError =>
      'Impossible de générer les conseils pour le moment.';
}
