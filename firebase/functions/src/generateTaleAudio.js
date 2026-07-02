const { db, bucket, getOpenRouterApiKey, requireAuth } = require("./admin");
const { generateSpeech } = require("./openrouter");
const { uploadBuffer } = require("./storage");

/**
 * @param {import("firebase-functions/v2/https").CallableRequest} req
 * @returns {Promise<{ audioUrl: string }>}
 */
async function generateTaleAudioHandler(req) {
  requireAuth(req);
  const apiKey = getOpenRouterApiKey();
  const { draftId, lang, feedback = null } = req.data || {};
  if (!draftId) {
    const { HttpsError } = require("firebase-functions/v2/https");
    throw new HttpsError("invalid-argument", "draftId required");
  }
  if (!lang) {
    const { HttpsError } = require("firebase-functions/v2/https");
    throw new HttpsError("invalid-argument", "lang required");
  }
  if (lang !== "es" && lang !== "en") {
    const { HttpsError } = require("firebase-functions/v2/https");
    throw new HttpsError("invalid-argument", "lang must be 'es' or 'en'");
  }

  const draftRef = db.collection("tale_drafts").doc(draftId);
  const snap = await draftRef.get();
  if (!snap.exists) {
    const { HttpsError } = require("firebase-functions/v2/https");
    throw new HttpsError("not-found", "Draft not found");
  }
  const d = snap.data();

  const text = lang === "es" ? d.specifications_es : d.specifications_en;
  if (!text || text.trim().length === 0) {
    const { HttpsError } = require("firebase-functions/v2/https");
    throw new HttpsError("failed-precondition", "Draft has no text for " + lang);
  }

  const audioBuffer = await generateSpeech({ input: text, lang, feedback, apiKey });
  const audioUrl = await uploadBuffer({
    bucket,
    path: `drafts/${draftId}/audio_${lang}.mp3`,
    buffer: audioBuffer,
    contentType: "audio/mpeg",
  });

  const update = lang === "es" ? { audio_url_es: audioUrl } : { audio_url_en: audioUrl };
  await draftRef.update(update);

  return { audioUrl };
}

module.exports = { generateTaleAudioHandler };
