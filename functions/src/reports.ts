import * as functions from "firebase-functions/v1";
import { db, FieldValue, Timestamp } from "./init";
import { requireAuth, enforceRateLimit, assertString } from "./security";

/**
 * Moteur de bilans : agrège les transactions par catégorie/bucket/commerçant
 * pour une période (semaine ou mois), compare à la période précédente et
 * détecte les dépenses récurrentes candidates au budget fixe.
 *
 * Les chiffres sont TOUJOURS calculés ici (déterministe) — jamais par l'IA.
 * Documents produits : households/{id}/reports/{periodId}
 *   periodId = "2026-07" (mensuel) ou "2026-W29" (hebdomadaire)
 */

// Catégories « entrées d'argent » exclues du total des dépenses.
const NON_SPENDING_CATEGORIES = ["INCOME", "TRANSFER_IN"];

// Mouvements internes (paiement de carte, virement entre ses comptes). Déjà
// sans effet sur les cagnottes, ils doivent aussi sortir des bilans : sinon
// le paiement d'une carte gonflerait le total des dépenses alors que les
// achats correspondants y figurent déjà.
const TRANSFER_BUCKET = "Transfer";

interface PeriodBounds {
  id: string;
  start: Date;
  end: Date;
  prevId: string;
  prevStart: Date;
  prevEnd: Date;
}

function isoWeekId(d: Date): string {
  const date = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()));
  const dayNum = (date.getUTCDay() + 6) % 7; // lundi = 0
  date.setUTCDate(date.getUTCDate() - dayNum + 3); // jeudi de la semaine ISO
  const firstThursday = new Date(Date.UTC(date.getUTCFullYear(), 0, 4));
  const ftDayNum = (firstThursday.getUTCDay() + 6) % 7;
  firstThursday.setUTCDate(firstThursday.getUTCDate() - ftDayNum + 3);
  const week =
    1 + Math.round((date.getTime() - firstThursday.getTime()) / (7 * 86400000));
  return `${date.getUTCFullYear()}-W${String(week).padStart(2, "0")}`;
}

function startOfWeek(d: Date): Date {
  const x = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()));
  x.setUTCDate(x.getUTCDate() - ((x.getUTCDay() + 6) % 7));
  return x;
}

/** Bornes de la période contenant `ref` + de la période précédente. */
export function periodBounds(periodType: "weekly" | "monthly", ref: Date): PeriodBounds {
  if (periodType === "monthly") {
    const start = new Date(Date.UTC(ref.getUTCFullYear(), ref.getUTCMonth(), 1));
    const end = new Date(Date.UTC(ref.getUTCFullYear(), ref.getUTCMonth() + 1, 1));
    const prevStart = new Date(Date.UTC(ref.getUTCFullYear(), ref.getUTCMonth() - 1, 1));
    const id = `${start.getUTCFullYear()}-${String(start.getUTCMonth() + 1).padStart(2, "0")}`;
    const prevId = `${prevStart.getUTCFullYear()}-${String(prevStart.getUTCMonth() + 1).padStart(2, "0")}`;
    return { id, start, end, prevId, prevStart, prevEnd: start };
  }
  const start = startOfWeek(ref);
  const end = new Date(start.getTime() + 7 * 86400000);
  const prevStart = new Date(start.getTime() - 7 * 86400000);
  return {
    id: isoWeekId(start),
    start,
    end,
    prevId: isoWeekId(prevStart),
    prevStart,
    prevEnd: start,
  };
}

interface TxRow {
  amount: number;
  merchant: string;
  category: string;
  bucket: string;
  createdAt: Date;
}

