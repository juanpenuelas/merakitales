const { db, requireAuth } = require("./admin");

/**
 * @param {import("firebase-functions/v2/https").CallableRequest} req
 * @returns {Promise<{ success: boolean, scheduledFor: string }>}
 */
async function scheduleDraftHandler(req) {
  requireAuth(req);
  const { draftId, scheduledAtISO } = req.data;
  
  if (!draftId) {
    const { HttpsError } = require("firebase-functions/v2/https");
    throw new HttpsError("invalid-argument", "draftId required");
  }
  if (!scheduledAtISO) {
    const { HttpsError } = require("firebase-functions/v2/https");
    throw new HttpsError("invalid-argument", "scheduledAtISO required");
  }

  const scheduledDate = new Date(scheduledAtISO);
  if (isNaN(scheduledDate.getTime())) {
    const { HttpsError } = require("firebase-functions/v2/https");
    throw new HttpsError("invalid-argument", "Invalid date format");
  }

  const draftRef = db.collection("tale_drafts").doc(draftId);
  const snap = await draftRef.get();
  if (!snap.exists) {
    const { HttpsError } = require("firebase-functions/v2/https");
    throw new HttpsError("not-found", "Draft not found");
  }

  await draftRef.update({
    status: "scheduled",
    scheduled_at: scheduledDate,
    scheduled_by: req.auth.uid,
  });

  return { success: true, scheduledFor: scheduledDate.toISOString() };
}

module.exports = { scheduleDraftHandler };
