import * as functions from "firebase-functions/v1";
import { db, FieldValue } from "./init";
import { requireAuth, enforceRateLimit } from "./security";
import { generateJoinCode } from "./households";
import { getPlaidClient, plaidSecrets, refreshConnectionCount } from "./plaid";

/** Limite Firestore : 500 écritures par lot, on garde une marge. */
const BATCH_SIZE = 400;

/** Foyer de l'appelant. Lève une erreur s'il n'en a pas. */
async function requireHousehold(uid: string): Promise<{
  householdId: string;
  household: FirebaseFirestore.DocumentData;
  ref: FirebaseFirestore.DocumentReference;
}> {
  const userSnap = await db.collection("users").doc(uid).get();
  const householdId = userSnap.data()?.household_id as string | undefined;
  if (!householdId) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Vous ne faites partie d'aucun foyer."
    );
  }
  const ref = db.collection("households").doc(householdId);
  const snap = await ref.get();
  if (!snap.exists) {
    throw new functions.https.HttpsError("not-found", "Foyer introuvable.");
  }
  return { householdId, household: snap.data()!, ref };
}

/**
 * Le siège occupé par `uid` : "A" ou "B".
 * Rétrocompatibilité : les anciens foyers n'ont pas `user_A_id`.
 */
function seatOf(household: FirebaseFirestore.DocumentData, uid: string): "A" | "B" {
  const userAId = household.user_A_id ?? household.created_by;
  return userAId === uid ? "A" : "B";
}

/** Identifiant de l'autre membre, ou `null` si le siège est libre. */
function partnerIdOf(
  household: FirebaseFirestore.DocumentData,
  uid: string
): string | null {
  const seat = seatOf(household, uid);
  const other = seat === "A" ? household.user_B_id : household.user_A_id;
  return (other as string | undefined) ?? null;
}

/** Supprime des documents par lots successifs. */
async function deleteAll(
  docs: FirebaseFirestore.QueryDocumentSnapshot[]
): Promise<void> {
  for (let i = 0; i < docs.length; i += BATCH_SIZE) {
    const batch = db.batch();
    docs.slice(i, i + BATCH_SIZE).forEach((d) => batch.delete(d.ref));
    await batch.commit();
  }
}

/**
 * Passage solo → couple : ouvre le foyer à un second membre.
 *
 * Le code d'invitation est **régénéré** : un code partagé lors d'une
 * tentative précédente ne doit plus permettre d'entrer.
 */
export const enableCoupleMode = functions.https.onCall(async (data, context) => {
  const uid = requireAuth(context);
  await enforceRateLimit("enableCoupleMode", uid, 10, 3600);

  const { household, ref } = await requireHousehold(uid);
  if (partnerIdOf(household, uid)) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Ce foyer compte déjà deux membres."
    );
  }

  const joinCode = generateJoinCode();
  await ref.update({
    household_mode: "couple",
    join_code: joinCode,
    // Répartition par défaut à deux. L'utilisateur l'ajuste ensuite dans
    // la configuration du budget.
    split_ratio_user_A: 50,
    split_ratio_user_B: 50,
    updated_at: FieldValue.serverTimestamp(),
  });

  return { success: true, join_code: joinCode };
});

/**
 * Retour couple → solo, **uniquement tant que personne n'a rejoint**.
 *
 * Si un partenaire est présent, il doit partir lui-même (`leaveHousehold`) :
 * personne ne peut retirer unilatéralement à quelqu'un l'accès à ses propres
 * données bancaires.
 */
export const revertToSolo = functions.https.onCall(async (data, context) => {
  const uid = requireAuth(context);
  await enforceRateLimit("revertToSolo", uid, 10, 3600);

  const { household, ref } = await requireHousehold(uid);
  if (partnerIdOf(household, uid)) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Un partenaire fait partie de ce foyer : il doit le quitter lui-même."
    );
  }

  const seat = seatOf(household, uid);
  await ref.update({
    household_mode: "solo",
    // Le code partagé pendant la période « couple » est invalidé.
    join_code: generateJoinCode(),
    split_ratio_user_A: seat === "A" ? 100 : 0,
    split_ratio_user_B: seat === "A" ? 0 : 100,
    updated_at: FieldValue.serverTimestamp(),
  });

  return { success: true };
});

/**
 * Séparation : l'appelant quitte le foyer, qui redevient solo pour l'autre.
 *
 * Séquence :
 *  1. Révocation des items Plaid de l'appelant puis effacement des connexions
 *     — sans quoi sa banque continuerait d'alimenter le foyer qu'il quitte.
 *  2. Suppression de ses transactions, avec renversement explicite de leur
 *     effet sur la cagnotte commune : le déclencheur `onTransactionAssigned`
 *     n'écoute que les mises à jour, jamais les suppressions.
 *  3. Suppression des bilans du foyer : ce sont des agrégats qui contiennent
 *     les dépenses de la personne qui part.
 *  4. Libération du siège, remise à zéro de la dette (consignée dans
 *     `settlements`) et régénération du code d'invitation.
 *
 * Le compte de l'appelant est conservé : il se retrouve sans foyer et peut
 * en créer un nouveau.
 */