async function fetchTransactions(
  householdId: string,
  from: Date,
  to: Date
): Promise<TxRow[]> {
  const snap = await db
    .collection("transactions")
    .where("household_id", "==", householdId)
    .where("created_at", ">=", Timestamp.fromDate(from))
    .where("created_at", "<", Timestamp.fromDate(to))
    .orderBy("created_at", "desc")
    .limit(3000)
    .get();

  return snap.docs.map((d) => {
    const data = d.data();
    return {
      amount: typeof data.amount === "number" ? data.amount : 0,
      merchant: (data.merchant_name as string) || "Inconnu",
      category: (data.category as string) || "OTHER",
      bucket: (data.assigned_to_bucket as string) || "",
      createdAt:
        (data.created_at as Timestamp | undefined)?.toDate() ??
        new Date(0),
    };
  });
}

function aggregate(rows: TxRow[]) {
  let total = 0;
  const byCategory: Record<string, number> = {};
  const byBucket: Record<string, number> = {};
  const merchants: Record<string, { amount: number; count: number }> = {};

  for (const t of rows) {
    if (t.amount <= 0) continue; // remboursements / entrées
    if (t.bucket === TRANSFER_BUCKET) continue;
    if (NON_SPENDING_CATEGORIES.includes(t.category)) continue;
    total += t.amount;
    byCategory[t.category] = (byCategory[t.category] ?? 0) + t.amount;
    const bucketKey = t.bucket === "" ? "Unassigned" : t.bucket;
    byBucket[bucketKey] = (byBucket[bucketKey] ?? 0) + t.amount;
    const m = merchants[t.merchant] ?? { amount: 0, count: 0 };
    m.amount += t.amount;
    m.count += 1;
    merchants[t.merchant] = m;
  }

  const topMerchants = Object.entries(merchants)
    .map(([name, v]) => ({ name, amount: v.amount, count: v.count }))
    .sort((a, b) => b.amount - a.amount)
    .slice(0, 5);

  return { total, byCategory, byBucket, topMerchants, count: rows.length };
}

function median(values: number[]): number {
  const s = [...values].sort((a, b) => a - b);
  const mid = Math.floor(s.length / 2);
  return s.length % 2 === 0 ? (s[mid - 1] + s[mid]) / 2 : s[mid];
}

export interface RecurringSuggestion {
  merchant: string;
  amount: number;
  frequency_days: number;
  frequency_label: string;
  occurrences: number;
}

/**
 * Heuristique de récurrence : même commerçant, montant stable (±15 % de la
 * médiane), intervalle régulier (~7, ~14 ou ~30 jours), 3+ occurrences sur
 * 90 jours. Exclut ce qui est déjà budgété ou ignoré par l'utilisateur.
 */
export function detectRecurring(
  rows: TxRow[],
  excludedNames: string[]
): RecurringSuggestion[] {
  const excluded = excludedNames.map((n) => n.toLowerCase().trim());
  const groups = new Map<string, TxRow[]>();
  for (const t of rows) {
    if (t.amount <= 0) continue;
    // Un paiement de carte revient tous les mois : sans cette exclusion, il
    // serait suggéré comme dépense fixe à budgéter, ce qui le compterait une
    // seconde fois dans le budget.
    if (t.bucket === TRANSFER_BUCKET) continue;
    if (NON_SPENDING_CATEGORIES.includes(t.category)) continue;
    const key = t.merchant.toLowerCase().trim();
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key)!.push(t);
  }

  const suggestions: RecurringSuggestion[] = [];
  for (const [key, txs] of groups) {
    if (txs.length < 3) continue;
    if (excluded.some((e) => e.length > 2 && (key.includes(e) || e.includes(key)))) {
      continue;
    }

    const amounts = txs.map((t) => t.amount);
    const med = median(amounts);
    if (med <= 0) continue;
    const stable = amounts.filter((a) => Math.abs(a - med) / med <= 0.15);
    if (stable.length < 3) continue;

    const dates = txs
      .map((t) => t.createdAt.getTime())
      .sort((a, b) => a - b);
    const intervals: number[] = [];
    for (let i = 1; i < dates.length; i++) {
      intervals.push((dates[i] - dates[i - 1]) / 86400000);
    }
    const medInterval = median(intervals);

    let frequencyDays: number;
    let label: string;
    if (medInterval >= 5.5 && medInterval <= 8.5) {
      frequencyDays = 7;
      label = "hebdomadaire";
    } else if (medInterval >= 12 && medInterval <= 16) {
      frequencyDays = 14;
      label = "aux 2 semaines";
    } else if (medInterval >= 25 && medInterval <= 35) {
      frequencyDays = 30;
      label = "mensuelle";
    } else {
      continue;
    }

    suggestions.push({
      merchant: txs[0].merchant,
      amount: Math.round(med * 100) / 100,
      frequency_days: frequencyDays,
      frequency_label: label,
      occurrences: txs.length,
    });
  }

  return suggestions.sort((a, b) => b.amount - a.amount).slice(0, 8);
}

