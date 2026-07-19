// Initialisation Admin SDK (API modulaire de firebase-admin 13+).
import { initializeApp } from "firebase-admin/app";
import { getFirestore, FieldValue, Timestamp } from "firebase-admin/firestore";
import { getAuth } from "firebase-admin/auth";

initializeApp();

export const db = getFirestore();
export const auth = getAuth();
export { FieldValue, Timestamp };
