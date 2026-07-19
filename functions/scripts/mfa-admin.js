#!/usr/bin/env node
/**
 * Outil d'administration MFA — désenrôlement manuel d'un second facteur.
 *
 * POURQUOI CE SCRIPT PLUTÔT QU'UNE FONCTION DÉPLOYÉE
 * La double authentification est obligatoire pour tous les comptes. Un
 * utilisateur qui perd son application d'authentification (téléphone perdu,
 * réinitialisé) ne peut plus se connecter, et Firebase n'offre AUCUNE
 * récupération intégrée pour le TOTP.
 *
 * Ce pouvoir de réinitialisation est volontairement HORS de l'application :
 * une fonction déployée « admin » serait une porte dérobée exposée sur
 * Internet. Ici, la capacité vit sur le poste de l'administrateur et exige
 * ses identifiants Google (eux-mêmes protégés par MFA). Ce fichier n'est
 * jamais déployé (voir l'exclusion "scripts" dans firebase.json).
 *
 * PRÉREQUIS (une seule fois)
 *   1. Installer Google Cloud CLI : https://cloud.google.com/sdk/docs/install
 *   2. gcloud auth application-default login
 *      (se connecter avec le compte Google administrateur du projet)
 *
 * USAGE
 *   cd functions
 *   node scripts/mfa-admin.js list  quelquun@example.com
 *   node scripts/mfa-admin.js reset quelquun@example.com
 *
 * Projet ciblé : variable GOOGLE_CLOUD_PROJECT, sinon horizon-dbba0.
 *
 * ⚠️ AVANT TOUTE RÉINITIALISATION : vérifier l'identité du demandeur par un
 * canal indépendant (appel téléphonique, question de sécurité). Un courriel
 * seul ne prouve rien — une boîte courriel compromise est précisément le
 * scénario contre lequel le MFA protège. Consigner la demande et la
 * vérification (registre des incidents, SECURITY_POLICY.md §6).
 */

const readline = require("readline");
const { initializeApp, applicationDefault } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");

const PROJECT_ID = process.env.GOOGLE_CLOUD_PROJECT || "horizon-dbba0";

function usage() {
  console.log(`
Usage :
  node scripts/mfa-admin.js list  <courriel>   Affiche les facteurs enrôlés
  node scripts/mfa-admin.js reset <courriel>   Retire TOUS les facteurs

Projet : ${PROJECT_ID}
`);
}

function confirm(question) {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });
  return new Promise((resolve) => {
    rl.question(question, (answer) => {
      rl.close();
      resolve(answer.trim());
    });
  });
}

function describeFactors(user) {
  const factors = user.multiFactor ? user.multiFactor.enrolledFactors : [];
  if (!factors || factors.length === 0) return null;
  return factors;
}

async function main() {
  const [command, email] = process.argv.slice(2);

  if (!command || !email) {
    usage();
    process.exit(1);
  }
  if (!["list", "reset"].includes(command)) {
    console.error(`Commande inconnue : ${command}`);
    usage();
    process.exit(1);
  }

  initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID });
  const auth = getAuth();

  let user;
  try {
    user = await auth.getUserByEmail(email);
  } catch (e) {
    if (e.code === "auth/user-not-found") {
      console.error(`Aucun compte pour ${email} dans ${PROJECT_ID}.`);
    } else {
      console.error(`Erreur : ${e.message}`);
    }
    process.exit(1);
  }

  const factors = describeFactors(user);

  console.log(`\nCompte   : ${user.email}`);
  console.log(`UID      : ${user.uid}`);
  console.log(`Vérifié  : ${user.emailVerified ? "oui" : "non"}`);
  console.log(`Créé le  : ${user.metadata.creationTime}`);
  console.log("Facteurs :");
  if (!factors) {
    console.log("  (aucun second facteur enrôlé)");
  } else {
    factors.forEach((f, i) => {
      console.log(
        `  ${i + 1}. ${f.displayName || "(sans nom)"} — ${f.factorId}` +
          ` — enrôlé le ${f.enrollmentTime}`
      );
    });
  }

  if (command === "list") {
    console.log("");
    return;
  }

  if (!factors) {
    console.log("\nRien à réinitialiser.\n");
    return;
  }

  console.log(
    "\n⚠️  Cette opération retire la double authentification du compte."
  );
  console.log(
    "   L'utilisateur pourra se reconnecter avec son mot de passe seul,"
  );
  console.log(
    "   puis devra ré-enrôler une application d'authentification"
  );
  console.log("   (la porte MFA de l'app l'y obligera immédiatement).");
  console.log(
    "\n   Avez-vous vérifié l'identité du demandeur par un canal INDÉPENDANT"
  );
  console.log("   du courriel (appel, question de sécurité) ?");

  const answer = await confirm(
    `\nTapez le courriel complet pour confirmer (${email}) : `
  );
  if (answer !== email) {
    console.log("Annulé — le courriel saisi ne correspond pas.\n");
    process.exit(1);
  }

  await auth.updateUser(user.uid, { multiFactor: { enrolledFactors: [] } });

  // Invalide les jetons existants : les sessions ouvertes sont coupées.
  await auth.revokeRefreshTokens(user.uid);

  console.log(
    `\n✅ Facteurs retirés pour ${email} et sessions révoquées.` +
      `\n   Consignez cette opération (date, demandeur, vérification` +
      ` d'identité) — SECURITY_POLICY.md §6.\n`
  );
}

main().catch((e) => {
  console.error(`Échec : ${e.message}`);
  process.exit(1);
});
