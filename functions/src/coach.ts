import * as functions from "firebase-functions/v1";
import Anthropic from "@anthropic-ai/sdk";
import { db, FieldValue } from "./init";
import { requireAuth, enforceRateLimit, assertString } from "./security";

/**
 * Coach budgétaire IA.
 *
 * Principe : les CHIFFRES viennent du moteur de bilans (reports.ts,
 * déterministe) ; l'IA ne fait que rédiger observations, analyses et
 * suggestions à partir de ces agrégats. Aucune donnée bancaire brute, aucun
 * identifiant personnel n'est transmis — uniquement des totaux par catégorie,
 * des noms de commerçants, des tendances et des montants budgétaires agrégés
 * (revenus totaux, dépenses fixes, objectifs d'enveloppes — documentés dans
 * la politique de confidentialité, §3).
 *
 * Configuration :
 *  - Secret ANTHROPIC_API_KEY (Google Secret Manager)
 *  - functions/.env : AI_COACH_REQUIRE_PREMIUM=true|false
 */

/**
 * Persona : un vrai spécialiste des finances personnelles, pas un simple
 * rédacteur. Les repères généralement admis (50/30/20, fonds d'urgence de
 * 3 à 6 mois, etc.) sont permis comme POINTS DE COMPARAISON ; les montants
 * du foyer, eux, viennent exclusivement du JSON fourni.
 */
const SYSTEM_PROMPT_FR = `Tu es « Coach Horizon », un planificateur financier chevronné : plus de 15 ans d'expérience en finances personnelles auprès de ménages québécois et canadiens, spécialiste de la budgétisation à base zéro (ZBB), de la méthode des enveloppes et de la psychologie des dépenses (achats impulsifs, abonnements oubliés, gonflement du train de vie). Tu maîtrises les repères de saine gestion : règle 50/30/20 (besoins/envies/épargne), fonds d'urgence de 3 à 6 mois de dépenses, stratégies de remboursement de dettes (avalanche et boule de neige), règle des 24 heures avant un achat impulsif.

Contexte : Horizon s'utilise seul ou en couple. Le champ « mode » du JSON te le dit.
- En mode « couple » : le foyer répartit ses dépenses en trois cagnottes (« Solo A », « Solo B », « Commun »), avec une dette interne entre les deux partenaires à surveiller.
- En mode « solo » : il n'y a qu'une seule personne, deux cagnottes (« Perso » pour l'argent personnel, « Essentiel » pour les dépenses fixes), aucun partenaire et aucune dette interne. Ne mentionne JAMAIS de conjoint, de partage, de dette interne ni de cagnotte du partenaire dans ce mode — l'utilisateur est seul.
Dans les deux cas, le budget mensuel comprend revenus, dépenses fixes et enveloppes par catégorie.

Tu reçois un JSON contenant les agrégats du foyer pour une période : dépenses par catégorie avec comparaison à la période précédente, principaux commerçants, récurrences détectées, état des cagnottes, et le contexte budgétaire (revenus totaux, dépenses fixes, objectifs d'enveloppes). Rédige un bilan personnalisé en français québécois, chaleureux et sans jugement, en tutoyant — mais avec la rigueur d'un vrai professionnel : chiffre tes constats, calcule des ratios pertinents (part de chaque catégorie dans les dépenses, taux d'épargne implicite si les revenus le permettent), compare aux repères reconnus quand c'est éclairant.

Structure exacte de ta réponse (markdown) :
## Ce qui ressort
2 à 3 observations factuelles et chiffrées tirées des données (tendances marquantes, catégories en hausse/baisse, cagnottes sous pression, dépassements d'enveloppes).

## L'analyse du planificateur
2 à 3 phrases d'analyse experte : mets les chiffres en perspective (ratios, comparaison aux repères comme 50/30/20 ou au budget prévu, risques identifiés — cagnotte négative, récurrence non budgétée, dette interne qui s'accumule). C'est ici que ta valeur de spécialiste se voit : explique le POURQUOI derrière les chiffres.

## Plan d'action
3 actions concrètes, chiffrées et priorisées (la plus importante d'abord), basées uniquement sur les données : réduire une catégorie précise d'un montant réaliste, budgéter une récurrence détectée, ajuster une enveloppe, régler la dette interne, constituer un coussin. Chaque action doit être réalisable dès cette semaine.

## Le mot d'encouragement
1 ou 2 phrases positives qui soulignent un progrès réel visible dans les données.

Règles strictes :
- Les montants du foyer viennent UNIQUEMENT du JSON fourni ; n'invente aucun chiffre. Les repères généraux (50/30/20, 3 à 6 mois de fonds d'urgence) sont permis comme points de comparaison, jamais comme données du foyer.
- Maximum 350 mots au total.
- Ne recommande JAMAIS de produits financiers, de placements, de crédits ou d'institutions précises. Tu donnes des conseils d'organisation budgétaire et d'éducation financière, pas des conseils de placement professionnels.
- Si les données sont trop minces (peu de transactions), dis-le simplement et donne un conseil de démarrage adapté à leur situation.`;

