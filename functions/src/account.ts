import * as functions from "firebase-functions/v1";
import { db, FieldValue, auth } from "./init";
import { requireAuth, enforceRateLimit } from "./security";
import { getPlaidClient, plaidSecrets, refreshConnectionCount } from "./plaid";

/**
 * Suppression complète du compte (droit à l'effacement — Loi 25 / RGPD).
 *
 * - Révoque les items Plaid et supprime les connexions bancaires.
 * - Supprime les transactions personnelles de l'utilisateur.
 * - Si l'utilisateur est seul dans le foyer : supprime le foyer entier
 *   (budgets, règlements, transactions restantes).
 * - Sinon : libère sa place et remet la dette interne à zéro.
 * - Supprime le profil Firestore puis le compte Firebase Auth.
 */
export const deleteAccount = functions
  .runWith({ secrets: plaidSecrets })
  .https.onCall(async (data, context) => {
    // La vérification du courriel n'est pas exigée : on doit toujours
    // pouvoir supprimer son compte.
    const uid = requireAuth(context, { requireVerifiedEmail: false });
    await enforceRateLimit("deleteAccount", uid, 3, 86400);

    // 1. Connexions bancaires : révocation Plaid + suppression des documents.
    const connections = await db
      .collection("bank_connections")
      .where("user_id", "==", uid)
      .get();
    if (!connections.empty) {
      const client = getPlaidClient();
      for (const doc of connections.docs) {
        const accessToken = doc.data().access_token as string | undefined;
        if (accessToken) {
          try {
            await client.itemRemove({ access_token: accessToken });
          } catch (e) {
            console.error(`itemRemove a échoué pour ${doc.id}:`, e);
          }
        }
        await doc.ref.delete();
      }
    }

    // 2. Foyer et transactions.
    const userRef = db.collection("users").doc(uid);
    const userSnap = await userRef.get();
    const householdId = userSnap.data()?.household_id as string | undefined;

    if (householdId) {
      const householdRef = db.collection("households").doc(householdId);
      const householdSnap = await householdRef.get();

      // Transactions personnelles de l'utilisateur.
      const myTx = await db
        .collection("transactions")
        .where("household_id", "==", householdId)
        .where("paid_by_user_id", "==", uid)
        .get();
      const batchSize = 400;
      for (let i = 0; i < myTx.docs.length; i += batchSize) {
        const batch = db.batch();
        myTx.docs.slice(i, i + batchSize).forEach((d) => batch.delete(d.ref));
        await batch.commit();
      }

      if (householdSnap.exists) {
        const household = householdSnap.data()!;
        const userAId = household.user_A_id ?? household.created_by;
        const isA = userAId === uid;
        const partnerId = isA ? household.user_B_id : userAId;

        if (!partnerId) {
          // Seul membre : suppression du foyer et de tout son contenu.
          const remainingTx = await db
            .collection("transactions")
            .where("household_id", "==", householdId)
            .get();
          for (let i = 0; i < remainingTx.docs.length; i += batchSize) {
            const batch = db.batch();
            remainingTx.docs
              .slice(i, i + batchSize)
              .forEach((d) => batch.delete(d.ref));
            await batch.commit();
          }
          // Supprime le document du foyer et ses sous-collections
          // (monthly_budgets, settlements).
          await db.recursiveDelete(householdRef);
        } else {
          // Le/la partenaire reste : on libère la place.
          await householdRef.update({
            [isA ? "user_A_id" : "user_B_id"]: null,
            [isA ? "user_A_name" : "user_B_name"]: null,
            internal_debt_balance: 0,
            [isA ? "safe_to_spend_solo_A" : "safe_to_spend_solo_B"]: 0,
            updated_at: FieldValue.serverTimestamp(),
          });
          await refreshConnectionCount(householdId);
        }
      }
    }

    // 3. Profil et compte d'authentification.
    await userRef.delete();
    await auth.deleteUser(uid);

    return { success: true };
  });

/**
 * Export des données personnelles (droit à la portabilité — Loi 25).
 * Retourne un objet JSON contenant toutes les données de l'utilisateur.
 */
export const exportMyData = functions.https.onCall(async (data, context) => {
  const uid = requireAuth(context);
  await enforceRateLimit("exportMyData", uid, 5, 86400);

  const userSnap = await db.collection("users").doc(uid).get();
  const profile = userSnap.data() ?? {};
  const householdId = profile.household_id as string | undefined;

  const result: Record<string, unknown> = {
    exported_at: new Date().toISOString(),
    user_id: uid,
    email: context.auth?.token.email ?? null,
    profile,
    household: null,
    monthly_budgets: [],
    settlements: [],
    transactions: [],
  };

  if (householdId) {
    const householdRef = db.collection("households").doc(householdId);
    const householdSnap = await householdRef.get();
    if (householdSnap.exists) {
      // Le code d'invitation n'appartient pas aux données personnelles.
      const { join_code, ...householdData } = householdSnap.data()!;
      void join_code;
      result.household = householdData;
    }

    const budgets = await householdRef.collection("monthly_budgets").get();
    result.monthly_budgets = budgets.docs.map((d) => ({
      month: d.id,
      ...d.data(),
    }));

    const settlements = await householdRef.collection("settlements").get();
    result.settlements = settlements.docs.map((d) => d.data());

    const transactions = await db
      .collection("transactions")
      .where("household_id", "==", householdId)
      .where("paid_by_user_id", "==", uid)
      .get();
    result.transactions = transactions.docs.map((d) => d.data());
  }

  return result;
});
