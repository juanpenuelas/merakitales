const { db, bucket, requireAuth } = require("./admin");
const { moveFile } = require("./storage");

/**
 * @param {import("firebase-functions/v2/https").CallableRequest} req
 * @returns {Promise<{ draftId: string }>}
 */
async function retractTaleHandler(req) {
  requireAuth(req);
  const { taleId } = req.data;
  if (taleId == null) {
    const { HttpsError } = require("firebase-functions/v2/https");
    throw new HttpsError("invalid-argument", "taleId required");
  }

  const esSnap = await db.collection("tales").doc(`${taleId}_es`).get();
  const enSnap = await db.collection("tales").doc(`${taleId}_en`).get();
  const commonSnap = await db.collection("tales_common_data").doc(`${taleId}`).get();

  if (!esSnap.exists || !enSnap.exists) {
    const { HttpsError } = require("firebase-functions/v2/https");
    throw new HttpsError("not-found", "Tale not found");
  }

  const es = esSnap.data();
  const en = enSnap.data();
  const common = commonSnap.exists ? commonSnap.data() : null;

  const draftId = db.collection("tale_drafts").doc().id;
  const fromPrefix = `tales/${taleId}`;
  const toPrefix = `drafts/${draftId}`;

  const moveIfExists = async (filename) => {
    try {
      return await moveFile({ bucket, fromPath: `${fromPrefix}/${filename}`, toPath: `${toPrefix}/${filename}` });
    } catch (_) {
      return null;
    }
  };
  const imageUrl = await moveIfExists("image_1024.png");
  const imageUrl640 = await moveIfExists("image_640.png");
  const audioUrlEs = await moveIfExists("audio_es.mp3");
  const audioUrlEn = await moveIfExists("audio_en.mp3");

  // Create the draft and delete the published docs atomically so a crash
  // mid-way never leaves a straddled state (draft created but tale only
  // partially deleted, or vice versa).
  const batch = db.batch();
  batch.set(db.collection("tale_drafts").doc(draftId), {
    status: "pending",
    step: "audio",
    created_at: new Date(),
    decided_at: null,
    decided_by: null,
    name_es: es.name,
    description_es: es.description,
    specifications_es: es.specifications,
    audio_url_es: audioUrlEs || es.audio_url,
    image_prompt: "",
    name_en: en.name,
    description_en: en.description,
    specifications_en: en.specifications,
    audio_url_en: audioUrlEn || en.audio_url,
    image_url: imageUrl || es.image_url,
    image_url_640px: imageUrl640 || es.image_url_640px,
    assigned_tale_id: null,
    retracted_from_tale_id: taleId,
  });
  batch.delete(db.collection("tales").doc(`${taleId}_es`));
  batch.delete(db.collection("tales").doc(`${taleId}_en`));
  if (commonSnap.exists) {
    batch.delete(db.collection("tales_common_data").doc(`${taleId}`));
  }
  await batch.commit();

  return { draftId };
}

module.exports = { retractTaleHandler };
