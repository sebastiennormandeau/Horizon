import * as functions from "firebase-functions/v1";
import * as crypto from "crypto";
import {
  Configuration,
  PlaidApi,
  PlaidEnvironments,
  Products,
  CountryCode,
  Transaction as PlaidTransaction,
  RemovedTransaction,
} from "plaid";
import { db, FieldValue, Timestamp } from "./init";
import {
  requireAuth,
  enforceRateLimit,
  assertString,
  PLAID_PUBLIC_TOKEN_PATTERN,
} from "./security";

// Injection des secrets Plaid via le Secret Manager de Google Cloud
export const plaidSecrets = ["PLAID_CLIENT_ID", "PLAID_SECRET"];

export function getPlaidClient(): PlaidApi {
  const clientId = process.env.PLAID_CLIENT_ID;
  const secret = process.env.PLAID_SECRET;

  if (!clientId || !secret) {
    console.error("Clés Plaid manquantes dans Secret Manager.");
    throw new functions.https.HttpsError(
      "internal",
      "Configuration serveur invalide"
    );
  }

  // Environnement contrôlé par functions/.env (sandbox | production).
  const envName = process.env.PLAID_ENV ?? "sandbox";
  const basePath =
    PlaidEnvironments[envName as keyof typeof PlaidEnvironments] ??
    PlaidEnvironments.sandbox;

  return new PlaidApi(
    new Configuration({
      basePath,
      baseOptions: {
        headers: {
          "PLAID-CLIENT-ID": clientId,
          "PLAID-SECRET": secret,
        },
      },
    })
  );
}

interface BankConnection {
  access_token: string;
  user_id: string;
  household_id: string;
  sync_cursor?: string;
  institution_name?: string | null;
  /** Comptes de l'institution, pour les afficher et les qualifier un à un. */
  accounts?: {
    account_id: string;
    name: string;
    mask?: string | null;
    type?: string | null;
    subtype?: string | null;
  }[];
  /**
   * Comptes conjoints de cette connexion : leurs dépenses communes ne créent
   * pas de dette interne.
   *
   * Au niveau du **compte** et non de la connexion : une même banque héberge
   * couramment le compte personnel et le compte conjoint, et les deux
   * n'appellent pas le même traitement.
   */
  joint_account_ids?: string[];
}

/** Comptes rattachés à une connexion, pour affichage et qualification. */
async function fetchAccounts(
  client: PlaidApi,
  accessToken: string
): Promise<
  {
    account_id: string;
    name: string;
    mask?: string | null;
    type?: string | null;
    subtype?: string | null;
  }[]
> {
  try {
    const resp = await client.accountsGet({ access_token: accessToken });
    return resp.data.accounts.map((a) => ({
      account_id: a.account_id,
      name: a.official_name || a.name,
      mask: a.mask ?? null,
      // Le type (`credit`, `depository`…) sert à reconnaître un paiement de
      // carte : un dépôt sur un compte de crédit n'est pas un revenu.
      type: a.type ?? null,
      subtype: a.subtype ?? null,
    }));
  } catch (e) {
    console.error("Récupération des comptes échouée:", e);
    return [];
  }
}

/**
 * Cagnotte fictive des mouvements internes (paiement de carte de crédit,
 * virement entre ses propres comptes).
 *
 * Absente de `VALID_BUCKETS` dans `ledger.ts` : le déclencheur l'ignore, ces
 * transactions n'ont donc **aucun effet** sur les soldes.
 *
 * Pourquoi c'est nécessaire : en budgétisation à base zéro, une dépense est
 * comptée au moment de **l'achat**, pas du paiement. Un achat par carte
 * réduit déjà la cagnotte ; si le paiement mensuel de la carte — qui apparaît
 * comme une sortie du compte chèque — était compté à son tour, la même somme
 * serait retranchée deux fois. Ce paiement est un transfert entre deux
 * comptes du foyer, pas une dépense.
 */
export const TRANSFER_BUCKET = "Transfer";

/**
 * Cagnotte fictive des transactions écartées du tri.
 *
 * Comme `Transfer`, absente de `VALID_BUCKETS` : aucun effet sur les soldes.
 * Sert à sortir de la file les dépenses des mois révolus — relier une banque
 * rapatrie des mois d'historique, et les trier viderait les cagnottes du mois
 * courant de dépenses qui ne le concernent pas.
 *
 * Contrairement à `Transfer`, ces transactions restent comptées dans les
 * bilans : ce sont de vraies dépenses, simplement pas à classer.
 */
export const ARCHIVED_BUCKET = "Archived";

/** Premier jour du mois courant, au format `AAAA-MM-JJ`. */
function startOfCurrentMonth(): string {
  const now = new Date();
  return `${now.getUTCFullYear()}-${String(now.getUTCMonth() + 1).padStart(2, "0")}-01`;
}

/**
 * Catégories détaillées de Plaid qui dénotent un mouvement interne.
 *
 * On se fonde sur la catégorie **détaillée** et non primaire : `LOAN_PAYMENTS`
 * couvre aussi l'hypothèque et le prêt auto, qui sont de vraies dépenses et
 * doivent continuer d'entamer les cagnottes.
 */
const INTERNAL_TRANSFER_DETAILED = new Set([
  "LOAN_PAYMENTS_CREDIT_CARD_PAYMENT",
  "TRANSFER_OUT_ACCOUNT_TRANSFER",
  "TRANSFER_IN_ACCOUNT_TRANSFER",
]);

export function isInternalTransfer(detailed?: string | null): boolean {
  return !!detailed && INTERNAL_TRANSFER_DETAILED.has(detailed);
}

/**
 * Paye régulière, déjà prise en compte dans le budget mensuel.
 *
 * Volontairement restreint au salaire : les autres entrées d'argent —
 * remboursement, pige, dividende, remboursement d'impôt, cadeau — ne sont
 * pas budgétées et doivent rester à classer, puisqu'elles augmentent
 * réellement ce que le foyer peut dépenser. Les glisser vers une cagnotte
 * l'augmente, ce qui est le comportement voulu.
 *
 * Un salaire, lui, financerait deux fois la même cagnotte : une fois par le
 * budget, une fois par le glissement.
 */
const PAYROLL_DETAILED = new Set(["INCOME_WAGES", "INCOME_SALARY"]);

export function isPayroll(detailed?: string | null): boolean {
  return !!detailed && PAYROLL_DETAILED.has(detailed);
}

