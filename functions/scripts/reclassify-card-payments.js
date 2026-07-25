#!/usr/bin/env node
/**
 * Reclasse en « Transfer » les paiements de carte DÉJÀ importés que Plaid a
 * étiquetés « revenu » à tort.
 *
 * Un dépôt sur un compte de CARTE de crédit est un paiement de carte (l'autre
 * côté du paiement qui sort du compte chèque), pas une entrée d'argent. Plaid
 * les classe souvent en `INCOME_CONTRACTOR`/`OTHER_OTHER`, et comme le libellé
 * (« PAYMENT THANK YOU / PAIEMENT MERCI ») ne cite aucun numéro de compte, ni
 * la catégorie ni `mentionsOwnAccount` ne les rattrapent.
 *
 * Cible sûre : entrée d'argent (montant < 0) SUR UN COMPTE CARTE (subcollection
 * `cards`) dont le libellé est un mémo de paiement. Un vrai paiement de client
 * reçu au compte chèque n'est jamais touché — il n'est pas sur un compte carte.
 *
 * Grand livre : "" ou "Archived" → "Transfer" est neutre ; un vrai pot →
 * "Transfer" déclenche `onTransactionAssigned` qui renverse l'effet lui-même
 * (donc aucun renversement manuel ici).
 *
 * Usage :
 *   node scripts/reclassify-card-payments.js            # simulation
 *   node scripts/reclassify-card-payments.js --apply    # applique
 */
const { initializeApp, applicationDefault } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");

const TRANSFER = "Transfer";
const apply = process.argv.includes("--apply");

initializeApp({ credential: applicationDefault(), projectId: "horizon-dbba0" });
const db = getFirestore();

// Doit rester synchronisé avec isCardPaymentMemo dans src/plaid.ts.
function isCardPaymentMemo(name) {
  if (!name) return false;
  const n = String(name).toLowerCase();
  const payment = n.includes("payment") || n.includes("paiement");
  const thanks = n.includes("thank you") || n.includes("merci");
  return payment && thanks;
}

(async () => {
  // Comptes de carte connus (subcollection cards de chaque foyer).
  const hhs = await db.collection("households").get();
  const cardAccts = new Set();
  for (const h of hhs.docs) {
    const cards = await h.ref.collection("cards").get();
    cards.forEach((c) => cardAccts.add(c.id));
  }

  const tx = await db.collection("transactions").get();
  const todo = tx.docs.filter((d) => {
    const t = d.data();
    return (
      t.assigned_to_bucket !== TRANSFER &&
      typeof t.amount === "number" &&
      t.amount < 0 &&
      cardAccts.has(t.account_id) &&
      isCardPaymentMemo(t.merchant_name)
    );
  });

  if (todo.length === 0) {
    console.log("Aucun paiement de carte mal classé.");
    return;
  }

  const byBucket = {};
  todo.forEach((d) => {
    const b = d.data().assigned_to_bucket || "";
    byBucket[b] = (byBucket[b] ?? 0) + 1;
  });

  console.log(`Comptes carte : ${[...cardAccts].length}`);
  console.log(`Paiements de carte à reclasser en Transfer : ${todo.length}`);
  console.log("Par bucket actuel :", byBucket);
  console.log("\nÉchantillon :");
  todo.slice(0, 20).forEach((d) => {
    const t = d.data();
    console.log(
      `  ${t.date}  +${Math.abs(t.amount)}$  "${t.assigned_to_bucket}"  detailed=${t.category_detailed}  « ${t.merchant_name} »`
    );
  });

  if (!apply) {
    console.log("\n(simulation — relancer avec --apply pour exécuter)");
    return;
  }

  const chunk = 400;
  for (let i = 0; i < todo.length; i += chunk) {
    const batch = db.batch();
    todo
      .slice(i, i + chunk)
      .forEach((d) => batch.update(d.ref, { assigned_to_bucket: TRANSFER }));
    await batch.commit();
  }

  console.log(`\n✅ ${todo.length} paiements de carte reclassés en Transfer.`);
})();
