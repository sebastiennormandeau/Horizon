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
  String get welcomeBody =>
      'The app is built around the Household. Do you want to create yours or join your partner?';

  @override
  String get createHouseholdButton => 'Create a new household';

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
}
