/**
 * Derives a draft's pipeline step purely from which assets exist.
 * Never stored — always computed from the draft's current fields, so it
 * can never disagree with reality.
 * @param {{ image_url?: string, audio_url_es?: string, audio_url_en?: string }} [draft]
 * @returns {"text" | "image" | "audio"}
 */
function computeStep({ image_url, audio_url_es, audio_url_en } = {}) {
  if (image_url && audio_url_es && audio_url_en) return "audio";
  if (image_url) return "image";
  return "text";
}

module.exports = { computeStep };
