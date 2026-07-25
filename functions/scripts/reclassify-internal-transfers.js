#!/usr/bin/env node
/**
 * Reclasse en « Transfer » les transactions DÉJÀ importées qui sont des
 * mouvements entre comptes du foyer, reconnus au libellé (le numéro du compte
 * contrepartie se termine par le masque d'un compte connecté).
 *
 * Pourquoi : la détection par catégorie Plaid (`isInternalTransfer`) rate les
 * virements chèque↔épargne étiquetés `TRANSFER_*_OTHER_*`, `TRANSFER_OUT_SAVINGS`
 * ou même `LOAN_PAYMENTS_CAR_PAYMENT` (« prêt auto » vers son épargne). La
 * détection au libellé (`mentionsOwnAccount`, ajoutée à src/plaid.ts) ne
 * s'applique qu'aux NOUVELLES transactions ; ce script rattrape les anciennes.
 *
 * Grand livre : passer de "" ou "Archived" à "Transfer" est neutre. Passer d'un
 * VRAI pot (Common/Solo_*) à "Transfer" déclenche `onTransactionAssigned`, qui
 * RENVERSE lui-même l'effet — donc surtout PAS de renversement manuel ici,
 * sous peine de le compter deux fois.
 *
 * Local, identifiants Google admin, jamais déployé. Prérequis :
 *   gcloud auth application-default login
 *
 * Usage :
 *   node scripts/reclassify-internal-transfers.js            # simulation
 *   node scripts/reclassify-internal-transfers.js --apply    # applique
 */
const { initializeApp, applicationDefault } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");

const TRANSFER = "Transfer";
const REAL = new Set(["Solo_A", "Solo_B", "Common"]);
const apply = process.argv.includes("--apply");

initializeApp({ credential: applicationDefault(), projectId: "horizon-dbba0" });
const db = getFirestore();

// Doit rester synchronisé avec mentionsOwnAccount dans src/plaid.ts.
function mentionsOwnAccount(name, masks) {
  if (!name || masks.length === 0) return false;
  const runs = String(name).match(/\d{6,}/g);
  if (!runs) return false;
  return runs.some((run) => masks.some((m) => run.endsWith(m)));
}

(async () => {
  const conns = await db.collection("bank_connections").get();
  const masksByHousehold = {};
  conns.forEach((d) => {
    const c = d.data();
    const set = (masksByHousehold[c.household_id] ??= new Set());
    for (const a of c.accounts ?? []) if (a.mask) set.add(a.mask);
  });

  const tx = await db.collection("transactions").get();
  const todo = [];
  for (const doc of tx.docs) {
    const t = doc.data();
    if (t.assigned_to_bucket === TRANSFER) continue; // déjà bon
    const masks = [...(masksByHousehold[t.household_id] ?? [])];
    if (mentionsOwnAccount(t.merchant_name, masks)) {
      todo.push({ ref: doc.ref, t });
    }
  }

  if (todo.length === 0) {
    console.log("Aucun mouvement interne à reclasser.");
    return;
  }

  const byBucket = {};
  let realPot = 0;
  for (const { t } of todo) {
    const b = t.assigned_to_bucket || "";
    byBucket[b] = (byBucket[b] ?? 0) + 1;
    if (REAL.has(b)) realPot++;
  }

  console.log(`Mouvements internes à reclasser en Transfer : ${todo.length}`);
  console.log("Par bucket actuel :", byBucket);
  console.log(
    `Déjà triées dans un vrai pot (le déclencheur renversera l'effet) : ${realPot}`
  );
  console.log("\nÉchantillon :");
  todo.slice(0, 25).forEach(({ t }) =>
    console.log(
      `  ${t.date}  ${t.amount}$  "${t.assigned_to_bucket}"  « ${t.merchant_name} »`
    )
  );

  if (!apply) {
    console.log("\n(simulation — relancer avec --apply pour exécuter)");
    return;
  }

  // Simple mise à jour du bucket : le déclencheur onTransactionAssigned
  // renverse tout effet grand-livre des transactions déjà triées.
  const chunk = 400;
  for (let i = 0; i < todo.length; i += chunk) {
    const batch = db.batch();
    todo
      .slice(i, i + chunk)
      .forEach(({ ref }) => batch.update(ref, { assigned_to_bucket: TRANSFER }));
    await batch.commit();
  }

  console.log(`\n✅ ${todo.length} transactions reclassées en Transfer.`);
})();