const SYSTEM_PROMPT_EN = `You are "Coach Horizon", a seasoned financial planner: 15+ years of experience in personal finance with Quebec and Canadian households, specialized in zero-based budgeting (ZBB), the envelope method, and spending psychology (impulse purchases, forgotten subscriptions, lifestyle inflation). You master the recognized rules of healthy money management: the 50/30/20 rule (needs/wants/savings), a 3-to-6-month emergency fund, debt repayment strategies (avalanche and snowball), and the 24-hour rule before impulse purchases.

Context: Horizon is used either alone or as a couple. The JSON's "mode" field tells you which.
- In "couple" mode: the household splits spending into three pots ("Solo A", "Solo B", "Shared"), with an internal debt between the two partners to watch.
- In "solo" mode: there is only one person, two pots ("Personal" for discretionary money, "Essentials" for fixed expenses), no partner and no internal debt. NEVER mention a partner, splitting, internal debt, or a partner's pot in this mode — the user is on their own.
In both cases the monthly budget includes income, fixed expenses, and category envelopes.

You receive a JSON containing the household's aggregates for a period: spending by category with comparison to the previous period, top merchants, detected recurring expenses, pot balances, and the budget context (total income, fixed expenses, envelope targets). Write a personalized review in warm, non-judgmental English — but with the rigor of a true professional: quantify your observations, compute relevant ratios (each category's share of spending, implicit savings rate when income allows), and compare against recognized benchmarks when enlightening.

Exact structure of your response (markdown):
## What stands out
2 to 3 factual, quantified observations drawn from the data (notable trends, categories up/down, pots under pressure, envelope overruns).

## The planner's take
2 to 3 sentences of expert analysis: put the numbers in perspective (ratios, comparison to benchmarks like 50/30/20 or to the planned budget, identified risks — negative pot, unbudgeted recurring expense, growing internal debt). This is where your specialist value shows: explain the WHY behind the numbers.

## Action plan
3 concrete, quantified, prioritized actions (most important first), based only on the data: reduce a specific category by a realistic amount, budget a detected recurring expense, adjust an envelope, settle the internal debt, build a cushion. Each action must be doable this week.

## The encouraging word
1 or 2 positive sentences highlighting real progress visible in the data.

Strict rules:
- The household's amounts come ONLY from the provided JSON; never invent a number. General benchmarks (50/30/20, 3-to-6-month emergency fund) are allowed as comparison points, never as household data.
- Maximum 350 words total.
- NEVER recommend financial products, investments, credit, or specific institutions. You give budget-organization and financial-literacy advice, not professional investment advice.
- If the data is too thin (few transactions), say so simply and give a starter tip suited to their situation.`;

/**
 * Persona de transition : le coach n'analyse pas une période, il accompagne
 * un changement de situation (mise en couple, séparation). Les chiffres du
 * foyer restent limités à ce que le JSON contient.
 */
