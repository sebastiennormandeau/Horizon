#!/usr/bin/env node
/**
 * Génère un PDF FORMULAIRE (cases à cocher interactives) listant les actions
 * qui restent à la charge de Sébastien, tirées de PRODUCTION_CHECKLIST.md.
 * Cochable et enregistrable dans n'importe quel lecteur PDF.
 */
const fs = require("fs");
const path = require("path");
const { PDFDocument, StandardFonts, rgb } = require("pdf-lib");

const OUT = process.argv[2] || "HORIZON_ACTIONS.pdf";

// Palette accordée à l'app.
const GREEN = rgb(0.07, 0.63, 0.51);
const DARK = rgb(0.1, 0.14, 0.2);
const MUTED = rgb(0.35, 0.4, 0.48);
const LINE = rgb(0.85, 0.87, 0.9);

// --- Contenu : sections -> items {t: titre, i: [instructions]} -----------
const SECTIONS = [
  {
    title: "A — Pour utiliser l'app pleinement (maintenant)",
    intro:
      "Ces points rendent l'app complète pour toi et ta conjointe dès aujourd'hui.",
    items: [
      {
        t: "Générer la clé de signature Android",
        i: [
          "Dans un terminal, exécuter :",
          "keytool -genkey -v -keystore horizon-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias horizon",
          "Répondre aux questions, choisir deux mots de passe.",
          "Copier android/key.properties.example en android/key.properties et y mettre le chemin du .jks et les mots de passe.",
        ],
      },
      {
        t: "Sauvegarder le .jks en lieu sûr (au moins deux endroits)",
        i: [
          "NordPass (fichier + mots de passe) ET une copie hors ligne (clé USB rangée ailleurs).",
          "À perdre = impossible de mettre l'app à jour sur le Play Store. À ne jamais versionner (déjà exclu du dépôt).",
        ],
      },
      {
        t: "Enregistrer les empreintes SHA dans Firebase",
        i: [
          "keytool -list -v -keystore horizon-release.jks -alias horizon",
          "Copier SHA-1 et SHA-256 dans Console Firebase -> Paramètres du projet -> app Android. Requis par Play Integrity.",
        ],
      },
      {
        t: "Reconnecter CIBC pour activer les échéances de carte",
        i: [
          "Le produit liabilities est actif, mais fixé à la connexion : la connexion CIBC actuelle ne l'a pas.",
          "Réglages -> Mes comptes bancaires -> déconnecter CIBC, puis la reconnecter.",
          "Vérifier d'abord le coût dans le tableau de bord Plaid -> Activity -> Usage (liabilities est facturé).",
        ],
      },
      {
        t: "Activer et tester les notifications",
        i: [
          "Réglages -> Notifications -> Activer sur cet appareil, accepter la permission du navigateur.",
          "iPhone : ajouter d'abord Horizon à l'écran d'accueil (Partager -> Sur l'écran d'accueil).",
          "Test concret : trier une dépense jusqu'à faire passer une cagnotte sous le seuil -> une notification doit arriver.",
        ],
      },
      {
        t: "Enrôler le compte de ta conjointe et tester le défi MFA",
        i: [
          "Créer/ouvrir son compte, enrôler son application d'authentification.",
          "Se déconnecter puis se reconnecter pour vérifier le défi MFA (jamais exercé jusqu'ici).",
        ],
      },
    ],
  },
  {
    title: "B — Sécurité du poste et sauvegardes",
    intro: "Rapide, et important puisque l'app héberge de vraies données bancaires.",
    items: [
      {
        t: "Activer BitLocker et les mises à jour automatiques (Windows)",
        i: [
          "Paramètres -> Confidentialité et sécurité -> Chiffrement de l'appareil (BitLocker).",
          "Vérifier que Windows Update et Microsoft Defender sont actifs.",
        ],
      },
      {
        t: "Tester une restauration de sauvegarde Firestore (par trimestre)",
        i: [
          "Les sauvegardes (PITR + quotidiennes) sont actives. Une sauvegarde jamais testée ne compte pas.",
          "gcloud firestore backups list --project=horizon-dbba0",
          "Restaurer vers une base de test, vérifier, puis la supprimer. À refaire chaque trimestre.",
        ],
      },
    ],
  },
  {
    title: "C — Avant d'ouvrir l'app à d'autres personnes",
    intro:
      "L'inscription est déjà publique via l'URL. Ces points la rendent solide pour de vrais inconnus.",
    items: [
      {
        t: "Appliquer App Check (Enforce)",
        i: [
          "Console Firebase -> App Check -> onglet API : vérifier que les requêtes vérifiées montent.",
          "Seulement ensuite : Enforce sur Firestore, Functions, Auth, puis ENFORCE_APP_CHECK=true dans functions/.env et redéployer.",
          "Ne pas appliquer avant d'avoir vu des requêtes vérifiées, sous peine de te verrouiller dehors.",
        ],
      },
      {
        t: "Configurer un SMTP personnalisé (livraison courriel)",
        i: [
          "iCloud ne reçoit pas les courriels de vérification (domaine d'envoi partagé de Firebase).",
          "Console Firebase -> Authentication -> Templates -> paramètres SMTP, avec SendGrid/Postmark/Mailgun + SPF/DKIM.",
        ],
      },
      {
        t: "Personnaliser les gabarits de courriels en français",
        i: [
          "Console Firebase -> Authentication -> Templates : vérification et réinitialisation, en français.",
        ],
      },
      {
        t: "Activer la protection anti-énumération de courriels",
        i: [
          "Console Firebase -> Authentication -> Settings : protection contre l'énumération + quotas d'inscription.",
        ],
      },
      {
        t: "Restreindre les clés API Google",
        i: [
          "Console Google Cloud -> APIs & Services -> Credentials.",
          "Clé Android : restreindre au paquet com.vibecodingmind.horizon + empreinte SHA-1.",
          "Clé Web : restreindre aux domaines autorisés (référents HTTP).",
        ],
      },
      {
        t: "Faire réviser les documents légaux par un juriste",
        i: [
          "Conditions d'utilisation + politique de confidentialité (fr et traductions en), avant toute commercialisation.",
        ],
      },
    ],
  },
  {
    title: "D — Seulement si tu commercialises",
    intro: "À ignorer tant que l'app reste un usage privé pour ton foyer.",
    items: [
      {
        t: "Créer les comptes marchands",
        i: [
          "Google Play Console (25 $ US une fois) + profil de paiement.",
          "Apple Developer Program (99 $ US/an) — seulement si tu vises l'App Store.",
        ],
      },
      {
        t: "Configurer RevenueCat (abonnements) et son MFA",
        i: [
          "app.revenuecat.com : projet, entitlement premium, offres, clés SDK, webhook.",
          "Activer le MFA du compte (Account -> Security -> 2FA).",
        ],
      },
      {
        t: "Acheter un domaine réel + SSL",
        i: [
          "Firebase Hosting fournit le TLS. Ajouter le domaine dans Hosting et dans Authentication -> Authorized domains.",
          "Mettre à jour l'URL des politiques et le tableau de bord Plaid.",
        ],
      },
      {
        t: "Activer Google Play App Signing",
        i: [
          "Google conserve la clé de signature principale ; tu ne gères qu'une clé d'upload récupérable.",
          "Recommandé pour éviter le drame du keystore perdu.",
        ],
      },
    ],
  },
];

