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

/** Nom lisible de l'institution, pour l'afficher dans l'app. */
async function institutionNameOf(
  client: PlaidApi,
  accessToken: string
): Promise<{ id: string | null; name: string | null }> {
  try {
    const item = await client.itemGet({ access_token: accessToken });
    const institutionId = item.data.item.institution_id;
    if (!institutionId) return { id: null, name: null };
    const inst = await client.institutionsGetById({
      institution_id: institutionId,
      country_codes: [CountryCode.Us, CountryCode.Ca],
    });
    return { id: institutionId, name: inst.data.institution.name };
  } catch (e) {
    // Cosmétique : l'app affichera « Compte bancaire » à défaut de nom.
    console.error("Récupération du nom d'institution échouée:", e);
    return { id: null, name: null };
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
      batch.set(refs[idx], {
        amount: t.amount,
        merchant_name: t.merchant_name || t.name || "Inconnu",
        paid_by_user_id: conn.user_id,
        household_id: conn.household_id,
        assigned_to_bucket: "",
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

      const institution = await institutionNameOf(client, accessToken);

      // L'access_token ne quitte jamais le serveur : les règles Firestore
      // interdisent toute lecture client de bank_connections.
      await db.collection("bank_connections").doc(itemId).set({
        user_id: uid,
        household_id: householdId,
        access_token: accessToken,
        item_id: itemId,
        institution_id: institution.id,
        institution_name: institution.name,
        created_at: FieldValue.serverTimestamp(),
      });

      const imported = await syncTransactionsForItem(itemId);
      await refreshConnectionCount(householdId);
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

    return {
      connections: snap.docs.map((d) => {
        const c = d.data();
        return {
          item_id: d.id,
          institution_name: c.institution_name ?? null,
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
 * Déconnecte une banque : révocation du jeton chez Plaid puis effacement.
 *
 * Réservé à la personne qui a établi la connexion — un membre ne coupe pas
 * l'accès bancaire de l'autre. Les transactions déjà importées sont
 * **conservées** : elles font partie de l'historique budgétaire du foyer et
 * des cagnottes déjà calculées ; seule la synchronisation cesse.
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

    return { success: true };
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
        // Rattrapage des connexions établies avant que le nom d'institution
        // soit enregistré : évite de devoir les délier puis relier.
        if (!doc.data().institution_name) {
          const token = doc.data().access_token as string | undefined;
          if (token) {
            const inst = await institutionNameOf(getPlaidClient(), token);
            if (inst.name) {
              await doc.ref.update({
                institution_id: inst.id,
                institution_name: inst.name,
              });
            }
          }
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
