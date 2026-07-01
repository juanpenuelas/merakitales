const { db, bucket, getOpenRouterApiKey, requireAuth } = require("./admin");
const { generateImage } = require("./openrouter");
const { resizeToWidth, uploadBase64Image, uploadBuffer, deletePrefix } = require("./storage");

/**
 * @param {import("firebase-functions/v2/https").CallableRequest} req
 * @returns {Promise<{ imageUrl: string, imageUrl640: string }>}
 */
async function generateTaleImageHandler(req) {
  requireAuth(req);
  const apiKey = getOpenRouterApiKey();
  const { draftId, feedback = null } = req.data || {};
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
  const d = snap.data();
  const storagePrefix = `drafts/${draftId}`;

  if (!d.image_prompt && !feedback) {
    const { HttpsError } = require("firebase-functions/v2/https");
    throw new HttpsError("failed-precondition", "Cannot regenerate image: draft has no image_prompt and no feedback was provided. Please provide feedback to generate a new image.");
  }

  const { b64 } = await generateImage({ prompt: d.image_prompt, feedback, apiKey });
  const imageBuffer = Buffer.from(b64, "base64");
  const image640 = await resizeToWidth({ buffer: imageBuffer, width: 640 });
  const imageUrl = await uploadBase64Image({ bucket, path: `${storagePrefix}/image_1024.png`, b64 });
  const imageUrl640 = await uploadBuffer({ bucket, path: `${storagePrefix}/image_640.png`, buffer: image640, contentType: "image/png" });

  await draftRef.update({
    step: "image",
    image_url: imageUrl,
    image_url_640px: imageUrl640,
  });

  return { imageUrl, imageUrl640 };
}

module.exports = { generateTaleImageHandler };
