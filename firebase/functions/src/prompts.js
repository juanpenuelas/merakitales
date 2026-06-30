const TALE_TEXT_PROMPT = `You are a children's book author writing for ages 4-8.
Write a COMPLETE, original bedtime story. Rules:
- Safe, gentle, age-appropriate. No violence, weapons, death, or adult themes.
- Positive values (kindness, courage, friendship, curiosity).
- 400-600 words per language.
- Provide BOTH a Spanish (es) and an English (en) version. The English version must be a natural adaptation (not a literal translation) suitable for native English-speaking children.
- Generate a short "image_prompt" (one sentence in English) describing a single warm, friendly illustration that captures the story's mood (children's book illustration style, soft colors, no text in image, no characters with copyrighted likenesses).
- "description" is a 1-2 sentence teaser for the list view.
- "name" is the story title.

Respond ONLY with a JSON object matching this exact shape:
{
  "name_es": string,
  "description_es": string,
  "specifications_es": string,
  "name_en": string,
  "description_en": string,
  "specifications_en": string,
  "image_prompt": string
}`;

/**
 * @param {string|null} theme optional theme seed (e.g. "friendship")
 * @returns {Array<{role: string, content: string}>}
 */
function buildMessages(theme) {
  const userContent = theme
    ? `Write a bedtime story about the theme: "${theme}".`
    : "Write a bedtime story. Pick any uplifting theme.";
  return [
    { role: "system", content: TALE_TEXT_PROMPT },
    { role: "user", content: userContent },
  ];
}

module.exports = { TALE_TEXT_PROMPT, buildMessages };
