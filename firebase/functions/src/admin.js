const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getStorage } = require("firebase-admin/storage");
const { defineString } = require("firebase-functions/params");

initializeApp();

const db = getFirestore();
const bucket = getStorage().bucket();

const openrouterApiKey = defineString("OPENROUTER_API_KEY");
const adminUid = defineString("ADMIN_UID");

/**
 * Throws HttpsError if the caller is not the admin.
 * @param {import("firebase-functions/v2/https").CallableRequest} req
 */
function requireAuth(req) {
  const expected = adminUid.value();
  if (!req.auth || req.auth.uid !== expected) {
    const { HttpsError } = require("firebase-functions/v2/https");
    throw new HttpsError("permission-denied", "Not authorized.");
  }
}

module.exports = { db, bucket, openrouterApiKey, adminUid, requireAuth };
