import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import * as crypto from "crypto";
import {
  Configuration,
  PlaidApi,
  PlaidEnvironments,
  Products,
  CountryCode,
  Transaction as PlaidTransaction,
} from "plaid";

admin.initializeApp();
const db = admin.firestore();

// Injection des secrets Plaid via le Secret Manager de Google Cloud
const plaidSecrets = ["PLAID_CLIENT_ID", "PLAID_SECRET"];

const VALID_BUCKETS = ["Common", "Solo_A", "Solo_B"];

function getPlaidClient(): PlaidApi {
  const clientId = process.env.PLAID_CLIENT_ID;
  const secret = process.env.PLAID_SECRET;

  if (!clientId || !secret) {
    console.error("Clés Plaid manquantes dans Secret Manager.");
    throw new functions.https.HttpsError("internal", "Configuration serveur invalide");
  }

  return new PlaidApi(
    new Configuration({
      // TODO: passer à PlaidEnvironments.production avant le lancement.
      basePath: PlaidEnvironments.sandbox,
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
 * Synchronise les transactions d'un item Plaid vers Firestore via /transactions/sync.
 * Idempotent : l'ID de transaction Plaid sert d'ID de document, et les documents
 * déjà existants ne sont jamais réécrits (le bucket assigné est préservé).
 */
async function syncTransactionsForItem(itemId: string): Promise<number> {
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
  let hasMore = true;

  while (hasMore) {
    const response = await client.transactionsSync({
      access_token: conn.access_token,
      cursor,
    });
    added = added.concat(response.data.added);
    hasMore = response.data.has_more;
    cursor = response.data.next_cursor;
  }

  const chunkSize = 400; // limite de 500 opérations par batch Firestore
  let imported = 0;
  for (let i = 0; i < added.length; i += chunkSize) {
    const chunk = added.slice(i, i + chunkSize);
    const refs = chunk.map((t) => db.collection("transactions").doc(t.transaction_id));
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
        status: t.pending ? "Pending" : "Posted",
        date: t.date ?? null,
        plaid_transaction_id: t.transaction_id,
        created_at: admin.firestore.FieldValue.serverTimestamp(),
      });
      imported++;
    });
    await batch.commit();
  }

  await connRef.update({
    sync_cursor: cursor,
    last_synced_at: admin.firestore.FieldValue.serverTimestamp(),
  });

  return imported;
}

export const generatePlaidLinkToken = functions
  .runWith({ secrets: plaidSecrets })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "User must be logged in");
    }

    const client = getPlaidClient();
    const projectId = process.env.GCLOUD_PROJECT;
    const webhookUrl = projectId
      ? `https://us-central1-${projectId}.cloudfunctions.net/plaidWebhookHandler`
      : undefined;

    try {
      const response = await client.linkTokenCreate({
        user: {
          client_user_id: context.auth.uid,
        },
        client_name: "Horizon App",
        products: [Products.Transactions],
        country_codes: [CountryCode.Us, CountryCode.Ca],
        language: "fr",
        webhook: webhookUrl,
      });
      return { link_token: response.data.link_token };
    } catch (error) {
      console.error("Erreur Plaid:", error);
      throw new functions.https.HttpsError("internal", "Impossible de générer le link_token");
    }
  });

