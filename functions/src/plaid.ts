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
import { db, FieldValue } from "./init";
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
      const existing = await db
        .collection("bank_connections")
        .where("household_id", "==", householdId)
        .limit(1)
        .get();
      if (!existing.empty) {
        throw new functions.https.HttpsError(
          "resource-exhausted",
          "Le plan gratuit permet un seul compte bancaire par foyer. Passez à Horizon Premium pour connecter des comptes illimités."
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

      // L'access_token ne quitte jamais le serveur : les règles Firestore
      // interdisent toute lecture client de bank_connections.
      await db.collection("bank_connections").doc(itemId).set({
        user_id: uid,
        household_id: householdId,
        access_token: accessToken,
        item_id: itemId,
        created_at: FieldValue.serverTimestamp(),
      });

      const imported = await syncTransactionsForItem(itemId);
      return { success: true, imported };
    } catch (error) {
      console.error("Erreur exchangePublicToken:", error);
      throw new functions.https.HttpsError(
        "internal",
        "Échec de la connexion bancaire"
      );
    }
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
