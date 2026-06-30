const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getStorage } = require("firebase-admin/storage");

initializeApp();

const db = getFirestore();
const bucket = getStorage().bucket();

/**
 * Throws HttpsError if the caller is not the admin.
 * Secrets are mounted as env vars via the `secrets` option in onCall.
 * @param {import("firebase-functions/v2/https").CallableRequest} req
 */
function requireAuth(req) {
  const expected = process.env.ADMIN_UID;
  if (!req.auth || req.auth.uid !== expected) {
    const { HttpsError } = require("firebase-functions/v2/https");
    throw new HttpsError("permission-denied", "Not authorized.");
  }
}

/**
 * Reads the OpenRouter API key from the env var mounted via secrets.
 * @returns {string}
 */
function getOpenRouterApiKey() {
  return process.env.OPENROUTER_API_KEY;
}

module.exports = { db, bucket, getOpenRouterApiKey, requireAuth };
