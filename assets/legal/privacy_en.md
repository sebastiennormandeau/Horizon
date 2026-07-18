# Privacy Policy

Last updated: July 18, 2026

> [!NOTE]
> This English version is provided as a courtesy translation. In case of any
> discrepancy or dispute, the French version ("Politique de Confidentialité")
> shall prevail.

**Vibe Coding Mind** (the "Studio", "We") places great importance on the privacy of its users. This Privacy Policy describes how the **Horizon** application collects, uses, and protects your personal data, in strict compliance with North American standards, including **Quebec's Law 25**.

## 1. Data Collected

### A. Identification and Account Data
To create your account or a Household, we collect:
- Your email address (encrypted and secured by Firebase Authentication).
- An alphanumeric household code (to link partner accounts).

### B. Financial Data (Read-only)
When you connect your bank, we use a trusted provider (Plaid). **We NEVER store your banking credentials.**
We collect and store (on Firebase Firestore):
- The transaction name, amount, and date.
- Secure access "tokens" allowing us to refresh your transaction list.

### C. Usage Data
We use **Google Analytics** and **Firebase Crashlytics** to detect bugs (crashes) and understand general application usage in an anonymized way.

## 2. Use of Data

Your data is used exclusively to:
- Provide the application's core service (the Zero-Based budgeting engine).
- Synchronize transactions across your devices and your partner's (within the "Shared Household").
- Process the Premium subscription through our partner **RevenueCat**.
- Secure access through **Firebase App Check**.

**We do NOT sell any personal or financial data to third parties.**

## 3. Third-Party Providers

To operate, the application relies on the infrastructure of certified, highly secure third parties:
- **Google Firebase (Firestore, Auth, Functions)**: primary cloud hosting of the data.
- **Plaid Inc.**: secure banking aggregator. By linking your bank, you also accept Plaid's privacy policy (available at plaid.com/legal).
- **RevenueCat**: subscription and in-app purchase management.
- **Anthropic** ("AI budget coach" feature, on demand only): when you request advice generation, **anonymized aggregates** of your review (totals by category, trends, merchant names, pot balances, and aggregated budget figures such as total income, fixed expenses, and category envelope targets) are sent to Anthropic's Claude API to write the suggestions. **No personal identifier, no authentication data, and no raw banking transaction is transmitted.** The generated advice is provided for informational purposes only and **does not constitute professional financial advice**.

## 4. Security and Retention (Law 25 Compliance)

In accordance with Quebec's Law 25:
- **Security**: your data is encrypted in transit (HTTPS) and at rest by Google's servers. Database access is restricted by strict Security Rules (your account can only read the data of its own household).
- **Retention**: your transactional and budget data is retained as long as your account is active.
- **Right to erasure**: you have the right to request the complete deletion of your data. This request will delete your account, the Plaid connection tokens, and all associated transactions from our servers.

## 5. Data Protection Officer Contact

If you have questions about your personal data or wish to exercise your rights, you can contact our privacy officer at: [Support Email Address].
