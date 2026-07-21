#!/usr/bin/env node
/**
 * Outil d'administration — vérification manuelle d'un courriel.
 *
 * POURQUOI CE SCRIPT
 * Certains fournisseurs de messagerie (iCloud notamment) rejettent
 * silencieusement les courriels envoyés depuis le domaine d'envoi par
 * défaut de Firebase (réputation partagée entre des milliers de projets) —
 * voir PRODUCTION_CHECKLIST.md §1. En attendant la configuration d'un SMTP
 * personnalisé, ce script permet de débloquer un compte dont le
 * *propriétaire* n'a jamais reçu son courriel, sans attendre la livraison.
 *
 * ⚠️ Ce contournement suppose que le compte appartient réellement à la
 * personne qui a tenté l'inscription (elle contrôle déjà l'adresse : c'est
 * elle qui l'a saisie). Ne l'utiliser QUE pour ses propres comptes ou après
 * avoir confirmé l'identité du demandeur — la vérification de courriel
 * existe aussi pour éviter qu'un compte soit créé avec l'adresse de
 * quelqu'un d'autre.
 *
 * PRÉREQUIS : voir mfa-admin.js (même prérequis gcloud, même projet).
 *
 * USAGE
 *   cd functions
 *   node scripts/verify-email.js check  quelquun@example.com
 *   node scripts/verify-email.js verify quelquun@example.com
 */

const readline = require("readline");
const { initializeApp, applicationDefault } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");

const PROJECT_ID = process.env.GOOGLE_CLOUD_PROJECT || "horizon-dbba0";

function usage() {
  console.log(`
Usage :
  node scripts/verify-email.js check  <courriel>   Affiche le statut
  node scripts/verify-email.js verify <courriel>   Marque comme vérifié

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

async function main() {
  const [command, email] = process.argv.slice(2);

  if (!command || !email) {
    usage();
    process.exit(1);
  }
  if (!["check", "verify"].includes(command)) {
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

  console.log(`\nCompte   : ${user.email}`);
  console.log(`UID      : ${user.uid}`);
  console.log(`Vérifié  : ${user.emailVerified ? "oui" : "non"}`);
  console.log(`Créé le  : ${user.metadata.creationTime}`);

  if (command === "check") {
    console.log("");
    return;
  }

  if (user.emailVerified) {
    console.log("\nDéjà vérifié — rien à faire.\n");
    return;
  }

  console.log(
    "\n⚠️  Ceci marque le courriel comme vérifié SANS lien de confirmation."
  );
  console.log(
    "   À utiliser uniquement si vous êtes certain que ce compte appartient"
  );
  console.log("   réellement à la personne qui a tenté l'inscription.");

  const answer = await confirm(
    `\nTapez le courriel complet pour confirmer (${email}) : `
  );
  if (answer !== email) {
    console.log("Annulé — le courriel saisi ne correspond pas.\n");
    process.exit(1);
  }

  await auth.updateUser(user.uid, { emailVerified: true });

  console.log(
    `\n✅ ${email} marqué comme vérifié. L'utilisateur peut maintenant se` +
      ` connecter et passera directement à l'enrôlement MFA.\n`
  );
}

main().catch((e) => {
  console.error(`Échec : ${e.message}`);
  process.exit(1);
});
