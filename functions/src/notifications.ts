import * as functions from "firebase-functions/v1";
import { db, messaging, FieldValue } from "./init";
import { requireAuth, assertString } from "./security";

/**
 * Notifications push (Firebase Cloud Messaging).
 *
 * Principe : chaque type de notification est activable individuellement par
 * l'utilisateur (`notif_prefs` sur son document). Un envoi vérifie toujours
 * la préférence correspondante avant de partir — le serveur ne présume jamais
 * du consentement.
 *
 * Les jetons FCM sont propres à un appareil ; un compte peut en avoir
 * plusieurs (téléphone, ordinateur). Un envoi qui échoue avec un jeton
 * périmé le retire, sans quoi la liste enflerait indéfiniment.
 */

/** Types de notification. Doivent rester alignés avec le client. */
export type NotifType =
  | "card_reminder"
  | "pot_alert"
  | "to_sort"
  | "partner"
  | "overspend";

/** Un type est actif si l'utilisateur ne l'a pas explicitement désactivé. */
function isEnabled(
  prefs: Record<string, unknown> | undefined,
  type: NotifType
): boolean {
  return prefs?.[type] !== false;
}

/**
 * Envoie une notification à un utilisateur, si le type est activé chez lui.
 *
 * Retourne le nombre de messages effectivement remis. Ne lève jamais : une
 * notification est un à-côté, son échec ne doit pas faire échouer l'action
 * qui l'a déclenchée.
 */
export async function sendToUser(
  uid: string,
  type: NotifType,
  title: string,
  body: string,
  data: Record<string, string> = {}
): Promise<number> {
  try {
    const snap = await db.collection("users").doc(uid).get();
    const user = snap.data();
    if (!user) return 0;

    const tokens = (user.fcm_tokens as string[] | undefined) ?? [];
    if (tokens.length === 0) return 0;
    if (!isEnabled(user.notif_prefs as Record<string, unknown>, type)) return 0;

    const res = await messaging.sendEachForMulticast({
      tokens,
      notification: { title, body },
      data: { type, ...data },
      webpush: {
        notification: { icon: "/icons/Icon-192.png", badge: "/icons/Icon-192.png" },
        fcmOptions: { link: "/" },
      },
    });

    // Purge des jetons devenus invalides (appareil déconnecté, cache vidé).
    const stale: string[] = [];
    res.responses.forEach((r, i) => {
      const code = r.error?.code;
      if (
        code === "messaging/registration-token-not-registered" ||
        code === "messaging/invalid-registration-token"
      ) {
        stale.push(tokens[i]);
      }
    });
    if (stale.length > 0) {
      await snap.ref.update({
        fcm_tokens: FieldValue.arrayRemove(...stale),
      });
    }

    return res.successCount;
  } catch (e) {
    console.error(`Notification ${type} échouée pour ${uid}:`, e);
    return 0;
  }
}

/** Membres (uid) d'un foyer. */
export async function householdMemberIds(
  household: FirebaseFirestore.DocumentData
): Promise<string[]> {
  const a = (household.user_A_id ?? household.created_by) as string | undefined;
  const b = household.user_B_id as string | undefined;
  return [a, b].filter((x): x is string => !!x);
}

/**
 * Enregistre le jeton FCM de l'appareil courant.
 *
 * `arrayUnion` : idempotent, et conserve les autres appareils du compte.
 */
export const registerPushToken = functions.https.onCall(
  async (data, context) => {
    const uid = requireAuth(context, { requireVerifiedEmail: false });
    const token = assertString(data?.token, "token", { maxLength: 4096 });
    await db
      .collection("users")
      .doc(uid)
      .set({ fcm_tokens: FieldValue.arrayUnion(token) }, { merge: true });
    return { success: true };
  }
);

/** Retire un jeton (déconnexion, refus des notifications). */
export const unregisterPushToken = functions.https.onCall(
  async (data, context) => {
    const uid = requireAuth(context, { requireVerifiedEmail: false });
    const token = assertString(data?.token, "token", { maxLength: 4096 });
    await db
      .collection("users")
      .doc(uid)
      .update({ fcm_tokens: FieldValue.arrayRemove(token) });
    return { success: true };
  }
);

/** Préférences de notification (map type → booléen) + délais. */
export const setNotifPrefs = functions.https.onCall(async (data, context) => {
  const uid = requireAuth(context, { requireVerifiedEmail: false });

  const prefs = data?.prefs;
  if (typeof prefs !== "object" || prefs === null) {
    throw new functions.https.HttpsError("invalid-argument", "prefs invalide");
  }
  const allowed: NotifType[] = [
    "card_reminder",
    "pot_alert",
    "to_sort",
    "partner",
    "overspend",
  ];
  const clean: Record<string, boolean> = {};
  for (const key of allowed) {
    if (typeof prefs[key] === "boolean") clean[key] = prefs[key];
  }

  const update: Record<string, unknown> = { notif_prefs: clean };
  // Délai de rappel avant échéance (jours), borné pour rester raisonnable.
  if (data?.card_lead_days !== undefined) {
    const n = Number(data.card_lead_days);
    if (Number.isFinite(n) && n >= 1 && n <= 14) {
      update.notif_card_lead_days = Math.round(n);
    }
  }

  await db.collection("users").doc(uid).set(update, { merge: true });
  return { success: true };
});

/**
 * Rappel hebdomadaire quand des transactions attendent d'être triées.
 * Lundi 13 h UTC (~8–9 h au Québec). N'envoie rien si la file est vide.
 */
export const weeklyToSortReminder = functions.pubsub
  .schedule("0 13 * * 1")
  .timeZone("America/Toronto")
  .onRun(async () => {
    const households = await db.collection("households").get();
    for (const h of households.docs) {
      const pending = await db
        .collection("transactions")
        .where("household_id", "==", h.id)
        .where("assigned_to_bucket", "==", "")
        .count()
        .get();
      const count = pending.data().count;
      if (count === 0) continue;

      const members = await householdMemberIds(h.data());
      for (const uid of members) {
        await sendToUser(
          uid,
          "to_sort",
          "Transactions à trier",
          `${count} transaction(s) attendent d'être classées dans Horizon.`
        );
      }
    }
    return null;
  });