/**
 * Masques (4 derniers chiffres) de tous les comptes reliés du foyer.
 *
 * Sert à repérer les virements entre comptes du foyer : leur libellé cite le
 * numéro du compte contrepartie.
 */
async function householdAccountMasks(householdId: string): Promise<string[]> {
  const conns = await db
    .collection("bank_connections")
    .where("household_id", "==", householdId)
    .get();
  const masks = new Set<string>();
  for (const d of conns.docs) {
    const accounts = (d.data().accounts ?? []) as {
      mask?: string | null;
    }[];
    for (const a of accounts) {
      if (a.mask) masks.add(a.mask);
    }
  }
  return [...masks];
}

/**
 * Le libellé désigne-t-il un mouvement vers/depuis un autre compte DU FOYER ?
 *
 * Plaid étiquette « virement chèque→épargne » d'une dizaine de façons
 * (`TRANSFER_IN_OTHER_TRANSFER_IN`, `TRANSFER_OUT_SAVINGS`…) et classe même un
 * virement « prêt auto » en `LOAN_PAYMENTS_CAR_PAYMENT` : la catégorie seule
 * rate ces mouvements internes, qui atterrissent alors dans la file de tri.
 *
 * Signal bien plus fiable : le libellé cite le numéro du compte contrepartie
 * (« Deposit from Tangerine Chequing Account - 4009344997 »), et ce numéro se
 * termine par le masque d'un compte connecté (••4997). Un dépôt d'un compte
 * NON relié (« Compte perso Alex - 4009344544 ») reste externe — son masque
 * n'est pas dans la liste, donc c'est bien une vraie entrée d'argent.
 */
function mentionsOwnAccount(
  name: string | undefined | null,
  masks: string[]
): boolean {
  if (!name || masks.length === 0) return false;
  const runs = name.match(/\d{6,}/g); // numéros de compte complets
  if (!runs) return false;
  return runs.some((run) => masks.some((m) => run.endsWith(m)));
}

/**
 * Le libellé est-il celui d'un paiement de carte reçu
 * (« PAYMENT - THANK YOU / PAIEMENT MERCI ») ?
 *
 * Sur un compte de CARTE, une entrée d'argent est soit un paiement (mouvement
 * interne, à ne pas compter), soit un remboursement de marchand. Ce mémo
 * distingue le paiement : exiger À LA FOIS un mot « paiement » ET un « merci »
 * évite de confondre avec un remboursement (qui porte le nom du marchand) ou
 * un vrai virement reçu au compte chèque libellé « payment ».
 */
function isCardPaymentMemo(name: string | undefined | null): boolean {
  if (!name) return false;
  const n = name.toLowerCase();
  const payment = n.includes("payment") || n.includes("paiement");
  const thanks = n.includes("thank you") || n.includes("merci");
  return payment && thanks;
}

/**
 * Recalcule le nombre de connexions bancaires du foyer et l'inscrit sur son
 * document.
 *
 * Les clients ne peuvent pas lire `bank_connections` (elle contient les
 * jetons d'accès) : sans ce compteur, l'accueil ne pourrait pas distinguer
 * « aucune banque connectée » de « tout est trié ». On recompte plutôt que
 * d'incrémenter, pour qu'une suppression manquée ne fasse pas dériver la
 * valeur durablement.
 */
export async function refreshConnectionCount(
  householdId: string
): Promise<void> {
  try {
    const snap = await db
      .collection("bank_connections")
      .where("household_id", "==", householdId)
      .count()
      .get();
    await db
      .collection("households")
      .doc(householdId)
      .update({ bank_connections_count: snap.data().count });
  } catch (e) {
    // Purement indicatif : un échec ne doit jamais faire échouer l'action
    // en cours (connexion, suppression de compte, départ d'un foyer).
    console.error(`Recompte des connexions échoué pour ${householdId}:`, e);
  }
}

/**
 * Renseigne la provenance des transactions importées avant que le champ
 * `institution_name` existe.
 *
 * Relit l'historique de la connexion depuis le début (curseur nul) sans
 * toucher au curseur enregistré : c'est le seul moyen de rattacher une
 * transaction déjà stockée à son institution, puisque son document ne
 * conservait aucun lien vers la connexion d'origine.
 *
 * Ne s'exécute que si des documents en manquent réellement.
 */
async function backfillInstitutionNames(
  client: PlaidApi,
  conn: BankConnection,
  itemId: string
): Promise<number> {
  if (!conn.institution_name) return 0;

  // Le compte d'origine est indispensable pour qualifier chaque compte
  // séparément : une même banque héberge souvent le compte personnel et le
  // compte conjoint.
  const accountOf = new Map<string, string>();
  let cursor: string | undefined = undefined;
  let hasMore = true;
  while (hasMore) {
    const resp = await client.transactionsSync({
      access_token: conn.access_token,
      cursor,
    });
    resp.data.added.forEach((t) => accountOf.set(t.transaction_id, t.account_id));
    resp.data.modified.forEach((t) =>
      accountOf.set(t.transaction_id, t.account_id)
    );
    hasMore = resp.data.has_more;
    cursor = resp.data.next_cursor;
  }

  const refs = [...accountOf.keys()].map((id) =>
    db.collection("transactions").doc(id)
  );
  let updated = 0;
  const chunk = 400;
  for (let i = 0; i < refs.length; i += chunk) {
    const slice = refs.slice(i, i + chunk);
    const snaps = await db.getAll(...slice);
    const batch = db.batch();
    let pending = 0;
    snaps.forEach((s) => {
      if (!s.exists || s.data()?.institution_name) return;
      const accountId = accountOf.get(s.id) ?? null;
      batch.update(s.ref, {
        institution_name: conn.institution_name,
        item_id: itemId,
        account_id: accountId,
        is_joint_account: accountId
          ? (conn.joint_account_ids ?? []).includes(accountId)
          : false,
      });
      pending++;
    });
    if (pending > 0) {
      await batch.commit();
      updated += pending;
    }
  }

  // Marqueur sur la connexion : on ne peut pas repérer les documents à
  // compléter par une requête, Firestore ne faisant pas correspondre un champ
  // ABSENT à `null`. Sans ce drapeau, chaque synchronisation relirait tout
  // l'historique chez Plaid.
  await db
    .collection("bank_connections")
    .doc(itemId)
    .update({ institution_backfilled: true });
  return updated;
}

