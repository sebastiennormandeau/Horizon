// Initialisation Admin SDK (API modulaire de firebase-admin 13+).
import { initializeApp } from "firebase-admin/app";
import { getFirestore, FieldValue, Timestamp } from "firebase-admin/firestore";
import { getAuth } from "firebase-admin/auth";
import { getMessaging } from "firebase-admin/messaging";

initializeApp();

export const db = getFirestore();
export const auth = getAuth();
export const messaging = getMessaging();
export { FieldValue, Timestamp };
