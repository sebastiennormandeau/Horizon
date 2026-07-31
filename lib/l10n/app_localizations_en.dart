// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTagline => 'Zero-based budgeting made simple for households';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get close => 'Close';

  @override
  String get copy => 'Copy';

  @override
  String get retry => 'Retry';

  @override
  String get continueLabel => 'Continue';

  @override
  String get loadingError => 'Loading error';

  @override
  String get profileLoadingError => 'Failed to load your profile.';

  @override
  String get pleaseReconnect => 'Please sign in again';

  @override
  String get householdNotFound => 'Household not found';

  @override
  String get bucketCommon => 'Shared';

  @override
  String get bucketEssential => 'Essentials';

  @override
  String get bucketPersonal => 'Personal';

  @override
  String get bucketToSort => 'To sort';

  @override
  String bucketMe(String name) {
    return '$name (me)';
  }

  @override
  String get loginError => 'Sign-in error';

  @override
  String get resetPasswordInvalidEmail =>
      'Enter a valid email address to reset your password.';

  @override
  String get resetPasswordSent =>
      'Password reset email sent. Check your inbox.';

  @override
  String get sendError => 'Sending failed.';

  @override
  String get emailLabel => 'Email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get passwordRequired => 'Please enter your password.';

  @override
  String get signIn => 'Sign in';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get createAccount => 'Create an account';

  @override
  String get registerTitle => 'Sign up';

  @override
  String get mustAcceptTerms => 'You must accept the Terms of Service.';

  @override
  String get registerError => 'Sign-up error';

  @override
  String get firstNameLabel => 'First name';

  @override
  String get firstNameHelper => 'Shown to your partner in the household';

  @override
  String get passwordHelper => '8 characters min., with letters and digits';

  @override
  String get confirmPasswordLabel => 'Confirm password';

  @override
  String get iAcceptThe => 'I accept the ';

  @override
  String get termsLinkLabel => 'Terms of Service';

  @override
  String get andThe => ' and the ';

  @override
  String get privacyLinkLabel => 'Privacy Policy';

  @override
  String get sentencePeriod => '.';

  @override
  String get termsDocTitle => 'Terms of Service';

  @override
  String get privacyDocTitle => 'Privacy Policy';

  @override
  String get verifyEmailTitle => 'Email verification';

  @override
  String get signOut => 'Sign out';

  @override
  String get verificationSent =>
      'Verification email sent. Check your inbox (and your spam folder).';

  @override
  String get confirmYourEmail => 'Confirm your email address';

  @override
  String verificationBody(String email) {
    return 'A verification link was sent to\n$email\n\nHorizon handles financial data: verifying your address is mandatory.';
  }

  @override
  String resendIn(String seconds) {
    return 'Resend in $seconds s';
  }

  @override
  String get resendEmail => 'Resend email';

  @override
  String get iConfirmedMyEmail => 'I have confirmed my address';

  @override
  String get mfaEnrollTitle => 'Secure your account';

  @override
  String get mfaEnrollHeading => 'Two-factor authentication required';

  @override
  String get mfaEnrollIntro =>
      'Horizon handles financial data: a second factor is required on every account. This takes two minutes and is done only once.';

  @override
  String get mfaStep1 => '1. Install an authenticator app';

  @override
  String get mfaStep1Detail =>
      'Google Authenticator, Microsoft Authenticator, Authy, or your phone\'s password manager.';

  @override
  String get mfaStep2 => '2. Scan this QR code';

  @override
  String get mfaStep2Manual =>
      'Can\'t scan? Enter this key manually in the app:';

  @override
  String get mfaCopyKey => 'Copy key';

  @override
  String get mfaKeyCopied => 'Key copied to clipboard.';

  @override
  String get mfaStep3 => '3. Enter the code shown';

  @override
  String get mfaCodeLabel => '6-digit code';

  @override
  String get mfaCodeRequired => 'Enter the 6-digit code.';

  @override
  String get mfaCodeInvalidFormat => 'The code must be exactly 6 digits.';

  @override
  String get mfaActivate => 'Enable two-factor authentication';

  @override
  String get mfaDeviceNameDefault => 'Authenticator app';

  @override
  String get mfaEnrollSuccess =>
      'Two-factor authentication enabled. Your account is protected.';

  @override
  String get mfaEnrollError => 'Activation failed. Please try again.';

  @override
  String get mfaCodeRejected =>
      'Code rejected. Check your phone\'s clock and enter the code currently displayed.';

  @override
  String get mfaRecentLoginRequired =>
      'For security, please sign in again before enabling two-factor authentication.';

  @override
  String get mfaPreparing => 'Preparing your security key...';

  @override
  String get mfaSecretError =>
      'Could not generate the security key. Please try again.';

  @override
  String get mfaBackupWarning =>
      'Important: keep access to this authenticator app. Without it you will not be able to sign in, and you will need to email us to reset your access.';

  @override
  String get mfaOpenInApp => 'Open in my authenticator app';

  @override
  String get mfaChallengeTitle => 'Two-step verification';

  @override
  String get mfaChallengeHeading => 'Enter your security code';

  @override
  String mfaChallengeIntro(String email) {
    return 'Open your authenticator app and enter the 6-digit code shown for $email.';
  }

  @override
  String get mfaVerify => 'Verify';

  @override
  String get mfaChallengeError =>
      'Code rejected. Try again with the code currently displayed.';

  @override
  String get mfaLostAccess => 'I lost access to my app';

  @override
  String get mfaLostAccessTitle => 'Lost access?';

  @override
  String mfaLostAccessBody(String email) {
    return 'For your security, only an administrator can reset two-factor authentication. Email $email from your account\'s email address, including your name. We will verify your identity before any reset.';
  }

  @override
  String get householdSetupTitle => 'Household Setup';

  @override
  String get householdCreated => 'Household created!';

  @override
  String get inviteCodeIntro => 'Here is your code to invite your partner:';

  @override
  String get inviteCodeNote =>
      'It will stay visible on your dashboard until your partner joins the household.';

  @override
  String get householdCreateError => 'Failed to create the household.';

  @override
  String get invalidCodeError => 'Invalid code or error.';

  @override
  String get welcomeTitle => 'Welcome to Horizon';

  @override
  String get welcomeBody => 'How do you plan to use Horizon?';

  @override
  String get modeSoloTitle => 'On my own';

  @override
  String get modeSoloDescription =>
      'Your essential expenses and personal spending money, managed just for you.';

  @override
  String get modeCoupleTitle => 'As a couple';

  @override
  String get modeCoupleDescription =>
      'Two people, one shared budget: common expenses, each partner\'s personal money, and the balance between you.';

  @override
  String get modeChangeNote => 'You can invite a partner later.';

  @override
  String get joinExistingTitle =>
      'Has your partner already created a household?';

  @override
  String get createHouseholdButton => 'Create a new household';

  @override
  String get householdCreatedSolo => 'Your household is ready!';

  @override
  String get householdCreatedSoloBody =>
      'You can now set up your budget and connect your bank.';

  @override
  String get orSeparator => 'OR';

  @override
  String get joinCodeFieldLabel => 'Household code (6 characters)';

  @override
  String get joinButton => 'Join';

  @override
  String get syncingTransactions => 'Syncing transactions...';

  @override
  String get bankConnected => 'Bank connected and synced!';

  @override
  String get syncError => 'Sync error.';

  @override
  String get plaidError => 'Failed to connect to Plaid.';

  @override
  String assignedTo(String bucket) {
    return 'Assigned to $bucket';
  }

  @override
  String get undoAction => 'UNDO';

  @override
  String get negativeWarningTitle => 'Negative balance warning';

  @override
  String negativeWarningBody(
    String merchant,
    String amount,
    String bucket,
    String after,
  ) {
    return 'Assigning \"$merchant\" ($amount) will bring the $bucket pot down to $after.\n\nContinue anyway?';
  }

  @override
  String get assignAnyway => 'Assign anyway';

  @override
  String get settleDebtTitle => 'Settle the internal debt';

  @override
  String settleDebtBody(String debtor, String amount, String creditor) {
    return '$debtor owes $amount to $creditor.\n\nDo you confirm this amount has been paid back (transfer, cash, etc.)? The balance will be reset to zero.';
  }

  @override
  String get confirmSettlement => 'Confirm settlement';

  @override
  String debtSettled(String amount) {
    return 'Debt of $amount settled!';
  }

  @override
  String get settleError => 'Settlement failed.';

  @override
  String get bilanTooltip => 'Review';

  @override
  String get historyTooltip => 'History';

  @override
  String get budgetConfigTooltip => 'Budget setup';

  @override
  String get settingsTooltip => 'Settings';

  @override
  String get transactionsToNeutralize => 'Transactions to neutralize';

  @override
  String get alertNegativeBanner =>
      'A pot is in the negative — open the Review to adjust.';

  @override
  String alertLowBanner(String threshold) {
    return 'A pot is getting close to zero (threshold: $threshold).';
  }

  @override
  String get inviteWithCode => 'Invite your partner with this code:';

  @override
  String get internalBalanceSettled => 'Internal balance: settled';

  @override
  String internalDebtOwes(String debtor, String amount, String creditor) {
    return '$debtor owes $amount to $creditor';
  }

  @override
  String get settleButton => 'SETTLE';

  @override
  String get noTransactionsToSort => 'No transactions to sort.';

  @override
  String get connectMyBank => 'Connect my bank';

  @override
  String get historyTitle => 'History';

  @override
  String get freePlanBanner => 'Free plan: 30 days of history.';

  @override
  String get premiumButton => 'PREMIUM';

  @override
  String get filterAll => 'All';

  @override
  String get noCategorizedTransactions => 'No categorized transactions.';

  @override
  String transactionCount(String count) {
    return '$count transaction(s)';
  }

  @override
  String totalAmount(String amount) {
    return 'Total: $amount';
  }

  @override
  String get allCategories => 'All categories';

  @override
  String get changeCategory => 'Change category';

  @override
  String moveTo(String bucket) {
    return 'Move to $bucket';
  }

  @override
  String get sendBackToSort => 'Send back to \"To sort\"';

  @override
  String get sentBackToSort => 'Transaction sent back to \"To sort\".';

  @override
  String movedTo(String bucket) {
    return 'Moved to $bucket.';
  }

  @override
  String get bilanTitle => 'Review';

  @override
  String get refreshTooltip => 'Refresh';

  @override
  String get reportError => 'Failed to generate the review.';

  @override
  String get coachUnavailable => 'The AI coach is unavailable.';

  @override
  String addedToFixedExpenses(String name, String amount) {
    return '\"$name\" added to fixed expenses ($amount/month).';
  }

  @override
  String get addError => 'Failed to add.';

  @override
  String noLongerSuggested(String name) {
    return '\"$name\" will no longer be suggested.';
  }

  @override
  String get thisMonth => 'This month';

  @override
  String get thisWeek => 'This week';

  @override
  String get reportUnavailable => 'Review unavailable.';

  @override
  String get spendingByCategory => 'Spending by category';

  @override
  String get topMerchants => 'Top merchants';

  @override
  String get recurringDetected => 'Recurring expenses detected';

  @override
  String get aiCoachSection => 'AI budget coach';

  @override
  String get monthSpending => 'This month\'s spending';

  @override
  String get weekSpending => 'This week\'s spending';

  @override
  String vsPreviousPeriod(String delta, String amount) {
    return '$delta% vs previous period ($amount)';
  }

  @override
  String get noPreviousPeriod => 'No previous period to compare yet.';

  @override
  String recurringInfo(String frequency, String occurrences, String monthly) {
    return '$frequency expense detected ($occurrences times) — ≈ $monthly/month';
  }

  @override
  String get freqLabelWeekly => 'Weekly';

  @override
  String get freqLabelBiweekly => 'Bi-weekly';

  @override
  String get freqLabelMonthly => 'Monthly';

  @override
  String get ignore => 'Ignore';

  @override
  String get addToBudget => 'Add to budget';

  @override
  String get monthEnvelopes => 'This month\'s envelopes';

  @override
  String overBudgetBy(String amount) {
    return 'Over budget by $amount';
  }

  @override
  String spentOfBudget(String spent, String budget) {
    return '$spent / $budget';
  }

  @override
  String get aiDisclaimer =>
      'These suggestions are generated by an AI from your aggregated spending data and do not constitute professional financial advice.';

  @override
  String get aiPitch =>
      'Get personalized observations and suggestions, written from this review\'s numbers.';

  @override
  String get generateAdvice => 'Generate my AI advice';

  @override
  String get regenerateAdvice => 'Regenerate advice';

  @override
  String get budgetSetupTitle => 'ZBB Budget Setup';

  @override
  String get freqMonthly => 'Monthly';

  @override
  String get freqBiweekly => 'Bi-weekly';

  @override
  String get freqWeekly => 'Weekly';

  @override
  String get newExpenseDefault => 'New expense';

  @override
  String get newAllocationDefault => 'New allocation';

  @override
  String get budgetSaved => 'Monthly budget saved!';

  @override
  String get budgetSaveError => 'Failed to save.';

  @override
  String get envelopesTitle => 'Envelopes by category';

  @override
  String get envelopesSubtitle =>
      'Monthly budgets for your variable spending — the Review tracks their progress.';

  @override
  String get categoryFieldLabel => 'Category';

  @override
  String get budgetFieldLabel => 'Budget';

  @override
  String get magicMonthsTitle => 'Magic Months calendar 🌟';

  @override
  String get magicMonthsSubtitle => 'A magic month contains an extra paycheck.';

  @override
  String get nameFieldLabel => 'Name';

  @override
  String get amountFieldLabel => 'Amount';

  @override
  String get incomeSection => 'Income';

  @override
  String get incomeALabel => 'Income A';

  @override
  String get incomeBLabel => 'Income B';

  @override
  String get incomeSoloLabel => 'My income';

  @override
  String get netEssentialExpenses => 'Net essential expenses:';

  @override
  String get payFrequencyLabel => 'Pay frequency';

  @override
  String get nextPayDateLabel => 'Next pay date';

  @override
  String get selectADate => 'Select a date';

  @override
  String get allocationsSection => 'Allocations & Deductions';

  @override
  String get fixedExpensesSection => 'Shared Fixed Expenses';

  @override
  String get alertThresholdTitle => 'Pot alert threshold';

  @override
  String get alertThresholdSubtitle =>
      'Below this amount, a pot turns orange on the dashboard.';

  @override
  String get thresholdFieldLabel => 'Threshold (\$)';

  @override
  String get proRataTitle => 'Pro-rata split';

  @override
  String userAShare(String pct) {
    return 'User A: $pct%';
  }

  @override
  String userBShare(String pct) {
    return 'User B: $pct%';
  }

  @override
  String get netCommonExpenses => 'Net shared expenses:';

  @override
  String aPays(String amount) {
    return 'A pays: $amount';
  }

  @override
  String bPays(String amount) {
    return 'B pays: $amount';
  }

  @override
  String get saveBudgetButton => 'Save Budget';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get editMyName => 'Edit my first name';

  @override
  String get nameUpdated => 'First name updated.';

  @override
  String get updateError => 'Update failed.';

  @override
  String get myDataJson => 'My data (JSON)';

  @override
  String get copiedToClipboard => 'Data copied to clipboard.';

  @override
  String get exportError => 'Export failed.';

  @override
  String get deleteAccountTitle => 'Delete my account';

  @override
  String deleteAccountBody(String keyword) {
    return 'This action is IRREVERSIBLE:\n\n• Your bank connections will be revoked\n• Your transactions will be deleted\n• Your account will be permanently erased\n\nType $keyword to confirm:';
  }

  @override
  String get deleteKeyword => 'DELETE';

  @override
  String get deleteForever => 'Delete permanently';

  @override
  String get deleteError => 'Deletion failed.';

  @override
  String get profileSection => 'Profile';

  @override
  String get emailVerified => 'Email verified';

  @override
  String get emailNotVerified => 'Email not verified';

  @override
  String get subscriptionSection => 'Subscription';

  @override
  String get premiumPlanTitle => 'Horizon Premium';

  @override
  String get freePlanTitle => 'Free plan';

  @override
  String get manageSubscription =>
      'Manage your subscription from the App Store / Play Store.';

  @override
  String get freePlanLimits => '1 bank account, 30 days of history';

  @override
  String get myDataSection => 'My data (Quebec Law 25)';

  @override
  String get exportMyData => 'Export my data';

  @override
  String get exportSubtitle => 'JSON copy of all your data';

  @override
  String get accountSection => 'Account';

  @override
  String get deleteAccountSubtitle => 'Permanent deletion of all your data';

  @override
  String get languageSection => 'Language / Langue';

  @override
  String get languageTile => 'App language';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSystem => 'Automatic (device language)';

  @override
  String get paywallTitle => 'Horizon Premium';

  @override
  String get featUnlimitedBanks => 'Unlimited bank accounts';

  @override
  String get featFullHistory => 'Full, unlimited history';

  @override
  String get featRealtimeSync => 'Real-time sync';

  @override
  String get featPrioritySupport => 'Priority support';

  @override
  String get purchaseWelcome =>
      'Welcome to Horizon Premium! Activating (a few seconds)...';

  @override
  String get purchaseFailed => 'Purchase failed. Please try again.';

  @override
  String get purchasesRestored => 'Purchases restored successfully!';

  @override
  String get nothingToRestore => 'No purchases to restore.';

  @override
  String get goPremium => 'Upgrade to Horizon Premium';

  @override
  String get webNoPurchase =>
      'Subscriptions are purchased from the Horizon mobile app (Android or iPhone). Once subscribed, your Premium status automatically applies to your whole household, including on the Web.';

  @override
  String get storeUnavailable =>
      'The store is not available yet. Please try again later.';

  @override
  String get restorePurchases => 'Restore my purchases';

  @override
  String get vEmailRequired => 'Please enter your email address.';

  @override
  String get vEmailInvalid => 'Invalid email address.';

  @override
  String get vPasswordRequired => 'Please enter a password.';

  @override
  String get vPasswordTooShort =>
      'The password must contain at least 8 characters.';

  @override
  String get vPasswordNeedsLetterDigit =>
      'The password must contain at least one letter and one digit.';

  @override
  String get vPasswordMismatch => 'The passwords do not match.';

  @override
  String get vNameTooShort => 'Please enter your first name (2 letters min.).';

  @override
  String get vNameTooLong => 'First name too long (40 characters max.).';

  @override
  String get vJoinCodeInvalid => 'The code must contain 6 letters or digits.';

  @override
  String get chartOtherCategories => 'Other categories';

  @override
  String get bucketTransfer => 'Internal transfer';

  @override
  String get bucketArchived => 'Skipped';

  @override
  String get sortFilterAll => 'All';

  @override
  String get sortFilterThisMonth => 'This month';

  @override
  String get archivePastTitle => 'Skip past months';

  @override
  String get archivePastBody =>
      'Unsorted transactions from before this month will be removed from the queue.\n\nThey stay visible in History and counted in your reports — only your pots, which are computed for the current month, are left untouched.';

  @override
  String get archivePastAction => 'Skip them';

  @override
  String archivePastDone(int count) {
    return '$count transaction(s) removed from the queue.';
  }

  @override
  String get archivePastNothing => 'No transactions from past months to skip.';

  @override
  String toSortCount(int count) {
    return '$count to sort';
  }

  @override
  String get bankSection => 'Bank accounts';

  @override
  String get bankManageTitle => 'My bank accounts';

  @override
  String get bankManageSubtitle => 'Connections and syncing';

  @override
  String get bankNone => 'No bank connected yet.';

  @override
  String get bankUnknownInstitution => 'Bank account';

  @override
  String get bankPartnerAccount => 'Linked by your partner';

  @override
  String get bankNeverSynced => 'Never synced';

  @override
  String bankLastSync(String date) {
    return 'Last sync: $date';
  }

  @override
  String get notifSection => 'Notifications';

  @override
  String get notifManageTitle => 'Manage my notifications';

  @override
  String get notifManageSubtitle => 'Card reminders, pot alerts...';

  @override
  String get notifEnableTitle => 'Enable notifications';

  @override
  String get notifEnableBody => 'Get reminders and alerts on this device.';

  @override
  String get notifEnableButton => 'Enable on this device';

  @override
  String get notifDisableButton => 'Disable on this device';

  @override
  String get notifEnabled => 'Notifications enabled.';

  @override
  String get notifRefused =>
      'Permission denied. On iPhone, first add Horizon to your home screen.';

  @override
  String get notifIosHint =>
      'On iPhone, notifications only work after adding Horizon to your home screen (Share → Add to Home Screen).';

  @override
  String get notifTypesTitle => 'Notification types';

  @override
  String get notifCardReminder => 'Card payment reminder';

  @override
  String get notifCardReminderSub => 'Before your credit cards are due';

  @override
  String get notifPotAlert => 'Pot alert';

  @override
  String get notifPotAlertSub =>
      'When a pot drops below the threshold or goes negative';

  @override
  String get notifToSort => 'Transactions to sort';

  @override
  String get notifToSortSub => 'Weekly reminder when transactions are waiting';

  @override
  String get notifPartner => 'Partner activity';

  @override
  String get notifPartnerSub => 'Debt settlements and household changes';

  @override
  String get notifOverspend => 'Cash shortfall';

  @override
  String get notifOverspendSub =>
      'When a card balance exceeds the cash available to pay it';

  @override
  String get notifEnvelope => 'Envelope nearly used up';

  @override
  String get notifEnvelopeSub =>
      'When a variable-budget envelope nears its threshold';

  @override
  String notifEnvelopePct(String pct) {
    return 'Envelope alert threshold: $pct%';
  }

  @override
  String notifLeadDays(int days) {
    return 'Card reminder: $days day(s) before the due date';
  }

  @override
  String get notifSaved => 'Preferences saved.';

  @override
  String get notifCardsTitle => 'My credit cards';

  @override
  String get notifCardDueDay => 'Due day (1–28)';

  @override
  String get notifCardDueAuto => 'Due date provided automatically';

  @override
  String get notifCardNone =>
      'No credit card detected. Link one, or reconnect it to enable due-date tracking.';

  @override
  String get notifCardManualHint =>
      'Enter the due day if your bank does not provide it automatically.';

  @override
  String get searchHint => 'Search a merchant, a category...';

  @override
  String get sortTooltip => 'Sort';

  @override
  String get sortDateDesc => 'Date — newest first';

  @override
  String get sortDateAsc => 'Date — oldest first';

  @override
  String get sortAmountDesc => 'Amount — highest first';

  @override
  String get sortAmountAsc => 'Amount — lowest first';

  @override
  String get noSearchResults => 'No transaction matches your search.';

  @override
  String get tutorialSkip => 'Skip';

  @override
  String get tutorialNext => 'Next';

  @override
  String get tutorialDone => 'Get started';

  @override
  String get tutorialReplay => 'Replay the getting-started guide';

  @override
  String get tutorial1Title => 'Every dollar has a job';

  @override
  String get tutorial1Body =>
      'Horizon splits your income into pots before you spend. That way you always know what you actually have left — not just your account balance.';

  @override
  String get tutorial2Title => 'Two kinds of pots';

  @override
  String get tutorial2Body =>
      'The shared pot holds exactly what it takes to cover this month\'s fixed costs: rent, utilities, insurance. It should drift down to zero as the bills get paid.\n\nYour personal pots are your free money: what remains once your share of the fixed costs is set aside.';

  @override
  String get tutorial3Title => 'Sort with a swipe';

  @override
  String get tutorial3Body =>
      'Each imported transaction waits to be filed. Swipe left for your personal pot, right for the shared pot.\n\nThe pot updates immediately, and you can undo.';

  @override
  String get tutorial4Title => 'Transfers and internal moves';

  @override
  String get tutorial4Body =>
      'Not every outflow is an expense. A credit-card payment, a transfer to your savings, a loan repayment with money already set aside: these are moves between your own accounts.\n\nHorizon sets them aside automatically when it recognizes them. Otherwise, the “⋮” menu on each transaction lets you file it as an “Internal transfer” — it won\'t touch any pot.';

  @override
  String get tutorial5Title => 'Keep the queue light';

  @override
  String get tutorial5Body =>
      'Linking a bank imports months of history. So you don\'t sort the past, the “Skip past months” button removes everything before the current month from the queue.\n\nThose transactions stay in your History and reports: only your pots, computed for the current month, are preserved.';

  @override
  String get tutorial6Title => 'Your bank accounts';

  @override
  String get tutorial6Body =>
      'Link as many accounts as you need — chequing, savings, credit card.\n\nOne setting matters most: mark which accounts are joint, so no debt gets invented between you when a shared cost leaves an account you both fund.';

  @override
  String get bankJointLabel => 'Joint account';

  @override
  String get bankJointHint =>
      'Shared expenses paid from this account will not create any debt between you: the money leaves an account you both fund.';

  @override
  String get bankPersonalHint =>
      'Shared expenses paid from this account will be recorded as money you fronted for your partner.';

  @override
  String get bankJointUpdated => 'Account type updated.';

  @override
  String get bankJointDebtNote =>
      'Debt already calculated is not recomputed. Use “Settle” on the home screen to start from zero.';

  @override
  String get bankDisconnect => 'Disconnect';

  @override
  String get bankDisconnectTitle => 'Disconnect this bank?';

  @override
  String get bankDisconnectBody =>
      'Horizon\'s access to this account will be revoked with Plaid, and the transactions imported from this bank will be removed from Horizon.\n\nTheir effect on your pots is reversed automatically. Reconnecting the bank will re-import its history.';

  @override
  String get bankDisconnected => 'Bank disconnected.';

  @override
  String get bankSyncNow => 'Sync now';

  @override
  String get bankSyncing => 'Syncing...';

  @override
  String bankSyncDone(int count) {
    return '$count new transaction(s) imported.';
  }

  @override
  String get bankSyncNothing =>
      'No new transactions. After a first connection, Plaid can take several minutes to deliver the history — transactions will appear on their own.';

  @override
  String get bankAddAnother => 'Connect another bank';

  @override
  String get bankFreePlanLimit =>
      'The free plan allows one bank per household.';

  @override
  String get allSortedTitle => 'All sorted!';

  @override
  String get allSortedBody =>
      'No transactions waiting. New ones will show up here automatically.';

  @override
  String get noBankTitle => 'Link your bank to get started';

  @override
  String get noBankBody =>
      'Your transactions will be imported automatically, then you sort them with a swipe.';

  @override
  String get plaidExitTitle => 'Bank connection interrupted';

  @override
  String plaidExitCancelled(String status) {
    return 'Connection cancelled at step: $status';
  }

  @override
  String get plaidExitHint =>
      'Share these details with support if the problem persists.';

  @override
  String get themeSection => 'Appearance';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeSystem => 'Automatic (system setting)';

  @override
  String get householdSection => 'Household';

  @override
  String get householdManageTitle => 'Manage my household';

  @override
  String get householdManageSubtitle => 'Mode, invitation, separation';

  @override
  String get householdStatusSolo => 'You are using Horizon on your own.';

  @override
  String get householdStatusWaiting => 'Waiting for a second member.';

  @override
  String householdStatusCouple(String name) {
    return 'Household shared with $name.';
  }

  @override
  String get invitePartnerTitle => 'Invite a partner';

  @override
  String get invitePartnerBody =>
      'Your household will switch to couple mode: a personal pot for each of you, a shared pot, and tracking of who fronted what. Shared expenses will be split 50/50 by default — you can adjust the split in the budget settings.';

  @override
  String get invitePartnerAction => 'Switch to couple mode';

  @override
  String get invitePartnerDone => 'Couple mode enabled.';

  @override
  String get shareCodeTitle => 'Invitation code';

  @override
  String get shareCodeBody =>
      'Your partner creates their Horizon account, then picks “Join a household” and enters this code.';

  @override
  String get copyCode => 'Copy the code';

  @override
  String get codeCopied => 'Code copied.';

  @override
  String get backToSoloTitle => 'Switch back to solo mode';

  @override
  String get backToSoloBody =>
      'The invitation code will be cancelled and you will again cover shared expenses on your own. Available as long as nobody has joined your household.';

  @override
  String get backToSoloAction => 'Back to solo';

  @override
  String get backToSoloDone => 'Solo mode re-enabled.';

  @override
  String get leaveHouseholdTitle => 'Leave the household';

  @override
  String get leaveHouseholdSubtitle => 'In case of separation';

  @override
  String leaveHouseholdBody(String name, String keyword) {
    return 'This action is IRREVERSIBLE:\n\n• Your bank connections will be revoked\n• Your transactions will be deleted from this household\n• The household reports will be erased (they mix both your expenses)\n• The internal debt will be cancelled — settle it first if needed\n• $name will be left alone in the household\n\nYour Horizon account is kept: you will be able to create a new household.\n\nType $keyword to confirm:';
  }

  @override
  String get leaveKeyword => 'LEAVE';

  @override
  String get leaveHouseholdAction => 'Leave permanently';

  @override
  String get leaveHouseholdDone => 'You have left the household.';

  @override
  String leaveDebtWarning(String amount) {
    return 'Outstanding internal debt: $amount. It will be cancelled with no compensation.';
  }

  @override
  String get cannotRemovePartner =>
      'You cannot remove your partner: they must leave the household themselves, from their own device.';

  @override
  String get householdActionError => 'The operation failed. Please try again.';

  @override
  String get resetDataTitle => 'Reset household data';

  @override
  String get resetDataSubtitle => 'Start fresh without deleting accounts';

  @override
  String resetDataBody(String keyword) {
    return 'The household\'s entire financial history will be erased:\n\n• Bank connections revoked\n• All transactions deleted\n• Budgets, settlements and reports erased\n• Pots and debt reset to zero\n\nAccounts, the household itself and your two-factor authentication are kept.\n\nType $keyword to confirm:';
  }

  @override
  String get resetKeyword => 'RESET';

  @override
  String get resetDataAction => 'Reset everything';

  @override
  String resetDataDone(int count) {
    return '$count transaction(s) deleted. The household starts fresh.';
  }

  @override
  String get resetDataOwnerOnly =>
      'Only the member who created the household can reset its data.';

  @override
  String get transitionAdviceCta => 'Coach advice for this step';

  @override
  String get transitionToCoupleTitle => 'Switching to couple mode';

  @override
  String get transitionToSoloTitle => 'Back to solo mode';

  @override
  String get transitionAdviceIntro =>
      'A change in circumstances shakes up a budget. The coach offers best practices to navigate this step calmly.';

  @override
  String get transitionAdviceGenerate => 'Get my advice';

  @override
  String get transitionAdviceLoading => 'The coach is writing your advice...';

  @override
  String get transitionAdviceError => 'Unable to generate advice right now.';

  @override
  String get realBalanceTitle => 'My real balance';

  @override
  String get realBalanceTooltip => 'Compare with my account\'s real balance';

  @override
  String get realBalanceMyAccounts => 'My personal accounts';

  @override
  String get realBalanceAvailable => 'Real available balance';

  @override
  String get realBalanceSoloPot => 'My solo pot';

  @override
  String get realBalanceJoint => 'Joint accounts (excluded)';

  @override
  String get realBalanceEmpty =>
      'No personal deposit account linked. Real balances show for your connected chequing and savings accounts.';

  @override
  String get realBalanceError => 'Unable to fetch balances right now.';

  @override
  String get realBalanceRefresh => 'Refresh';

  @override
  String get realBalanceNote =>
      'Your solo pot is the personal money you have left to spend this month. Your real account also holds money for shared and fixed expenses — the two amounts aren\'t meant to match.';

  @override
  String get acctChecking => 'Chequing';

  @override
  String get acctSavings => 'Savings';

  @override
  String get acctDeposit => 'Deposit';

  @override
  String get realBalanceChecking => 'My chequing';

  @override
  String get realBalanceSavings => 'My savings';

  @override
  String get investedThisPeriod => 'Invested this period 💪';

  @override
  String investmentProgress(String pct) {
    return '$pct% of your goal';
  }

  @override
  String get investmentGoalReached => 'Goal reached! 🎉';

  @override
  String get investmentSetGoalHint => 'Tap to set a monthly goal';

  @override
  String get investmentGoalTitle => 'Investment goal';

  @override
  String get investmentGoalLabel => 'Target monthly amount';

  @override
  String get edit => 'Edit';

  @override
  String get soloEnvelopesTitle => 'Variable budget (solo)';

  @override
  String get soloEnvelopesIntro =>
      'Reserve part of your solo pot per category. Suggested amounts come from your 3-month averages — adjust them.';

  @override
  String get soloEnvelopesApplyAll => 'Suggest all';

  @override
  String soloEnvelopesSuggestion(String amount) {
    return 'average: $amount';
  }

  @override
  String get soloEnvelopesTotal => 'Total reserved';

  @override
  String get soloEnvelopesSaved => 'Variable budget saved';

  @override
  String get soloEnvelopesConfigure => 'Set up';

  @override
  String get soloEnvelopesConfigureHint =>
      'Reserve part of your solo pot per category, suggested from your averages.';

  @override
  String get soloEnvelopesReserved => 'Reserved';

  @override
  String get soloEnvelopesFree => 'Free to spend';

  @override
  String get soloEnvelopesReservedShort => 'Res.';

  @override
  String get soloEnvelopesFreeShort => 'Free';

  @override
  String get commonEnvelopesTitle => 'Variable budget (shared)';

  @override
  String get commonEnvelopesIntro =>
      'Break the shared pot down by category. \"Reserved\" is what still has to go out this month; \"Free\" is what is genuinely left for shared variable spending. Suggested amounts come from your 3-month averages.';

  @override
  String get commonEnvelopesConfigureHint =>
      'Break the shared pot down by category to see what is genuinely free.';

  @override
  String get spendingByCategoryHint =>
      'Tap a category to see and fix its transactions.';

  @override
  String get categoryTxEmpty =>
      'No transactions in this category for this period.';

  @override
  String categoryTxTotal(String amount) {
    return 'Total: $amount';
  }

  @override
  String get categoryTxChange => 'Change category';

  @override
  String get categoryTxPickTitle => 'Pick a category';

  @override
  String get categoryTxUpdated => 'Category updated';

  @override
  String get categoryTxError => 'Update failed.';

  @override
  String get checkingBalanceLabel => 'Real chequing balance';

  @override
  String get checkingBalanceShort => 'Account';

  @override
  String get checkingBalanceJointShort => 'Joint';

  @override
  String get checkingBalancePrivate => 'Private';

  @override
  String get checkingBalancePrivateHint =>
      'Your partner\'s personal account balance stays private, just as yours does from them.';

  @override
  String get bankReauthNeeded => 'A bank needs to be reconnected';

  @override
  String bankReauthNeededNamed(String institution) {
    return '$institution: reconnection required';
  }

  @override
  String get bankReconnect => 'Reconnect';

  @override
  String get bankReconnecting => 'Reconnecting…';

  @override
  String get bankReconnected => 'Bank reconnected';

  @override
  String get bankReauthDialogBody =>
      'Your bank cut access after a period of inactivity (normal). Reconnect it to refresh your balances and transactions.';

  @override
  String get later => 'Later';

  @override
  String get ruleAlwaysSort => 'Always sort this merchant…';

  @override
  String rulePickTitle(String merchant) {
    return 'Always sort “$merchant”';
  }

  @override
  String ruleCreated(String merchant, String count) {
    return 'Rule created for “$merchant” · $count sorted';
  }

  @override
  String get ruleError => 'Couldn\'t create the rule.';

  @override
  String get sortRulesTitle => 'Sorting rules';

  @override
  String get sortRulesSubtitle => 'Automatically sort certain merchants';

  @override
  String get sortRulesEmpty =>
      'No rules yet. In the sort queue, open a transaction\'s ⋮ menu, then “Always sort this merchant”.';

  @override
  String get ruleDeleted => 'Rule deleted';
}