interface InstitutionInfo {
  id: string | null;
  name: string | null;
  /** Logo PNG 152×152, encodé en data URI, ou null si Plaid n'en fournit pas. */
  logo: string | null;
  /** Couleur de marque hexadécimale, pour la pastille de repli. */
  color: string | null;
}

/**
 * Nom, logo et couleur de l'institution.
 *
 * `include_optional_metadata` demande le logo : Plaid ne l'a pas pour toutes
 * les banques (le repli est alors une pastille colorée). Plaid ne détient pas
 * ces logos et décline toute garantie — ils sont affichés tels quels, sans
 * retraitement.
 */
async function institutionInfoOf(
  client: PlaidApi,
  accessToken: string
): Promise<InstitutionInfo> {
  const empty: InstitutionInfo = {
    id: null,
    name: null,
    logo: null,
    color: null,
  };
  try {
    const item = await client.itemGet({ access_token: accessToken });
    const institutionId = item.data.item.institution_id;
    if (!institutionId) return empty;
    const inst = await client.institutionsGetById({
      institution_id: institutionId,
      country_codes: [CountryCode.Us, CountryCode.Ca],
      options: { include_optional_metadata: true },
    });
    const i = inst.data.institution;
    return {
      id: institutionId,
      name: i.name,
      logo: i.logo ? `data:image/png;base64,${i.logo}` : null,
      color: i.primary_color ?? null,
    };
  } catch (e) {
    // Cosmétique : l'app affichera « Compte bancaire » à défaut de nom.
    console.error("Récupération de l'institution échouée:", e);
    return empty;
  }
}

/**
 * Range le logo d'une institution sur le document du foyer, indexé par nom.
 *
 * Stocké là plutôt que sur chaque transaction : un même logo pèse ~10 Ko et
 * le recopier sur des milliers de documents les alourdirait inutilement. Le
 * foyer est déjà chargé par l'accueil, qui reconstitue le lien nom → logo.
 */
async function storeInstitutionLogo(
  householdId: string,
  inst: InstitutionInfo
): Promise<void> {
  if (!inst.name || (!inst.logo && !inst.color)) return;
  try {
    await db
      .collection("households")
      .doc(householdId)
      .set(
        {
          institution_logos: {
            [inst.name]: { logo: inst.logo, color: inst.color },
          },
        },
        { merge: true }
      );
  } catch (e) {
    console.error(`Logo d'institution non enregistré (${inst.name}):`, e);
  }
}

/**
 * Synchronise les transactions d'un item Plaid vers Firestore via
 * /transactions/sync. Idempotent : l'ID de transaction Plaid sert d'ID de
 * document et les documents existants ne sont jamais réécrits aveuglément.
 *
 * - `added`    : créées si absentes (les transactions en attente sont ignorées
 *                pour éviter les ajustements de montant après assignation).
 * - `modified` : montant/nom mis à jour uniquement si non assignées.
 * - `removed`  : désassignées (la Cloud Function renverse l'effet sur les
 *                cagnottes) puis supprimées.
 */
export async function syncTransactionsForItem(itemId: string): Promise<number> {
  const connRef = db.collection("bank_connections").doc(itemId);
  const connSnap = await connRef.get();
  if (!connSnap.exists) {
    console.warn(`Webhook/sync pour un item inconnu: ${itemId}`);
    return 0;
  }
  const conn = connSnap.data() as BankConnection;

  const client = getPlaidClient();
  // Première synchronisation d'une connexion : Plaid livre alors des mois
  // d'historique d'un coup. Les dépenses antérieures au mois courant sont
  // écartées de la file de tri (voir ARCHIVED_BUCKET). On se limite à ce
  // premier import : ainsi une transaction du mois passé qui se règle avec
  // quelques jours de retard reste bien à trier.
  const isInitialSync = !conn.sync_cursor;
  const monthStart = startOfCurrentMonth();
  const jointIds = conn.joint_account_ids ?? [];
  // Numéros des comptes du foyer, pour reconnaître un virement interne au
  // libellé plutôt qu'à la seule catégorie Plaid (qui en rate beaucoup).
  const ownMasks = await householdAccountMasks(conn.household_id);
  // Comptes de crédit du foyer : un dépôt sur une carte est un paiement de
  // carte (mouvement interne), jamais un revenu. On réunit les cartes connues
  // via liabilities et les comptes marqués « credit » sur la connexion.
  const creditAccts = new Set<string>();
  const cardDocs = await db
    .collection("households")
    .doc(conn.household_id)
    .collection("cards")
    .get();
  cardDocs.forEach((c) => creditAccts.add(c.id));
  for (const a of conn.accounts ?? []) {
    if (a.type === "credit") creditAccts.add(a.account_id);
  }
  let cursor = conn.sync_cursor;
  let added: PlaidTransaction[] = [];
  let modified: PlaidTransaction[] = [];
  let removed: RemovedTransaction[] = [];
  let hasMore = true;

  while (hasMore) {
    const response = await client.transactionsSync({
      access_token: conn.access_token,
      cursor,
    });
    added = added.concat(response.data.added);
    modified = modified.concat(response.data.modified);
    removed = removed.concat(response.data.removed);
    hasMore = response.data.has_more;
    cursor = response.data.next_cursor;
  }

  const txCollection = db.collection("transactions");
  const chunkSize = 400; // limite de 500 opérations par batch Firestore
  let imported = 0;

  // --- Ajouts ---
  const postedAdded = added.filter((t) => !t.pending);
  for (let i = 0; i < postedAdded.length; i += chunkSize) {
    const chunk = postedAdded.slice(i, i + chunkSize);
    const refs = chunk.map((t) => txCollection.doc(t.transaction_id));
    const existing = await db.getAll(...refs);

    const batch = db.batch();
    existing.forEach((snap, idx) => {
      if (snap.exists) return;
      const t = chunk[idx];
      const detailed = t.personal_finance_category?.detailed ?? null;
      const isOld = isInitialSync && !!t.date && t.date < monthStart;
      // Interne si la catégorie le dit, OU si le libellé cite un compte du
      // foyer (virement chèque↔épargne, « prêt auto » vers son épargne…), OU
      // si c'est un paiement reçu sur une carte de crédit (Plaid l'étiquette
      // souvent « income » à tort).
      const label = t.name || t.merchant_name;
      const isCardPayment =
        typeof t.amount === "number" &&
        t.amount < 0 &&
        creditAccts.has(t.account_id) &&
        isCardPaymentMemo(label);
      const isInternal =
        isInternalTransfer(detailed) ||
        mentionsOwnAccount(label, ownMasks) ||
        isCardPayment;
      batch.set(refs[idx], {
        amount: t.amount,
        merchant_name: t.merchant_name || t.name || "Inconnu",
        paid_by_user_id: conn.user_id,
        household_id: conn.household_id,
        // Provenance : permet d'afficher l'institution sur chaque transaction
        // sans exposer `bank_connections`, interdite de lecture cliente.
        institution_name: conn.institution_name ?? null,
        account_id: t.account_id ?? null,
        item_id: itemId,
        // Copié sur la transaction plutôt que lu au vol : le déclencheur du
        // grand livre ne dispose que du document de transaction.
        is_joint_account: jointIds.includes(t.account_id),
        // Les mouvements internes sont classés d'office : ils ne doivent ni
        // encombrer la file de tri, ni toucher aux cagnottes. Les dépenses
        // des mois révolus sont écartées du tri mais restent dans les bilans.
        assigned_to_bucket: isInternal
          ? TRANSFER_BUCKET
          : isOld || isPayroll(detailed)
            ? ARCHIVED_BUCKET
            : "",
        status: "Posted",
        date: t.date ?? null,
        // Catégorisation Plaid (personal_finance_category), affinable par
        // l'utilisateur côté client.
        category: t.personal_finance_category?.primary ?? "OTHER",
        category_detailed: t.personal_finance_category?.detailed ?? null,
        plaid_transaction_id: t.transaction_id,
        created_at: FieldValue.serverTimestamp(),
      });
      imported++;
    });
    await batch.commit();
  }

  // --- Modifications ---
  for (const t of modified.filter((m) => !m.pending)) {
    const ref = txCollection.doc(t.transaction_id);
    const snap = await ref.get();
    if (!snap.exists) continue;
    const data = snap.data()!;
    if (data.assigned_to_bucket === "") {
      await ref.update({
        amount: t.amount,
        merchant_name: t.merchant_name || t.name || "Inconnu",
        date: t.date ?? null,
        category: t.personal_finance_category?.primary ?? "OTHER",
        category_detailed: t.personal_finance_category?.detailed ?? null,
      });
    } else {
      // Déjà comptabilisée dans les cagnottes : on ne touche pas au montant.
      console.warn(
        `Transaction ${t.transaction_id} modifiée par Plaid mais déjà assignée; montant conservé.`
      );
    }
  }

  // --- Suppressions ---
  for (const r of removed) {
    const ref = txCollection.doc(r.transaction_id);
    const snap = await ref.get();
    if (!snap.exists) continue;
    if (snap.data()!.assigned_to_bucket !== "") {
      // Désassigner d'abord : le trigger renverse l'effet sur les cagnottes.
      await ref.update({ assigned_to_bucket: "" });
    }
    await ref.delete();
  }

  await connRef.update({
    sync_cursor: cursor,
    last_synced_at: FieldValue.serverTimestamp(),
  });

  return imported;
}