(async () => {
  const doc = await PDFDocument.create();
  const font = await doc.embedFont(StandardFonts.Helvetica);
  const bold = await doc.embedFont(StandardFonts.HelveticaBold);
  const mono = await doc.embedFont(StandardFonts.Courier);
  const form = doc.getForm();

  const W = 612, H = 792; // Lettre US
  const ML = 54, MR = 54, MT = 60, MB = 54;
  const CW = W - ML - MR;

  let page = doc.addPage([W, H]);
  let y = H - MT;
  let cbId = 0;

  const nl = (val) => font.encodeText ? val : val; // placeholder

  function ensure(space) {
    if (y - space < MB) {
      page = doc.addPage([W, H]);
      y = H - MT;
    }
  }

  // Découpe un texte pour tenir dans une largeur donnée.
  function wrap(text, f, size, maxw) {
    const words = text.split(" ");
    const lines = [];
    let cur = "";
    for (const w of words) {
      const test = cur ? cur + " " + w : w;
      if (f.widthOfTextAtSize(test, size) > maxw && cur) {
        lines.push(cur);
        cur = w;
      } else {
        cur = test;
      }
    }
    if (cur) lines.push(cur);
    return lines;
  }

  function drawWrapped(text, f, size, x, maxw, color, lineGap = 3) {
    for (const line of wrap(text, f, size, maxw)) {
      ensure(size + lineGap);
      page.drawText(line, { x, y: y - size, size, font: f, color });
      y -= size + lineGap;
    }
  }

  // --- En-tête ---
  page.drawText("Horizon", { x: ML, y: y - 22, size: 24, font: bold, color: GREEN });
  y -= 30;
  page.drawText("Mes actions a completer", {
    x: ML, y: y - 16, size: 15, font: bold, color: DARK,
  });
  y -= 24;
  drawWrapped(
    "Coche chaque case au fur et a mesure (le PDF est enregistrable). Genere depuis PRODUCTION_CHECKLIST.md. Les sections A et B sont prioritaires ; C avant d'ouvrir a d'autres ; D seulement en cas de commercialisation.",
    font, 9.5, ML, CW, MUTED, 3
  );
  y -= 8;
  page.drawLine({ start: { x: ML, y }, end: { x: W - MR, y }, thickness: 1, color: LINE });
  y -= 18;

  for (const section of SECTIONS) {
    ensure(60);
    page.drawText(section.title, { x: ML, y: y - 13, size: 13, font: bold, color: GREEN });
    y -= 20;
    drawWrapped(section.intro, font, 9, ML, CW, MUTED, 3);
    y -= 8;

    for (const item of section.items) {
      // Hauteur estimée du bloc pour éviter de casser un item en deux pages.
      ensure(40);

      const cbSize = 12;
      const cb = form.createCheckBox("cb" + cbId++);
      cb.addToPage(page, {
        x: ML,
        y: y - cbSize,
        width: cbSize,
        height: cbSize,
        borderColor: GREEN,
        borderWidth: 1.2,
      });

      const tx = ML + cbSize + 10;
      const tw = CW - cbSize - 10;
      // Titre de l'item (gras).
      for (const line of wrap(item.t, bold, 11, tw)) {
        ensure(11 + 3);
        page.drawText(line, { x: tx, y: y - 11, size: 11, font: bold, color: DARK });
        y -= 11 + 3;
      }
      y -= 2;
      // Instructions.
      for (const ins of item.i) {
        const looksCmd =
          ins.startsWith("keytool") ||
          ins.startsWith("gcloud") ||
          ins.startsWith("firebase") ||
          ins.includes("--project") ||
          ins.includes("key.properties");
        const f = looksCmd ? mono : font;
        const size = looksCmd ? 8 : 9;
        for (const line of wrap(ins, f, size, tw - 8)) {
          ensure(size + 3);
          page.drawText((looksCmd ? "" : "- ") + line, {
            x: tx + 6, y: y - size, size, font: f,
            color: looksCmd ? DARK : MUTED,
          });
          y -= size + 3;
        }
      }
      y -= 12;
    }
    y -= 6;
  }

  // Pied de page sur chaque page.
  const pages = doc.getPages();
  pages.forEach((p, i) => {
    p.drawText(`Horizon — actions a completer          ${i + 1} / ${pages.length}`, {
      x: ML, y: 28, size: 8, font, color: MUTED,
    });
  });

  const bytes = await doc.save();
  fs.writeFileSync(path.resolve(OUT), bytes);
  console.log(`PDF ecrit : ${path.resolve(OUT)} (${(bytes.length / 1024).toFixed(0)} Ko, ${pages.length} page(s), ${cbId} cases)`);
})();
