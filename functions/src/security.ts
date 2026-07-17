import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { db } from "./init";

/**
 * Garde d'authentification commune à toutes les fonctions appelables.
 *
 * - Exige un utilisateur connecté.
 * - Exige une adresse courriel vérifiée (sauf `requireVerifiedEmail: false`,
 *   p. ex. pour la suppression de compte).
 * - Protection anti-bot : exige un jeton App Check valide lorsque
 *   ENFORCE_APP_CHECK=true (à activer en production une fois les clés
 *   Play Integrity / App Attest / reCAPTCHA configurées).
 */
export function requireAuth(
  context: functions.https.CallableContext,
  options: { requireVerifiedEmail?: boolean } = {}
): string {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Vous devez être connecté."
    );
  }

  if (process.env.ENFORCE_APP_CHECK === "true" && !context.app) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Requête non autorisée (App Check manquant)."
    );
  }

  const requireVerified = options.requireVerifiedEmail !== false;
  if (requireVerified && context.auth.token.email_verified !== true) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Veuillez vérifier votre adresse courriel avant de continuer."
    );
  }

  return context.auth.uid;
}

/**
 * Limiteur de débit par utilisateur et par fonction (fenêtre glissante,
 * persistée dans Firestore — collection inaccessible aux clients).
 */
export async function enforceRateLimit(
  functionName: string,
  uid: string,
  maxCalls: number,
  windowSeconds: number
): Promise<void> {
  const ref = db.collection("rate_limits").doc(`${functionName}_${uid}`);

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const now = Date.now();
    const windowStart = now - windowSeconds * 1000;

    const timestamps: number[] = ((snap.data()?.timestamps as number[]) ?? [])
      .filter((t) => t > windowStart);

    if (timestamps.length >= maxCalls) {
      throw new functions.https.HttpsError(
        "resource-exhausted",
        "Trop de requêtes. Veuillez réessayer plus tard."
      );
    }

    timestamps.push(now);
    tx.set(ref, {
      timestamps,
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
}

// ---------------------------------------------------------------------------
// Validation des entrées
// ---------------------------------------------------------------------------

export function assertString(
  value: unknown,
  name: string,
  opts: { minLength?: number; maxLength?: number; pattern?: RegExp } = {}
): string {
  if (typeof value !== "string") {
    throw new functions.https.HttpsError(
      "invalid-argument",
      `Paramètre invalide: ${name}`
    );
  }
  const { minLength = 1, maxLength = 4096, pattern } = opts;
  if (value.length < minLength || value.length > maxLength) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      `Paramètre invalide: ${name}`
    );
  }
  if (pattern && !pattern.test(value)) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      `Paramètre invalide: ${name}`
    );
  }
  return value;
}

/** Code de foyer : 6 caractères alphanumériques majuscules. */
export const JOIN_CODE_PATTERN = /^[A-Z0-9]{6}$/;

/** Jeton public Plaid : `public-<env>-<uuid>`. */
export const PLAID_PUBLIC_TOKEN_PATTERN = /^public-[a-z]+-[0-9a-f-]{16,64}$/;