// ---------------------------------------------------------------------------
// Vérification de signature des webhooks Plaid (JWT ES256)
// https://plaid.com/docs/api/webhooks/webhook-verification/
// ---------------------------------------------------------------------------

const webhookKeyCache = new Map<string, object>();

export async function verifyPlaidWebhook(
  req: functions.https.Request
): Promise<boolean> {
  if (process.env.PLAID_SKIP_WEBHOOK_VERIFICATION === "true") {
    console.warn("Vérification de signature Plaid DÉSACTIVÉE (dev seulement).");
    return true;
  }

  try {
    const token = req.headers["plaid-verification"];
    if (typeof token !== "string") return false;

    const parts = token.split(".");
    if (parts.length !== 3) return false;

    const header = JSON.parse(Buffer.from(parts[0], "base64url").toString());
    if (header.alg !== "ES256" || typeof header.kid !== "string") return false;

    let jwk = webhookKeyCache.get(header.kid);
    if (!jwk) {
      const client = getPlaidClient();
      const resp = await client.webhookVerificationKeyGet({
        key_id: header.kid,
      });
      jwk = resp.data.key as object;
      webhookKeyCache.set(header.kid, jwk);
    }

    const publicKey = crypto.createPublicKey({
      key: jwk as crypto.JsonWebKey,
      format: "jwk",
    });

    const signatureValid = crypto.verify(
      "sha256",
      Buffer.from(`${parts[0]}.${parts[1]}`),
      { key: publicKey, dsaEncoding: "ieee-p1363" },
      Buffer.from(parts[2], "base64url")
    );
    if (!signatureValid) return false;

    const payload = JSON.parse(Buffer.from(parts[1], "base64url").toString());

    // Jeton trop vieux (> 5 minutes) : rejeté.
    if (
      typeof payload.iat !== "number" ||
      Date.now() / 1000 - payload.iat > 300
    ) {
      return false;
    }

    // Le corps de la requête doit correspondre au hachage signé.
    const bodyHash = crypto
      .createHash("sha256")
      .update(req.rawBody)
      .digest("hex");
    const expected = payload.request_body_sha256;
    if (typeof expected !== "string" || expected.length !== bodyHash.length) {
      return false;
    }
    return crypto.timingSafeEqual(
      Buffer.from(bodyHash),
      Buffer.from(expected)
    );
  } catch (e) {
    console.error("Erreur de vérification du webhook Plaid:", e);
    return false;
  }
}

// ---------------------------------------------------------------------------
// Fonctions exportées
// ---------------------------------------------------------------------------

