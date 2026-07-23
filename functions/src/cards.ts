import * as functions from "firebase-functions/v1";
import { db, FieldValue } from "./init";
import { requireAuth, enforceRateLimit, assertString } from "./security";
import { getPlaidClient, plaidSecrets } from "./plaid";
import { sendToUser, householdMemberIds } from "./notifications";

/**
 * Cartes de crédit et liquidités.
 *
 * Deux besoins :
 *  - Rappeler une échéance de carte avant qu'elle tombe.
 *  - Avertir quand le solde d'une carte dépasse les liquidités disponibles,
 *    c.-à-d. quand on ne pourrait pas la payer entièrement.
 *
 * Les échéances viennent du produit Plaid `liabilities` quand l'institution
 * le supporte ; sinon l'utilisateur saisit le jour d'échéance à la main. Les
 * deux voies alimentent le même document `households/{hid}/cards/{account_id}`.
 */

interface CardDoc {
  account_id: string;
  item_id: string;
  institution_name: string | null;
  name: string;
  mask: string | null;
  /** Solde dû actuel (positif = argent dû). */
  current_balance: number | null;
  /** Solde du dernier relevé. */
  statement_balance: number | null;
  minimum_payment: number | null;
  /** Échéance fournie par Plaid (`AAAA-MM-JJ`), si disponible. */
  due_date: string | null;
  /** Jour d'échéance saisi à la main (1–28), quand Plaid ne le fournit pas. */
  manual_due_day: number | null;
}

/**
 * Rafraîchit les cartes et les liquidités d'un foyer depuis Plaid.
 *
 * - `liabilitiesGet` pour les échéances et soldes de carte (échoue proprement
 *   si l'item n'a pas le produit : on tombe alors sur les seules balances).
 * - `accountsBalanceGet` pour les liquidités (comptes chèque et épargne).
 *
 * Écrit un document par carte et le total des liquidités sur le foyer. Les
 * `manual_due_day` déjà saisis sont préservés.
 */
export async function refreshCardData(householdId: string): Promise<void> {
  const conns = await db
    .collection("bank_connections")
    .where("household_id", "==", householdId)
    .get();
  if (conns.empty) return;

  const client = getPlaidClient();
  let availableCash = 0;
  const seenCardIds: string[] = [];

  for (const conn of conns.docs) {
    const accessToken = conn.data().access_token as string | undefined;
    const institutionName =
      (conn.data().institution_name as string | undefined) ?? null;
    if (!accessToken) continue;

    // Liquidités : solde disponible des comptes de dépôt.
    try {
      const bal = await client.accountsBalanceGet({ access_token: accessToken });
      for (const a of bal.data.accounts) {
        if (a.type === "depository") {
          availableCash += a.balances.available ?? a.balances.current ?? 0;
        }
      }
    } catch (e) {
      console.error(`Balances indisponibles pour ${conn.id}:`, e);
    }

    // Échéances et soldes de carte (produit liabilities, facultatif).
    try {
      const liab = await client.liabilitiesGet({ access_token: accessToken });
      const accounts = liab.data.accounts;
      for (const credit of liab.data.liabilities.credit ?? []) {
        const acct = accounts.find(
          (a) => a.account_id === credit.account_id
        );
        if (!credit.account_id) continue;
        seenCardIds.push(credit.account_id);

        const ref = db
          .collection("households")
          .doc(householdId)
          .collection("cards")
          .doc(credit.account_id);
        const existing = (await ref.get()).data() as CardDoc | undefined;

        const card: CardDoc = {
          account_id: credit.account_id,
          item_id: conn.id,
          institution_name: institutionName,
          name: acct?.official_name || acct?.name || "Carte de crédit",
          mask: acct?.mask ?? null,
          current_balance: acct?.balances.current ?? null,
          statement_balance: credit.last_statement_balance ?? null,
          minimum_payment: credit.minimum_payment_amount ?? null,
          due_date: credit.next_payment_due_date ?? null,
          // Ne pas écraser une saisie manuelle si Plaid ne donne pas de date.
          manual_due_day: existing?.manual_due_day ?? null,
        };
        await ref.set(card, { merge: true });
      }
    } catch {
      // L'item n'a pas le produit liabilities : les cartes de cette
      // connexion reposeront sur la saisie manuelle. Rien à journaliser en
      // erreur, c'est un cas nominal.
    }
  }

  await db.collection("households").doc(householdId).set(
    {
      available_cash: availableCash,
      cards_synced_at: FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
}

/** Callable : force le rafraîchissement (utilisé après une reconnexion). */
export const refreshCards = functions
  .runWith({ secrets: plaidSecrets })
  .https.onCall(async (data, context) => {
    const uid = requireAuth(context);
    await enforceRateLimit("refreshCards", uid, 10, 3600);
    const userSnap = await db.collection("users").doc(uid).get();
    const householdId = userSnap.data()?.household_id as string | undefined;
    if (!householdId) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Vous ne faites partie d'aucun foyer."
      );
    }
    await refreshCardData(householdId);
    return { success: true };
  });

