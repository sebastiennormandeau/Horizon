"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.joinHousehold = exports.createHousehold = exports.exchangePublicToken = exports.onTransactionAssigned = exports.plaidWebhookHandler = exports.generatePlaidLinkToken = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const plaid_1 = require("plaid");
admin.initializeApp();
const db = admin.firestore();
// Injection des secrets Plaid via le Secret Manager de Google Cloud
const plaidSecrets = ["PLAID_CLIENT_ID", "PLAID_SECRET"];
exports.generatePlaidLinkToken = functions
    .runWith({ secrets: plaidSecrets })
    .https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "User must be logged in");
    }
    const clientId = process.env.PLAID_CLIENT_ID;
    const secret = process.env.PLAID_SECRET;
    if (!clientId || !secret) {
        console.error("Clés Plaid manquantes dans Secret Manager.");
        throw new functions.https.HttpsError("internal", "Configuration serveur invalide");
    }
    const configuration = new plaid_1.Configuration({
        basePath: plaid_1.PlaidEnvironments.sandbox,
        baseOptions: {
            headers: {
                'PLAID-CLIENT-ID': clientId,
                'PLAID-SECRET': secret,
            },
        },
    });
    const client = new plaid_1.PlaidApi(configuration);
    try {
        const response = await client.linkTokenCreate({
            user: {
                client_user_id: context.auth.uid,
            },
            client_name: 'Horizon App',
            products: [plaid_1.Products.Transactions],
            country_codes: [plaid_1.CountryCode.Us],
            language: 'fr',
        });
        return { link_token: response.data.link_token };
    }
    catch (error) {
        console.error("Erreur Plaid:", error);
        throw new functions.https.HttpsError("internal", "Impossible de générer le link_token");
    }
});
exports.plaidWebhookHandler = functions
    .runWith({ secrets: plaidSecrets })
    .https.onRequest(async (req, res) => {
    try {
        const clientId = process.env.PLAID_CLIENT_ID;
        const secret = process.env.PLAID_SECRET;
        if (!clientId || !secret) {
            console.error("Clés Plaid manquantes dans Secret Manager.");
            res.status(500).send("Erreur de configuration serveur.");
            return;
        }
        const { webhook_type, webhook_code, item_id, new_transactions } = req.body;
        if (webhook_type === "TRANSACTIONS" && webhook_code === "DEFAULT_UPDATE") {
            const userId = await getUserIdFromPlaidItemId(item_id);
            // Simuler la création de X transactions pour démonstration
            const transactionsToCreate = new_transactions || 1;
            for (let i = 0; i < transactionsToCreate; i++) {
                const newTransaction = {
                    amount: Math.floor(Math.random() * 100) + 10,
                    merchant_name: "Commerçant Test",
                    paid_by_user_id: userId,
                    assigned_to_bucket: "", // Reste vide pour l'interface Tinder
                    status: "Posted",
                    created_at: admin.firestore.FieldValue.serverTimestamp()
                };
                await db.collection("transactions").add(newTransaction);
            }
        }
        res.status(200).send("Webhook traité avec succès.");
    }
    catch (error) {
        console.error("Erreur Webhook:", error);
        res.status(500).send("Erreur interne");
    }
});
exports.onTransactionAssigned = functions.firestore
    .document("transactions/{transactionId}")
    .onUpdate(async (change, context) => {
    var _a;
    const before = change.before.data();
    const after = change.after.data();
    if (before.assigned_to_bucket === "" && after.assigned_to_bucket !== "") {
        const amount = after.amount;
        const bucket = after.assigned_to_bucket;
        const payerId = after.paid_by_user_id;
        const userRef = db.collection("users").doc(payerId);
        const userDoc = await userRef.get();
        if (!userDoc.exists)
            return;
        const householdId = (_a = userDoc.data()) === null || _a === void 0 ? void 0 : _a.household_id;
        if (!householdId)
            return;
        const householdRef = db.collection("households").doc(householdId);
        await db.runTransaction(async (transaction) => {
            var _a;
            const householdDoc = await transaction.get(householdRef);
            const household = householdDoc.data();
            if (!household)
                throw new Error("Foyer introuvable");
            let newCommon = household.safe_to_spend_common || 0;
            let newSoloA = household.safe_to_spend_solo_A || 0;
            let newSoloB = household.safe_to_spend_solo_B || 0;
            let internalDebt = household.internal_debt_balance || 0;
            const safetyCushion = ((_a = userDoc.data()) === null || _a === void 0 ? void 0 : _a.safety_cushion) || 0;
            console.log(`Safety Cushion pour l'utilisateur ${payerId}: ${safetyCushion}`);
            if (bucket === "Common") {
                newCommon -= amount;
                const isUserA = (payerId === household.user_A_id);
                const ratioA = (household.split_ratio_user_A || 50) / 100;
                const ratioB = (household.split_ratio_user_B || 50) / 100;
                if (isUserA) {
                    internalDebt += (amount * ratioB);
                }
                else {
                    internalDebt -= (amount * ratioA);
                }
            }
            else if (bucket === "Solo_A") {
                newSoloA -= amount;
            }
            else if (bucket === "Solo_B") {
                newSoloB -= amount;
            }
            transaction.update(householdRef, {
                safe_to_spend_common: newCommon,
                safe_to_spend_solo_A: newSoloA,
                safe_to_spend_solo_B: newSoloB,
                internal_debt_balance: internalDebt,
                updated_at: admin.firestore.FieldValue.serverTimestamp()
            });
        });
        console.log(`Transaction neutralisée: bucket ${bucket}, montant ${amount}`);
    }
});
async function getUserIdFromPlaidItemId(itemId) {
    return "user_id_test_123";
}
exports.exchangePublicToken = functions
    .runWith({ secrets: plaidSecrets })
    .https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "User must be logged in");
    }
    const publicToken = data.public_token;
    if (!publicToken) {
        throw new functions.https.HttpsError("invalid-argument", "Missing public_token");
    }
    const clientId = process.env.PLAID_CLIENT_ID;
    const secret = process.env.PLAID_SECRET;
    if (!clientId || !secret) {
        throw new functions.https.HttpsError("internal", "Server configuration error");
    }
    const configuration = new plaid_1.Configuration({
        basePath: plaid_1.PlaidEnvironments.sandbox,
        baseOptions: {
            headers: {
                'PLAID-CLIENT-ID': clientId,
                'PLAID-SECRET': secret,
            },
        },
    });
    const client = new plaid_1.PlaidApi(configuration);
    try {
        // 1. Échange du public_token contre un access_token
        const exchangeResponse = await client.itemPublicTokenExchange({
            public_token: publicToken,
        });
        const accessToken = exchangeResponse.data.access_token;
        const itemId = exchangeResponse.data.item_id;
        // 2. Sauvegarde de la connexion bancaire dans Firestore
        await db.collection("bank_connections").doc(itemId).set({
            user_id: context.auth.uid,
            access_token: accessToken,
            item_id: itemId,
            created_at: admin.firestore.FieldValue.serverTimestamp(),
        });
        // 3. Récupération des transactions pour la PoC
        const now = new Date();
        const thirtyDaysAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
        const transactionsResponse = await client.transactionsGet({
            access_token: accessToken,
            start_date: thirtyDaysAgo.toISOString().split('T')[0],
            end_date: now.toISOString().split('T')[0],
            options: {
                count: 5,
            }
        });
        const transactions = transactionsResponse.data.transactions;
        for (const t of transactions) {
            await db.collection("transactions").add({
                amount: t.amount,
                merchant_name: t.merchant_name || t.name || "Inconnu",
                paid_by_user_id: context.auth.uid,
                assigned_to_bucket: "", // Pour la mécanique Tinder
                status: "Posted",
                created_at: admin.firestore.FieldValue.serverTimestamp(),
                plaid_transaction_id: t.transaction_id,
            });
        }
        return { success: true };
    }
    catch (error) {
        console.error("Erreur exchangePublicToken:", error);
        // Fallback pour la PoC si Plaid met du temps à initialiser les transactions Sandbox
        for (let i = 0; i < 5; i++) {
            await db.collection("transactions").add({
                amount: Math.floor(Math.random() * 50) + 10,
                merchant_name: "Dépense Simulée (Sandbox)",
                paid_by_user_id: context.auth.uid,
                assigned_to_bucket: "",
                status: "Posted",
                created_at: admin.firestore.FieldValue.serverTimestamp(),
            });
        }
        return { success: true, warning: "Fallback mock transactions used." };
    }
});
function generateJoinCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    let result = '';
    for (let i = 0; i < 6; i++) {
        result += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return result;
}
exports.createHousehold = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "User must be logged in");
    }
    const joinCode = generateJoinCode();
    const householdRef = await db.collection("households").add({
        created_by: context.auth.uid,
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        join_code: joinCode,
        safe_to_spend_common: 0,
        safe_to_spend_solo_A: 0,
        safe_to_spend_solo_B: 0,
    });
    await db.collection("users").doc(context.auth.uid).set({
        household_id: householdRef.id,
        role: "admin",
    }, { merge: true });
    return { success: true, household_id: householdRef.id, join_code: joinCode };
});
exports.joinHousehold = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "User must be logged in");
    }
    const joinCode = data.join_code;
    if (!joinCode || typeof joinCode !== 'string' || joinCode.length !== 6) {
        throw new functions.https.HttpsError("invalid-argument", "Invalid join code");
    }
    const snapshot = await db.collection("households").where("join_code", "==", joinCode).limit(1).get();
    if (snapshot.empty) {
        throw new functions.https.HttpsError("not-found", "Household not found");
    }
    const householdId = snapshot.docs[0].id;
    await db.collection("users").doc(context.auth.uid).set({
        household_id: householdId,
        role: "member",
    }, { merge: true });
    return { success: true, household_id: householdId };
});
//# sourceMappingURL=index.js.map