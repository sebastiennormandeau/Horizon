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
exports.onTransactionAssigned = exports.plaidWebhookHandler = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
admin.initializeApp();
const db = admin.firestore();
// Injection des secrets Plaid via le Secret Manager de Google Cloud
const plaidSecrets = ["PLAID_CLIENT_ID", "PLAID_SECRET"];
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
    // S'activer uniquement si on passe de 'non assigné' à 'assigné'
    if (before.assigned_to_bucket === "" && after.assigned_to_bucket !== "") {
        const amount = after.amount;
        const bucket = after.assigned_to_bucket; // "Common", "Solo_A", "Solo_B"
        const payerId = after.paid_by_user_id;
        const userRef = db.collection("users").doc(payerId);
        const userDoc = await userRef.get();
        if (!userDoc.exists) {
            console.error("Utilisateur introuvable:", payerId);
            return;
        }
        const householdId = (_a = userDoc.data()) === null || _a === void 0 ? void 0 : _a.household_id;
        if (!householdId) {
            console.warn("Utilisateur sans foyer:", payerId);
            return;
        }
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
            // On récupère le montant de sécurité défini par l'utilisateur
            const safetyCushion = ((_a = userDoc.data()) === null || _a === void 0 ? void 0 : _a.safety_cushion) || 0;
            // Logique Agent 4 : Calcul du bucket et balance interne
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
            // Mise à jour de l'état "neutralisé"
            transaction.update(householdRef, {
                safe_to_spend_common: newCommon,
                safe_to_spend_solo_A: newSoloA,
                safe_to_spend_solo_B: newSoloB,
                internal_debt_balance: internalDebt,
                updated_at: admin.firestore.FieldValue.serverTimestamp()
            });
        });
        console.log(`Transaction ${context.params.transactionId} neutralisée dans ${bucket} pour un montant de ${amount}`);
    }
});
async function getUserIdFromPlaidItemId(itemId) {
    return "user_id_test_123";
}
//# sourceMappingURL=index.js.map