export const generatePlaidLinkToken = functions
  .runWith({ secrets: plaidSecrets })
  .https.onCall(async (data, context) => {
    const uid = requireAuth(context);
    await enforceRateLimit("generatePlaidLinkToken", uid, 20, 3600);

    // Langue de l'interface Plaid Link (l'app est bilingue fr/en).
    const language =
      data?.language === undefined
        ? "fr"
        : assertString(data.language, "language", {
            maxLength: 2,
            pattern: /^(fr|en)$/,
          });

    // Plateforme appelante : détermine comment Plaid revient vers l'app
    // après une authentification OAuth.
    const platform =
      data?.platform === undefined
        ? "web"
        : assertString(data.platform, "platform", {
            maxLength: 7,
            pattern: /^(web|android|ios)$/,
          });

    const client = getPlaidClient();
    const projectId = process.env.GCLOUD_PROJECT;
    const webhookUrl = projectId
      ? `https://us-central1-${projectId}.cloudfunctions.net/plaidWebhookHandler`
      : undefined;

    // En production, la quasi-totalité des institutions canadiennes impose
    // l'OAuth : la banque authentifie l'utilisateur chez elle puis renvoie
    // vers nous. Sans ces paramètres — enregistrés au préalable dans le
    // tableau de bord Plaid — ces institutions échouent.
    //   - web et iOS : une URL https exacte (PLAID_REDIRECT_URI) ;
    //     « localhost » est refusé, l'app web doit donc être hébergée.
    //   - Android : le nom du paquet, jamais une URL.
    // Les deux sont facultatifs : à vide, le comportement sandbox actuel est
    // inchangé.
    const redirectUri = process.env.PLAID_REDIRECT_URI;
    const androidPackage = process.env.PLAID_ANDROID_PACKAGE;
    const oauth =
      platform === "android"
        ? androidPackage
          ? { android_package_name: androidPackage }
          : {}
        : redirectUri
          ? { redirect_uri: redirectUri }
          : {};

    // Personnalisation Link. Plaid impose (Data Transparency Messaging v5)
    // qu'au moins un « cas d'usage » soit déclaré, sinon l'ouverture d'une
    // institution OAuth échoue avec INVALID_LINK_CUSTOMIZATION.
    // Inutile si la personnalisation *par défaut* est configurée dans le
    // tableau de bord ; à renseigner seulement si on en crée une nommée.
    const customization = process.env.PLAID_LINK_CUSTOMIZATION;

    try {
      const response = await client.linkTokenCreate({
        user: {
          client_user_id: uid,
        },
        client_name: "Horizon App",
        products: [Products.Transactions],
        // Échéances et soldes de relevé des cartes de crédit, ajoutés
        // uniquement quand l'institution les supporte : celles qui ne les
        // offrent pas restent sélectionnables (contrairement à `products`,
        // qui filtrerait la liste des banques).
        //
        // Piloté par une variable d'environnement, car le produit doit être
        // activé sur le compte Plaid : le demander sans y avoir droit fait
        // échouer `linkTokenCreate` pour **toutes** les institutions, y
        // compris celles qui marchaient. Mettre PLAID_ENABLE_LIABILITIES=false
        // rétablit le comportement précédent sans redéployer de code.
        //
        // ⚠️ En production, chaque produit est facturé dès l'initialisation
        // du Item et ne peut plus en être retiré : seule la suppression du
        // Item (`/item/remove`) arrête les frais.
        ...(process.env.PLAID_ENABLE_LIABILITIES === "true"
          ? { required_if_supported_products: [Products.Liabilities] }
          : {}),
        country_codes: [CountryCode.Us, CountryCode.Ca],
        language,
        webhook: webhookUrl,
        ...oauth,
        ...(customization
          ? { link_customization_name: customization }
          : {}),
      });
      return { link_token: response.data.link_token };
    } catch (error) {
      console.error("Erreur Plaid:", error);
      throw new functions.https.HttpsError(
        "internal",
        "Impossible de générer le link_token"
      );
    }
  });

export const exchangePublicToken = functions
  .runWith({ secrets: plaidSecrets })
  .https.onCall(async (data, context) => {
    const uid = requireAuth(context);
    await enforceRateLimit("exchangePublicToken", uid, 10, 3600);

    const publicToken = assertString(data?.public_token, "public_token", {
      maxLength: 128,
      pattern: PLAID_PUBLIC_TOKEN_PATTERN,
    });

    const userSnap = await db.collection("users").doc(uid).get();
    const householdId = userSnap.data()?.household_id;
    if (!householdId) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Vous devez d'abord créer ou rejoindre un foyer."
      );
    }

    // Gating Premium : le plan gratuit permet un seul compte bancaire par foyer.
    const householdSnap = await db
      .collection("households")
      .doc(householdId)
      .get();
    const tier = householdSnap.data()?.subscription_tier ?? "free";
    if (tier !== "premium") {
      // Limite du plan gratuit, ajustable par FREE_PLAN_BANK_LIMIT.
      // Elle existe pour la monétisation : pendant le pilote, où personne ne
      // paie et où l'on veut réunir comptes bancaires et cartes de crédit au
      // même endroit, on la relève plutôt que de marquer le foyer
      // « premium » — ce champ n'est écrit que par le webhook RevenueCat et
      // doit continuer de refléter un vrai abonnement.
      const limit = Number(process.env.FREE_PLAN_BANK_LIMIT ?? "1");
      const existing = await db
        .collection("bank_connections")
        .where("household_id", "==", householdId)
        .count()
        .get();
      if (existing.data().count >= limit) {
        throw new functions.https.HttpsError(
          "resource-exhausted",
          `Le plan gratuit permet ${limit} connexion(s) bancaire(s) par foyer. Passez à Horizon Premium pour connecter des comptes illimités.`
        );
      }
    }

    const client = getPlaidClient();

    try {
      const exchangeResponse = await client.itemPublicTokenExchange({
        public_token: publicToken,
      });
      const accessToken = exchangeResponse.data.access_token;
      const itemId = exchangeResponse.data.item_id;

      const institution = await institutionInfoOf(client, accessToken);
      const accounts = await fetchAccounts(client, accessToken);

      // L'access_token ne quitte jamais le serveur : les règles Firestore
      // interdisent toute lecture client de bank_connections.
      await db.collection("bank_connections").doc(itemId).set({
        user_id: uid,
        household_id: householdId,
        access_token: accessToken,
        item_id: itemId,
        institution_id: institution.id,
        institution_name: institution.name,
        accounts,
        joint_account_ids: [],
        created_at: FieldValue.serverTimestamp(),
      });

      await storeInstitutionLogo(householdId, institution);

      // Re-lier une institution déjà connectée = la remplacer. Sans ça, les
      // transactions de l'ancienne connexion resteraient orphelines et
      // seraient réimportées en double sous les nouveaux identifiants Plaid.
      // Couvre le cas « reconnecter sans déconnecter d'abord », pour n'importe
      // quelle institution.
      await replaceSameInstitutionConnections(
        client,
        uid,
        householdId,
        institution.id,
        itemId
      );

      const imported = await syncTransactionsForItem(itemId);
      await refreshConnectionCount(householdId);
      // Solde et échéance des cartes de la nouvelle connexion, si elle
      // supporte liabilities. Best-effort : n'empêche pas la connexion.
      // Import différé pour éviter la boucle plaid ↔ cards au chargement
      // (cards importe plaidSecrets d'ici, évalué à l'initialisation).
      try {
        const { refreshCardData } = await import("./cards");
        await refreshCardData(householdId);
      } catch (e) {
        console.error("refreshCardData après connexion:", e);
      }
      return { success: true, imported };
    } catch (error) {
      console.error("Erreur exchangePublicToken:", error);
      throw new functions.https.HttpsError(
        "internal",
        "Échec de la connexion bancaire"
      );
    }
  });

