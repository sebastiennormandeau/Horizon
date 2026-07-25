#!/usr/bin/env node
/**
 * Supprime les transactions orphelines : celles dont l'`item_id` ne correspond
 * à AUCUNE connexion bancaire vivante. Elles restent quand une banque est
 * déconnectée puis reconnectée (l'ancien item disparaît, ses transactions non).
 * Reconnecter réimporte les mêmes achats sous de nouveaux identifiants → des
 * doublons à trier. (La cause racine est corrigée dans removeBankConnection.)
 *
 * Effet grand-livre : une orpheline dans un VRAI pot (Solo_A/Solo_B/Common) a
 * déjà agi sur les cagnottes. On renverse cet effet — addition pure, donc
 * `FieldValue.increment`, sans course avec le déclencheur — avant de supprimer.
 * Les orphelines "", Transfer et Archived sont neutres : suppression directe.
 *
 * Comme les autres scripts d'administration, tourne en local avec les
 * identifiants Google admin, jamais déployé. Prérequis :
 *   gcloud auth application-default login
 *
 * Usage :
 *   node scripts/cleanup-orphan-transactions.js            # simulation
 *   node scripts/cleanup-orphan-transactions.js --apply    # applique
 */
const { initializeApp, applicationDefault } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");

const REAL_BUCKETS = new Set(["Solo_A", "Solo_B", "Common"]);
const apply = process.argv.includes("--apply");

initializeApp({ credential: applicationDefault(), projectId: "horizon-dbba0" });
const db = getFirestore();

(async () => {
  const conns = await db.collection("bank_connections").get();
  const liveItems = new Set(conns.docs.map((d) => d.id));

  const tx = await db.collection("transactions").get();
  const orphans = tx.docs.filter((d) => {
    const item = d.data().item_id;
    return item && !liveItems.has(item);
  });

  if (orphans.length === 0) {
    console.log("Aucune transaction orpheline. Rien à faire.");
    return;
  }

  // Renversement grand-livre agrégé par foyer, pour les orphelines déjà triées.
  // deltas[householdId] = { common, soloA, soloB, debt }
  const deltas = {};
  const hhCache = {};
  const getHousehold = async (id) => {
    if (!hhCache[id]) hhCache[id] = (await db.collection("households").doc(id).get()).data() || {};
    return hhCache[id];
  };

  let realPot = 0;
  for (const doc of orphans) {
    const t = doc.data();
    const bucket = t.assigned_to_bucket ?? "";
    if (!REAL_BUCKETS.has(bucket)) continue;
    realPot++;
    const hid = t.household_id;
    const hh = await getHousehold(hid);
    const amount = typeof t.amount === "number" ? t.amount : 0;
    const d = (deltas[hid] ??= { common: 0, soloA: 0, soloB: 0, debt: 0 });

    if (bucket === "Common") {
      d.common += amount;
      const isJoint = t.is_joint_account === true;
      if (!isJoint) {
        const userAId = hh.user_A_id ?? hh.created_by;
        const isUserA = t.paid_by_user_id === userAId;
        const ratioA = (hh.split_ratio_user_A ?? 50) / 100;
        const ratioB = (hh.split_ratio_user_B ?? 50) / 100;
        // Renverse apply("Common", +1) : debt -= (isUserA ? amount*ratioB : -(amount*ratioA))
        d.debt -= isUserA ? amount * ratioB : -(amount * ratioA);
      }
    } else if (bucket === "Solo_A") {
      d.soloA += amount;
    } else if (bucket === "Solo_B") {
      d.soloB += amount;
    }
  }

  console.log(`Transactions orphelines : ${orphans.length}`);
  console.log(`  dont déjà triées dans un vrai pot : ${realPot}`);
  console.log(`\nRenversement grand-livre par foyer :`);
  for (const [hid, d] of Object.entries(deltas)) {
    console.log(
      `  ${hid} : common +${d.common.toFixed(2)}  soloA +${d.soloA.toFixed(2)}  soloB +${d.soloB.toFixed(2)}  debt ${d.debt >= 0 ? "+" : ""}${d.debt.toFixed(2)}`
    );
  }

  if (!apply) {
    console.log("\n(simulation — relancer avec --apply pour exécuter)");
    return;
  }

  // 1. Renversement grand-livre (incréments atomiques, avant suppression).
  for (const [hid, d] of Object.entries(deltas)) {
    await db.collection("households").doc(hid).update({
      safe_to_spend_common: FieldValue.increment(d.common),
      safe_to_spend_solo_A: FieldValue.increment(d.soloA),
      safe_to_spend_solo_B: FieldValue.increment(d.soloB),
      internal_debt_balance: FieldValue.increment(d.debt),
      updated_at: FieldValue.serverTimestamp(),
    });
  }

  // 2. Suppression de toutes les orphelines, par lots.
  const chunk = 400;
  for (let i = 0; i < orphans.length; i += chunk) {
    const batch = db.batch();
    orphans.slice(i, i + chunk).forEach((d) => batch.delete(d.ref));
    await batch.commit();
  }

  console.log(`\n✅ ${orphans.length} orphelines supprimées, grand-livre renversé.`);
})();
