const sharp = require("sharp");

/**
 * Resize an image buffer so its width <= target, never upscaling.
 * @param {{ buffer: Buffer, width: number }} opts
 * @returns {Promise<Buffer>}
 */
async function resizeToWidth({ buffer, width }) {
  return sharp(buffer)
    .resize({ width, withoutEnlargement: true })
    .png()
    .toBuffer();
}

/**
 * Upload a Buffer to Storage and make it publicly readable.
 * @param {{ bucket: import("firebase-admin/storage").Storage["bucket"], path: string, buffer: Buffer, contentType: string }} opts
 * @returns {Promise<string>} public URL
 */
async function uploadBuffer({ bucket, path, buffer, contentType }) {
  const file = bucket.file(path);
  await file.save(buffer, { metadata: { contentType } });
  await file.makePublic();
  return `https://storage.googleapis.com/${bucket.name}/${path}`;
}

/**
 * Upload a base64-encoded image.
 * @param {{ bucket, path: string, b64: string, contentType?: string }} opts
 * @returns {Promise<string>}
 */
async function uploadBase64Image({ bucket, path, b64, contentType = "image/png" }) {
  const buffer = Buffer.from(b64, "base64");
  return uploadBuffer({ bucket, path, buffer, contentType });
}

/**
 * Move (copy + delete) a file within the same bucket.
 * @param {{ bucket, fromPath: string, toPath: string }} opts
 * @returns {Promise<string>} new public URL
 */
async function moveFile({ bucket, fromPath, toPath }) {
  await bucket.file(fromPath).move(toPath);
  await bucket.file(toPath).makePublic();
  return `https://storage.googleapis.com/${bucket.name}/${toPath}`;
}

/**
 * Delete all files under a prefix (used on reject).
 * @param {{ bucket, prefix: string }} opts
 */
async function deletePrefix({ bucket, prefix }) {
  const [files] = await bucket.getFiles({ prefix });
  await Promise.all(files.map((f) => f.delete()));
}

/**
 * Download a file's contents as a Buffer.
 * @param {{ bucket, path: string }} opts
 * @returns {Promise<Buffer>}
 */
async function downloadFile({ bucket, path }) {
  const [buffer] = await bucket.file(path).download();
  return buffer;
}

/**
 * Check whether a file exists at the given path.
 * @param {{ bucket, path: string }} opts
 * @returns {Promise<boolean>}
 */
async function fileExists({ bucket, path }) {
  const [exists] = await bucket.file(path).exists();
  return exists;
}

module.exports = { resizeToWidth, uploadBuffer, uploadBase64Image, moveFile, deletePrefix, downloadFile, fileExists };