export const exchangePublicToken = functions
  .runWith({ secrets: plaidSecrets })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "User must be logged in");
    }

    const publicToken = data.public_token;
    if (!publicToken || typeof publicToken !== "string") {
      throw new functions.https.HttpsError("invalid-argument", "Missing public_token");
    }

    const userSnap = await db.collection("users").doc(context.auth.uid).get();
    const householdId = userSnap.data()?.household_id;
    if (!householdId) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Vous devez d'abord créer ou rejoindre un foyer."
      );
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
        user_id: context.auth.uid,
        household_id: householdId,
        access_token: accessToken,
        item_id: itemId,
        created_at: admin.firestore.FieldValue.serverTimestamp(),
      });

      const imported = await syncTransactionsForItem(itemId);
      return { success: true, imported };
    } catch (error) {
      console.error("Erreur exchangePublicToken:", error);
      throw new functions.https.HttpsError("internal", "Échec de la connexion bancaire");
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
      // TODO avant production : vérifier la signature JWT du webhook Plaid
      // (en-tête Plaid-Verification, endpoint /webhook_verification_key/get).
      const { webhook_type: webhookType, webhook_code: webhookCode, item_id: itemId } =
        req.body ?? {};

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
        console.log(`Webhook ${webhookCode}: ${imported} transaction(s) importée(s) pour ${itemId}`);
      }

      res.status(200).send("OK");
    } catch (error) {
      console.error("Erreur Webhook:", error);
      res.status(500).send("Erreur interne");
    }
  });

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

    await db.runTransaction(async (tx) => {
      const householdSnap = await tx.get(householdRef);
      if (!householdSnap.exists) return;
      const household = householdSnap.data()!;

      let common: number = household.safe_to_spend_common || 0;
      let soloA: number = household.safe_to_spend_solo_A || 0;
      let soloB: number = household.safe_to_spend_solo_B || 0;
      let internalDebt: number = household.internal_debt_balance || 0;

      const isUserA = payerId === household.user_A_id;
      const ratioA = (household.split_ratio_user_A ?? 50) / 100;
      const ratioB = (household.split_ratio_user_B ?? 50) / 100;

      // sign = +1 pour appliquer l'effet d'un bucket, -1 pour l'annuler.
      const apply = (bucket: string, sign: number) => {
        if (!VALID_BUCKETS.includes(bucket)) return;
        if (bucket === "Common") {
          common -= sign * amount;
          // Le payeur avance la part de l'autre : dette interne positive = B doit à A.
          internalDebt += sign * (isUserA ? amount * ratioB : -(amount * ratioA));
        } else if (bucket === "Solo_A") {
          soloA -= sign * amount;
        } else if (bucket === "Solo_B") {
          soloB -= sign * amount;
        }
      };

      apply(beforeBucket, -1);
      apply(afterBucket, 1);

      tx.update(householdRef, {
        safe_to_spend_common: common,
        safe_to_spend_solo_A: soloA,
        safe_to_spend_solo_B: soloB,
        internal_debt_balance: internalDebt,
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      });
    });
  });

function generateJoinCode(): string {
  // Sans I, O, 0, 1 pour éviter les confusions à la saisie.
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  let result = "";
  for (let i = 0; i < 6; i++) {
    result += chars.charAt(crypto.randomInt(chars.length));
  }
  return result;
}

export const createHousehold = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "User must be logged in");
  }
  const uid = context.auth.uid;

  const userRef = db.collection("users").doc(uid);
  const userSnap = await userRef.get();
  if (userSnap.data()?.household_id) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Vous faites déjà partie d'un foyer."
    );
  }

  const joinCode = generateJoinCode();

  const householdRef = await db.collection("households").add({
    created_by: uid,
    created_at: admin.firestore.FieldValue.serverTimestamp(),
    join_code: joinCode,
    user_A_id: uid,
    user_B_id: null,
    split_ratio_user_A: 50,
    split_ratio_user_B: 50,
    safe_to_spend_common: 0,
    safe_to_spend_solo_A: 0,
    safe_to_spend_solo_B: 0,
    internal_debt_balance: 0,
  });

  await userRef.set(
    {
      household_id: householdRef.id,
      role: "admin",
    },
    { merge: true }
  );

  return { success: true, household_id: householdRef.id, join_code: joinCode };
});

export const joinHousehold = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "User must be logged in");
  }
  const uid = context.auth.uid;

  const rawCode = data.join_code;
  const joinCode = typeof rawCode === "string" ? rawCode.trim().toUpperCase() : "";
  if (joinCode.length !== 6) {
    throw new functions.https.HttpsError("invalid-argument", "Invalid join code");
  }

  const userRef = db.collection("users").doc(uid);
  let householdId = "";

  await db.runTransaction(async (tx) => {
    const userSnap = await tx.get(userRef);
    if (userSnap.data()?.household_id) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Vous faites déjà partie d'un foyer."
      );
    }

    const query = db.collection("households").where("join_code", "==", joinCode).limit(1);
    const snapshot = await tx.get(query);
    if (snapshot.empty) {
      throw new functions.https.HttpsError("not-found", "Household not found");
    }

    const householdDoc = snapshot.docs[0];
    const household = householdDoc.data();

    if (household.user_A_id === uid) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Vous ne pouvez pas rejoindre votre propre foyer."
      );
    }
    if (household.user_B_id) {
      throw new functions.https.HttpsError("failed-precondition", "Ce foyer est déjà complet.");
    }

    householdId = householdDoc.id;
    tx.update(householdDoc.ref, { user_B_id: uid });
    tx.set(
      userRef,
      {
        household_id: householdId,
        role: "member",
      },
      { merge: true }
    );
  });

  return { success: true, household_id: householdId };
});