/**
 * Saisie manuelle du jour d'échéance d'une carte (1–28).
 *
 * Pour les institutions que `liabilities` ne couvre pas : sans date fournie
 * par Plaid, c'est le seul moyen d'obtenir un rappel. Borné à 28 pour exister
 * dans tous les mois.
 */
export const setCardDueDay = functions.https.onCall(async (data, context) => {
  const uid = requireAuth(context);
  await enforceRateLimit("setCardDueDay", uid, 20, 3600);

  const accountId = assertString(data?.account_id, "account_id", {
    maxLength: 128,
  });
  const userSnap = await db.collection("users").doc(uid).get();
  const householdId = userSnap.data()?.household_id as string | undefined;
  if (!householdId) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Vous ne faites partie d'aucun foyer."
    );
  }

  const day = data?.due_day === null ? null : Number(data?.due_day);
  if (day !== null && (!Number.isInteger(day) || day < 1 || day > 28)) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Le jour d'échéance doit être entre 1 et 28."
    );
  }

  await db
    .collection("households")
    .doc(householdId)
    .collection("cards")
    .doc(accountId)
    .set({ manual_due_day: day }, { merge: true });
  return { success: true };
});

/** Prochaine occurrence d'un jour du mois, à partir d'aujourd'hui (UTC). */
function nextOccurrence(day: number): Date {
  const now = new Date();
  let d = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), day));
  if (d < new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()))) {
    d = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + 1, day));
  }
  return d;
}

/** Nombre de jours entiers d'ici une date (négatif si passée). */
function daysUntil(dateIso: string): number {
  const target = new Date(dateIso + "T00:00:00Z").getTime();
  const today = new Date();
  const todayUtc = Date.UTC(
    today.getUTCFullYear(),
    today.getUTCMonth(),
    today.getUTCDate()
  );
  return Math.round((target - todayUtc) / 86400000);
}

/**
 * Vérifications quotidiennes des cartes : rappels d'échéance et dépassement
 * des liquidités. Planifié à 13 h UTC (~8–9 h au Québec).
 */
export const dailyCardChecks = functions.pubsub
  .schedule("0 13 * * *")
  .timeZone("America/Toronto")
  .onRun(async () => {
    const households = await db.collection("households").get();

    for (const h of households.docs) {
      try {
        await refreshCardData(h.id);
      } catch (e) {
        console.error(`refreshCardData a échoué pour ${h.id}:`, e);
      }

      const fresh = await db.collection("households").doc(h.id).get();
      const availableCash = (fresh.data()?.available_cash as number) ?? 0;
      const members = await householdMemberIds(fresh.data() ?? {});
      if (members.length === 0) continue;

      // Délai de rappel : le plus tôt souhaité parmi les membres, borné.
      let leadDays = 3;
      for (const uid of members) {
        const u = (await db.collection("users").doc(uid).get()).data();
        const l = u?.notif_card_lead_days as number | undefined;
        if (typeof l === "number") leadDays = Math.max(leadDays, l);
      }

      const cards = await h.ref.collection("cards").get();
      for (const cardSnap of cards.docs) {
        const c = cardSnap.data() as CardDoc;

        // Échéance : Plaid en priorité, sinon la saisie manuelle.
        const dueIso =
          c.due_date ??
          (c.manual_due_day
            ? nextOccurrence(c.manual_due_day).toISOString().slice(0, 10)
            : null);

        const label = c.mask ? `${c.name} ••${c.mask}` : c.name;

        // Rappel d'échéance.
        if (dueIso) {
          const d = daysUntil(dueIso);
          if (d >= 0 && d <= leadDays) {
            const amount =
              c.statement_balance ?? c.minimum_payment ?? c.current_balance;
            const body =
              d === 0
                ? `${label} : paiement dû aujourd'hui` +
                  (amount ? ` (${amount.toFixed(2)} $).` : ".")
                : `${label} : paiement dû dans ${d} jour(s)` +
                  (amount ? ` (${amount.toFixed(2)} $).` : ".");
            for (const uid of members) {
              await sendToUser(uid, "card_reminder", "Échéance de carte", body);
            }
          }
        }

        // Dépassement des liquidités : le solde dû excède ce qui est
        // disponible pour le payer. Seuil de 1 $ pour éviter le bruit.
        const owed = c.current_balance ?? 0;
        if (owed > 1 && owed > availableCash + 1) {
          const manque = (owed - availableCash).toFixed(2);
          const body =
            `${label} : solde de ${owed.toFixed(2)} $, ` +
            `mais ${availableCash.toFixed(2)} $ disponibles. ` +
            `Il manque ${manque} $ pour la régler entièrement.`;
          for (const uid of members) {
            await sendToUser(uid, "overspend", "Attention aux liquidités", body);
          }
        }
      }
    }
    return null;
  });