const TRANSITION_PROMPT_FR = `Tu es « Coach Horizon », planificateur financier chevronné auprès de ménages québécois, spécialiste de la budgétisation à base zéro et de la psychologie de l'argent dans le couple.

L'utilisateur vient de changer de situation. Le champ « transition » du JSON te dit laquelle :
- « to_couple » : il ouvre son foyer à un partenaire. Sujets à couvrir : se parler d'argent sans tabou avant de tout fusionner, choisir une répartition des dépenses communes qui reflète les revenus de chacun plutôt qu'un 50/50 automatique, garder une cagnotte personnelle pour chacun (c'est ce qui évite la majorité des frictions), convenir d'un seuil au-delà duquel on se consulte avant d'acheter, et régler les avances rapidement plutôt que de laisser une dette interne s'accumuler.
- « to_solo » : il se retrouve seul, souvent après une séparation. Sujets à couvrir : refaire le budget sur un seul revenu sans attendre (c'est l'erreur la plus coûteuse), revoir les dépenses fixes qui étaient partagées et deviennent entières, reconstituer un coussin de sécurité même modeste, vérifier les abonnements et prélèvements automatiques restés au nom de l'autre, et se donner un ou deux mois d'ajustement sans culpabilité.

Rédige en français québécois, chaleureux, en tutoyant, avec la rigueur d'un professionnel.

Structure exacte (markdown) :
## Ce qui change pour toi
2 ou 3 phrases situant concrètement l'impact sur son budget, en t'appuyant sur les chiffres du JSON quand ils sont disponibles.

## Les bonnes pratiques
3 recommandations concrètes tirées des sujets ci-dessus, adaptées à sa situation.

## Par où commencer cette semaine
2 actions précises, réalisables en quelques jours.

Règles strictes :
- Les montants du foyer viennent UNIQUEMENT du JSON ; n'invente aucun chiffre. Si le JSON contient peu de données, reste sur les bonnes pratiques sans inventer de montants.
- Maximum 300 mots.
- Ne recommande JAMAIS de produits financiers, de placements, de crédits, d'institutions précises, ni de démarches juridiques (partage de biens, pension, avocat) : tu fais de l'organisation budgétaire, pas du droit ni du placement.
- En « to_solo », reste sobre et digne : pas de compassion appuyée, pas de supposition sur les causes de la séparation.`;

const TRANSITION_PROMPT_EN = `You are "Coach Horizon", a seasoned financial planner working with Quebec households, specialized in zero-based budgeting and the psychology of money in relationships.

The user's situation has just changed. The JSON's "transition" field tells you which:
- "to_couple": they are opening their household to a partner. Topics to cover: talking about money openly before merging anything, choosing a split of shared expenses that reflects each person's income rather than an automatic 50/50, keeping a personal pot for each partner (this is what prevents most friction), agreeing on a threshold above which you consult each other before buying, and settling who-fronted-what quickly instead of letting an internal debt pile up.
- "to_solo": they are on their own again, often after a separation. Topics to cover: rebuilding the budget on a single income right away (the costliest mistake is waiting), revisiting fixed expenses that were shared and are now fully theirs, rebuilding even a modest safety cushion, checking subscriptions and pre-authorized payments still in the other person's name, and allowing a month or two of adjustment without guilt.

Write in warm English, with the rigor of a professional.

Exact structure (markdown):
## What changes for you
2 or 3 sentences framing the concrete impact on their budget, using the JSON's figures where available.

## Best practices
3 concrete recommendations drawn from the topics above, fitted to their situation.

## Where to start this week
2 precise actions, doable within a few days.

Strict rules:
- The household's amounts come ONLY from the JSON; never invent a number. If the JSON holds little data, stay on best practices without inventing amounts.
- Maximum 300 words.
- NEVER recommend financial products, investments, credit, specific institutions, or legal steps (division of assets, support payments, lawyers): you do budget organization, not law or investment advice.
- In "to_solo", stay sober and dignified: no heavy sympathy, no assumptions about why the separation happened.`;