/** Identifiant d'item Plaid. */
const ITEM_ID_PATTERN = /^[A-Za-z0-9._-]{8,128}$/;

/**
 * Connexions bancaires du foyer, sans le moindre jeton.
 *
 * Les règles Firestore interdisent toute lecture cliente de
 * `bank_connections` : c'est cette fonction qui expose la part affichable.
 */
export const listBankConnections = functions.https.onCall(
  async (data, context) => {
    const uid = requireAuth(context);

    const userSnap = await db.collection("users").doc(uid).get();
    const householdId = userSnap.data()?.household_id as string | undefined;
    if (!householdId) return { connections: [] };

    const snap = await db
      .collection("bank_connections")
      .where("household_id", "==", householdId)
      .get();

    // Les logos vivent sur le foyer (indexés par nom d'institution) pour ne
    // pas être dupliqués sur chaque connexion.
    const householdSnap = await db
      .collection("households")
      .doc(householdId)
      .get();
    const logos = (householdSnap.data()?.institution_logos ?? {}) as Record<
      string,
      { logo?: string | null; color?: string | null }
    >;

    return {
      connections: snap.docs.map((d) => {
        const c = d.data();
        const branding = c.institution_name ? logos[c.institution_name] : null;
        return {
          item_id: d.id,
          institution_name: c.institution_name ?? null,
          logo: branding?.logo ?? null,
          color: branding?.color ?? null,
          accounts: c.accounts ?? [],
          joint_account_ids: c.joint_account_ids ?? [],
          // Permet à l'app de distinguer ses propres comptes de ceux du
          // partenaire, sans exposer d'identifiant utilisable autrement.
          is_mine: c.user_id === uid,
          created_at: (c.created_at as Timestamp | undefined)
            ?.toDate()
            .toISOString() ?? null,
          last_synced_at: (c.last_synced_at as Timestamp | undefined)
            ?.toDate()
            .toISOString() ?? null,
        };
      }),
    };
  }
);

/**
 * Retire les transactions d'un item et renverse leur effet sur les cagnottes.
 *
 * Déconnecter une banque doit emporter ses transactions : les garder en fait
 * des orphelines, et reconnecter la même banque les réimporte sous de nouveaux
 * identifiants Plaid — un doublon par achat (c'est précisément le bug que ceci
 * corrige). Une transaction déjà triée dans un vrai pot (Solo_A/Solo_B/Common)
 * a agi sur les cagnottes : on renverse cet effet — addition pure, donc
 * `FieldValue.increment`, sans course avec `onTransactionAssigned` (qui, lui,
 * ne se déclenche pas à la suppression) — avant d'effacer les documents.
 */
async function reverseAndDeleteItemTransactions(
  itemId: string,
  householdId: string
): Promise<number> {
  const [txSnap, hhSnap] = await Promise.all([
    db.collection("transactions").where("item_id", "==", itemId).get(),
    db.collection("households").doc(householdId).get(),
  ]);
  if (txSnap.empty) return 0;
  const household = hhSnap.data() ?? {};

  const userAId = household.user_A_id ?? household.created_by;
  const ratioA = (household.split_ratio_user_A ?? 50) / 100;
  const ratioB = (household.split_ratio_user_B ?? 50) / 100;

  let dCommon = 0;
  let dSoloA = 0;
  let dSoloB = 0;
  let dDebt = 0;
  for (const doc of txSnap.docs) {
    const t = doc.data();
    const bucket: string = t.assigned_to_bucket ?? "";
    const amount = typeof t.amount === "number" ? t.amount : 0;
    if (bucket === "Common") {
      dCommon += amount;
      // Renverse apply("Common", +1) de ledger.ts, sauf sur compte conjoint.
      if (t.is_joint_account !== true) {
        const isUserA = t.paid_by_user_id === userAId;
        dDebt -= isUserA ? amount * ratioB : -(amount * ratioA);
      }
    } else if (bucket === "Solo_A") {
      dSoloA += amount;
    } else if (bucket === "Solo_B") {
      dSoloB += amount;
    }
  }

  if (dCommon || dSoloA || dSoloB || dDebt) {
    await db.collection("households").doc(householdId).update({
      safe_to_spend_common: FieldValue.increment(dCommon),
      safe_to_spend_solo_A: FieldValue.increment(dSoloA),
      safe_to_spend_solo_B: FieldValue.increment(dSoloB),
      internal_debt_balance: FieldValue.increment(dDebt),
      updated_at: FieldValue.serverTimestamp(),
    });
  }

  const chunk = 400; // limite Firestore : 500 écritures par lot
  for (let i = 0; i < txSnap.docs.length; i += chunk) {
    const batch = db.batch();
    txSnap.docs.slice(i, i + chunk).forEach((d) => batch.delete(d.ref));
    await batch.commit();
  }
  return txSnap.size;
}

/**
 * Retire les autres connexions du même utilisateur à la même institution.
 *
 * Re-lier une banque crée un nouvel item Plaid ; garder l'ancienne connexion
 * dédoublerait chaque transaction. On traite donc un re-lien comme un
 * remplacement — un foyer n'a qu'une connexion par institution. Réutilise le
 * même renversement grand-livre + suppression que `removeBankConnection`.
 */
async function replaceSameInstitutionConnections(
  client: PlaidApi,
  uid: string,
  householdId: string,
  institutionId: string | null | undefined,
  keepItemId: string
): Promise<void> {
  if (!institutionId) return;
  const snap = await db
    .collection("bank_connections")
    .where("household_id", "==", householdId)
    .get();
  for (const d of snap.docs) {
    const c = d.data();
    if (
      d.id === keepItemId ||
      c.user_id !== uid ||
      c.institution_id !== institutionId
    ) {
      continue;
    }
    await reverseAndDeleteItemTransactions(d.id, householdId);
    const oldCards = await db
      .collection("households")
      .doc(householdId)
      .collection("cards")
      .where("item_id", "==", d.id)
      .get();
    for (const card of oldCards.docs) await card.ref.delete();
    const token = c.access_token as string | undefined;
    if (token) {
      try {
        await client.itemRemove({ access_token: token });
      } catch (e) {
        console.error(`itemRemove (re-lien) a échoué pour ${d.id}:`, e);
      }
    }
    await d.ref.delete();
  }
}

