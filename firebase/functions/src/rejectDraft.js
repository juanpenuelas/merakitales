const { db, bucket, requireAuth } = require("./admin");
const { deletePrefix } = require("./storage");

/**
 * @param {import("firebase-functions/v2/https").CallableRequest} req
 * @returns {Promise<{ ok: boolean }>}
 */
async function rejectDraftHandler(req) {
  requireAuth(req);
  const { draftId } = req.data;
  if (!draftId) {
    const { HttpsError } = require("firebase-functions/v2/https");
    throw new HttpsError("invalid-argument", "draftId required");
  }
  const draftRef = db.collection("tale_drafts").doc(draftId);
  const snap = await draftRef.get();
  if (!snap.exists) {
    const { HttpsError } = require("firebase-functions/v2/https");
    throw new HttpsError("not-found", "Draft not found");
  }
  await draftRef.delete();
  await deletePrefix({ bucket, prefix: `drafts/${draftId}` });
  return { ok: true };
}

module.exports = { rejectDraftHandler };
