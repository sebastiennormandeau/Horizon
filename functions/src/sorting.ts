import * as functions from "firebase-functions/v1";
import { db } from "./init";
import { requireAuth, enforceRateLimit, assertString } from "./security";

/**
 * Règles de classement automatique par marchand.
 *
 * Une règle associe un marchand (normalisé en minuscules) à une cagnotte :
 * les prochaines transactions de ce marchand se classent seules à l'import
 * (voir `sortRules` dans `syncTransactionsForItem`), et les transactions déjà
 * en file du même marchand sont classées immédiatement.
 *
 * Stockées dans `households/{id}.sort_rules` (carte marchand → cagnotte),
 * écrites uniquement par ces callables (Admin SDK) — jamais par le client.
 */

const VALID_RULE_BUCKETS = [
  "Common",
  "Solo_A",
  "Solo_B",
  "Transfer",
  "Archived",
];

async function householdIdOf(uid: string): Promise<string> {
  const userSnap = await db.collection("users").doc(uid).get();
  const householdId = userSnap.data()?.household_id as string | undefined;
  if (!householdId) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Vous ne faites partie d'aucun foyer."
    );
  }
  return householdId;
}

/** Clé de règle : marchand en minuscules, espaces normalisés. */
function ruleKey(merchant: string): string {
  return merchant.toLowerCase().trim().replace(/\s+/g, " ");
}

/**
 * Crée (ou remplace) une règle marchand → cagnotte et l'applique aux
 * transactions non triées de ce marchand déjà présentes.
 */
export const setSortRule = functions.https.onCall(async (data, context) => {
  const uid = requireAuth(context);
  await enforceRateLimit("setSortRule", uid, 40, 3600);

  const merchant = assertString(data?.merchant, "merchant", { maxLength: 140 });
  const bucket = assertString(data?.bucket, "bucket", { maxLength: 16 });
  if (!VALID_RULE_BUCKETS.includes(bucket)) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Cagnotte de règle invalide."
    );
  }
  const key = ruleKey(merchant);
  if (!key) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Marchand vide."
    );
  }

  const householdId = await householdIdOf(uid);
  await db
    .collection("households")
    .doc(householdId)
    .set({ sort_rules: { [key]: bucket } }, { merge: true });

  // Applique aux transactions encore en file de ce marchand. Passer de « » à
  // une cagnotte déclenche `onTransactionAssigned`, qui met à jour les pots.
  const snap = await db
    .collection("transactions")
    .where("household_id", "==", householdId)
    .where("assigned_to_bucket", "==", "")
    .get();
  const matching = snap.docs.filter(
    (d) => ruleKey((d.data().merchant_name as string) || "") === key
  );

  const chunk = 400; // limite Firestore : 500 écritures par lot
  for (let i = 0; i < matching.length; i += chunk) {
    const batch = db.batch();
    matching
      .slice(i, i + chunk)
      .forEach((d) => batch.update(d.ref, { assigned_to_bucket: bucket }));
    await batch.commit();
  }

  return { success: true, applied: matching.length };
});

/** Supprime une règle. Les transactions déjà classées ne sont pas touchées. */
export const deleteSortRule = functions.https.onCall(async (data, context) => {
  const uid = requireAuth(context);
  await enforceRateLimit("deleteSortRule", uid, 40, 3600);

  const merchant = assertString(data?.merchant, "merchant", { maxLength: 140 });
  const key = ruleKey(merchant);
  const householdId = await householdIdOf(uid);

  // Lecture-modification-écriture plutôt qu'un chemin de champ « sort_rules.X »
  // : un marchand peut contenir un point (« Amazon.ca ») que Firestore
  // interpréterait comme un champ imbriqué.
  const ref = db.collection("households").doc(householdId);
  const rules = {
    ...((await ref.get()).data()?.sort_rules ?? {}),
  } as Record<string, string>;
  delete rules[key];
  await ref.update({ sort_rules: rules });

  return { success: true };
});