export const leaveHousehold = functions
  .runWith({ secrets: plaidSecrets })
  .https.onCall(async (data, context) => {
    const uid = requireAuth(context);
    await enforceRateLimit("leaveHousehold", uid, 3, 86400);

    const { householdId, household, ref } = await requireHousehold(uid);
    const partnerId = partnerIdOf(household, uid);
    if (!partnerId) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Vous êtes seul(e) dans ce foyer : supprimez-le plutôt via votre compte."
      );
    }
    const seat = seatOf(household, uid);

    // 1. Connexions bancaires de l'appelant.
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
            // Même comportement que deleteAccount : le jeton disparaît de nos
            // systèmes dans tous les cas, l'échec est consigné pour révocation
            // manuelle éventuelle.
            console.error(`itemRemove a échoué pour ${doc.id}:`, e);
          }
        }
        await doc.ref.delete();
      }
    }

    // 2. Transactions de l'appelant.
    const myTx = await db
      .collection("transactions")
      .where("household_id", "==", householdId)
      .where("paid_by_user_id", "==", uid)
      .get();

    // Ce que ses dépenses avaient retiré de la cagnotte commune doit y
    // revenir, puisque ces transactions cessent d'exister. Sa propre cagnotte
    // et la dette interne sont remises à zéro plus bas : inutile de les
    // recalculer poste par poste.
    let commonToRestore = 0;
    for (const doc of myTx.docs) {
      const t = doc.data();
      if (t.assigned_to_bucket === "Common" && typeof t.amount === "number") {
        commonToRestore += t.amount;
      }
    }
    await deleteAll(myTx.docs);

    // 3. Bilans : agrégats mêlant les dépenses des deux membres.
    await db.recursiveDelete(ref.collection("reports"));

    // 4. Libération du siège.
    const debt = (household.internal_debt_balance as number) || 0;
    const batch = db.batch();
    if (Math.abs(debt) >= 0.01) {
      // Trace comptable de l'annulation, pour que l'historique du foyer
      // n'affiche pas une dette disparue sans explication.
      batch.set(ref.collection("settlements").doc(), {
        amount: Math.abs(debt),
        direction: debt > 0 ? "B_owes_A" : "A_owes_B",
        settled_by: uid,
        reason: "separation",
        created_at: FieldValue.serverTimestamp(),
      });
    }
    batch.update(ref, {
      [seat === "A" ? "user_A_id" : "user_B_id"]: null,
      [seat === "A" ? "user_A_name" : "user_B_name"]: null,
      [seat === "A" ? "safe_to_spend_solo_A" : "safe_to_spend_solo_B"]: 0,
      safe_to_spend_common:
        ((household.safe_to_spend_common as number) || 0) + commonToRestore,
      internal_debt_balance: 0,
      household_mode: "solo",
      // L'ex-partenaire connaît l'ancien code : il ne doit plus ouvrir ce foyer.
      join_code: generateJoinCode(),
      // Le membre restant assume désormais seul les dépenses communes.
      split_ratio_user_A: seat === "A" ? 0 : 100,
      split_ratio_user_B: seat === "A" ? 100 : 0,
      updated_at: FieldValue.serverTimestamp(),
    });
    batch.update(db.collection("users").doc(uid), {
      household_id: FieldValue.delete(),
      role: FieldValue.delete(),
    });
    await batch.commit();
    await refreshConnectionCount(householdId);

    return { success: true, transactions_deleted: myTx.size };
  });

/**
 * Remise à zéro des données financières du foyer, comptes conservés.
 *
 * Sert à repartir sur une base propre — typiquement en passant des données
 * de test aux données bancaires réelles. Efface connexions bancaires,
 * transactions, budgets, règlements et bilans du foyer, puis remet les
 * cagnottes et la dette à zéro. Les comptes, le foyer, ses membres et leur
 * second facteur MFA sont intacts.
 *
 * Volontairement réservé au **premier membre** (siège A) quand le foyer en
 * compte deux : effacer l'historique bancaire de son partenaire ne doit pas
 * être à la portée d'un simple appui, et la confirmation forte côté client
 * ne protège que celui qui la voit.
 */
export const resetHouseholdData = functions
  .runWith({ secrets: plaidSecrets })
  .https.onCall(async (data, context) => {
    const uid = requireAuth(context);
    await enforceRateLimit("resetHouseholdData", uid, 3, 86400);

    const { householdId, household, ref } = await requireHousehold(uid);
    if (partnerIdOf(household, uid) && seatOf(household, uid) !== "A") {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Seul le membre qui a créé le foyer peut réinitialiser ses données."
      );
    }

    // 1. Connexions bancaires du foyer (les deux membres).
    const connections = await db
      .collection("bank_connections")
      .where("household_id", "==", householdId)
      .get();
    if (!connections.empty) {
      const client = getPlaidClient();
      for (const doc of connections.docs) {
        const accessToken = doc.data().access_token as string | undefined;
        if (accessToken) {
          try {
            await client.itemRemove({ access_token: accessToken });
          } catch (e) {
            // Attendu lors du passage sandbox → production : les anciens
            // jetons n'existent pas dans le nouvel environnement.
            console.error(`itemRemove a échoué pour ${doc.id}:`, e);
          }
        }
        await doc.ref.delete();
      }
    }

    // 2. Transactions du foyer.
    const tx = await db
      .collection("transactions")
      .where("household_id", "==", householdId)
      .get();
    await deleteAll(tx.docs);

    // 3. Sous-collections : budgets, règlements, bilans.
    await db.recursiveDelete(ref.collection("monthly_budgets"));
    await db.recursiveDelete(ref.collection("settlements"));
    await db.recursiveDelete(ref.collection("reports"));

    // 4. Compteurs remis à zéro.
    await ref.update({
      safe_to_spend_common: 0,
      safe_to_spend_solo_A: 0,
      safe_to_spend_solo_B: 0,
      internal_debt_balance: 0,
      updated_at: FieldValue.serverTimestamp(),
    });

    await refreshConnectionCount(householdId);

    return {
      success: true,
      transactions_deleted: tx.size,
      connections_removed: connections.size,
    };
  });
