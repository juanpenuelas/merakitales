const { db, bucket, requireAuth } = require("./admin");
const { moveFile } = require("./storage");
const { computeStep } = require("./draftStep");
const { getMessaging } = require("firebase-admin/messaging");

/**
 * Core logic to publish a draft. Can be called by HTTP handler or Cron Job.
 */
async function publishDraft(draftId, decidedByUid) {
  const draftRef = db.collection("tale_drafts").doc(draftId);
  const draftSnap = await draftRef.get();
  if (!draftSnap.exists) {
    throw new Error("Draft not found");
  }
  const d = draftSnap.data();
  if (d.status !== "pending" && d.status !== "scheduled") {
    throw new Error(`Draft is already ${d.status}`);
  }
  if (computeStep(d) !== "audio") {
    throw new Error("Draft is missing image/audio assets and cannot be published yet");
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
    decided_by: decidedByUid,
    assigned_tale_id: taleId,
  });

  // ---------------------------------------------------------
  // Send Push Notifications
  // ---------------------------------------------------------
  try {
    const messaging = getMessaging();
    
    // Notification payload for Spanish users
    const messageEs = {
      notification: {
        title: "¡Nuevo cuento disponible!",
        body: d.name_es,
      },
      topic: "new_tales_es",
      data: {
        taleId: taleId.toString(),
      }
    };

    // Notification payload for English users
    const messageEn = {
      notification: {
        title: "New tale available!",
        body: d.name_en,
      },
      topic: "new_tales_en",
      data: {
        taleId: taleId.toString(),
      }
    };

    const results = await Promise.allSettled([
      messaging.send(messageEs),
      messaging.send(messageEn)
    ]);
    
    results.forEach((result, index) => {
      if (result.status === "rejected") {
        const lang = index === 0 ? "es" : "en";
        console.error(`Error sending ${lang} push notification for tale ${taleId}:`, result.reason);
      }
    });
    console.log(`Push notifications dispatch completed for tale ${taleId}`);
  } catch (error) {
    console.error("Error sending push notifications:", error);
    // We don't throw here to avoid failing the draft publication if notifications fail
  }

  return taleId;
}

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

  try {
    const taleId = await publishDraft(draftId, req.auth.uid);
    return { taleId };
  } catch (e) {
    const { HttpsError } = require("firebase-functions/v2/https");
    throw new HttpsError("failed-precondition", e.message);
  }
}

module.exports = { approveDraftHandler, publishDraft };
