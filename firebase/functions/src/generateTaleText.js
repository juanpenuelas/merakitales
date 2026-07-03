const { db, getOpenRouterApiKey, requireAuth } = require("./admin");
const { generateTaleText } = require("./openrouter");

/**
 * @param {import("firebase-functions/v2/https").CallableRequest} req
 * @returns {Promise<{ draftId: string }>}
 */
async function generateTaleTextHandler(req) {
  requireAuth(req);
  const apiKey = getOpenRouterApiKey();
  const { theme = null, feedback = null } = req.data || {};

  let draftId = req.data.draftId;
  
  try {
    const tale = await generateTaleText({ theme, feedback, apiKey });

    const draftUpdates = {
      name_es: tale.name_es,
      description_es: tale.description_es,
      specifications_es: tale.specifications_es,
      image_prompt: tale.image_prompt,
      name_en: tale.name_en,
      description_en: tale.description_en,
      specifications_en: tale.specifications_en,
      is_generating_text: false,
    };

    if (draftId) {
      await db.collection("tale_drafts").doc(draftId).update(draftUpdates);
    } else {
      draftId = db.collection("tale_drafts").doc().id;
      await db.collection("tale_drafts").doc(draftId).set({
        status: "pending",
        created_at: new Date(),
        decided_at: null,
        decided_by: null,
        audio_url_es: "",
        audio_url_en: "",
        image_url: "",
        image_url_640px: "",
        assigned_tale_id: null,
        retracted_from_tale_id: null,
        ...draftUpdates,
      });
    }
    return { draftId };
  } catch (err) {
    if (draftId) {
      await db.collection("tale_drafts").doc(draftId).update({ is_generating_text: false });
    }
    throw err;
  }
}

module.exports = { generateTaleTextHandler };
