const { db, bucket, requireAuth } = require("./admin");
const { resizeToWidth, uploadBuffer, downloadFile, fileExists } = require("./storage");

/**
 * @param {import("firebase-functions/v2/https").CallableRequest} req
 * @returns {Promise<{ imageUrl: string, imageUrl640: string }>}
 */
async function resizeDraftImageHandler(req) {
  requireAuth(req);
  const { draftId } = req.data || {};
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

  const path1024 = `drafts/${draftId}/image_1024.png`;
  if (!(await fileExists({ bucket, path: path1024 }))) {
    const { HttpsError } = require("firebase-functions/v2/https");
    throw new HttpsError("failed-precondition", "Image not uploaded yet");
  }

  const buffer = await downloadFile({ bucket, path: path1024 });
  const imageUrl = await uploadBuffer({ bucket, path: path1024, buffer, contentType: "image/png" });

  const resized = await resizeToWidth({ buffer, width: 640 });
  const imageUrl640 = await uploadBuffer({
    bucket,
    path: `drafts/${draftId}/image_640.png`,
    buffer: resized,
    contentType: "image/png",
  });

  await draftRef.update({ image_url: imageUrl, image_url_640px: imageUrl640 });

  return { imageUrl, imageUrl640 };
}

module.exports = { resizeDraftImageHandler };
