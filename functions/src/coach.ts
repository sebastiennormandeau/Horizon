import * as functions from "firebase-functions";
import Anthropic from "@anthropic-ai/sdk";
import { admin, db } from "./init";
import { requireAuth, enforceRateLimit, assertString } from "./security";

/**
 * Coach budgétaire IA.
 *
 * Principe : les CHIFFRES viennent du moteur de bilans (reports.ts,
 * déterministe) ; l'IA ne fait que rédiger des observations et suggestions
 * à partir de ces agrégats. Aucune donnée bancaire brute, aucun identifiant
 * personnel n'est transmis — uniquement des totaux par catégorie, des noms
 * de commerçants et des tendances.
 *
 * Configuration :
 *  - Secret ANTHROPIC_API_KEY (Google Secret Manager)
 *  - functions/.env : AI_COACH_REQUIRE_PREMIUM=true|false
 */

const SYSTEM_PROMPT = `Tu es le coach budgétaire de l'application Horizon, une app québécoise de gestion de finances pour les couples (méthode Zero-Based Budgeting : cagnottes « Solo A », « Solo B » et « Commun »).

Tu reçois un JSON contenant les agrégats de dépenses d'un foyer pour une période (totaux par catégorie, comparaison avec la période précédente, principaux commerçants, dépenses récurrentes détectées, état des cagnottes). Rédige un court bilan personnalisé en français québécois, chaleureux et sans jugement, en tutoyant.

Structure exacte de ta réponse (markdown) :
## Ce qui ressort
2 à 3 observations factuelles tirées des chiffres fournis (tendances marquantes, catégories en hausse/baisse, cagnottes sous pression).

## Suggestions concrètes
2 à 3 suggestions actionnables et chiffrées, basées uniquement sur les données (ex. réduire une catégorie précise d'un montant réaliste, budgéter une récurrence détectée, rééquilibrer une cagnotte). Inclure au moins un principe de saine gestion pertinent (fonds d'urgence, règle des 24 h avant un achat impulsif, etc.) relié à leurs chiffres.

## Le mot d'encouragement
1 ou 2 phrases positives qui soulignent un progrès réel visible dans les données.

Règles strictes :
- Base-toi UNIQUEMENT sur les chiffres fournis; n'invente aucun montant ni aucune donnée.
- Maximum 250 mots au total.
- Ne recommande JAMAIS de produits financiers, de placements, de crédits ou d'institutions précises. Tu donnes des conseils d'organisation budgétaire, pas des conseils financiers professionnels.
- Si les données sont trop minces (peu de transactions), dis-le simplement et donne un conseil général de démarrage.`;

function getAnthropicClient(): Anthropic {
  const apiKey = process.env.ANTHROPIC_API_KEY;
  if (!apiKey || apiKey === "REPLACE_ME") {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Le coach IA n'est pas encore configuré (clé API manquante)."
    );
  }
  return new Anthropic({ apiKey });
}

export const generateCoachAdvice = functions
  .runWith({ secrets: ["ANTHROPIC_API_KEY"], timeoutSeconds: 120 })
  .https.onCall(async (data, context) => {
    const uid = requireAuth(context);
    // Contrôle des coûts : 5 générations par jour et par utilisateur.
    await enforceRateLimit("generateCoachAdvice", uid, 5, 86400);

    const reportId = assertString(data?.report_id, "report_id", {
      maxLength: 16,
      pattern: /^[0-9]{4}-(W?[0-9]{2})$/,
    });

    const userSnap = await db.collection("users").doc(uid).get();
    const householdId = userSnap.data()?.household_id as string | undefined;
    if (!householdId) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Vous ne faites partie d'aucun foyer."
      );
    }

    const householdRef = db.collection("households").doc(householdId);
    const householdSnap = await householdRef.get();
    const household = householdSnap.data() ?? {};

    // Gating Premium (désactivable en dev via functions/.env).
    const requirePremium = process.env.AI_COACH_REQUIRE_PREMIUM === "true";
    if (requirePremium && household.subscription_tier !== "premium") {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Le coach IA est réservé à Horizon Premium."
      );
    }

    const reportRef = householdRef.collection("reports").doc(reportId);
    const reportSnap = await reportRef.get();
    if (!reportSnap.exists) {
      throw new functions.https.HttpsError(
        "not-found",
        "Bilan introuvable. Générez d'abord le bilan."
      );
    }
    const report = reportSnap.data()!;

    // Agrégats uniquement — aucune transaction brute, aucun identifiant.
    const payload = {
      periode: {
        type: report.period_type,
        id: reportId,
      },
      depenses_totales: report.total_spent,
      depenses_periode_precedente: report.prev_total_spent,
      nombre_transactions: report.transaction_count,
      par_categorie: report.by_category,
      par_categorie_precedente: report.prev_by_category,
      par_cagnotte: report.by_bucket,
      principaux_commercants: report.top_merchants,
      recurrences_detectees: report.recurring_suggestions,
      etat_cagnottes: {
        solo_A: household.safe_to_spend_solo_A ?? 0,
        commun: household.safe_to_spend_common ?? 0,
        solo_B: household.safe_to_spend_solo_B ?? 0,
        dette_interne: household.internal_debt_balance ?? 0,
      },
    };

    const anthropic = getAnthropicClient();

    try {
      const message = await anthropic.messages.create({
        model: "claude-opus-4-8",
        max_tokens: 2048,
        system: SYSTEM_PROMPT,
        messages: [
          {
            role: "user",
            content:
              "Voici les agrégats du bilan du foyer. Rédige le bilan " +
              `personnalisé.\n\n${JSON.stringify(payload)}`,
          },
        ],
      });

      const advice = message.content
        .filter((block) => block.type === "text")
        .map((block) => (block as { text: string }).text)
        .join("\n")
        .trim();

      if (!advice) {
        throw new functions.https.HttpsError(
          "internal",
          "Le coach n'a pas pu générer de conseils. Réessayez."
        );
      }

      await reportRef.update({
        ai_advice: advice,
        ai_advice_at: admin.firestore.FieldValue.serverTimestamp(),
      });

      return { success: true };
    } catch (error) {
      if (error instanceof functions.https.HttpsError) throw error;
      console.error("Erreur du coach IA:", error);
      throw new functions.https.HttpsError(
        "internal",
        "Le coach IA est momentanément indisponible."
      );
    }
  });
