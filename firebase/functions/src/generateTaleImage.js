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

  let promptToUse = d.image_prompt;
  if (!promptToUse || promptToUse.trim().length === 0) {
    const storyText = d.specifications_en || d.specifications_es || "";
    if (storyText.trim().length > 0) {
      const preview = storyText.trim().slice(0, 400).replace(/\n/g, " ");
      promptToUse = `A beautiful illustration for a children's storybook, colorful, magic, cute. Story context: ${preview}`;
    }
  }

  try {
    const { b64 } = await generateImage({ prompt: promptToUse, feedback, apiKey });
    const imageBuffer = Buffer.from(b64, "base64");
    const image640 = await resizeToWidth({ buffer: imageBuffer, width: 640 });
    const rawImageUrl = await uploadBase64Image({ bucket, path: `${storagePrefix}/image_1024.png`, b64 });
    const rawImageUrl640 = await uploadBuffer({ bucket, path: `${storagePrefix}/image_640.png`, buffer: image640, contentType: "image/png" });
    
    const ts = Date.now();
    const imageUrl = `${rawImageUrl}?v=${ts}`;
    const imageUrl640 = `${rawImageUrl640}?v=${ts}`;

    await draftRef.update({
      image_url: imageUrl,
      image_url_640px: imageUrl640,
      is_generating_image: false,
    });

    return { imageUrl, imageUrl640 };
  } catch (err) {
    await draftRef.update({ is_generating_image: false });
    throw err;
  }
}

module.exports = { generateTaleImageHandler };
