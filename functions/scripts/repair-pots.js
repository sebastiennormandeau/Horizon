#!/usr/bin/env node
/**
 * Recalcule les cagnottes du mois courant à partir du budget et des seules
 * dépenses DU MOIS COURANT.
 *
 * Pourquoi ce script existe : `onTransactionAssigned` ponctionnait la cagnotte
 * courante quelle que soit la DATE de la transaction. Trier au début d'un mois
 * les transactions du mois précédent (celles restées en file) vidait donc la
 * provision fraîchement posée par `monthlyRollover` pour des factures déjà
 * payées le mois d'avant. Le déclencheur ignore désormais les transactions
 * d'un mois révolu ; ce script répare les soldes déjà faussés.
 *
 * Recalcul (identique à `monthlyRollover`, moins les dépenses du mois) :
 *   provision commune = Σ dépenses fixes − Σ déductions
 *   cagnotte solo X   = revenu X − contribution X (selon le ratio de partage)
 *   puis on retranche les transactions du mois courant déjà classées.
 *
 * La dette interne n'est PAS touchée : c'est un cumul qui traverse les mois,
 * et seul `settleDebt` doit y toucher.
 *
 * Comme mfa-admin.js, tourne en local avec les identifiants Google
 * administrateur et n'est jamais déployé (exclusion `scripts` dans
 * firebase.json). Prérequis : `gcloud auth application-default login`.
 *
 * Usage :
 *   node scripts/repair-pots.js            # simulation
 *   node scripts/repair-pots.js --apply    # applique
 */
const { initializeApp, applicationDefault } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");

const VALID_BUCKETS = ["Common", "Solo_A", "Solo_B"];
const apply = process.argv.includes("--apply");

initializeApp({ credential: applicationDefault(), projectId: "horizon-dbba0" });
const db = getFirestore();

const sum = (items) =>
  Array.isArray(items)
    ? items.reduce(
        (acc, i) => acc + (typeof i?.amount === "number" ? i.amount : 0),
        0
      )
    : 0;

(async () => {
  const now = new Date();
  const monthId = `${now.getUTCFullYear()}-${String(
    now.getUTCMonth() + 1
  ).padStart(2, "0")}`;
  const monthStart = `${monthId}-01`;
  console.log(`Mois courant : ${monthId} (depuis ${monthStart})\n`);

  const households = await db.collection("households").get();

  for (const h of households.docs) {
    const hd = h.data();
    const budgetSnap = await h.ref
      .collection("monthly_budgets")
      .doc(monthId)
      .get();
    if (!budgetSnap.exists) continue;
    const b = budgetSnap.data();

    const net = sum(b.fixed_expenses) - sum(b.deductions);
    const ratioA = b.split_ratio_A ?? 50;
    const provisionA = (b.income_A ?? 0) - net * (ratioA / 100);
    const provisionB = (b.income_B ?? 0) - net * ((100 - ratioA) / 100);

    // Dépenses DU MOIS COURANT déjà classées dans une vraie cagnotte.
    const txs = await db
      .collection("transactions")
      .where("household_id", "==", h.id)
      .where("date", ">=", monthStart)
      .orderBy("date", "desc")
      .get();

    const spent = { Common: 0, Solo_A: 0, Solo_B: 0 };
    txs.forEach((d) => {
      const t = d.data();
      const bucket = t.assigned_to_bucket;
      if (!VALID_BUCKETS.includes(bucket)) return;
      const a = typeof t.amount === "number" ? t.amount : 0;
      spent[bucket] += a;
    });

    const target = {
      safe_to_spend_common: net - spent.Common,
      safe_to_spend_solo_A: provisionA - spent.Solo_A,
      safe_to_spend_solo_B: provisionB - spent.Solo_B,
    };

    const current = {
      safe_to_spend_common: hd.safe_to_spend_common ?? 0,
      safe_to_spend_solo_A: hd.safe_to_spend_solo_A ?? 0,
      safe_to_spend_solo_B: hd.safe_to_spend_solo_B ?? 0,
    };

    const drift = Object.keys(target).some(
      (k) => Math.abs(target[k] - current[k]) > 0.01
    );
    if (!drift) continue;

    console.log(`Foyer ${h.id}`);
    for (const k of Object.keys(target)) {
      console.log(
        `  ${k.padEnd(24)} ${current[k].toFixed(2).padStart(10)} → ${target[k]
          .toFixed(2)
          .padStart(10)}`
      );
    }
    console.log(
      `  (provision commune ${net.toFixed(2)} − dépenses du mois ${spent.Common.toFixed(2)})\n`
    );

    if (apply) {
      await h.ref.update(target);
    }
  }

  console.log(
    apply ? "Cagnottes recalculées." : "Simulation. Relancer avec --apply."
  );
  process.exit(0);
})().catch((e) => {
  console.error("Échec :", e.message);
  process.exit(1);
});
