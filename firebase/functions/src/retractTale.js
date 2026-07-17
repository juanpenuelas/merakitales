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

  const esQuery = await db.collection("tales").where("tale_id", "==", taleId).where("lang", "==", "es").limit(1).get();
  const enQuery = await db.collection("tales").where("tale_id", "==", taleId).where("lang", "==", "en").limit(1).get();

  if (esQuery.empty || enQuery.empty) {
    const { HttpsError } = require("firebase-functions/v2/https");
    throw new HttpsError("not-found", "Tale not found");
  }

  const esSnap = esQuery.docs[0];
  const enSnap = enQuery.docs[0];
  const es = esSnap.data();
  const en = enSnap.data();
  const commonSnap = es.tale_common_data_ref ? await es.tale_common_data_ref.get() : null;

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
    is_premium_tale: es.is_premium_tale ?? false,
  });
  batch.delete(esSnap.ref);
  batch.delete(enSnap.ref);
  if (commonSnap && commonSnap.exists) {
    batch.delete(commonSnap.ref);
  }
  await batch.commit();

  return { draftId };
}

module.exports = { retractTaleHandler };
