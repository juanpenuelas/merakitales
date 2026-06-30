const { db, bucket, getOpenRouterApiKey, requireAuth } = require("./admin");
const { generateTaleText, generateImage, generateSpeech } = require("./openrouter");
const { resizeToWidth, uploadBuffer, uploadBase64Image, deletePrefix } = require("./storage");

/**
 * @param {import("firebase-functions/v2/https").CallableRequest} req
 * @returns {Promise<{ draftId: string }>}
 */
async function generateTaleDraftHandler(req) {
  requireAuth(req);
  const apiKey = getOpenRouterApiKey();
  const theme = req.data?.theme || null;
  const draftId = db.collection("tale_drafts").doc().id;
  const storagePrefix = `drafts/${draftId}`;

  try {
    // 1. Text
    const tale = await generateTaleText({ theme, apiKey });

    // 2. Image (1024 original + 640 resized)
    const { b64 } = await generateImage({ prompt: tale.image_prompt, apiKey });
    const imageBuffer = Buffer.from(b64, "base64");
    const image640 = await resizeToWidth({ buffer: imageBuffer, width: 640 });
    const imageUrl = await uploadBase64Image({ bucket, path: `${storagePrefix}/image_1024.png`, b64 });
    const imageUrl640 = await uploadBuffer({ bucket, path: `${storagePrefix}/image_640.png`, buffer: image640, contentType: "image/png" });

    // 3. TTS ES + EN in parallel
    const [audioEs, audioEn] = await Promise.all([
      generateSpeech({ input: tale.specifications_es, apiKey }),
      generateSpeech({ input: tale.specifications_en, apiKey }),
    ]);
    const [audioUrlEs, audioUrlEn] = await Promise.all([
      uploadBuffer({ bucket, path: `${storagePrefix}/audio_es.mp3`, buffer: audioEs, contentType: "audio/mpeg" }),
      uploadBuffer({ bucket, path: `${storagePrefix}/audio_en.mp3`, buffer: audioEn, contentType: "audio/mpeg" }),
    ]);

    // 5. Save draft
    const draft = {
      status: "pending",
      created_at: new Date(),
      decided_at: null,
      decided_by: null,
      name_es: tale.name_es,
      description_es: tale.description_es,
      specifications_es: tale.specifications_es,
      audio_url_es: audioUrlEs,
      audio_duration_es: null,
      image_prompt_es: tale.image_prompt,
      name_en: tale.name_en,
      description_en: tale.description_en,
      specifications_en: tale.specifications_en,
      audio_url_en: audioUrlEn,
      audio_duration_en: null,
      image_prompt_en: tale.image_prompt,
      image_url: imageUrl,
      image_url_640px: imageUrl640,
      assigned_tale_id: null,
    };
    await db.collection("tale_drafts").doc(draftId).set(draft);
    return { draftId };
  } catch (err) {
    // Cleanup partial files
    try { await deletePrefix({ bucket, prefix: storagePrefix }); } catch (_) {}
    throw err;
  }
}

module.exports = { generateTaleDraftHandler };