/** Montant mensuel équivalent d'une récurrence. */
export function monthlyEquivalent(amount: number, frequencyDays: number): number {
  const perMonth = frequencyDays === 30 ? 1 : frequencyDays === 14 ? 2.17 : 4.33;
  return Math.round(amount * perMonth * 100) / 100;
}

/**
 * Calcule et enregistre le bilan d'un foyer pour la période contenant `ref`.
 * Retourne l'ID du document report. `merge: true` préserve les conseils IA
 * déjà générés quand seuls les chiffres sont rafraîchis.
 */
export async function generateStoredReport(
  householdId: string,
  periodType: "weekly" | "monthly",
  ref: Date
): Promise<string> {
  const bounds = periodBounds(periodType, ref);

  const [rows, prevRows] = await Promise.all([
    fetchTransactions(householdId, bounds.start, bounds.end),
    fetchTransactions(householdId, bounds.prevStart, bounds.prevEnd),
  ]);
  const current = aggregate(rows);
  const previous = aggregate(prevRows);

  // Récurrence : fenêtre de 90 jours, en excluant le déjà-budgété/ignoré.
  const householdSnap = await db.collection("households").doc(householdId).get();
  const household = householdSnap.data() ?? {};
  const excluded: string[] = [
    ...((household.budgeted_recurring as string[]) ?? []),
    ...((household.dismissed_recurring as string[]) ?? []),
  ];
  const monthId = `${ref.getUTCFullYear()}-${String(ref.getUTCMonth() + 1).padStart(2, "0")}`;
  const budgetSnap = await db
    .collection("households")
    .doc(householdId)
    .collection("monthly_budgets")
    .doc(monthId)
    .get();
  const fixedExpenses = (budgetSnap.data()?.fixed_expenses as
    | { name?: string }[]
    | undefined) ?? [];
  for (const e of fixedExpenses) {
    if (e?.name) excluded.push(String(e.name));
  }

  const ninetyDaysAgo = new Date(Date.now() - 90 * 86400000);
  const recurringRows = await fetchTransactions(householdId, ninetyDaysAgo, new Date());
  const recurring = detectRecurring(recurringRows, excluded);

  const reportRef = db
    .collection("households")
    .doc(householdId)
    .collection("reports")
    .doc(bounds.id);

  await reportRef.set(
    {
      period_type: periodType,
      period_start: Timestamp.fromDate(bounds.start),
      period_end: Timestamp.fromDate(bounds.end),
      generated_at: FieldValue.serverTimestamp(),
      total_spent: current.total,
      transaction_count: current.count,
      by_category: current.byCategory,
      by_bucket: current.byBucket,
      top_merchants: current.topMerchants,
      prev_period_id: bounds.prevId,
      prev_total_spent: previous.total,
      prev_by_category: previous.byCategory,
      recurring_suggestions: recurring.map((r) => ({
        ...r,
        monthly_amount: monthlyEquivalent(r.amount, r.frequency_days),
      })),
    },
    { merge: true }
  );

  return bounds.id;
}

// ---------------------------------------------------------------------------
// Fonctions exportées
// ---------------------------------------------------------------------------

async function householdIdOf(uid: string): Promise<string> {
  const userSnap = await db.collection("users").doc(uid).get();
  const householdId = userSnap.data()?.household_id as string | undefined;
  if (!householdId) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Vous ne faites partie d'aucun foyer."
    );
  }
  return householdId;
}

