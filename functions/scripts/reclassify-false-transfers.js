#!/usr/bin/env node
/**
 * Renvoie dans la file de tri les transactions faussement classées
 * « virement interne ».
 *
 * Pourquoi ce script existe : `TRANSFER_OUT_ACCOUNT_TRANSFER` /
 * `TRANSFER_IN_ACCOUNT_TRANSFER` étaient traitées comme internes d'office
 * (voir `INTERNAL_TRANSFER_DETAILED` dans src/plaid.ts). Or Plaid range sous
 * cette étiquette les prélèvements préautorisés vers un TIERS — assurances,
 * hypothèque, prêt — et les virements Interac à une personne. Résultat : de
 * vraies dépenses fixes n'entamaient jamais la cagnotte Commune, qui restait
 * anormalement haute en fin de mois.
 *
 * Le tri est refait avec le même critère que l'import corrigé : est interne
 * ce dont le libellé cite le numéro d'un compte relié du foyer
 * (`mentionsOwnAccount`). Tout le reste retourne « à trier » (`""`).
 *
 * Effet sur le grand livre : `Transfer` et `""` sont tous deux absents de
 * `VALID_BUCKETS`, le passage de l'un à l'autre est donc neutre — aucune
 * cagnotte n'est touchée par ce script. Ce sont les tris manuels qui
 * suivront qui débiteront la cagnotte Commune, comme il se doit.
 *
 * Comme mfa-admin.js, tourne en local avec les identifiants Google
 * administrateur et n'est jamais déployé (exclusion `scripts` dans
 * firebase.json). Prérequis : `gcloud auth application-default login`.
 *
 * Usage :
 *   node scripts/reclassify-false-transfers.js            # simulation
 *   node scripts/reclassify-false-transfers.js --apply    # applique
 */
const { initializeApp, applicationDefault } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");

// Catégories jadis considérées comme internes d'office, désormais soumises à
// la vérification du libellé. Doit rester synchronisé avec src/plaid.ts.
const RECHECK_DETAILED = new Set([
  "TRANSFER_OUT_ACCOUNT_TRANSFER",
  "TRANSFER_IN_ACCOUNT_TRANSFER",
]);

const TRANSFER_BUCKET = "Transfer";
const BATCH_SIZE = 400;

const apply = process.argv.includes("--apply");

initializeApp({ credential: applicationDefault(), projectId: "horizon-dbba0" });
const db = getFirestore();

/** Copie de `mentionsOwnAccount` (src/plaid.ts) : le libellé cite-t-il le
 *  numéro d'un compte relié du foyer ? */
function mentionsOwnAccount(name, masks) {
  if (!name || masks.length === 0) return false;
  const runs = name.match(/\d{6,}/g);
  if (!runs) return false;
  return runs.some((run) => masks.some((m) => run.endsWith(m)));
}

(async () => {
  // Masques des comptes reliés, par foyer.
  const conns = await db.collection("bank_connections").get();
  const masksByHousehold = new Map();
  conns.docs.forEach((c) => {
    const d = c.data();
    if (!d.household_id) return;
    const set = masksByHousehold.get(d.household_id) ?? new Set();
    (d.accounts ?? []).forEach((a) => a.mask && set.add(a.mask));
    masksByHousehold.set(d.household_id, set);
  });

  const snap = await db.collection("transactions").get();

  const todo = [];
  for (const doc of snap.docs) {
    const t = doc.data();
    if (t.assigned_to_bucket !== TRANSFER_BUCKET) continue;
    if (!RECHECK_DETAILED.has(t.category_detailed)) continue;

    const masks = [...(masksByHousehold.get(t.household_id) ?? [])];
    const label = t.merchant_name;
    if (mentionsOwnAccount(label, masks)) continue; // vraiment interne

    todo.push({
      ref: doc.ref,
      amount: typeof t.amount === "number" ? t.amount : 0,
      merchant: label,
      date: t.date,
    });
  }

  // Regroupe par libellé pour une lecture compacte.
  const byLabel = new Map();
  todo.forEach((t) => {
    const e = byLabel.get(t.merchant) ?? { n: 0, sum: 0 };
    e.n += 1;
    e.sum += t.amount;
    byLabel.set(t.merchant, e);
  });

  const outflow = todo.reduce((a, t) => a + Math.max(t.amount, 0), 0);
  console.log(`Transactions examinées : ${snap.size}`);
  console.log(`Faussement « internes », renvoyées au tri : ${todo.length}`);
  console.log(`  dont sorties d'argent (vraies dépenses) : ${outflow.toFixed(2)} $`);
  console.log("\nPar libellé :");
  [...byLabel.entries()]
    .sort((a, b) => Math.abs(b[1].sum) - Math.abs(a[1].sum))
    .forEach(([k, v]) =>
      console.log(`  x${String(v.n).padEnd(3)} ${v.sum.toFixed(2).padStart(10)} $  ${k}`)
    );

  if (!apply) {
    console.log("\nSimulation. Relancer avec --apply pour appliquer.");
    process.exit(0);
  }

  for (let i = 0; i < todo.length; i += BATCH_SIZE) {
    const batch = db.batch();
    todo
      .slice(i, i + BATCH_SIZE)
      .forEach((t) => batch.update(t.ref, { assigned_to_bucket: "" }));
    await batch.commit();
  }
  console.log(`\n${todo.length} transaction(s) renvoyée(s) dans la file de tri.`);
  process.exit(0);
})().catch((e) => {
  console.error("Échec :", e.message);
  process.exit(1);
});
