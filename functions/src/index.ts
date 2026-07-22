/**
 * Horizon — Cloud Functions
 *
 * Modules :
 *  - plaid.ts      : connexion bancaire, synchronisation, webhook signé
 *  - ledger.ts     : cagnottes/dette interne, règlement de dette
 *  - households.ts : création et adhésion aux foyers
 *  - membership.ts : transitions solo↔couple, séparation, remise à zéro
 *  - account.ts    : suppression de compte et export de données (Loi 25)
 *  - billing.ts    : webhook RevenueCat, rollover budgétaire mensuel
 *  - security.ts   : authentification, rate limiting, validation d'entrées
 */
export {
  generatePlaidLinkToken,
  exchangePublicToken,
  plaidWebhookHandler,
  listBankConnections,
  removeBankConnection,
  syncBankConnections,
  archivePastTransactions,
  setBankConnectionJoint,
} from "./plaid";
export { onTransactionAssigned, settleDebt } from "./ledger";
export { createHousehold, joinHousehold } from "./households";
export {
  enableCoupleMode,
  revertToSolo,
  leaveHousehold,
  resetHouseholdData,
} from "./membership";
export { deleteAccount, exportMyData } from "./account";
export { revenueCatWebhook, monthlyRollover } from "./billing";
export { generateReport, addRecurringToBudget, weeklyReports } from "./reports";
export { generateCoachAdvice, generateTransitionAdvice } from "./coach";