/** Génère (ou rafraîchit) le bilan de la période courante et retourne son ID. */
export const generateReport = functions.https.onCall(async (data, context) => {
  const uid = requireAuth(context);
  await enforceRateLimit("generateReport", uid, 20, 3600);

  const periodType = data?.period_type === "weekly" ? "weekly" : "monthly";
  const householdId = await householdIdOf(uid);

  const reportId = await generateStoredReport(householdId, periodType, new Date());
  return { success: true, report_id: reportId };
});

/**
 * Ajoute une dépense récurrente détectée aux dépenses fixes du budget du mois
 * courant, recalcule les cagnottes et retire la suggestion des prochains bilans.
 */
export const addRecurringToBudget = functions.https.onCall(async (data, context) => {
  const uid = requireAuth(context);
  await enforceRateLimit("addRecurringToBudget", uid, 20, 3600);

  const name = assertString(data?.name, "name", { maxLength: 80 });
  const amount = typeof data?.amount === "number" ? data.amount : NaN;
  if (!Number.isFinite(amount) || amount <= 0 || amount > 1000000) {
    throw new functions.https.HttpsError("invalid-argument", "Montant invalide.");
  }

  const householdId = await householdIdOf(uid);
  const householdRef = db.collection("households").doc(householdId);
  const now = new Date();
  const monthId = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}`;
  const budgetRef = householdRef.collection("monthly_budgets").doc(monthId);

  await db.runTransaction(async (tx) => {
    const [householdSnap, budgetSnap] = await Promise.all([
      tx.get(householdRef),
      tx.get(budgetRef),
    ]);
    if (!householdSnap.exists) {
      throw new functions.https.HttpsError("not-found", "Foyer introuvable.");
    }
    const budget = budgetSnap.data() ?? {};

    const fixedExpenses = [
      ...(((budget.fixed_expenses as { name: string; amount: number }[]) ?? [])),
      { name, amount: Math.round(amount * 100) / 100 },
    ];
    const deductions = (budget.deductions as { amount?: number }[]) ?? [];

    const sum = (items: { amount?: number }[]) =>
      items.reduce((acc, i) => acc + (typeof i?.amount === "number" ? i.amount : 0), 0);
    const incomeA = (budget.income_A as number) ?? 0;
    const incomeB = (budget.income_B as number) ?? 0;
    const ratioA =
      (budget.split_ratio_A as number) ??
      (householdSnap.data()?.split_ratio_user_A as number) ??
      50;
    const net = sum(fixedExpenses) - sum(deductions);
    const contributionA = net * (ratioA / 100);
    const contributionB = net * ((100 - ratioA) / 100);

    tx.set(
      budgetRef,
      {
        fixed_expenses: fixedExpenses,
        updated_at: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    tx.update(householdRef, {
      safe_to_spend_common: net,
      safe_to_spend_solo_A: incomeA - contributionA,
      safe_to_spend_solo_B: incomeB - contributionB,
      budgeted_recurring: FieldValue.arrayUnion(name),
      updated_at: FieldValue.serverTimestamp(),
    });
  });

  return { success: true };
});

/**
 * Bilans hebdomadaires : chaque lundi à 6 h (heure de l'Est), génère le bilan
 * de la semaine qui vient de se terminer pour tous les foyers.
 */
export const weeklyReports = functions.pubsub
  .schedule("0 6 * * 1")
  .timeZone("America/Toronto")
  .onRun(async () => {
    const households = await db.collection("households").get();
    const lastWeek = new Date(Date.now() - 7 * 86400000);
    let generated = 0;

    for (const doc of households.docs) {
      try {
        await generateStoredReport(doc.id, "weekly", lastWeek);
        generated++;
      } catch (e) {
        console.error(`Bilan hebdo échoué pour le foyer ${doc.id}:`, e);
      }
    }
    console.log(`Bilans hebdomadaires générés : ${generated} foyer(s).`);
  });
