import * as functions from "firebase-functions/v1";
import { db } from "./init";
import { requireAuth, enforceRateLimit } from "./security";

// Entrées d'argent : jamais des dépenses variables à budgéter.
const NON_SPENDING = ["INCOME", "TRANSFER_IN"];

/**
 * Réglages de budget personnels (par siège A/B) et communs.
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

/** Date `AAAA-MM-JJ` (UTC) il y a `months` mois. */
function isoMonthsAgo(months: number): string {
  const n = new Date();
  const d = new Date(Date.UTC(n.getUTCFullYear(), n.getUTCMonth() - months, 1));
  return d.toISOString().slice(0, 10);
}

/**
 * Moyennes mensuelles par catégorie sur les 3 derniers mois, pour UNE cagnotte.
 *
 * Sert de proposition d'enveloppes : l'utilisateur n'a aucun montant à
 * inventer, on lui montre ce qu'il dépense réellement. Ne réserve rien et
 * n'écrit rien.
 */
async function suggestForBucket(householdId: string, bucket: string) {
  const from = isoMonthsAgo(3);
  const to = new Date().toISOString().slice(0, 10);
  const snap = await db
    .collection("transactions")
    .where("household_id", "==", householdId)
    .where("date", ">=", from)
    .where("date", "<", to)
    .orderBy("date", "desc")
    .limit(3000)
    .get();

  const byCat: Record<string, number> = {};
  snap.forEach((d) => {
    const t = d.data();
    const amount = typeof t.amount === "number" ? t.amount : 0;
    if (amount <= 0) return;
    if (t.assigned_to_bucket !== bucket) return;
    if (t.is_investment === true) return;
    const cat = (t.category as string) || "OTHER";
    if (NON_SPENDING.includes(cat)) return;
    byCat[cat] = (byCat[cat] ?? 0) + amount;
  });

  // Moyenne mensuelle = total sur 3 mois / 3, arrondie au dollar.
  return Object.entries(byCat)
    .map(([category, sum]) => ({
      category,
      monthly_average: Math.round(sum / 3),
    }))
    .filter((s) => s.monthly_average > 0)
    .sort((a, b) => b.monthly_average - a.monthly_average);
}

/** Valide et normalise une carte catégorie → montant mensuel (dollars). */
function sanitizeEnvelopes(raw: unknown): Record<string, number> {
  if (raw === null || typeof raw !== "object" || Array.isArray(raw)) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Enveloppes invalides."
    );
  }
  const envelopes: Record<string, number> = {};
  for (const [cat, amt] of Object.entries(raw as Record<string, unknown>)) {
    const n = Number(amt);
    if (typeof cat !== "string" || cat.length > 64) continue;
    if (!Number.isFinite(n) || n < 0 || n > 1000000) continue;
    if (n > 0) envelopes[cat] = Math.round(n);
  }
  return envelopes;
}

/**
 * Suggère des enveloppes de budget variable SOLO à partir des moyennes des 3
 * derniers mois de la cagnotte solo de l'appelant.
 */
export const suggestSoloEnvelopes = functions.https.onCall(
  async (data, context) => {
    const uid = requireAuth(context);
    await enforceRateLimit("suggestSoloEnvelopes", uid, 20, 3600);
    const { householdId, seat } = await seatOfCaller(uid);
    const suggestions = await suggestForBucket(householdId, `Solo_${seat}`);
    return { suggestions };
  }
);

/**
 * Enregistre les enveloppes de budget variable solo de l'appelant.
 * `envelopes` : carte catégorie → montant mensuel (dollars).
 */
export const setSoloEnvelopes = functions.https.onCall(
  async (data, context) => {
    const uid = requireAuth(context);
    await enforceRateLimit("setSoloEnvelopes", uid, 30, 3600);

    const envelopes = sanitizeEnvelopes(data?.envelopes);
    const { householdId, seat } = await seatOfCaller(uid);
    // update (et non set/merge) : remplace la carte en entier, pour qu'une
    // catégorie retirée disparaisse au lieu de persister par fusion.
    await db
      .collection("households")
      .doc(householdId)
      .update({ [`solo_envelopes_${seat}`]: envelopes });

    return { success: true, count: Object.keys(envelopes).length };
  }
);

/**
 * Suggère des enveloppes pour la cagnotte COMMUNE, mêmes moyennes sur 3 mois.
 *
 * Utile même si la cagnotte commune est d'abord une provision de dépenses
 * fixes : les enveloppes disent quelle part de la provision est encore
 * attendue en sortie ce mois-ci (« Réservé »), donc ce qui reste réellement
 * disponible pour le variable partagé (« Libre »).
 */
export const suggestCommonEnvelopes = functions.https.onCall(
  async (data, context) => {
    const uid = requireAuth(context);
    await enforceRateLimit("suggestCommonEnvelopes", uid, 20, 3600);
    const { householdId } = await seatOfCaller(uid);
    const suggestions = await suggestForBucket(householdId, "Common");
    return { suggestions };
  }
);

/**
 * Enregistre les enveloppes de la cagnotte commune.
 *
 * Pas de siège : la cagnotte est partagée, chacun des deux membres peut les
 * ajuster — comme le budget commun lui-même.
 */
export const setCommonEnvelopes = functions.https.onCall(
  async (data, context) => {
    const uid = requireAuth(context);
    await enforceRateLimit("setCommonEnvelopes", uid, 30, 3600);

    const envelopes = sanitizeEnvelopes(data?.envelopes);
    const { householdId } = await seatOfCaller(uid);
    await db
      .collection("households")
      .doc(householdId)
      .update({ common_envelopes: envelopes });

    return { success: true, count: Object.keys(envelopes).length };
  }
);
