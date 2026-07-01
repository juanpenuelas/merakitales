const { db, requireAuth } = require("./admin");

/**
 * @param {import("firebase-functions/v2/https").CallableRequest} req
 * @returns {Promise<{ ok: boolean }>}
 */
async function updateDraftTextHandler(req) {
  requireAuth(req);
  const { draftId, lang, text } = req.data || {};
  const { HttpsError } = require("firebase-functions/v2/https");
  if (!draftId) throw new HttpsError("invalid-argument", "draftId required");
  if (lang !== "es" && lang !== "en") throw new HttpsError("invalid-argument", "lang must be 'es' or 'en'");
  if (typeof text !== "string" || !text.trim()) throw new HttpsError("invalid-argument", "text required");

  const draftRef = db.collection("tale_drafts").doc(draftId);
  const snap = await draftRef.get();
  if (!snap.exists) throw new HttpsError("not-found", "Draft not found");
  if (snap.data().status !== "pending") throw new HttpsError("failed-precondition", `Draft already ${snap.data().status}`);

  await draftRef.update({ [`specifications_${lang}`]: text.trim() });
  return { ok: true };
}

module.exports = { updateDraftTextHandler };
