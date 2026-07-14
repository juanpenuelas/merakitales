const axios = require("axios");

/**
 * Calls OpenRouter to add acting tags to the tale text.
 * @param {string} text - Original tale text
 * @param {string} lang - Language ('es' or 'en')
 * @param {string} openRouterApiKey - OpenRouter API key
 * @returns {Promise<string>} The text with [style:X]...[/style] tags
 */
async function addActingTags(text, lang, openRouterApiKey) {
  if (!openRouterApiKey) {
    throw new Error("Missing OpenRouter API key");
  }

  const allowedStyles = "excited, whispering, fearful, happy, joyful, sad, shouting, surprised";

  const systemPrompt = `You are an audio director for children's tales. 
Your job is to add acting style tags to a given text.
The allowed styles are ONLY: ${allowedStyles}.
Format: [style:excited]...[/style].

CRITICAL RULES:
1. Do NOT change, add, or remove ANY words from the original text. ONLY add the tags.
2. Do NOT tag every sentence. Only add tags for notable emotion changes, dialogues, or very expressive parts.
3. Keep the normal narration without tags.
4. Do NOT nest tags.`;

  const userPrompt = `Here is the tale text (${lang}):\n\n${text}\n\nPlease add the acting tags following the rules.`;

  try {
    const response = await axios.post(
      'https://openrouter.ai/api/v1/chat/completions',
      {
        model: 'anthropic/claude-3-haiku',
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: userPrompt }
        ],
        temperature: 0.1 // Low temperature to stick to the text
      },
      {
        headers: {
          'Authorization': `Bearer ${openRouterApiKey}`,
          'Content-Type': 'application/json',
          'HTTP-Referer': 'https://merakitales.web.app', // Required by OpenRouter
          'X-Title': 'MerakiTales' // Required by OpenRouter
        },
        timeout: 30000 // 30 seconds
      }
    );

    const generatedText = response.data.choices[0].message.content.trim();
    return generatedText;
  } catch (error) {
    console.error("Audio Director Error:", error.message);
    throw new Error(`Audio Director failed: ${error.message}`);
  }
}

module.exports = { addActingTags };