/**
 * Déconnecte une banque : révocation du jeton chez Plaid puis effacement.
 *
 * Réservé à la personne qui a établi la connexion — un membre ne coupe pas
 * l'accès bancaire de l'autre. Les transactions importées sont **retirées** et
 * leur effet sur les cagnottes renversé (voir
 * `reverseAndDeleteItemTransactions`) : sinon une reconnexion les dédoublerait.
 * Les cartes rattachées à l'item sont aussi effacées.
 */
export const removeBankConnection = functions
  .runWith({ secrets: plaidSecrets })
  .https.onCall(async (data, context) => {
    const uid = requireAuth(context);
    await enforceRateLimit("removeBankConnection", uid, 10, 3600);

    const itemId = assertString(data?.item_id, "item_id", {
      maxLength: 128,
      pattern: ITEM_ID_PATTERN,
    });

    const ref = db.collection("bank_connections").doc(itemId);
    const snap = await ref.get();
    if (!snap.exists) {
      throw new functions.https.HttpsError(
        "not-found",
        "Cette connexion bancaire n'existe pas."
      );
    }
    const conn = snap.data() as BankConnection;
    if (conn.user_id !== uid) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Seule la personne qui a connecté cette banque peut la déconnecter."
      );
    }

    // Retirer d'abord les transactions (et renverser leur effet grand-livre) :
    // les laisser en ferait des orphelines, dédoublées à la reconnexion.
    const deleted = await reverseAndDeleteItemTransactions(
      itemId,
      conn.household_id
    );

    // Cartes rattachées à cet item : sans quoi un rappel d'échéance
    // continuerait de tomber pour une carte déconnectée.
    const cardsSnap = await db
      .collection("households")
      .doc(conn.household_id)
      .collection("cards")
      .where("item_id", "==", itemId)
      .get();
    for (const c of cardsSnap.docs) await c.ref.delete();

    if (conn.access_token) {
      try {
        await getPlaidClient().itemRemove({ access_token: conn.access_token });
      } catch (e) {
        // Même politique que deleteAccount : le jeton disparaît de nos
        // systèmes dans tous les cas, l'échec est consigné.
        console.error(`itemRemove a échoué pour ${itemId}:`, e);
      }
    }
    await ref.delete();
    await refreshConnectionCount(conn.household_id);

    // Les liquidités du foyer comptaient les comptes de cette connexion :
    // recalcul depuis les connexions restantes (best-effort, import différé).
    try {
      const { refreshCardData } = await import("./cards");
      await refreshCardData(conn.household_id);
    } catch (e) {
      console.error("refreshCardData après déconnexion:", e);
    }

    return { success: true, transactions_deleted: deleted };
  });

/**
 * Relance la synchronisation de toutes les connexions du foyer.
 *
 * Plaid livre normalement les transactions par webhook, mais l'historique
 * d'un compte fraîchement relié peut mettre plusieurs minutes à arriver :
 * ce bouton évite d'attendre sans savoir si quelque chose se passe.
 */
export const syncBankConnections = functions
  .runWith({ secrets: plaidSecrets, timeoutSeconds: 300 })
  .https.onCall(async (data, context) => {
    const uid = requireAuth(context);
    await enforceRateLimit("syncBankConnections", uid, 10, 3600);

    const userSnap = await db.collection("users").doc(uid).get();
    const householdId = userSnap.data()?.household_id as string | undefined;
    if (!householdId) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Vous ne faites partie d'aucun foyer."
      );
    }

    const snap = await db
      .collection("bank_connections")
      .where("household_id", "==", householdId)
      .get();

    let imported = 0;
    for (const doc of snap.docs) {
      try {
        // Rattrapage des connexions établies avant que le nom et le logo de
        // l'institution soient enregistrés : évite de devoir les délier puis
        // relier. On (re)tente tant que le logo manque sur le foyer.
        const householdSnap = await db
          .collection("households")
          .doc(householdId)
          .get();
        const hasLogo =
          !!doc.data().institution_name &&
          !!(householdSnap.data()?.institution_logos ?? {})[
            doc.data().institution_name
          ];
        if (!doc.data().institution_name || !hasLogo) {
          const token = doc.data().access_token as string | undefined;
          if (token) {
            const inst = await institutionInfoOf(getPlaidClient(), token);
            if (inst.name) {
              await doc.ref.update({
                institution_id: inst.id,
                institution_name: inst.name,
              });
              await storeInstitutionLogo(householdId, inst);
            }
          }
        }
        const conn = doc.data() as BankConnection & {
          institution_backfilled?: boolean;
        };
        if (conn.institution_name && !conn.institution_backfilled) {
          await backfillInstitutionNames(getPlaidClient(), conn, doc.id);
        }
        // Liste de comptes rafraîchie : elle alimente les interrupteurs
        // « compte conjoint » et peut changer côté banque.
        if (!conn.accounts || conn.accounts.length === 0) {
          const accounts = await fetchAccounts(
            getPlaidClient(),
            conn.access_token
          );
          if (accounts.length > 0) await doc.ref.update({ accounts });
        }
        imported += await syncTransactionsForItem(doc.id);
      } catch (e) {
        // Une connexion en erreur (jeton révoqué côté banque) ne doit pas
        // empêcher les autres de se synchroniser.
        console.error(`Synchronisation échouée pour ${doc.id}:`, e);
      }
    }

    // Rattrape aussi un compteur absent : les foyers reliés avant l ajout
    // de ce champ n en ont pas, et l accueil les croirait sans banque.
    await refreshConnectionCount(householdId);

    return { success: true, imported, connections: snap.size };
  });

/**
 * Marque une connexion comme conjointe ou personnelle.
 *
 * Le drapeau est recopié sur les transactions existantes de la connexion :
 * le déclencheur du grand livre ne lit que le document de transaction.
 *
 * ⚠️ La dette interne **déjà calculée** n'est pas recalculée — il faudrait
 * rejouer tout l'historique des assignations. Le solde existant se remet à
 * zéro avec « Régler la dette » (`settleDebt`), qui en consigne la trace.
 */
