#!/usr/bin/env node
/**
 * Reclasse en « Transfert interne » les transactions déjà importées qui sont
 * des mouvements entre comptes du foyer.
 *
 * Pourquoi ce script existe : la détection automatique (voir
 * `isInternalTransfer` dans src/plaid.ts) ne s'applique qu'à l'import. Les
 * transactions rapatriées AVANT sa mise en place sont restées classables, et
 * un paiement de carte de crédit trié dans une cagnotte compte une seconde
 * fois une dépense déjà comptée à l'achat.
 *
 * Effet sur le grand livre : `Transfer` n'appartient pas à `VALID_BUCKETS`,
 * donc passer de `""` à `Transfer` est neutre. Passer d'une vraie cagnotte à
 * `Transfer` déclenche le renversement de son effet, ce qui est le résultat
 * recherché.
 *
 * Comme mfa-admin.js, ce script tourne en local avec les identifiants
 * Google administrateur et n'est jamais déployé (exclusion `scripts` dans
 * firebase.json). Prérequis : `gcloud auth application-default login`.
 *
 * Usage :
 *   node scripts/reclassify-transfers.js            # simulation (par défaut)
 *   node scripts/reclassify-transfers.js --apply    # applique réellement
 */
const { initializeApp, applicationDefault } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");

// Doit rester synchronisé avec INTERNAL_TRANSFER_DETAILED dans src/plaid.ts.
const INTERNAL_TRANSFER_DETAILED = new Set([
  "LOAN_PAYMENTS_CREDIT_CARD_PAYMENT",
  "TRANSFER_OUT_ACCOUNT_TRANSFER",
  "TRANSFER_IN_ACCOUNT_TRANSFER",
]);

// Paye régulière : déjà comptée dans le budget, la glisser vers une cagnotte
// la financerait une seconde fois. Restreint au salaire — les autres entrées
// (pige, remboursement, cadeau) ne sont pas budgétées et restent à classer.
const PAYROLL_DETAILED = new Set(["INCOME_WAGES", "INCOME_SALARY"]);

const TRANSFER_BUCKET = "Transfer";
const ARCHIVED_BUCKET = "Archived";
const BATCH_SIZE = 400; // limite Firestore : 500 écritures par lot

const apply = process.argv.includes("--apply");

initializeApp({ credential: applicationDefault(), projectId: "horizon-dbba0" });
const db = getFirestore();

(async () => {
  const snap = await db.collection("transactions").get();

  const todo = [];
  for (const doc of snap.docs) {
    const t = doc.data();
    const isTransfer = INTERNAL_TRANSFER_DETAILED.has(t.category_detailed);
    const isPayroll = PAYROLL_DETAILED.has(t.category_detailed);
    if (!isTransfer && !isPayroll) continue;
    const target = isTransfer ? TRANSFER_BUCKET : ARCHIVED_BUCKET;
    if (t.assigned_to_bucket === target) continue;
    todo.push({
      ref: doc.ref,
      target,
      from: t.assigned_to_bucket === "" ? "(à trier)" : t.assigned_to_bucket,
      amount: typeof t.amount === "number" ? t.amount : 0,
      merchant: t.merchant_name,
      date: t.date,
    });
  }

  const total = todo.reduce((acc, t) => acc + Math.max(t.amount, 0), 0);
  const fromSorted = todo.filter((t) => t.from !== "(à trier)");

  console.log(`Transactions examinées : ${snap.size}`);
  console.log(`À reclasser (transfert interne ou paye) : ${todo.length}`);
  console.log(`  dont déjà triées dans une cagnotte : ${fromSorted.length}`);
  console.log(`  montant total retiré des dépenses : ${total.toFixed(2)} $`);

  if (fromSorted.length > 0) {
    console.log("\nCelles-ci verront leur effet sur les cagnottes annulé :");
    fromSorted.forEach((t) =>
      console.log(`  ${t.date}  ${t.amount.toFixed(2)} $  ${t.from}  ${t.merchant}`)
    );
  }

  if (!apply) {
    console.log("\nSimulation. Relancer avec --apply pour appliquer.");
    process.exit(0);
  }

  for (let i = 0; i < todo.length; i += BATCH_SIZE) {
    const batch = db.batch();
    todo
      .slice(i, i + BATCH_SIZE)
      .forEach((t) => batch.update(t.ref, { assigned_to_bucket: t.target }));
    await batch.commit();
  }
  console.log(`\n${todo.length} transaction(s) reclassée(s).`);
  process.exit(0);
})().catch((e) => {
  console.error("Échec :", e.message);
  process.exit(1);
});
