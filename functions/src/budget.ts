import * as functions from "firebase-functions/v1";
import { db } from "./init";
import { requireAuth, enforceRateLimit } from "./security";

/**
 * Réglages de budget personnels (par siège A/B).
 *
 * Écrits par callable (Admin SDK) plutôt qu'en direct : ce sont des champs du
 * foyer, et on veut valider + router vers le bon siège côté serveur.
 */

async function seatOfCaller(
  uid: string
): Promise<{ householdId: string; seat: "A" | "B" }> {
  const userSnap = await db.collection("users").doc(uid).get();
  const householdId = userSnap.data()?.household_id as string | undefined;
  if (!householdId) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Vous ne faites partie d'aucun foyer."
    );
  }
  const hh = (await db.collection("households").doc(householdId).get()).data();
  const userAId = hh?.user_A_id ?? hh?.created_by;
  return { householdId, seat: uid === userAId ? "A" : "B" };
}

/** Fixe l'objectif d'investissement mensuel de l'appelant (thermomètre). */
export const setInvestmentGoal = functions.https.onCall(
  async (data, context) => {
    const uid = requireAuth(context);
    await enforceRateLimit("setInvestmentGoal", uid, 30, 3600);

    const amount = Number(data?.amount);
    if (!Number.isFinite(amount) || amount < 0 || amount > 1000000) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Objectif invalide."
      );
    }

    const { householdId, seat } = await seatOfCaller(uid);
    await db
      .collection("households")
      .doc(householdId)
      .set({ [`investment_goal_${seat}`]: amount }, { merge: true });

    return { success: true };
  }
);
