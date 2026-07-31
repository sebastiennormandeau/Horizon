import * as functions from "firebase-functions/v1";
import { db, FieldValue } from "./init";
import { requireAuth, enforceRateLimit } from "./security";
import { sendToUser, householdMemberIds } from "./notifications";

const VALID_BUCKETS = ["Common", "Solo_A", "Solo_B"];

// Libellés courts (fr) pour les notifications — les notifications sont en
// français. Miroir compact de lib/utils/categories.dart ; repli sur la clé.
const CATEGORY_LABEL_FR: Record<string, string> = {
  FOOD_AND_DRINK: "Restauration & alcool",
  GENERAL_MERCHANDISE: "Magasinage",
  TRANSPORTATION: "Transport",
  RENT_AND_UTILITIES: "Logement & services",
  ENTERTAINMENT: "Divertissement",
  TRAVEL: "Voyages",
  MEDICAL: "Santé",
  PERSONAL_CARE: "Soins personnels",
  GENERAL_SERVICES: "Services",
  HOME_IMPROVEMENT: "Rénovation & maison",
  LOAN_PAYMENTS: "Remboursements de prêts",
  BANK_FEES: "Frais bancaires",
  GOVERNMENT_AND_NON_PROFIT: "Gouvernement & dons",
  TRANSFER_OUT: "Virements sortants",
};

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

    // Détecte un franchissement de seuil vers le bas pour n'alerter qu'une
    // fois, au moment où une cagnotte passe sous le seuil — pas à chaque
    // dépense supplémentaire une fois déjà sous le seuil.
    let crossedPot: { label: string; before: number; after: number } | null =
      null;

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

      const commonBefore = common;
      const soloABefore = soloA;
      const soloBBefore = soloB;

      apply(beforeBucket, -1);
      apply(afterBucket, 1);

      // La cagnotte touchée par cette assignation vient-elle de franchir le
      // seuil ? On ne regarde que celle qui a bougé.
      const threshold = (household.alert_threshold as number) ?? 100;
      const check = (label: string, was: number, now: number) => {
        if (was >= threshold && now < threshold) {
          crossedPot = { label, before: was, after: now };
        }
      };
      if (afterBucket === "Common" || beforeBucket === "Common") {
        check("Commun", commonBefore, common);
      }
      if (afterBucket === "Solo_A" || beforeBucket === "Solo_A") {
        check("Solo_A", soloABefore, soloA);
      }
      if (afterBucket === "Solo_B" || beforeBucket === "Solo_B") {
        check("Solo_B", soloBBefore, soloB);
      }

      tx.update(householdRef, {
        safe_to_spend_common: common,
        safe_to_spend_solo_A: soloA,
        safe_to_spend_solo_B: soloB,
        internal_debt_balance: internalDebt,
        updated_at: FieldValue.serverTimestamp(),
      });
    });

    // Notifications hors transaction : un envoi ne doit jamais bloquer ni
    // rejouer l'écriture du grand livre.
    const assignedToSolo = afterBucket === "Solo_A" || afterBucket === "Solo_B";
    const assignedToCommon = afterBucket === "Common";
    if (!crossedPot && !assignedToSolo && !assignedToCommon) return;
    const hd = (await householdRef.get()).data() ?? {};

    if (crossedPot) {
      const pot = crossedPot as { label: string; after: number };
      const members = await householdMemberIds(hd);
      // Libellé lisible : le prénom pour les cagnottes personnelles.
      const label =
        pot.label === "Solo_A"
          ? (hd.user_A_name as string) || "Solo A"
          : pot.label === "Solo_B"
            ? (hd.user_B_name as string) || "Solo B"
            : pot.label;
      pot.label = label;
      const negative = pot.after < 0;
      const body = negative
        ? `La cagnotte « ${pot.label} » est passée dans le négatif (${pot.after.toFixed(2)} $).`
        : `La cagnotte « ${pot.label} » est passée sous votre seuil d'alerte (${pot.after.toFixed(2)} $).`;
      for (const uid of members) {
        await sendToUser(uid, "pot_alert", "Cagnotte sous surveillance", body);
      }
    }

    // Alerte d'enveloppe : la dépense dans cette catégorie vient de franchir
    // le seuil configuré de l'enveloppe de budget variable.
    //
    // Vaut pour les enveloppes solo (la personne du siège est seule
    // prévenue) comme pour les enveloppes communes (les deux membres le
    // sont — la cagnotte est partagée, la nouvelle concerne les deux).
    if ((assignedToSolo || assignedToCommon) &&
        after.is_investment !== true &&
        amount > 0) {
      const seat = afterBucket === "Solo_A" ? "A" : "B";
      const envelopes = (assignedToCommon
        ? (hd.common_envelopes ?? {})
        : (hd[`solo_envelopes_${seat}`] ?? {})) as Record<string, number>;
      const category = (after.category as string) || "OTHER";
      const budget = envelopes[category] ?? 0;
      const soloUid =
        seat === "A" ? (hd.user_A_id ?? hd.created_by) : hd.user_B_id;
      // Chacun garde SON seuil : on évalue le franchissement par personne.
      const recipients: string[] = assignedToCommon
        ? await householdMemberIds(hd)
        : soloUid
          ? [soloUid]
          : [];

      if (budget > 0 && recipients.length > 0) {
        // Dépense du mois dans cette catégorie (après cette assignation).
        const now = new Date();
        const monthStart = `${now.getUTCFullYear()}-${String(
          now.getUTCMonth() + 1
        ).padStart(2, "0")}-01`;
        const snap = await db
          .collection("transactions")
          .where("household_id", "==", householdId)
          .where("assigned_to_bucket", "==", afterBucket)
          .where("date", ">=", monthStart)
          // orderBy explicite : sans lui Firestore trierait par `date`
          // ASCENDANT et réclamerait un index absent, au lieu de
          // (household_id, assigned_to_bucket, date DESC) déjà déployé.
          .orderBy("date", "desc")
          .get();
        let spentAfter = 0;
        snap.forEach((d) => {
          const t = d.data();
          if (((t.category as string) || "OTHER") !== category) return;
          if (t.is_investment === true) return;
          const a = typeof t.amount === "number" ? t.amount : 0;
          if (a > 0) spentAfter += a;
        });
        const spentBefore = spentAfter - amount;
        const catLabel = CATEGORY_LABEL_FR[category] ?? category;
        const depleted = spentAfter >= budget;
        const amounts = `${spentAfter.toFixed(0)} / ${budget.toFixed(0)} $`;
        const body = assignedToCommon
          ? depleted
            ? `Votre enveloppe commune « ${catLabel} » est épuisée (${amounts}).`
            : `Votre enveloppe commune « ${catLabel} » est presque épuisée (${amounts}).`
          : depleted
            ? `Ton enveloppe « ${catLabel} » est épuisée (${amounts}).`
            : `Ton enveloppe « ${catLabel} » est presque épuisée (${amounts}).`;

        for (const uid of recipients) {
          const user = (await db.collection("users").doc(uid).get()).data();
          const pct =
            typeof user?.notif_envelope_pct === "number"
              ? user.notif_envelope_pct
              : 0.9;
          const threshold = budget * pct;
          // Franchissement vers le haut uniquement : une seule alerte.
          if (spentBefore < threshold && spentAfter >= threshold) {
            await sendToUser(uid, "envelope_alert", "Budget variable", body);
          }
        }
      }
    }
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

  // Prévient l'autre membre : un règlement le concerne directement.
  const hd = (await householdRef.get()).data() ?? {};
  const members = await householdMemberIds(hd);
  const settlerName =
    (hd.user_A_id ?? hd.created_by) === uid
      ? (hd.user_A_name as string) || "Votre partenaire"
      : (hd.user_B_name as string) || "Votre partenaire";
  for (const memberId of members) {
    if (memberId === uid) continue;
    await sendToUser(
      memberId,
      "partner",
      "Dette réglée",
      `${settlerName} a réglé la dette interne (${Math.abs(settled).toFixed(2)} $).`
    );
  }

  return { success: true, amount_settled: Math.abs(settled) };
});
