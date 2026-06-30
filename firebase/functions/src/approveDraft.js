const { db, bucket, requireAuth } = require("./admin");
const { moveFile } = require("./storage");

/**
 * @param {import("firebase-functions/v2/https").CallableRequest} req
 * @returns {Promise<{ taleId: number }>}
 */
async function approveDraftHandler(req) {
  requireAuth(req);
  const { draftId } = req.data;
  if (!draftId) {
    const { HttpsError } = require("firebase-functions/v2/https");
    throw new HttpsError("invalid-argument", "draftId required");
  }

  const draftRef = db.collection("tale_drafts").doc(draftId);
  const draftSnap = await draftRef.get();
  if (!draftSnap.exists) {
    const { HttpsError } = require("firebase-functions/v2/https");
    throw new HttpsError("not-found", "Draft not found");
  }
  const d = draftSnap.data();
  if (d.status !== "pending") {
    const { HttpsError } = require("firebase-functions/v2/https");
    throw new HttpsError("failed-precondition", `Draft already ${d.status}`);
  }

  // Assign next tale_id in a transaction
  const taleId = await db.runTransaction(async (tx) => {
    const q = await tx.get(db.collection("tales").orderBy("tale_id", "desc").limit(1));
    const maxId = q.empty ? 0 : q.docs[0].data().tale_id || 0;
    return maxId + 1;
  });

  // Move storage files drafts/{draftId}/ -> tales/{taleId}/
  const fromPrefix = `drafts/${draftId}`;
  const toPrefix = `tales/${taleId}`;
  const imageUrl = await moveFile({ bucket, fromPath: `${fromPrefix}/image_1024.png`, toPath: `${toPrefix}/image_1024.png` });
  const imageUrl640 = await moveFile({ bucket, fromPath: `${fromPrefix}/image_640.png`, toPath: `${toPrefix}/image_640.png` });
  const audioUrlEs = await moveFile({ bucket, fromPath: `${fromPrefix}/audio_es.mp3`, toPath: `${toPrefix}/audio_es.mp3` });
  const audioUrlEn = await moveFile({ bucket, fromPath: `${fromPrefix}/audio_en.mp3`, toPath: `${toPrefix}/audio_en.mp3` });

  const now = new Date();
  const commonRef = db.collection("tales_common_data").doc(`${taleId}`);

  // Write common_data
  await commonRef.set({
    tale_id: taleId,
    image_url_1024px: imageUrl,
    image_url_640px: imageUrl640,
  });

  // Write ES tale
  await db.collection("tales").doc(`${taleId}_es`).set({
    name: d.name_es,
    description: d.description_es,
    specifications: d.specifications_es,
    price: 0,
    created_at: now,
    modified_at: now,
    on_sale: false,
    sale_price: 0,
    quantity: 0,
    image_url: imageUrl,
    image_url_640px: imageUrl640,
    lang: "es",
    tale_id: taleId,
    tale_common_data_ref: commonRef,
    audio_url: audioUrlEs,
  });

  // Write EN tale
  await db.collection("tales").doc(`${taleId}_en`).set({
    name: d.name_en,
    description: d.description_en,
    specifications: d.specifications_en,
    price: 0,
    created_at: now,
    modified_at: now,
    on_sale: false,
    sale_price: 0,
    quantity: 0,
    image_url: imageUrl,
    image_url_640px: imageUrl640,
    lang: "en",
    tale_id: taleId,
    tale_common_data_ref: commonRef,
    audio_url: audioUrlEn,
  });

  // Mark draft approved
  await draftRef.update({
    status: "approved",
    decided_at: now,
    decided_by: req.auth.uid,
    assigned_tale_id: taleId,
  });

  return { taleId };
}

module.exports = { approveDraftHandler };
