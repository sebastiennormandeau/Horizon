import * as functions from "firebase-functions/v1";
import { db, FieldValue } from "./init";
import { requireAuth, enforceRateLimit } from "./security";

const VALID_BUCKETS = ["Common", "Solo_A", "Solo_B"];

/**
 * Met à jour les cagnottes du foyer quand une transaction change de bucket.
 * Gère aussi le retrait d'un bucket (undo) : l'ancien effet est annulé
 * avant d'appliquer le nouveau.
 */
export const onTransactionAssigned = functions.firestore
  .document("transactions/{transactionId}")
  .onUpdate(async (change) => {
    const before = change.before.data();
    const after = change.after.data();

    const beforeBucket: string = before.assigned_to_bucket ?? "";
    const afterBucket: string = after.assigned_to_bucket ?? "";
    if (beforeBucket === afterBucket) return;

    const amount = typeof after.amount === "number" ? after.amount : 0;
    const payerId: string | undefined = after.paid_by_user_id;
    const householdId: string | undefined = after.household_id;
    if (!payerId || !householdId || amount === 0) return;

    const householdRef = db.collection("households").doc(householdId);

    await db.runTransaction(async (tx) => {
      const householdSnap = await tx.get(householdRef);
      if (!householdSnap.exists) return;
      const household = householdSnap.data()!;

      let common: number = household.safe_to_spend_common || 0;
      let soloA: number = household.safe_to_spend_solo_A || 0;
      let soloB: number = household.safe_to_spend_solo_B || 0;
      let internalDebt: number = household.internal_debt_balance || 0;

      // Rétrocompatibilité : les anciens foyers n'ont pas user_A_id.
      const userAId = household.user_A_id ?? household.created_by;
      const isUserA = payerId === userAId;
      const ratioA = (household.split_ratio_user_A ?? 50) / 100;
      const ratioB = (household.split_ratio_user_B ?? 50) / 100;

      // Compte conjoint : personne n'avance quoi que ce soit, l'argent sort
      // d'un compte que les deux alimentent. Sans cette exception, la dette
      // interne grossirait chaque mois au profit du membre sous lequel la
      // connexion bancaire a été établie — une illusion comptable, puisque
      // Plaid attribue toutes les transactions d'un compte à un seul
      // identifiant.
      const isJointAccount = after.is_joint_account === true;

      // sign = +1 pour appliquer l'effet d'un bucket, -1 pour l'annuler.
      const apply = (bucket: string, sign: number) => {
        if (!VALID_BUCKETS.includes(bucket)) return;
        if (bucket === "Common") {
          common -= sign * amount;
          // Le payeur avance la part de l'autre : dette positive = B doit à A.
          if (!isJointAccount) {
            internalDebt +=
              sign * (isUserA ? amount * ratioB : -(amount * ratioA));
          }
        } else if (bucket === "Solo_A") {
          soloA -= sign * amount;
        } else if (bucket === "Solo_B") {
          soloB -= sign * amount;
        }
      };

      apply(beforeBucket, -1);
      apply(afterBucket, 1);

      tx.update(householdRef, {
        safe_to_spend_common: common,
        safe_to_spend_solo_A: soloA,
        safe_to_spend_solo_B: soloB,
        internal_debt_balance: internalDebt,
        updated_at: FieldValue.serverTimestamp(),
      });
    });
  });

/**
 * Règle la dette interne du foyer : enregistre un règlement dans
 * `households/{id}/settlements` et remet la balance à zéro.
 */
export const settleDebt = functions.https.onCall(async (data, context) => {
  const uid = requireAuth(context);
  await enforceRateLimit("settleDebt", uid, 20, 3600);

  const userSnap = await db.collection("users").doc(uid).get();
  const householdId = userSnap.data()?.household_id;
  if (!householdId) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Vous ne faites partie d'aucun foyer."
    );
  }

  const householdRef = db.collection("households").doc(householdId);

  const settled = await db.runTransaction(async (tx) => {
    const snap = await tx.get(householdRef);
    if (!snap.exists) {
      throw new functions.https.HttpsError("not-found", "Foyer introuvable.");
    }
    const household = snap.data()!;
    const debt: number = household.internal_debt_balance || 0;

    if (Math.abs(debt) < 0.01) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Aucune dette à régler : la balance est déjà équilibrée."
      );
    }

    const settlementRef = householdRef.collection("settlements").doc();
    tx.set(settlementRef, {
      amount: Math.abs(debt),
      direction: debt > 0 ? "B_owes_A" : "A_owes_B",
      settled_by: uid,
      created_at: FieldValue.serverTimestamp(),
    });
    tx.update(householdRef, {
      internal_debt_balance: 0,
      updated_at: FieldValue.serverTimestamp(),
    });

    return debt;
  });

  return { success: true, amount_settled: Math.abs(settled) };
});
