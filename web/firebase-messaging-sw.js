// Service worker dédié à Firebase Cloud Messaging.
//
// Distinct du service worker de mise en cache de Flutter, retiré volontairement
// (--pwa-strategy=none) parce qu'il servait un bundle périmé. Celui-ci ne fait
// QUE recevoir les notifications en arrière-plan : il ne met rien en cache.
//
// Les clés ci-dessous sont des identifiants Firebase publics (pas des
// secrets) — voir PRODUCTION_CHECKLIST.md §4.
importScripts(
  "https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js"
);
importScripts(
  "https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js"
);

firebase.initializeApp({
  apiKey: "AIzaSyDx94b5rIzU-41eW4Dv_Z6SDIponfX1ZNo",
  appId: "1:187587171163:web:60a5b6a6cc4d4ffdc4c07e",
  messagingSenderId: "187587171163",
  projectId: "horizon-dbba0",
  authDomain: "horizon-dbba0.firebaseapp.com",
  storageBucket: "horizon-dbba0.firebasestorage.app",
});

const messaging = firebase.messaging();

// Notification reçue quand l'app est fermée ou en arrière-plan.
messaging.onBackgroundMessage(function (payload) {
  const title = (payload.notification && payload.notification.title) || "Horizon";
  const body = (payload.notification && payload.notification.body) || "";
  self.registration.showNotification(title, {
    body: body,
    icon: "/icons/Icon-192.png",
    badge: "/icons/Icon-192.png",
  });
});

// Ouvre (ou ramène au premier plan) l'app au clic sur la notification.
self.addEventListener("notificationclick", function (event) {
  event.notification.close();
  event.waitUntil(
    clients.matchAll({ type: "window" }).then(function (list) {
      for (const client of list) {
        if ("focus" in client) return client.focus();
      }
      if (clients.openWindow) return clients.openWindow("/");
    })
  );
});
