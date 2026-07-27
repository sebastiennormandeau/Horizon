#!/usr/bin/env node
/**
 * Rattrape les virements d'investissement déjà importés (courtage/REER).
 *
 * - Marque `is_investment: true` sur toute transaction dont la catégorie
 *   détaillée est TRANSFER_OUT_INVESTMENT_AND_RETIREMENT_FUNDS (le bilan les
 *   exclut alors des dépenses, et le compteur « Investi » les additionne).
 * - Reclasse celles du MOIS COURANT (en file « » ou Archived) dans la cagnotte
 *   solo du payeur : passer à Solo_A/Solo_B déclenche onTransactionAssigned,
 *   qui vide la cagnotte solo (l'argent investi n'est plus « à dépenser »).
 *   Les mois révolus restent Archived : ils ne concernent pas le pot courant.
 *
 * Usage :
 *   node scripts/backfill-investments.js            # simulation
 *   node scripts/backfill-investments.js --apply    # applique
 */
const { initializeApp, applicationDefault } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");

const INVESTMENT_DETAILED = "TRANSFER_OUT_INVESTMENT_AND_RETIREMENT_FUNDS";
const apply = process.argv.includes("--apply");

initializeApp({ credential: applicationDefault(), projectId: "horizon-dbba0" });
const db = getFirestore();

function startOfMonth() {
  const n = new Date();
  return `${n.getFullYear()}-${String(n.getMonth() + 1).padStart(2, "0")}-01`;
}

(async () => {
  // Siège A de chaque foyer, pour router vers Solo_A / Solo_B.
  const hhs = await db.collection("households").get();
  const userAOf = {};
  hhs.forEach((h) => {
    const d = h.data();
    userAOf[h.id] = d.user_A_id ?? d.created_by ?? null;
  });

  const tx = await db.collection("transactions").get();
  const invest = tx.docs.filter(
    (d) => d.data().category_detailed === INVESTMENT_DETAILED
  );

  const monthStart = startOfMonth();
  const toSolo = []; // mois courant, à reclasser dans le solo du payeur
  invest.forEach((d) => {
    const t = d.data();
    const bucket = t.assigned_to_bucket ?? "";
    const isCurrent = !!t.date && t.date >= monthStart;
    if (isCurrent && (bucket === "" || bucket === "Archived")) {
      const seatA = userAOf[t.household_id];
      const solo = t.paid_by_user_id === seatA ? "Solo_A" : "Solo_B";
      toSolo.push({ ref: d.ref, solo, amount: t.amount, date: t.date, m: t.merchant_name });
    }
  });

  console.log(`Virements d'investissement trouvés : ${invest.length}`);
  console.log(`  à marquer is_investment : ${invest.length}`);
  console.log(`  du mois courant à reclasser en solo : ${toSolo.length}`);
  toSolo.forEach((x) =>
    console.log(`    ${x.date}  ${x.amount}$ -> ${x.solo}  « ${x.m} »`)
  );

  if (!apply) {
    console.log("\n(simulation — relancer avec --apply)");
    return;
  }

  const chunk = 400;
  // 1. Marque is_investment partout.
  for (let i = 0; i < invest.length; i += chunk) {
    const batch = db.batch();
    invest
      .slice(i, i + chunk)
      .forEach((d) => batch.update(d.ref, { is_investment: true }));
    await batch.commit();
  }
  // 2. Reclasse le mois courant en solo (déclenche le grand livre).
  for (let i = 0; i < toSolo.length; i += chunk) {
    const batch = db.batch();
    toSolo
      .slice(i, i + chunk)
      .forEach((x) => batch.update(x.ref, { assigned_to_bucket: x.solo }));
    await batch.commit();
  }

  console.log(
    `\n✅ ${invest.length} marquées is_investment, ${toSolo.length} reclassées en solo.`
  );
})();