export const setBankConnectionJoint = functions.https.onCall(
  async (data, context) => {
    const uid = requireAuth(context);
    await enforceRateLimit("setBankConnectionJoint", uid, 20, 3600);

    const itemId = assertString(data?.item_id, "item_id", {
      maxLength: 128,
      pattern: ITEM_ID_PATTERN,
    });
    const accountId = assertString(data?.account_id, "account_id", {
      maxLength: 128,
      pattern: ITEM_ID_PATTERN,
    });
    if (typeof data?.is_joint !== "boolean") {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Paramètre invalide: is_joint"
      );
    }
    const isJoint = data.is_joint as boolean;

    const ref = db.collection("bank_connections").doc(itemId);
    const snap = await ref.get();
    if (!snap.exists) {
      throw new functions.https.HttpsError(
        "not-found",
        "Cette connexion bancaire n'existe pas."
      );
    }
    const conn = snap.data() as BankConnection;

    // Tout membre du foyer peut qualifier un compte de conjoint : c'est une
    // description de la réalité du couple, pas un privilège.
    const userSnap = await db.collection("users").doc(uid).get();
    if (userSnap.data()?.household_id !== conn.household_id) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Cette connexion n'appartient pas à votre foyer."
      );
    }

    const current = new Set(conn.joint_account_ids ?? []);
    if (isJoint) {
      current.add(accountId);
    } else {
      current.delete(accountId);
    }
    await ref.update({ joint_account_ids: [...current] });

    const tx = await db
      .collection("transactions")
      .where("account_id", "==", accountId)
      .get();
    const chunk = 400;
    for (let i = 0; i < tx.docs.length; i += chunk) {
      const batch = db.batch();
      tx.docs
        .slice(i, i + chunk)
        .forEach((d) => batch.update(d.ref, { is_joint_account: isJoint }));
      await batch.commit();
    }

    return { success: true, transactions_updated: tx.size };
  }
);

/**
 * Écarte de la file de tri les transactions non classées des mois révolus.
 *
 * Les cagnottes sont calculées pour le **mois courant** : trier des dépenses
 * d'avril viderait le budget de juillet de sommes qui ne le concernent pas.
 * Ces transactions restent visibles dans l'historique et comptées dans les
 * bilans, qui se bornent sur la date réelle.
 */
export const archivePastTransactions = functions.https.onCall(
  async (data, context) => {
    const uid = requireAuth(context);
    await enforceRateLimit("archivePastTransactions", uid, 10, 3600);

    const userSnap = await db.collection("users").doc(uid).get();
    const householdId = userSnap.data()?.household_id as string | undefined;
    if (!householdId) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Vous ne faites partie d'aucun foyer."
      );
    }

    const snap = await db
      .collection("transactions")
      .where("household_id", "==", householdId)
      .where("assigned_to_bucket", "==", "")
      .get();

    const monthStart = startOfCurrentMonth();
    const old = snap.docs.filter((d) => {
      const date = d.data().date as string | undefined;
      return !!date && date < monthStart;
    });

    const chunk = 400; // limite Firestore : 500 écritures par lot
    for (let i = 0; i < old.length; i += chunk) {
      const batch = db.batch();
      old
        .slice(i, i + chunk)
        .forEach((d) =>
          batch.update(d.ref, { assigned_to_bucket: ARCHIVED_BUCKET })
        );
      await batch.commit();
    }

    return { success: true, archived: old.length };
  }
);

/**
 * Soldes réels des comptes de dépôt de l'appelant (chèque/épargne), pour les
 * comparer à sa cagnotte solo. Ne renvoie que **ses** connexions, et marque
 * chaque compte conjoint ou non, afin d'isoler le personnel du partagé.
 *
 * Lecture directe chez Plaid : `bank_connections` est interdit de lecture
 * cliente, donc un solde ne peut transiter que par un callable.
 */
export const getMyCashBalances = functions
  .runWith({ secrets: plaidSecrets })
  .https.onCall(async (data, context) => {
    const uid = requireAuth(context);
    await enforceRateLimit("getMyCashBalances", uid, 30, 3600);

    const conns = await db
      .collection("bank_connections")
      .where("user_id", "==", uid)
      .get();

    const client = getPlaidClient();
    const accounts: {
      account_id: string;
      name: string;
      mask: string | null;
      subtype: string | null;
      balance: number;
      institution_name: string | null;
      is_joint: boolean;
    }[] = [];

    for (const doc of conns.docs) {
      const conn = doc.data() as BankConnection;
      if (!conn.access_token) continue;
      const jointIds = new Set(conn.joint_account_ids ?? []);
      try {
        const bal = await client.accountsBalanceGet({
          access_token: conn.access_token,
        });
        for (const a of bal.data.accounts) {
          if (a.type !== "depository") continue;
          accounts.push({
            account_id: a.account_id,
            name: a.official_name || a.name || "Compte",
            mask: a.mask ?? null,
            subtype: a.subtype ?? null,
            balance: a.balances.available ?? a.balances.current ?? 0,
            institution_name: conn.institution_name ?? null,
            is_joint: jointIds.has(a.account_id),
          });
        }
      } catch (e) {
        console.error(`Solde indisponible pour ${doc.id}:`, e);
      }
    }

    return { accounts };
  });

export const plaidWebhookHandler = functions
  .runWith({ secrets: plaidSecrets })
  .https.onRequest(async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }

    try {
      const verified = await verifyPlaidWebhook(req);
      if (!verified) {
        console.warn("Webhook Plaid rejeté : signature invalide.");
        res.status(401).send("Unauthorized");
        return;
      }

      const {
        webhook_type: webhookType,
        webhook_code: webhookCode,
        item_id: itemId,
      } = req.body ?? {};

      const syncCodes = [
        "SYNC_UPDATES_AVAILABLE",
        "INITIAL_UPDATE",
        "HISTORICAL_UPDATE",
        "DEFAULT_UPDATE",
      ];

      if (
        webhookType === "TRANSACTIONS" &&
        syncCodes.includes(webhookCode) &&
        typeof itemId === "string"
      ) {
        const imported = await syncTransactionsForItem(itemId);
        console.log(
          `Webhook ${webhookCode}: ${imported} transaction(s) importée(s) pour ${itemId}`
        );
      }

      res.status(200).send("OK");
    } catch (error) {
      console.error("Erreur Webhook:", error);
      res.status(500).send("Erreur interne");
    }
  });
