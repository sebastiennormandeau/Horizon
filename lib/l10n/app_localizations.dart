import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @appTagline.
  ///
  /// In fr, this message translates to:
  /// **'Le ZBB simplifié pour les foyers'**
  String get appTagline;

  /// No description provided for @cancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get save;

  /// No description provided for @close.
  ///
  /// In fr, this message translates to:
  /// **'Fermer'**
  String get close;

  /// No description provided for @copy.
  ///
  /// In fr, this message translates to:
  /// **'Copier'**
  String get copy;

  /// No description provided for @retry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get retry;

  /// No description provided for @continueLabel.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get continueLabel;

  /// No description provided for @loadingError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur de chargement'**
  String get loadingError;

  /// No description provided for @profileLoadingError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur de chargement du profil.'**
  String get profileLoadingError;

  /// No description provided for @pleaseReconnect.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez vous reconnecter'**
  String get pleaseReconnect;

  /// No description provided for @householdNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Foyer introuvable'**
  String get householdNotFound;

  /// No description provided for @bucketCommon.
  ///
  /// In fr, this message translates to:
  /// **'Commun'**
  String get bucketCommon;

  /// No description provided for @bucketEssential.
  ///
  /// In fr, this message translates to:
  /// **'Essentiel'**
  String get bucketEssential;

  /// No description provided for @bucketPersonal.
  ///
  /// In fr, this message translates to:
  /// **'Perso'**
  String get bucketPersonal;

  /// No description provided for @bucketToSort.
  ///
  /// In fr, this message translates to:
  /// **'À trier'**
  String get bucketToSort;

  /// No description provided for @bucketMe.
  ///
  /// In fr, this message translates to:
  /// **'{name} (moi)'**
  String bucketMe(String name);

  /// No description provided for @loginError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur de connexion'**
  String get loginError;

  /// No description provided for @resetPasswordInvalidEmail.
  ///
  /// In fr, this message translates to:
  /// **'Entrez une adresse courriel valide pour réinitialiser le mot de passe.'**
  String get resetPasswordInvalidEmail;

  /// No description provided for @resetPasswordSent.
  ///
  /// In fr, this message translates to:
  /// **'Email de réinitialisation envoyé. Vérifiez votre boîte de réception.'**
  String get resetPasswordSent;

  /// No description provided for @sendError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de l\'envoi.'**
  String get sendError;

  /// No description provided for @emailLabel.
  ///
  /// In fr, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe'**
  String get passwordLabel;

  /// No description provided for @passwordRequired.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez entrer votre mot de passe.'**
  String get passwordRequired;

  /// No description provided for @signIn.
  ///
  /// In fr, this message translates to:
  /// **'Se connecter'**
  String get signIn;

  /// No description provided for @forgotPassword.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe oublié ?'**
  String get forgotPassword;

  /// No description provided for @createAccount.
  ///
  /// In fr, this message translates to:
  /// **'Créer un compte'**
  String get createAccount;

  /// No description provided for @registerTitle.
  ///
  /// In fr, this message translates to:
  /// **'Inscription'**
  String get registerTitle;

  /// No description provided for @mustAcceptTerms.
  ///
  /// In fr, this message translates to:
  /// **'Vous devez accepter les conditions d\'utilisation.'**
  String get mustAcceptTerms;

  /// No description provided for @registerError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur d\'inscription'**
  String get registerError;

  /// No description provided for @firstNameLabel.
  ///
  /// In fr, this message translates to:
  /// **'Prénom'**
  String get firstNameLabel;

  /// No description provided for @firstNameHelper.
  ///
  /// In fr, this message translates to:
  /// **'Affiché à votre partenaire dans le foyer'**
  String get firstNameHelper;

  /// No description provided for @passwordHelper.
  ///
  /// In fr, this message translates to:
  /// **'8 caractères min., avec lettres et chiffres'**
  String get passwordHelper;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer le mot de passe'**
  String get confirmPasswordLabel;

  /// No description provided for @iAcceptThe.
  ///
  /// In fr, this message translates to:
  /// **'J\'accepte les '**
  String get iAcceptThe;

  /// No description provided for @termsLinkLabel.
  ///
  /// In fr, this message translates to:
  /// **'Conditions d\'utilisation'**
  String get termsLinkLabel;

  /// No description provided for @andThe.
  ///
  /// In fr, this message translates to:
  /// **' et la '**
  String get andThe;

  /// No description provided for @privacyLinkLabel.
  ///
  /// In fr, this message translates to:
  /// **'Politique de confidentialité'**
  String get privacyLinkLabel;

  /// No description provided for @sentencePeriod.
  ///
  /// In fr, this message translates to:
  /// **'.'**
  String get sentencePeriod;

  /// No description provided for @termsDocTitle.
  ///
  /// In fr, this message translates to:
  /// **'Conditions d\'Utilisation'**
  String get termsDocTitle;

  /// No description provided for @privacyDocTitle.
  ///
  /// In fr, this message translates to:
  /// **'Politique de Confidentialité'**
  String get privacyDocTitle;

  /// No description provided for @verifyEmailTitle.
  ///
  /// In fr, this message translates to:
  /// **'Vérification du courriel'**
  String get verifyEmailTitle;

  /// No description provided for @signOut.
  ///
  /// In fr, this message translates to:
  /// **'Se déconnecter'**
  String get signOut;

  /// No description provided for @verificationSent.
  ///
  /// In fr, this message translates to:
  /// **'Courriel de vérification envoyé. Vérifiez vos courriels (et vos indésirables).'**
  String get verificationSent;

  /// No description provided for @confirmYourEmail.
  ///
  /// In fr, this message translates to:
  /// **'Confirmez votre adresse courriel'**
  String get confirmYourEmail;

  /// No description provided for @verificationBody.
  ///
  /// In fr, this message translates to:
  /// **'Un lien de vérification a été envoyé à\n{email}\n\nHorizon gère des données financières : la vérification de votre adresse est obligatoire.'**
  String verificationBody(String email);

  /// No description provided for @resendIn.
  ///
  /// In fr, this message translates to:
  /// **'Renvoyer dans {seconds} s'**
  String resendIn(String seconds);

  /// No description provided for @resendEmail.
  ///
  /// In fr, this message translates to:
  /// **'Renvoyer le courriel'**
  String get resendEmail;

  /// No description provided for @iConfirmedMyEmail.
  ///
  /// In fr, this message translates to:
  /// **'J\'ai confirmé mon adresse'**
  String get iConfirmedMyEmail;

  /// No description provided for @mfaEnrollTitle.
  ///
  /// In fr, this message translates to:
  /// **'Sécurisez votre compte'**
  String get mfaEnrollTitle;

  /// No description provided for @mfaEnrollHeading.
  ///
  /// In fr, this message translates to:
  /// **'Double authentification obligatoire'**
  String get mfaEnrollHeading;

  /// No description provided for @mfaEnrollIntro.
  ///
  /// In fr, this message translates to:
  /// **'Horizon gère des données financières : un deuxième facteur est exigé pour tous les comptes. Cette étape prend deux minutes et ne se fait qu\'une seule fois.'**
  String get mfaEnrollIntro;

  /// No description provided for @mfaStep1.
  ///
  /// In fr, this message translates to:
  /// **'1. Installez une application d\'authentification'**
  String get mfaStep1;

  /// No description provided for @mfaStep1Detail.
  ///
  /// In fr, this message translates to:
  /// **'Google Authenticator, Microsoft Authenticator, Authy, ou le gestionnaire de mots de passe de votre téléphone.'**
  String get mfaStep1Detail;

  /// No description provided for @mfaStep2.
  ///
  /// In fr, this message translates to:
  /// **'2. Scannez ce code QR'**
  String get mfaStep2;

  /// No description provided for @mfaStep2Manual.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de scanner ? Entrez cette clé manuellement dans l\'application :'**
  String get mfaStep2Manual;

  /// No description provided for @mfaCopyKey.
  ///
  /// In fr, this message translates to:
  /// **'Copier la clé'**
  String get mfaCopyKey;

  /// No description provided for @mfaKeyCopied.
  ///
  /// In fr, this message translates to:
  /// **'Clé copiée dans le presse-papiers.'**
  String get mfaKeyCopied;

  /// No description provided for @mfaStep3.
  ///
  /// In fr, this message translates to:
  /// **'3. Entrez le code affiché'**
  String get mfaStep3;

  /// No description provided for @mfaCodeLabel.
  ///
  /// In fr, this message translates to:
  /// **'Code à 6 chiffres'**
  String get mfaCodeLabel;

  /// No description provided for @mfaCodeRequired.
  ///
  /// In fr, this message translates to:
  /// **'Entrez le code à 6 chiffres.'**
  String get mfaCodeRequired;

  /// No description provided for @mfaCodeInvalidFormat.
  ///
  /// In fr, this message translates to:
  /// **'Le code doit contenir exactement 6 chiffres.'**
  String get mfaCodeInvalidFormat;

  /// No description provided for @mfaActivate.
  ///
  /// In fr, this message translates to:
  /// **'Activer la double authentification'**
  String get mfaActivate;

  /// No description provided for @mfaDeviceNameDefault.
  ///
  /// In fr, this message translates to:
  /// **'Application d\'authentification'**
  String get mfaDeviceNameDefault;

  /// No description provided for @mfaEnrollSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Double authentification activée. Votre compte est protégé.'**
  String get mfaEnrollSuccess;

  /// No description provided for @mfaEnrollError.
  ///
  /// In fr, this message translates to:
  /// **'L\'activation a échoué. Réessayez.'**
  String get mfaEnrollError;

  /// No description provided for @mfaCodeRejected.
  ///
  /// In fr, this message translates to:
  /// **'Code refusé. Vérifiez l\'heure de votre téléphone et entrez le code affiché en ce moment.'**
  String get mfaCodeRejected;

  /// No description provided for @mfaRecentLoginRequired.
  ///
  /// In fr, this message translates to:
  /// **'Par sécurité, reconnectez-vous avant d\'activer la double authentification.'**
  String get mfaRecentLoginRequired;

  /// No description provided for @mfaPreparing.
  ///
  /// In fr, this message translates to:
  /// **'Préparation de la clé de sécurité...'**
  String get mfaPreparing;

  /// No description provided for @mfaSecretError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de générer la clé de sécurité. Réessayez.'**
  String get mfaSecretError;

  /// No description provided for @mfaBackupWarning.
  ///
  /// In fr, this message translates to:
  /// **'Important : gardez l\'accès à cette application d\'authentification. Sans elle, vous ne pourrez plus vous connecter et il faudra nous écrire pour réinitialiser votre accès.'**
  String get mfaBackupWarning;

  /// No description provided for @mfaOpenInApp.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir dans mon application d\'authentification'**
  String get mfaOpenInApp;

  /// No description provided for @mfaChallengeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Vérification en deux étapes'**
  String get mfaChallengeTitle;

  /// No description provided for @mfaChallengeHeading.
  ///
  /// In fr, this message translates to:
  /// **'Entrez votre code de sécurité'**
  String get mfaChallengeHeading;

  /// No description provided for @mfaChallengeIntro.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrez votre application d\'authentification et entrez le code à 6 chiffres affiché pour {email}.'**
  String mfaChallengeIntro(String email);

  /// No description provided for @mfaVerify.
  ///
  /// In fr, this message translates to:
  /// **'Vérifier'**
  String get mfaVerify;

  /// No description provided for @mfaChallengeError.
  ///
  /// In fr, this message translates to:
  /// **'Code refusé. Réessayez avec le code affiché en ce moment.'**
  String get mfaChallengeError;

  /// No description provided for @mfaLostAccess.
  ///
  /// In fr, this message translates to:
  /// **'J\'ai perdu l\'accès à mon application'**
  String get mfaLostAccess;

  /// No description provided for @mfaLostAccessTitle.
  ///
  /// In fr, this message translates to:
  /// **'Accès perdu ?'**
  String get mfaLostAccessTitle;

  /// No description provided for @mfaLostAccessBody.
  ///
  /// In fr, this message translates to:
  /// **'Pour votre sécurité, seul un administrateur peut réinitialiser la double authentification. Écrivez à {email} depuis l\'adresse courriel de votre compte en précisant votre nom. Nous vérifierons votre identité avant toute réinitialisation.'**
  String mfaLostAccessBody(String email);

  /// No description provided for @householdSetupTitle.
  ///
  /// In fr, this message translates to:
  /// **'Configuration du Foyer'**
  String get householdSetupTitle;

  /// No description provided for @householdCreated.
  ///
  /// In fr, this message translates to:
  /// **'Foyer créé !'**
  String get householdCreated;

  /// No description provided for @inviteCodeIntro.
  ///
  /// In fr, this message translates to:
  /// **'Voici votre code pour inviter votre conjoint(e) :'**
  String get inviteCodeIntro;

  /// No description provided for @inviteCodeNote.
  ///
  /// In fr, this message translates to:
  /// **'Il restera visible sur votre tableau de bord tant que votre partenaire n\'a pas rejoint le foyer.'**
  String get inviteCodeNote;

  /// No description provided for @householdCreateError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la création du foyer.'**
  String get householdCreateError;

  /// No description provided for @invalidCodeError.
  ///
  /// In fr, this message translates to:
  /// **'Code invalide ou erreur.'**
  String get invalidCodeError;

  /// No description provided for @welcomeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Bienvenue sur Horizon'**
  String get welcomeTitle;

  /// No description provided for @welcomeBody.
  ///
  /// In fr, this message translates to:
  /// **'Comment comptez-vous utiliser Horizon ?'**
  String get welcomeBody;

  /// No description provided for @modeSoloTitle.
  ///
  /// In fr, this message translates to:
  /// **'Seul(e)'**
  String get modeSoloTitle;

  /// No description provided for @modeSoloDescription.
  ///
  /// In fr, this message translates to:
  /// **'Vos dépenses essentielles et votre argent personnel, gérés pour vous seul(e).'**
  String get modeSoloDescription;

  /// No description provided for @modeCoupleTitle.
  ///
  /// In fr, this message translates to:
  /// **'En couple'**
  String get modeCoupleTitle;

  /// No description provided for @modeCoupleDescription.
  ///
  /// In fr, this message translates to:
  /// **'Deux personnes, un budget partagé : dépenses communes, argent perso de chacun et équilibre entre vous.'**
  String get modeCoupleDescription;

  /// No description provided for @modeChangeNote.
  ///
  /// In fr, this message translates to:
  /// **'Vous pourrez inviter un partenaire plus tard.'**
  String get modeChangeNote;

  /// No description provided for @joinExistingTitle.
  ///
  /// In fr, this message translates to:
  /// **'Votre partenaire a déjà créé un foyer ?'**
  String get joinExistingTitle;

  /// No description provided for @createHouseholdButton.
  ///
  /// In fr, this message translates to:
  /// **'Créer un nouveau foyer'**
  String get createHouseholdButton;

  /// No description provided for @householdCreatedSolo.
  ///
  /// In fr, this message translates to:
  /// **'Votre foyer est prêt !'**
  String get householdCreatedSolo;

  /// No description provided for @householdCreatedSoloBody.
  ///
  /// In fr, this message translates to:
  /// **'Vous pouvez commencer à configurer votre budget et connecter votre banque.'**
  String get householdCreatedSoloBody;

  /// No description provided for @orSeparator.
  ///
  /// In fr, this message translates to:
  /// **'OU'**
  String get orSeparator;

  /// No description provided for @joinCodeFieldLabel.
  ///
  /// In fr, this message translates to:
  /// **'Code de foyer (6 caractères)'**
  String get joinCodeFieldLabel;

  /// No description provided for @joinButton.
  ///
  /// In fr, this message translates to:
  /// **'Rejoindre'**
  String get joinButton;

  /// No description provided for @syncingTransactions.
  ///
  /// In fr, this message translates to:
  /// **'Synchronisation des transactions en cours...'**
  String get syncingTransactions;

  /// No description provided for @bankConnected.
  ///
  /// In fr, this message translates to:
  /// **'Banque connectée et synchronisée !'**
  String get bankConnected;

  /// No description provided for @syncError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la synchronisation.'**
  String get syncError;

  /// No description provided for @plaidError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la connexion à Plaid.'**
  String get plaidError;

  /// No description provided for @assignedTo.
  ///
  /// In fr, this message translates to:
  /// **'Assigné à {bucket}'**
  String assignedTo(String bucket);

  /// No description provided for @undoAction.
  ///
  /// In fr, this message translates to:
  /// **'ANNULER'**
  String get undoAction;

  /// No description provided for @negativeWarningTitle.
  ///
  /// In fr, this message translates to:
  /// **'Attention au négatif'**
  String get negativeWarningTitle;

  /// No description provided for @negativeWarningBody.
  ///
  /// In fr, this message translates to:
  /// **'Assigner « {merchant} » ({amount}) mettra la cagnotte {bucket} à {after}.\n\nContinuer quand même ?'**
  String negativeWarningBody(
    String merchant,
    String amount,
    String bucket,
    String after,
  );

  /// No description provided for @assignAnyway.
  ///
  /// In fr, this message translates to:
  /// **'Assigner quand même'**
  String get assignAnyway;

  /// No description provided for @settleDebtTitle.
  ///
  /// In fr, this message translates to:
  /// **'Régler la dette interne'**
  String get settleDebtTitle;

  /// No description provided for @settleDebtBody.
  ///
  /// In fr, this message translates to:
  /// **'{debtor} doit {amount} à {creditor}.\n\nConfirmez-vous que ce montant a été remboursé (virement, argent comptant, etc.) ? La balance sera remise à zéro.'**
  String settleDebtBody(String debtor, String amount, String creditor);

  /// No description provided for @confirmSettlement.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer le règlement'**
  String get confirmSettlement;

  /// No description provided for @debtSettled.
  ///
  /// In fr, this message translates to:
  /// **'Dette de {amount} réglée !'**
  String debtSettled(String amount);

  /// No description provided for @settleError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors du règlement.'**
  String get settleError;

  /// No description provided for @bilanTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Bilan'**
  String get bilanTooltip;

  /// No description provided for @historyTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Historique'**
  String get historyTooltip;

  /// No description provided for @budgetConfigTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Configuration du budget'**
  String get budgetConfigTooltip;

  /// No description provided for @settingsTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Réglages'**
  String get settingsTooltip;

  /// No description provided for @transactionsToNeutralize.
  ///
  /// In fr, this message translates to:
  /// **'Transactions à neutraliser'**
  String get transactionsToNeutralize;

  /// No description provided for @alertNegativeBanner.
  ///
  /// In fr, this message translates to:
  /// **'Une cagnotte est dans le négatif — consultez le Bilan pour ajuster.'**
  String get alertNegativeBanner;

  /// No description provided for @alertLowBanner.
  ///
  /// In fr, this message translates to:
  /// **'Une cagnotte approche de zéro (seuil : {threshold}).'**
  String alertLowBanner(String threshold);

  /// No description provided for @inviteWithCode.
  ///
  /// In fr, this message translates to:
  /// **'Invitez votre conjoint(e) avec ce code :'**
  String get inviteWithCode;

  /// No description provided for @internalBalanceSettled.
  ///
  /// In fr, this message translates to:
  /// **'Balance interne : équilibrée'**
  String get internalBalanceSettled;

  /// No description provided for @internalDebtOwes.
  ///
  /// In fr, this message translates to:
  /// **'{debtor} doit {amount} à {creditor}'**
  String internalDebtOwes(String debtor, String amount, String creditor);

  /// No description provided for @settleButton.
  ///
  /// In fr, this message translates to:
  /// **'RÉGLER'**
  String get settleButton;

  /// No description provided for @noTransactionsToSort.
  ///
  /// In fr, this message translates to:
  /// **'Aucune transaction à trier.'**
  String get noTransactionsToSort;

  /// No description provided for @connectMyBank.
  ///
  /// In fr, this message translates to:
  /// **'Connecter ma banque'**
  String get connectMyBank;

  /// No description provided for @historyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Historique'**
  String get historyTitle;

  /// No description provided for @freePlanBanner.
  ///
  /// In fr, this message translates to:
  /// **'Plan gratuit : 30 jours d\'historique.'**
  String get freePlanBanner;

  /// No description provided for @premiumButton.
  ///
  /// In fr, this message translates to:
  /// **'PREMIUM'**
  String get premiumButton;

  /// No description provided for @filterAll.
  ///
  /// In fr, this message translates to:
  /// **'Tous'**
  String get filterAll;

  /// No description provided for @noCategorizedTransactions.
  ///
  /// In fr, this message translates to:
  /// **'Aucune transaction catégorisée.'**
  String get noCategorizedTransactions;

  /// No description provided for @transactionCount.
  ///
  /// In fr, this message translates to:
  /// **'{count} transaction(s)'**
  String transactionCount(String count);

  /// No description provided for @totalAmount.
  ///
  /// In fr, this message translates to:
  /// **'Total : {amount}'**
  String totalAmount(String amount);

  /// No description provided for @allCategories.
  ///
  /// In fr, this message translates to:
  /// **'Toutes catégories'**
  String get allCategories;

  /// No description provided for @changeCategory.
  ///
  /// In fr, this message translates to:
  /// **'Changer la catégorie'**
  String get changeCategory;

  /// No description provided for @moveTo.
  ///
  /// In fr, this message translates to:
  /// **'Déplacer vers {bucket}'**
  String moveTo(String bucket);

  /// No description provided for @sendBackToSort.
  ///
  /// In fr, this message translates to:
  /// **'Renvoyer dans « À trier »'**
  String get sendBackToSort;

  /// No description provided for @sentBackToSort.
  ///
  /// In fr, this message translates to:
  /// **'Transaction renvoyée dans « À trier ».'**
  String get sentBackToSort;

  /// No description provided for @movedTo.
  ///
  /// In fr, this message translates to:
  /// **'Déplacée vers {bucket}.'**
  String movedTo(String bucket);

  /// No description provided for @bilanTitle.
  ///
  /// In fr, this message translates to:
  /// **'Bilan'**
  String get bilanTitle;

  /// No description provided for @refreshTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Rafraîchir'**
  String get refreshTooltip;

  /// No description provided for @reportError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la génération du bilan.'**
  String get reportError;

  /// No description provided for @coachUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Le coach IA est indisponible.'**
  String get coachUnavailable;

  /// No description provided for @addedToFixedExpenses.
  ///
  /// In fr, this message translates to:
  /// **'« {name} » ajouté aux dépenses fixes ({amount}/mois).'**
  String addedToFixedExpenses(String name, String amount);

  /// No description provided for @addError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de l\'ajout.'**
  String get addError;

  /// No description provided for @noLongerSuggested.
  ///
  /// In fr, this message translates to:
  /// **'« {name} » ne sera plus suggéré.'**
  String noLongerSuggested(String name);

  /// No description provided for @thisMonth.
  ///
  /// In fr, this message translates to:
  /// **'Ce mois-ci'**
  String get thisMonth;

  /// No description provided for @thisWeek.
  ///
  /// In fr, this message translates to:
  /// **'Cette semaine'**
  String get thisWeek;

  /// No description provided for @reportUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Bilan indisponible.'**
  String get reportUnavailable;

  /// No description provided for @spendingByCategory.
  ///
  /// In fr, this message translates to:
  /// **'Dépenses par catégorie'**
  String get spendingByCategory;

  /// No description provided for @topMerchants.
  ///
  /// In fr, this message translates to:
  /// **'Principaux commerçants'**
  String get topMerchants;

  /// No description provided for @recurringDetected.
  ///
  /// In fr, this message translates to:
  /// **'Dépenses récurrentes détectées'**
  String get recurringDetected;

  /// No description provided for @aiCoachSection.
  ///
  /// In fr, this message translates to:
  /// **'Coach budgétaire IA'**
  String get aiCoachSection;

  /// No description provided for @monthSpending.
  ///
  /// In fr, this message translates to:
  /// **'Dépenses du mois'**
  String get monthSpending;

  /// No description provided for @weekSpending.
  ///
  /// In fr, this message translates to:
  /// **'Dépenses de la semaine'**
  String get weekSpending;

  /// No description provided for @vsPreviousPeriod.
  ///
  /// In fr, this message translates to:
  /// **'{delta} % vs période précédente ({amount})'**
  String vsPreviousPeriod(String delta, String amount);

  /// No description provided for @noPreviousPeriod.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore de période précédente à comparer.'**
  String get noPreviousPeriod;

  /// No description provided for @recurringInfo.
  ///
  /// In fr, this message translates to:
  /// **'Dépense {frequency} détectée ({occurrences} fois) — ≈ {monthly}/mois'**
  String recurringInfo(String frequency, String occurrences, String monthly);

  /// No description provided for @freqLabelWeekly.
  ///
  /// In fr, this message translates to:
  /// **'hebdomadaire'**
  String get freqLabelWeekly;

  /// No description provided for @freqLabelBiweekly.
  ///
  /// In fr, this message translates to:
  /// **'aux 2 semaines'**
  String get freqLabelBiweekly;

  /// No description provided for @freqLabelMonthly.
  ///
  /// In fr, this message translates to:
  /// **'mensuelle'**
  String get freqLabelMonthly;

  /// No description provided for @ignore.
  ///
  /// In fr, this message translates to:
  /// **'Ignorer'**
  String get ignore;

  /// No description provided for @addToBudget.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter au budget'**
  String get addToBudget;

  /// No description provided for @monthEnvelopes.
  ///
  /// In fr, this message translates to:
  /// **'Enveloppes du mois'**
  String get monthEnvelopes;

  /// No description provided for @overBudgetBy.
  ///
  /// In fr, this message translates to:
  /// **'Dépassement de {amount}'**
  String overBudgetBy(String amount);

  /// No description provided for @spentOfBudget.
  ///
  /// In fr, this message translates to:
  /// **'{spent} / {budget}'**
  String spentOfBudget(String spent, String budget);

  /// No description provided for @aiDisclaimer.
  ///
  /// In fr, this message translates to:
  /// **'Ces suggestions sont générées par une IA à partir de vos agrégats de dépenses et ne constituent pas un conseil financier professionnel.'**
  String get aiDisclaimer;

  /// No description provided for @aiPitch.
  ///
  /// In fr, this message translates to:
  /// **'Obtenez des observations et suggestions personnalisées, rédigées à partir des chiffres de ce bilan.'**
  String get aiPitch;

  /// No description provided for @generateAdvice.
  ///
  /// In fr, this message translates to:
  /// **'Générer mes conseils IA'**
  String get generateAdvice;

  /// No description provided for @regenerateAdvice.
  ///
  /// In fr, this message translates to:
  /// **'Régénérer les conseils'**
  String get regenerateAdvice;

  /// No description provided for @budgetSetupTitle.
  ///
  /// In fr, this message translates to:
  /// **'Configuration Budget ZBB'**
  String get budgetSetupTitle;

  /// No description provided for @freqMonthly.
  ///
  /// In fr, this message translates to:
  /// **'Mensuel'**
  String get freqMonthly;

  /// No description provided for @freqBiweekly.
  ///
  /// In fr, this message translates to:
  /// **'Bi-hebdomadaire'**
  String get freqBiweekly;

  /// No description provided for @freqWeekly.
  ///
  /// In fr, this message translates to:
  /// **'Hebdomadaire'**
  String get freqWeekly;

  /// No description provided for @newExpenseDefault.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle dépense'**
  String get newExpenseDefault;

  /// No description provided for @newAllocationDefault.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle allocation'**
  String get newAllocationDefault;

  /// No description provided for @budgetSaved.
  ///
  /// In fr, this message translates to:
  /// **'Budget mensuel sauvegardé !'**
  String get budgetSaved;

  /// No description provided for @budgetSaveError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la sauvegarde.'**
  String get budgetSaveError;

  /// No description provided for @envelopesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Enveloppes par catégorie'**
  String get envelopesTitle;

  /// No description provided for @envelopesSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Budgets mensuels pour vos dépenses variables — le Bilan suit leur progression.'**
  String get envelopesSubtitle;

  /// No description provided for @categoryFieldLabel.
  ///
  /// In fr, this message translates to:
  /// **'Catégorie'**
  String get categoryFieldLabel;

  /// No description provided for @budgetFieldLabel.
  ///
  /// In fr, this message translates to:
  /// **'Budget'**
  String get budgetFieldLabel;

  /// No description provided for @magicMonthsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Calendrier des Mois Magiques 🌟'**
  String get magicMonthsTitle;

  /// No description provided for @magicMonthsSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Un mois magique contient une paie supplémentaire.'**
  String get magicMonthsSubtitle;

  /// No description provided for @nameFieldLabel.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get nameFieldLabel;

  /// No description provided for @amountFieldLabel.
  ///
  /// In fr, this message translates to:
  /// **'Montant'**
  String get amountFieldLabel;

  /// No description provided for @incomeSection.
  ///
  /// In fr, this message translates to:
  /// **'Revenus'**
  String get incomeSection;

  /// No description provided for @incomeALabel.
  ///
  /// In fr, this message translates to:
  /// **'Revenu A'**
  String get incomeALabel;

  /// No description provided for @incomeBLabel.
  ///
  /// In fr, this message translates to:
  /// **'Revenu B'**
  String get incomeBLabel;

  /// No description provided for @incomeSoloLabel.
  ///
  /// In fr, this message translates to:
  /// **'Mon revenu'**
  String get incomeSoloLabel;

  /// No description provided for @netEssentialExpenses.
  ///
  /// In fr, this message translates to:
  /// **'Dépenses essentielles nettes :'**
  String get netEssentialExpenses;

  /// No description provided for @payFrequencyLabel.
  ///
  /// In fr, this message translates to:
  /// **'Fréquence de paie'**
  String get payFrequencyLabel;

  /// No description provided for @nextPayDateLabel.
  ///
  /// In fr, this message translates to:
  /// **'Prochaine date de paie'**
  String get nextPayDateLabel;

  /// No description provided for @selectADate.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionner une date'**
  String get selectADate;

  /// No description provided for @allocationsSection.
  ///
  /// In fr, this message translates to:
  /// **'Allocations & Déductions'**
  String get allocationsSection;

  /// No description provided for @fixedExpensesSection.
  ///
  /// In fr, this message translates to:
  /// **'Dépenses Fixes Communes'**
  String get fixedExpensesSection;

  /// No description provided for @alertThresholdTitle.
  ///
  /// In fr, this message translates to:
  /// **'Seuil d\'alerte des cagnottes'**
  String get alertThresholdTitle;

  /// No description provided for @alertThresholdSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'En dessous de ce montant, une cagnotte passe en orange sur le tableau de bord.'**
  String get alertThresholdSubtitle;

  /// No description provided for @thresholdFieldLabel.
  ///
  /// In fr, this message translates to:
  /// **'Seuil (\$)'**
  String get thresholdFieldLabel;

  /// No description provided for @proRataTitle.
  ///
  /// In fr, this message translates to:
  /// **'Répartition pro-rata'**
  String get proRataTitle;

  /// No description provided for @userAShare.
  ///
  /// In fr, this message translates to:
  /// **'User A : {pct}%'**
  String userAShare(String pct);

  /// No description provided for @userBShare.
  ///
  /// In fr, this message translates to:
  /// **'User B : {pct}%'**
  String userBShare(String pct);

  /// No description provided for @netCommonExpenses.
  ///
  /// In fr, this message translates to:
  /// **'Dépenses nettes communes :'**
  String get netCommonExpenses;

  /// No description provided for @aPays.
  ///
  /// In fr, this message translates to:
  /// **'A paie : {amount}'**
  String aPays(String amount);

  /// No description provided for @bPays.
  ///
  /// In fr, this message translates to:
  /// **'B paie : {amount}'**
  String bPays(String amount);

  /// No description provided for @saveBudgetButton.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarder le Budget'**
  String get saveBudgetButton;

  /// No description provided for @settingsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Réglages'**
  String get settingsTitle;

  /// No description provided for @editMyName.
  ///
  /// In fr, this message translates to:
  /// **'Modifier mon prénom'**
  String get editMyName;

  /// No description provided for @nameUpdated.
  ///
  /// In fr, this message translates to:
  /// **'Prénom mis à jour.'**
  String get nameUpdated;

  /// No description provided for @updateError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la mise à jour.'**
  String get updateError;

  /// No description provided for @myDataJson.
  ///
  /// In fr, this message translates to:
  /// **'Mes données (JSON)'**
  String get myDataJson;

  /// No description provided for @copiedToClipboard.
  ///
  /// In fr, this message translates to:
  /// **'Données copiées dans le presse-papiers.'**
  String get copiedToClipboard;

  /// No description provided for @exportError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de l\'export.'**
  String get exportError;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer mon compte'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountBody.
  ///
  /// In fr, this message translates to:
  /// **'Cette action est IRRÉVERSIBLE :\n\n• Vos connexions bancaires seront révoquées\n• Vos transactions seront supprimées\n• Votre compte sera définitivement effacé\n\nTapez {keyword} pour confirmer :'**
  String deleteAccountBody(String keyword);

  /// No description provided for @deleteKeyword.
  ///
  /// In fr, this message translates to:
  /// **'SUPPRIMER'**
  String get deleteKeyword;

  /// No description provided for @deleteForever.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer définitivement'**
  String get deleteForever;

  /// No description provided for @deleteError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la suppression.'**
  String get deleteError;

  /// No description provided for @profileSection.
  ///
  /// In fr, this message translates to:
  /// **'Profil'**
  String get profileSection;

  /// No description provided for @emailVerified.
  ///
  /// In fr, this message translates to:
  /// **'Courriel vérifié'**
  String get emailVerified;

  /// No description provided for @emailNotVerified.
  ///
  /// In fr, this message translates to:
  /// **'Courriel non vérifié'**
  String get emailNotVerified;

  /// No description provided for @subscriptionSection.
  ///
  /// In fr, this message translates to:
  /// **'Abonnement'**
  String get subscriptionSection;

  /// No description provided for @premiumPlanTitle.
  ///
  /// In fr, this message translates to:
  /// **'Horizon Premium'**
  String get premiumPlanTitle;

  /// No description provided for @freePlanTitle.
  ///
  /// In fr, this message translates to:
  /// **'Plan gratuit'**
  String get freePlanTitle;

  /// No description provided for @manageSubscription.
  ///
  /// In fr, this message translates to:
  /// **'Gérez votre abonnement depuis l\'App Store / Play Store.'**
  String get manageSubscription;

  /// No description provided for @freePlanLimits.
  ///
  /// In fr, this message translates to:
  /// **'1 compte bancaire, 30 jours d\'historique'**
  String get freePlanLimits;

  /// No description provided for @myDataSection.
  ///
  /// In fr, this message translates to:
  /// **'Mes données (Loi 25)'**
  String get myDataSection;

  /// No description provided for @exportMyData.
  ///
  /// In fr, this message translates to:
  /// **'Exporter mes données'**
  String get exportMyData;

  /// No description provided for @exportSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Copie JSON de toutes vos données'**
  String get exportSubtitle;

  /// No description provided for @accountSection.
  ///
  /// In fr, this message translates to:
  /// **'Compte'**
  String get accountSection;

  /// No description provided for @deleteAccountSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Suppression définitive de toutes vos données'**
  String get deleteAccountSubtitle;

  /// No description provided for @languageSection.
  ///
  /// In fr, this message translates to:
  /// **'Langue / Language'**
  String get languageSection;

  /// No description provided for @languageTile.
  ///
  /// In fr, this message translates to:
  /// **'Langue de l\'application'**
  String get languageTile;

  /// No description provided for @languageFrench.
  ///
  /// In fr, this message translates to:
  /// **'Français'**
  String get languageFrench;

  /// No description provided for @languageEnglish.
  ///
  /// In fr, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageSystem.
  ///
  /// In fr, this message translates to:
  /// **'Automatique (langue de l\'appareil)'**
  String get languageSystem;

  /// No description provided for @paywallTitle.
  ///
  /// In fr, this message translates to:
  /// **'Horizon Premium'**
  String get paywallTitle;

  /// No description provided for @featUnlimitedBanks.
  ///
  /// In fr, this message translates to:
  /// **'Comptes bancaires illimités'**
  String get featUnlimitedBanks;

  /// No description provided for @featFullHistory.
  ///
  /// In fr, this message translates to:
  /// **'Historique complet et illimité'**
  String get featFullHistory;

  /// No description provided for @featRealtimeSync.
  ///
  /// In fr, this message translates to:
  /// **'Synchronisation en temps réel'**
  String get featRealtimeSync;

  /// No description provided for @featPrioritySupport.
  ///
  /// In fr, this message translates to:
  /// **'Soutien prioritaire'**
  String get featPrioritySupport;

  /// No description provided for @purchaseWelcome.
  ///
  /// In fr, this message translates to:
  /// **'Bienvenue dans Horizon Premium ! Activation en cours (quelques secondes)...'**
  String get purchaseWelcome;

  /// No description provided for @purchaseFailed.
  ///
  /// In fr, this message translates to:
  /// **'L\'achat a échoué. Réessayez.'**
  String get purchaseFailed;

  /// No description provided for @purchasesRestored.
  ///
  /// In fr, this message translates to:
  /// **'Achats restaurés avec succès !'**
  String get purchasesRestored;

  /// No description provided for @nothingToRestore.
  ///
  /// In fr, this message translates to:
  /// **'Aucun achat à restaurer.'**
  String get nothingToRestore;

  /// No description provided for @goPremium.
  ///
  /// In fr, this message translates to:
  /// **'Passez à Horizon Premium'**
  String get goPremium;

  /// No description provided for @webNoPurchase.
  ///
  /// In fr, this message translates to:
  /// **'L\'abonnement s\'effectue depuis l\'application mobile Horizon (Android ou iPhone). Une fois abonné, votre statut Premium s\'applique automatiquement à tout votre foyer, y compris sur le Web.'**
  String get webNoPurchase;

  /// No description provided for @storeUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'La boutique n\'est pas encore disponible. Réessayez plus tard.'**
  String get storeUnavailable;

  /// No description provided for @restorePurchases.
  ///
  /// In fr, this message translates to:
  /// **'Restaurer mes achats'**
  String get restorePurchases;

  /// No description provided for @vEmailRequired.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez entrer votre adresse courriel.'**
  String get vEmailRequired;

  /// No description provided for @vEmailInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Adresse courriel invalide.'**
  String get vEmailInvalid;

  /// No description provided for @vPasswordRequired.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez entrer un mot de passe.'**
  String get vPasswordRequired;

  /// No description provided for @vPasswordTooShort.
  ///
  /// In fr, this message translates to:
  /// **'Le mot de passe doit contenir au moins 8 caractères.'**
  String get vPasswordTooShort;

  /// No description provided for @vPasswordNeedsLetterDigit.
  ///
  /// In fr, this message translates to:
  /// **'Le mot de passe doit contenir au moins une lettre et un chiffre.'**
  String get vPasswordNeedsLetterDigit;

  /// No description provided for @vPasswordMismatch.
  ///
  /// In fr, this message translates to:
  /// **'Les mots de passe ne correspondent pas.'**
  String get vPasswordMismatch;

  /// No description provided for @vNameTooShort.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez entrer votre prénom (2 lettres min.).'**
  String get vNameTooShort;

  /// No description provided for @vNameTooLong.
  ///
  /// In fr, this message translates to:
  /// **'Prénom trop long (40 caractères max.).'**
  String get vNameTooLong;

  /// No description provided for @vJoinCodeInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Le code doit contenir 6 lettres ou chiffres.'**
  String get vJoinCodeInvalid;

  /// No description provided for @chartOtherCategories.
  ///
  /// In fr, this message translates to:
  /// **'Autres catégories'**
  String get chartOtherCategories;

  /// No description provided for @bucketTransfer.
  ///
  /// In fr, this message translates to:
  /// **'Transfert interne'**
  String get bucketTransfer;

  /// No description provided for @bucketArchived.
  ///
  /// In fr, this message translates to:
  /// **'Écartée du tri'**
  String get bucketArchived;

  /// No description provided for @sortFilterAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout'**
  String get sortFilterAll;

  /// No description provided for @sortFilterThisMonth.
  ///
  /// In fr, this message translates to:
  /// **'Ce mois-ci'**
  String get sortFilterThisMonth;

  /// No description provided for @archivePastTitle.
  ///
  /// In fr, this message translates to:
  /// **'Écarter les mois passés'**
  String get archivePastTitle;

  /// No description provided for @archivePastBody.
  ///
  /// In fr, this message translates to:
  /// **'Les transactions non triées antérieures à ce mois-ci seront retirées de la file.\n\nElles resteront visibles dans l\'Historique et comptées dans vos bilans — seules vos cagnottes, qui sont calculées pour le mois courant, ne seront pas touchées.'**
  String get archivePastBody;

  /// No description provided for @archivePastAction.
  ///
  /// In fr, this message translates to:
  /// **'Écarter'**
  String get archivePastAction;

  /// No description provided for @archivePastDone.
  ///
  /// In fr, this message translates to:
  /// **'{count} transaction(s) écartée(s) de la file.'**
  String archivePastDone(int count);

  /// No description provided for @archivePastNothing.
  ///
  /// In fr, this message translates to:
  /// **'Aucune transaction d\'un mois passé à écarter.'**
  String get archivePastNothing;

  /// No description provided for @toSortCount.
  ///
  /// In fr, this message translates to:
  /// **'{count} à trier'**
  String toSortCount(int count);

  /// No description provided for @bankSection.
  ///
  /// In fr, this message translates to:
  /// **'Comptes bancaires'**
  String get bankSection;

  /// No description provided for @bankManageTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mes comptes bancaires'**
  String get bankManageTitle;

  /// No description provided for @bankManageSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Connexions et synchronisation'**
  String get bankManageSubtitle;

  /// No description provided for @bankNone.
  ///
  /// In fr, this message translates to:
  /// **'Aucune banque connectée pour l\'instant.'**
  String get bankNone;

  /// No description provided for @bankUnknownInstitution.
  ///
  /// In fr, this message translates to:
  /// **'Compte bancaire'**
  String get bankUnknownInstitution;

  /// No description provided for @bankPartnerAccount.
  ///
  /// In fr, this message translates to:
  /// **'Relié par votre partenaire'**
  String get bankPartnerAccount;

  /// No description provided for @bankNeverSynced.
  ///
  /// In fr, this message translates to:
  /// **'Jamais synchronisé'**
  String get bankNeverSynced;

  /// No description provided for @bankLastSync.
  ///
  /// In fr, this message translates to:
  /// **'Dernière synchronisation : {date}'**
  String bankLastSync(String date);

  /// No description provided for @notifSection.
  ///
  /// In fr, this message translates to:
  /// **'Notifications'**
  String get notifSection;

  /// No description provided for @notifManageTitle.
  ///
  /// In fr, this message translates to:
  /// **'Gérer mes notifications'**
  String get notifManageTitle;

  /// No description provided for @notifManageSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Rappels de carte, alertes de cagnotte...'**
  String get notifManageSubtitle;

  /// No description provided for @notifEnableTitle.
  ///
  /// In fr, this message translates to:
  /// **'Activer les notifications'**
  String get notifEnableTitle;

  /// No description provided for @notifEnableBody.
  ///
  /// In fr, this message translates to:
  /// **'Recevez des rappels et des alertes sur cet appareil.'**
  String get notifEnableBody;

  /// No description provided for @notifEnableButton.
  ///
  /// In fr, this message translates to:
  /// **'Activer sur cet appareil'**
  String get notifEnableButton;

  /// No description provided for @notifDisableButton.
  ///
  /// In fr, this message translates to:
  /// **'Désactiver sur cet appareil'**
  String get notifDisableButton;

  /// No description provided for @notifEnabled.
  ///
  /// In fr, this message translates to:
  /// **'Notifications activées.'**
  String get notifEnabled;

  /// No description provided for @notifRefused.
  ///
  /// In fr, this message translates to:
  /// **'Permission refusée. Sur iPhone, ajoutez d\'abord Horizon à votre écran d\'accueil.'**
  String get notifRefused;

  /// No description provided for @notifIosHint.
  ///
  /// In fr, this message translates to:
  /// **'Sur iPhone, les notifications ne fonctionnent qu\'après avoir ajouté Horizon à l\'écran d\'accueil (Partager → Sur l\'écran d\'accueil).'**
  String get notifIosHint;

  /// No description provided for @notifTypesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Types de notifications'**
  String get notifTypesTitle;

  /// No description provided for @notifCardReminder.
  ///
  /// In fr, this message translates to:
  /// **'Rappel de paiement de carte'**
  String get notifCardReminder;

  /// No description provided for @notifCardReminderSub.
  ///
  /// In fr, this message translates to:
  /// **'Avant l\'échéance de vos cartes de crédit'**
  String get notifCardReminderSub;

  /// No description provided for @notifPotAlert.
  ///
  /// In fr, this message translates to:
  /// **'Alerte de cagnotte'**
  String get notifPotAlert;

  /// No description provided for @notifPotAlertSub.
  ///
  /// In fr, this message translates to:
  /// **'Quand une cagnotte passe sous le seuil ou dans le négatif'**
  String get notifPotAlertSub;

  /// No description provided for @notifToSort.
  ///
  /// In fr, this message translates to:
  /// **'Transactions à trier'**
  String get notifToSort;

  /// No description provided for @notifToSortSub.
  ///
  /// In fr, this message translates to:
  /// **'Rappel hebdomadaire si des transactions attendent'**
  String get notifToSortSub;

  /// No description provided for @notifPartner.
  ///
  /// In fr, this message translates to:
  /// **'Activité du partenaire'**
  String get notifPartner;

  /// No description provided for @notifPartnerSub.
  ///
  /// In fr, this message translates to:
  /// **'Règlements de dette et changements du foyer'**
  String get notifPartnerSub;

  /// No description provided for @notifOverspend.
  ///
  /// In fr, this message translates to:
  /// **'Dépassement des liquidités'**
  String get notifOverspend;

  /// No description provided for @notifOverspendSub.
  ///
  /// In fr, this message translates to:
  /// **'Quand le solde d\'une carte dépasse l\'argent disponible pour la payer'**
  String get notifOverspendSub;

  /// No description provided for @notifLeadDays.
  ///
  /// In fr, this message translates to:
  /// **'Rappel de carte : {days} jour(s) avant l\'échéance'**
  String notifLeadDays(int days);

  /// No description provided for @notifSaved.
  ///
  /// In fr, this message translates to:
  /// **'Préférences enregistrées.'**
  String get notifSaved;

  /// No description provided for @notifCardsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mes cartes de crédit'**
  String get notifCardsTitle;

  /// No description provided for @notifCardDueDay.
  ///
  /// In fr, this message translates to:
  /// **'Jour d\'échéance (1–28)'**
  String get notifCardDueDay;

  /// No description provided for @notifCardDueAuto.
  ///
  /// In fr, this message translates to:
  /// **'Échéance fournie automatiquement'**
  String get notifCardDueAuto;

  /// No description provided for @notifCardNone.
  ///
  /// In fr, this message translates to:
  /// **'Aucune carte de crédit détectée. Reliez-en une, ou reconnectez-la pour activer le suivi des échéances.'**
  String get notifCardNone;

  /// No description provided for @notifCardManualHint.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez le jour d\'échéance si votre banque ne le fournit pas automatiquement.'**
  String get notifCardManualHint;

  /// No description provided for @searchHint.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un commerçant, une catégorie...'**
  String get searchHint;

  /// No description provided for @sortTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Trier'**
  String get sortTooltip;

  /// No description provided for @sortDateDesc.
  ///
  /// In fr, this message translates to:
  /// **'Date — du plus récent'**
  String get sortDateDesc;

  /// No description provided for @sortDateAsc.
  ///
  /// In fr, this message translates to:
  /// **'Date — du plus ancien'**
  String get sortDateAsc;

  /// No description provided for @sortAmountDesc.
  ///
  /// In fr, this message translates to:
  /// **'Montant — du plus élevé'**
  String get sortAmountDesc;

  /// No description provided for @sortAmountAsc.
  ///
  /// In fr, this message translates to:
  /// **'Montant — du plus faible'**
  String get sortAmountAsc;

  /// No description provided for @noSearchResults.
  ///
  /// In fr, this message translates to:
  /// **'Aucune transaction ne correspond à votre recherche.'**
  String get noSearchResults;

  /// No description provided for @tutorialSkip.
  ///
  /// In fr, this message translates to:
  /// **'Passer'**
  String get tutorialSkip;

  /// No description provided for @tutorialNext.
  ///
  /// In fr, this message translates to:
  /// **'Suivant'**
  String get tutorialNext;

  /// No description provided for @tutorialDone.
  ///
  /// In fr, this message translates to:
  /// **'Commencer'**
  String get tutorialDone;

  /// No description provided for @tutorialReplay.
  ///
  /// In fr, this message translates to:
  /// **'Revoir le guide de démarrage'**
  String get tutorialReplay;

  /// No description provided for @tutorial1Title.
  ///
  /// In fr, this message translates to:
  /// **'Chaque dollar a une mission'**
  String get tutorial1Title;

  /// No description provided for @tutorial1Body.
  ///
  /// In fr, this message translates to:
  /// **'Horizon répartit vos revenus en cagnottes avant que vous ne dépensiez. Vous savez ainsi, à tout moment, ce qu\'il vous reste réellement — pas seulement le solde de votre compte.'**
  String get tutorial1Body;

  /// No description provided for @tutorial2Title.
  ///
  /// In fr, this message translates to:
  /// **'Deux natures de cagnottes'**
  String get tutorial2Title;

  /// No description provided for @tutorial2Body.
  ///
  /// In fr, this message translates to:
  /// **'La cagnotte commune contient exactement de quoi payer vos charges du mois : loyer, électricité, assurances. Elle doit descendre vers zéro à mesure que les factures se paient.\n\nVos cagnottes personnelles, elles, sont votre argent libre : ce qu\'il vous reste une fois votre part des charges mise de côté.'**
  String get tutorial2Body;

  /// No description provided for @tutorial3Title.
  ///
  /// In fr, this message translates to:
  /// **'Triez d\'un glissement'**
  String get tutorial3Title;

  /// No description provided for @tutorial3Body.
  ///
  /// In fr, this message translates to:
  /// **'Chaque transaction importée attend d\'être classée. Glissez vers la gauche pour votre cagnotte personnelle, vers la droite pour la cagnotte commune.\n\nLa cagnotte se met à jour aussitôt, et vous pouvez annuler.'**
  String get tutorial3Body;

  /// No description provided for @tutorial4Title.
  ///
  /// In fr, this message translates to:
  /// **'Transferts et mouvements internes'**
  String get tutorial4Title;

  /// No description provided for @tutorial4Body.
  ///
  /// In fr, this message translates to:
  /// **'Toute sortie d\'argent n\'est pas une dépense. Un paiement de carte de crédit, un virement vers votre épargne, un remboursement de prêt avec de l\'argent déjà mis de côté : ce sont des mouvements entre vos propres comptes.\n\nHorizon les écarte d\'office quand il les reconnaît. Sinon, le menu « ⋮ » sur chaque transaction vous laisse la classer en « Transfert interne » — elle n\'entamera aucune cagnotte.'**
  String get tutorial4Body;

  /// No description provided for @tutorial5Title.
  ///
  /// In fr, this message translates to:
  /// **'Gardez la file légère'**
  String get tutorial5Title;

  /// No description provided for @tutorial5Body.
  ///
  /// In fr, this message translates to:
  /// **'Relier une banque importe des mois d\'historique. Pour ne pas trier le passé, le bouton « Écarter les mois passés » retire de la file tout ce qui précède le mois courant.\n\nCes transactions restent dans votre Historique et vos bilans : seules vos cagnottes, calculées pour le mois en cours, sont préservées.'**
  String get tutorial5Body;

  /// No description provided for @tutorial6Title.
  ///
  /// In fr, this message translates to:
  /// **'Vos comptes bancaires'**
  String get tutorial6Title;

  /// No description provided for @tutorial6Body.
  ///
  /// In fr, this message translates to:
  /// **'Reliez autant de comptes que nécessaire — chèque, épargne, carte de crédit.\n\nUn réglage compte particulièrement : indiquez quels comptes sont conjoints, pour qu\'aucune dette ne s\'invente entre vous quand une charge commune sort d\'un compte que vous alimentez tous les deux.'**
  String get tutorial6Body;

  /// No description provided for @bankJointLabel.
  ///
  /// In fr, this message translates to:
  /// **'Compte conjoint'**
  String get bankJointLabel;

  /// No description provided for @bankJointHint.
  ///
  /// In fr, this message translates to:
  /// **'Les dépenses communes payées depuis ce compte ne créeront aucune dette entre vous : l\'argent sort d\'un compte que vous alimentez tous les deux.'**
  String get bankJointHint;

  /// No description provided for @bankPersonalHint.
  ///
  /// In fr, this message translates to:
  /// **'Les dépenses communes payées depuis ce compte seront notées comme une avance faite à votre partenaire.'**
  String get bankPersonalHint;

  /// No description provided for @bankJointUpdated.
  ///
  /// In fr, this message translates to:
  /// **'Type de compte mis à jour.'**
  String get bankJointUpdated;

  /// No description provided for @bankJointDebtNote.
  ///
  /// In fr, this message translates to:
  /// **'La dette déjà calculée n\'est pas recalculée. Utilisez « Régler » sur l\'accueil pour repartir de zéro.'**
  String get bankJointDebtNote;

  /// No description provided for @bankDisconnect.
  ///
  /// In fr, this message translates to:
  /// **'Déconnecter'**
  String get bankDisconnect;

  /// No description provided for @bankDisconnectTitle.
  ///
  /// In fr, this message translates to:
  /// **'Déconnecter cette banque ?'**
  String get bankDisconnectTitle;

  /// No description provided for @bankDisconnectBody.
  ///
  /// In fr, this message translates to:
  /// **'L\'accès d\'Horizon à ce compte sera révoqué auprès de Plaid, et les transactions importées de cette banque seront retirées d\'Horizon.\n\nLeur effet sur les cagnottes est annulé automatiquement. Reconnecter la banque réimportera son historique.'**
  String get bankDisconnectBody;

  /// No description provided for @bankDisconnected.
  ///
  /// In fr, this message translates to:
  /// **'Banque déconnectée.'**
  String get bankDisconnected;

  /// No description provided for @bankSyncNow.
  ///
  /// In fr, this message translates to:
  /// **'Synchroniser maintenant'**
  String get bankSyncNow;

  /// No description provided for @bankSyncing.
  ///
  /// In fr, this message translates to:
  /// **'Synchronisation en cours...'**
  String get bankSyncing;

  /// No description provided for @bankSyncDone.
  ///
  /// In fr, this message translates to:
  /// **'{count} nouvelle(s) transaction(s) importée(s).'**
  String bankSyncDone(int count);

  /// No description provided for @bankSyncNothing.
  ///
  /// In fr, this message translates to:
  /// **'Aucune nouvelle transaction. Après une première connexion, Plaid peut mettre plusieurs minutes à livrer l\'historique — les transactions apparaîtront toutes seules.'**
  String get bankSyncNothing;

  /// No description provided for @bankAddAnother.
  ///
  /// In fr, this message translates to:
  /// **'Connecter une autre banque'**
  String get bankAddAnother;

  /// No description provided for @bankFreePlanLimit.
  ///
  /// In fr, this message translates to:
  /// **'Le plan gratuit permet une seule banque par foyer.'**
  String get bankFreePlanLimit;

  /// No description provided for @allSortedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Tout est trié !'**
  String get allSortedTitle;

  /// No description provided for @allSortedBody.
  ///
  /// In fr, this message translates to:
  /// **'Aucune transaction en attente. Les prochaines apparaîtront ici automatiquement.'**
  String get allSortedBody;

  /// No description provided for @noBankTitle.
  ///
  /// In fr, this message translates to:
  /// **'Reliez votre banque pour commencer'**
  String get noBankTitle;

  /// No description provided for @noBankBody.
  ///
  /// In fr, this message translates to:
  /// **'Vos transactions seront importées automatiquement, puis vous les classerez d\'un glissement.'**
  String get noBankBody;

  /// No description provided for @plaidExitTitle.
  ///
  /// In fr, this message translates to:
  /// **'Connexion bancaire interrompue'**
  String get plaidExitTitle;

  /// No description provided for @plaidExitCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Connexion annulée à l\'étape : {status}'**
  String plaidExitCancelled(String status);

  /// No description provided for @plaidExitHint.
  ///
  /// In fr, this message translates to:
  /// **'Transmettez ces informations au soutien si le problème persiste.'**
  String get plaidExitHint;

  /// No description provided for @themeSection.
  ///
  /// In fr, this message translates to:
  /// **'Apparence'**
  String get themeSection;

  /// No description provided for @themeLight.
  ///
  /// In fr, this message translates to:
  /// **'Clair'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In fr, this message translates to:
  /// **'Sombre'**
  String get themeDark;

  /// No description provided for @themeSystem.
  ///
  /// In fr, this message translates to:
  /// **'Automatique (réglage du système)'**
  String get themeSystem;

  /// No description provided for @householdSection.
  ///
  /// In fr, this message translates to:
  /// **'Foyer'**
  String get householdSection;

  /// No description provided for @householdManageTitle.
  ///
  /// In fr, this message translates to:
  /// **'Gérer mon foyer'**
  String get householdManageTitle;

  /// No description provided for @householdManageSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Mode, invitation, séparation'**
  String get householdManageSubtitle;

  /// No description provided for @householdStatusSolo.
  ///
  /// In fr, this message translates to:
  /// **'Vous utilisez Horizon seul(e).'**
  String get householdStatusSolo;

  /// No description provided for @householdStatusWaiting.
  ///
  /// In fr, this message translates to:
  /// **'En attente d\'un second membre.'**
  String get householdStatusWaiting;

  /// No description provided for @householdStatusCouple.
  ///
  /// In fr, this message translates to:
  /// **'Foyer partagé avec {name}.'**
  String householdStatusCouple(String name);

  /// No description provided for @invitePartnerTitle.
  ///
  /// In fr, this message translates to:
  /// **'Inviter un partenaire'**
  String get invitePartnerTitle;

  /// No description provided for @invitePartnerBody.
  ///
  /// In fr, this message translates to:
  /// **'Votre foyer passera en mode couple : une cagnotte personnelle pour chacun, une cagnotte commune, et le suivi des avances entre vous. Les dépenses communes seront partagées 50/50 par défaut — vous pourrez ajuster la répartition dans la configuration du budget.'**
  String get invitePartnerBody;

  /// No description provided for @invitePartnerAction.
  ///
  /// In fr, this message translates to:
  /// **'Passer en mode couple'**
  String get invitePartnerAction;

  /// No description provided for @invitePartnerDone.
  ///
  /// In fr, this message translates to:
  /// **'Mode couple activé.'**
  String get invitePartnerDone;

  /// No description provided for @shareCodeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Code d\'invitation'**
  String get shareCodeTitle;

  /// No description provided for @shareCodeBody.
  ///
  /// In fr, this message translates to:
  /// **'Votre partenaire crée son compte Horizon, puis choisit « Rejoindre un foyer » et saisit ce code.'**
  String get shareCodeBody;

  /// No description provided for @copyCode.
  ///
  /// In fr, this message translates to:
  /// **'Copier le code'**
  String get copyCode;

  /// No description provided for @codeCopied.
  ///
  /// In fr, this message translates to:
  /// **'Code copié.'**
  String get codeCopied;

  /// No description provided for @backToSoloTitle.
  ///
  /// In fr, this message translates to:
  /// **'Revenir en mode solo'**
  String get backToSoloTitle;

  /// No description provided for @backToSoloBody.
  ///
  /// In fr, this message translates to:
  /// **'Le code d\'invitation sera annulé et vous assumerez de nouveau seul(e) les dépenses communes. Possible tant que personne n\'a rejoint votre foyer.'**
  String get backToSoloBody;

  /// No description provided for @backToSoloAction.
  ///
  /// In fr, this message translates to:
  /// **'Revenir en solo'**
  String get backToSoloAction;

  /// No description provided for @backToSoloDone.
  ///
  /// In fr, this message translates to:
  /// **'Mode solo réactivé.'**
  String get backToSoloDone;

  /// No description provided for @leaveHouseholdTitle.
  ///
  /// In fr, this message translates to:
  /// **'Quitter le foyer'**
  String get leaveHouseholdTitle;

  /// No description provided for @leaveHouseholdSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'En cas de séparation'**
  String get leaveHouseholdSubtitle;

  /// No description provided for @leaveHouseholdBody.
  ///
  /// In fr, this message translates to:
  /// **'Cette action est IRRÉVERSIBLE :\n\n• Vos connexions bancaires seront révoquées\n• Vos transactions seront supprimées de ce foyer\n• Les bilans du foyer seront effacés (ils mêlent vos dépenses)\n• La dette interne sera annulée — réglez-la avant si nécessaire\n• {name} se retrouvera seul(e) dans le foyer\n\nVotre compte Horizon est conservé : vous pourrez créer un nouveau foyer.\n\nTapez {keyword} pour confirmer :'**
  String leaveHouseholdBody(String name, String keyword);

  /// No description provided for @leaveKeyword.
  ///
  /// In fr, this message translates to:
  /// **'QUITTER'**
  String get leaveKeyword;

  /// No description provided for @leaveHouseholdAction.
  ///
  /// In fr, this message translates to:
  /// **'Quitter définitivement'**
  String get leaveHouseholdAction;

  /// No description provided for @leaveHouseholdDone.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez quitté le foyer.'**
  String get leaveHouseholdDone;

  /// No description provided for @leaveDebtWarning.
  ///
  /// In fr, this message translates to:
  /// **'Dette interne en cours : {amount}. Elle sera annulée sans compensation.'**
  String leaveDebtWarning(String amount);

  /// No description provided for @cannotRemovePartner.
  ///
  /// In fr, this message translates to:
  /// **'Vous ne pouvez pas retirer votre partenaire : il doit quitter le foyer lui-même, depuis son propre appareil.'**
  String get cannotRemovePartner;

  /// No description provided for @householdActionError.
  ///
  /// In fr, this message translates to:
  /// **'L\'opération a échoué. Réessayez.'**
  String get householdActionError;

  /// No description provided for @resetDataTitle.
  ///
  /// In fr, this message translates to:
  /// **'Réinitialiser les données du foyer'**
  String get resetDataTitle;

  /// No description provided for @resetDataSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Repartir à zéro sans supprimer les comptes'**
  String get resetDataSubtitle;

  /// No description provided for @resetDataBody.
  ///
  /// In fr, this message translates to:
  /// **'Tout l\'historique financier du foyer sera effacé :\n\n• Connexions bancaires révoquées\n• Toutes les transactions supprimées\n• Budgets, règlements et bilans effacés\n• Cagnottes et dette remises à zéro\n\nLes comptes, le foyer et votre double authentification sont conservés.\n\nTapez {keyword} pour confirmer :'**
  String resetDataBody(String keyword);

  /// No description provided for @resetKeyword.
  ///
  /// In fr, this message translates to:
  /// **'REINITIALISER'**
  String get resetKeyword;

  /// No description provided for @resetDataAction.
  ///
  /// In fr, this message translates to:
  /// **'Tout réinitialiser'**
  String get resetDataAction;

  /// No description provided for @resetDataDone.
  ///
  /// In fr, this message translates to:
  /// **'{count} transaction(s) supprimée(s). Le foyer repart à zéro.'**
  String resetDataDone(int count);

  /// No description provided for @resetDataOwnerOnly.
  ///
  /// In fr, this message translates to:
  /// **'Seul le membre qui a créé le foyer peut réinitialiser ses données.'**
  String get resetDataOwnerOnly;

  /// No description provided for @transitionAdviceCta.
  ///
  /// In fr, this message translates to:
  /// **'Conseils du coach pour cette étape'**
  String get transitionAdviceCta;

  /// No description provided for @transitionToCoupleTitle.
  ///
  /// In fr, this message translates to:
  /// **'Passage en mode couple'**
  String get transitionToCoupleTitle;

  /// No description provided for @transitionToSoloTitle.
  ///
  /// In fr, this message translates to:
  /// **'Retour en mode solo'**
  String get transitionToSoloTitle;

  /// No description provided for @transitionAdviceIntro.
  ///
  /// In fr, this message translates to:
  /// **'Un changement de situation bouscule un budget. Le coach vous propose des bonnes pratiques pour aborder cette étape sereinement.'**
  String get transitionAdviceIntro;

  /// No description provided for @transitionAdviceGenerate.
  ///
  /// In fr, this message translates to:
  /// **'Obtenir mes conseils'**
  String get transitionAdviceGenerate;

  /// No description provided for @transitionAdviceLoading.
  ///
  /// In fr, this message translates to:
  /// **'Le coach rédige vos conseils...'**
  String get transitionAdviceLoading;

  /// No description provided for @transitionAdviceError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de générer les conseils pour le moment.'**
  String get transitionAdviceError;

  /// No description provided for @realBalanceTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mon solde réel'**
  String get realBalanceTitle;

  /// No description provided for @realBalanceTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Comparer au solde réel de mon compte'**
  String get realBalanceTooltip;

  /// No description provided for @realBalanceMyAccounts.
  ///
  /// In fr, this message translates to:
  /// **'Mes comptes personnels'**
  String get realBalanceMyAccounts;

  /// No description provided for @realBalanceAvailable.
  ///
  /// In fr, this message translates to:
  /// **'Solde réel disponible'**
  String get realBalanceAvailable;

  /// No description provided for @realBalanceSoloPot.
  ///
  /// In fr, this message translates to:
  /// **'Ma cagnotte solo'**
  String get realBalanceSoloPot;

  /// No description provided for @realBalanceJoint.
  ///
  /// In fr, this message translates to:
  /// **'Comptes conjoints (exclus du calcul)'**
  String get realBalanceJoint;

  /// No description provided for @realBalanceEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun compte de dépôt personnel relié. Le solde réel s\'affiche pour tes comptes chèque et épargne connectés.'**
  String get realBalanceEmpty;

  /// No description provided for @realBalanceError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de récupérer les soldes pour le moment.'**
  String get realBalanceError;

  /// No description provided for @realBalanceRefresh.
  ///
  /// In fr, this message translates to:
  /// **'Rafraîchir'**
  String get realBalanceRefresh;

  /// No description provided for @realBalanceNote.
  ///
  /// In fr, this message translates to:
  /// **'Ta cagnotte solo, c\'est l\'argent perso qu\'il te reste à dépenser ce mois-ci. Ton compte réel contient aussi de quoi couvrir les dépenses communes et fixes : les deux montants ne sont pas censés être identiques.'**
  String get realBalanceNote;

  /// No description provided for @acctChecking.
  ///
  /// In fr, this message translates to:
  /// **'Chèque'**
  String get acctChecking;

  /// No description provided for @acctSavings.
  ///
  /// In fr, this message translates to:
  /// **'Épargne'**
  String get acctSavings;

  /// No description provided for @acctDeposit.
  ///
  /// In fr, this message translates to:
  /// **'Dépôt'**
  String get acctDeposit;

  /// No description provided for @spendingByCategoryHint.
  ///
  /// In fr, this message translates to:
  /// **'Touchez une catégorie pour voir et corriger ses transactions.'**
  String get spendingByCategoryHint;

  /// No description provided for @categoryTxEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune transaction dans cette catégorie pour cette période.'**
  String get categoryTxEmpty;

  /// No description provided for @categoryTxTotal.
  ///
  /// In fr, this message translates to:
  /// **'Total : {amount}'**
  String categoryTxTotal(String amount);

  /// No description provided for @categoryTxChange.
  ///
  /// In fr, this message translates to:
  /// **'Changer la catégorie'**
  String get categoryTxChange;

  /// No description provided for @categoryTxPickTitle.
  ///
  /// In fr, this message translates to:
  /// **'Choisir une catégorie'**
  String get categoryTxPickTitle;

  /// No description provided for @categoryTxUpdated.
  ///
  /// In fr, this message translates to:
  /// **'Catégorie mise à jour'**
  String get categoryTxUpdated;

  /// No description provided for @categoryTxError.
  ///
  /// In fr, this message translates to:
  /// **'La mise à jour a échoué.'**
  String get categoryTxError;

  /// No description provided for @checkingBalanceLabel.
  ///
  /// In fr, this message translates to:
  /// **'Compte chèque réel'**
  String get checkingBalanceLabel;

  /// No description provided for @bankReauthNeeded.
  ///
  /// In fr, this message translates to:
  /// **'Une banque doit être reconnectée'**
  String get bankReauthNeeded;

  /// No description provided for @bankReauthNeededNamed.
  ///
  /// In fr, this message translates to:
  /// **'{institution} : reconnexion requise'**
  String bankReauthNeededNamed(String institution);

  /// No description provided for @bankReconnect.
  ///
  /// In fr, this message translates to:
  /// **'Reconnecter'**
  String get bankReconnect;

  /// No description provided for @bankReconnecting.
  ///
  /// In fr, this message translates to:
  /// **'Reconnexion en cours…'**
  String get bankReconnecting;

  /// No description provided for @bankReconnected.
  ///
  /// In fr, this message translates to:
  /// **'Banque reconnectée'**
  String get bankReconnected;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
