import * as functions from "firebase-functions/v1";
import * as crypto from "crypto";
import { db, FieldValue } from "./init";
import {
  requireAuth,
  enforceRateLimit,
  assertString,
  JOIN_CODE_PATTERN,
} from "./security";

function generateJoinCode(): string {
  // Sans I, O, 0, 1 pour éviter les confusions à la saisie.
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  let result = "";
  for (let i = 0; i < 6; i++) {
    result += chars.charAt(crypto.randomInt(chars.length));
  }
  return result;
}

/** Prénom affiché, lu depuis le profil utilisateur. */
async function displayNameOf(uid: string, fallback: string): Promise<string> {
  const snap = await db.collection("users").doc(uid).get();
  const name = (snap.data()?.display_name as string | undefined)?.trim();
  return name && name.length > 0 ? name.slice(0, 40) : fallback;
}

export const createHousehold = functions.https.onCall(
  async (data, context) => {
    const uid = requireAuth(context);
    await enforceRateLimit("createHousehold", uid, 5, 3600);

    const userRef = db.collection("users").doc(uid);
    const userSnap = await userRef.get();
    if (userSnap.data()?.household_id) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Vous faites déjà partie d'un foyer."
      );
    }

    const joinCode = generateJoinCode();
    const name = await displayNameOf(uid, "Membre A");

    const householdRef = await db.collection("households").add({
      created_by: uid,
      created_at: FieldValue.serverTimestamp(),
      join_code: joinCode,
      user_A_id: uid,
      user_B_id: null,
      user_A_name: name,
      user_B_name: null,
      subscription_tier: "free",
      split_ratio_user_A: 50,
      split_ratio_user_B: 50,
      safe_to_spend_common: 0,
      safe_to_spend_solo_A: 0,
      safe_to_spend_solo_B: 0,
      internal_debt_balance: 0,
    });

    await userRef.set(
      {
        household_id: householdRef.id,
        role: "admin",
      },
      { merge: true }
    );

    return { success: true, household_id: householdRef.id, join_code: joinCode };
  }
);

export const joinHousehold = functions.https.onCall(async (data, context) => {
  const uid = requireAuth(context);
  // Limite stricte : empêche la recherche de codes par force brute.
  await enforceRateLimit("joinHousehold", uid, 10, 3600);

  const joinCode = assertString(
    typeof data?.join_code === "string"
      ? data.join_code.trim().toUpperCase()
      : data?.join_code,
    "join_code",
    { minLength: 6, maxLength: 6, pattern: JOIN_CODE_PATTERN }
  );

  const name = await displayNameOf(uid, "Membre B");
  const userRef = db.collection("users").doc(uid);
  let householdId = "";

  await db.runTransaction(async (tx) => {
    const userSnap = await tx.get(userRef);
    if (userSnap.data()?.household_id) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Vous faites déjà partie d'un foyer."
      );
    }

    const query = db
      .collection("households")
      .where("join_code", "==", joinCode)
      .limit(1);
    const snapshot = await tx.get(query);
    if (snapshot.empty) {
      throw new functions.https.HttpsError(
        "not-found",
        "Aucun foyer ne correspond à ce code."
      );
    }

    const householdDoc = snapshot.docs[0];
    const household = householdDoc.data();

    if ((household.user_A_id ?? household.created_by) === uid) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Vous ne pouvez pas rejoindre votre propre foyer."
      );
    }
    if (household.user_B_id) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Ce foyer est déjà complet."
      );
    }

    householdId = householdDoc.id;
    tx.update(householdDoc.ref, {
      user_B_id: uid,
      user_B_name: name,
    });
    tx.set(
      userRef,
      {
        household_id: householdId,
        role: "member",
      },
      { merge: true }
    );
  });

  return { success: true, household_id: householdId };
});
