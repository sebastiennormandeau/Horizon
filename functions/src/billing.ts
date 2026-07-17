import * as functions from "firebase-functions";
import { admin, db } from "./init";

/**
 * Webhook RevenueCat : source de vérité serveur pour le statut d'abonnement.
 * https://www.revenuecat.com/docs/integrations/webhooks
 *
 * Configuration côté RevenueCat :
 *   URL   : https://us-central1-<projet>.cloudfunctions.net/revenueCatWebhook
 *   Header Authorization : la valeur du secret REVENUECAT_WEBHOOK_AUTH
 *   (créer avec : firebase functions:secrets:set REVENUECAT_WEBHOOK_AUTH)
 */
export const revenueCatWebhook = functions
  .runWith({ secrets: ["REVENUECAT_WEBHOOK_AUTH"] })
  .https.onRequest(async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }

    const expected = process.env.REVENUECAT_WEBHOOK_AUTH;
    if (!expected || req.headers.authorization !== expected) {
      console.warn("Webhook RevenueCat rejeté : autorisation invalide.");
      res.status(401).send("Unauthorized");
      return;
    }

    try {
      const event = req.body?.event;
      if (!event || typeof event.app_user_id !== "string") {
        res.status(400).send("Bad Request");
        return;
      }

      // L'app_user_id RevenueCat est l'UID Firebase (Purchases.logIn côté client).
      const uid: string = event.app_user_id;
      const type: string = event.type ?? "";

      const grantTypes = [
        "INITIAL_PURCHASE",
        "RENEWAL",
        "UNCANCELLATION",
        "PRODUCT_CHANGE",
        "NON_RENEWING_PURCHASE",
        "SUBSCRIPTION_EXTENDED",
      ];
      const revokeTypes = ["EXPIRATION"];

      let tier: "premium" | "free" | null = null;
      if (grantTypes.includes(type)) tier = "premium";
      else if (revokeTypes.includes(type)) tier = "free";

      if (tier === null) {
        // CANCELLATION (auto-renouvellement désactivé mais encore actif),
        // BILLING_ISSUE, TEST, etc. : aucun changement d'accès immédiat.
        res.status(200).send("Ignored");
        return;
      }

      const userRef = db.collection("users").doc(uid);
      const userSnap = await userRef.get();
      if (!userSnap.exists) {
        console.warn(`Webhook RevenueCat : utilisateur inconnu ${uid}`);
        res.status(200).send("Unknown user");
        return;
      }

      await userRef.set({ subscription_tier: tier }, { merge: true });

      const householdId = userSnap.data()?.household_id as string | undefined;
      if (householdId) {
        await db.collection("households").doc(householdId).set(
          {
            subscription_tier: tier,
            updated_at: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
      }

      console.log(`Abonnement ${tier} appliqué à ${uid} (événement ${type}).`);
      res.status(200).send("OK");
    } catch (error) {
      console.error("Erreur webhook RevenueCat:", error);
      res.status(500).send("Erreur interne");
    }
  });

/**
 * Rollover mensuel : le 1er de chaque mois à 6 h (heure de l'Est), copie le
 * budget du mois précédent vers le nouveau mois et recalcule les cagnottes.
 * La dette interne n'est jamais réinitialisée.
 */
export const monthlyRollover = functions.pubsub
  .schedule("0 6 1 * *")
  .timeZone("America/Toronto")
  .onRun(async () => {
    const now = new Date();
    const currentMonth = `${now.getFullYear()}-${String(
      now.getMonth() + 1
    ).padStart(2, "0")}`;
    const prev = new Date(now.getFullYear(), now.getMonth() - 1, 1);
    const previousMonth = `${prev.getFullYear()}-${String(
      prev.getMonth() + 1
    ).padStart(2, "0")}`;

    const households = await db.collection("households").get();
    let rolled = 0;

    for (const householdDoc of households.docs) {
      try {
        const budgets = householdDoc.ref.collection("monthly_budgets");
        const [currentSnap, prevSnap] = await Promise.all([
          budgets.doc(currentMonth).get(),
          budgets.doc(previousMonth).get(),
        ]);

        if (currentSnap.exists || !prevSnap.exists) continue;

        const b = prevSnap.data()!;
        const sum = (items: unknown): number =>
          Array.isArray(items)
            ? items.reduce(
                (acc: number, item: { amount?: number }) =>
                  acc + (typeof item?.amount === "number" ? item.amount : 0),
                0
              )
            : 0;

        const incomeA: number = b.income_A ?? 0;
        const incomeB: number = b.income_B ?? 0;
        const ratioA: number = b.split_ratio_A ?? 50;
        const net = sum(b.fixed_expenses) - sum(b.deductions);
        const contributionA = net * (ratioA / 100);
        const contributionB = net * ((100 - ratioA) / 100);

        await budgets.doc(currentMonth).set({
          ...b,
          rolled_over_from: previousMonth,
          updated_at: admin.firestore.FieldValue.serverTimestamp(),
        });

        await householdDoc.ref.update({
          safe_to_spend_common: net,
          safe_to_spend_solo_A: incomeA - contributionA,
          safe_to_spend_solo_B: incomeB - contributionB,
          updated_at: admin.firestore.FieldValue.serverTimestamp(),
        });
        rolled++;
      } catch (e) {
        console.error(`Rollover échoué pour le foyer ${householdDoc.id}:`, e);
      }
    }

    console.log(
      `Rollover mensuel ${currentMonth} : ${rolled} foyer(s) mis à jour.`
    );
  });