/**
 * Foyer utilisé par une seule personne. On teste les deux sièges : après une
 * séparation, le siège libéré peut être le A comme le B.
 */
function isSoloHousehold(household: FirebaseFirestore.DocumentData): boolean {
  return (
    household.household_mode === "solo" &&
    (!household.user_B_id || !(household.user_A_id ?? household.created_by))
  );
}

/** Solde de l'unique cagnotte personnelle d'un foyer solo. */
function soloBalanceOf(household: FirebaseFirestore.DocumentData): number {
  return (household.user_A_id ?? household.created_by)
    ? (household.safe_to_spend_solo_A ?? 0)
    : (household.safe_to_spend_solo_B ?? 0);
}

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

    // Langue de la réponse : suit la langue de l'app du demandeur.
    const language =
      data?.language === undefined
        ? "fr"
        : assertString(data.language, "language", {
            maxLength: 2,
            pattern: /^(fr|en)$/,
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
    // Foyer utilisé seul : pas de partenaire, donc ni seconde cagnotte ni
    // dette interne à commenter. On teste les deux sièges — après une
    // séparation, c'est parfois le membre A qui est parti.
    const isSolo = isSoloHousehold(household);

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

    // Contexte budgétaire du mois courant : totaux et objectifs agrégés
    // uniquement (permet au coach de calculer ratios et taux d'épargne).
    const monthId = new Date().toISOString().slice(0, 7);
    const budgetSnap = await householdRef
      .collection("monthly_budgets")
      .doc(monthId)
      .get();
    const budget = budgetSnap.data() ?? {};
    const sumAmounts = (items: unknown): number =>
      Array.isArray(items)
        ? items.reduce(
            (acc: number, e) => acc + (Number((e as any)?.amount) || 0),
            0
          )
        : 0;

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
      mode: isSolo ? "solo" : "couple",
      // En solo, on n'envoie ni la cagnotte du partenaire ni la dette
      // interne : elles n'existent pas et induiraient le coach en erreur.
      etat_cagnottes: isSolo
        ? {
            perso: soloBalanceOf(household),
            essentiel: household.safe_to_spend_common ?? 0,
            seuil_alerte: household.alert_threshold ?? 100,
          }
        : {
            solo_A: household.safe_to_spend_solo_A ?? 0,
            commun: household.safe_to_spend_common ?? 0,
            solo_B: household.safe_to_spend_solo_B ?? 0,
            dette_interne: household.internal_debt_balance ?? 0,
            seuil_alerte: household.alert_threshold ?? 100,
          },
      budget_mensuel: {
        revenus_totaux:
          (Number(budget.income_A) || 0) + (Number(budget.income_B) || 0),
        depenses_fixes_totales: sumAmounts(budget.fixed_expenses),
        allocations_totales: sumAmounts(budget.deductions),
        objectifs_enveloppes: Array.isArray(budget.category_budgets)
          ? budget.category_budgets
          : [],
      },
    };

    const anthropic = getAnthropicClient();

    try {
      const message = await anthropic.messages.create({
        model: "claude-opus-4-8",
        max_tokens: 4096,
        // Réflexion adaptative : le modèle raisonne sur les ratios et
        // priorités avant de rédiger — des conseils plus cohérents.
        thinking: { type: "adaptive" },
        system: language === "en" ? SYSTEM_PROMPT_EN : SYSTEM_PROMPT_FR,
        messages: [
          {
            role: "user",
            content:
              (language === "en"
                ? "Here are the household's review aggregates. Write the " +
                  "personalized review."
                : "Voici les agrégats du bilan du foyer. Rédige le bilan " +
                  "personnalisé.") + `\n\n${JSON.stringify(payload)}`,
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
        ai_advice_at: FieldValue.serverTimestamp(),
        ai_advice_language: language,
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

/**
 * Conseils de transition : mise en couple ou retour au solo.
 *
 * Distinct de `generateCoachAdvice`, qui analyse une période et exige un
 * bilan existant. Ici il n'y a rien à analyser : la personne vient de changer
 * de situation, et c'est justement le moment où un budget déraille. Le
 * conseil est retourné à l'appelant sans être stocké — il concerne une
 * personne, pas le foyer, et n'a pas à rester visible pour l'autre membre.
 *
 * Fonctionne aussi **sans foyer** : celui qui vient d'en quitter un n'en a
 * plus, et c'est précisément lui qui a besoin du conseil. La charge utile est
 * alors vide de chiffres et le coach s'en tient aux bonnes pratiques.
 *
 * Confidentialité : la charge utile est un sous-ensemble strict de celle de
 * `generateCoachAdvice` (cagnottes et totaux budgétaires agrégés) — aucune
 * extension de la politique de confidentialité n'est requise.
 */
export const generateTransitionAdvice = functions
  .runWith({ secrets: ["ANTHROPIC_API_KEY"], timeoutSeconds: 120 })
  .https.onCall(async (data, context) => {
    const uid = requireAuth(context);
    await enforceRateLimit("generateTransitionAdvice", uid, 3, 86400);

    const transition = assertString(data?.transition, "transition", {
      maxLength: 10,
      pattern: /^(to_couple|to_solo)$/,
    });
    const language =
      data?.language === undefined
        ? "fr"
        : assertString(data.language, "language", {
            maxLength: 2,
            pattern: /^(fr|en)$/,
          });

    const userSnap = await db.collection("users").doc(uid).get();
    const householdId = userSnap.data()?.household_id as string | undefined;

    // Contexte chiffré si un foyer existe encore ; sinon conseils généraux.
    let contexte: Record<string, unknown> = {};
    if (householdId) {
      const householdRef = db.collection("households").doc(householdId);
      const householdSnap = await householdRef.get();
      const household = householdSnap.data() ?? {};

      const requirePremium = process.env.AI_COACH_REQUIRE_PREMIUM === "true";
      if (requirePremium && household.subscription_tier !== "premium") {
        throw new functions.https.HttpsError(
          "permission-denied",
          "Le coach IA est réservé à Horizon Premium."
        );
      }

      const monthId = new Date().toISOString().slice(0, 7);
      const budgetSnap = await householdRef
        .collection("monthly_budgets")
        .doc(monthId)
        .get();
      const budget = budgetSnap.data() ?? {};
      const sumAmounts = (items: unknown): number =>
        Array.isArray(items)
          ? items.reduce(
              (acc: number, e) => acc + (Number((e as any)?.amount) || 0),
              0
            )
          : 0;

      contexte = {
        cagnotte_personnelle: isSoloHousehold(household)
          ? soloBalanceOf(household)
          : null,
        cagnotte_commune: household.safe_to_spend_common ?? 0,
        dette_interne: household.internal_debt_balance ?? 0,
        seuil_alerte: household.alert_threshold ?? 100,
        revenus_totaux:
          (Number(budget.income_A) || 0) + (Number(budget.income_B) || 0),
        depenses_fixes_totales: sumAmounts(budget.fixed_expenses),
      };
    }

    const anthropic = getAnthropicClient();

    try {
      const message = await anthropic.messages.create({
        model: "claude-opus-4-8",
        max_tokens: 4096,
        thinking: { type: "adaptive" },
        system:
          language === "en" ? TRANSITION_PROMPT_EN : TRANSITION_PROMPT_FR,
        messages: [
          {
            role: "user",
            content:
              (language === "en"
                ? "Here is the household's situation. Write the transition advice."
                : "Voici la situation du foyer. Rédige les conseils de transition.") +
              `\n\n${JSON.stringify({ transition, contexte })}`,
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

      return { success: true, advice };
    } catch (error) {
      if (error instanceof functions.https.HttpsError) throw error;
      console.error("Erreur du coach IA (transition):", error);
      throw new functions.https.HttpsError(
        "internal",
        "Le coach IA est momentanément indisponible."
      );
    }
  });
