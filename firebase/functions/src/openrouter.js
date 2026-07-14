const axios = require("axios");
const { jsonrepair } = require("jsonrepair");

function escapeXml(unsafe) {
  if (typeof unsafe !== 'string') return String(unsafe || '');
  return unsafe.replace(/[<>&'"]/g, function (c) {
    switch (c) {
      case '<': return '&lt;';
      case '>': return '&gt;';
      case '&': return '&amp;';
      case '\'': return '&apos;';
      case '"': return '&quot;';
    }
  });
}

const BASE_URL = "https://openrouter.ai/api/v1";

const TEXT_MODEL = "anthropic/claude-sonnet-4.6";
const IMAGE_MODEL = "bytedance-seed/seedream-4.5";
const TTS_EN_MODEL = "microsoft/mai-voice-2";
const TTS_EN_VOICE = "en-US-Aria:MAI-Voice-2";
const TTS_ES_MODEL = "microsoft/mai-voice-2";
const TTS_ES_VOICE = "es-MX-Valeria:MAI-Voice-2";

/**
 * @param {{ theme?: string|null, feedback?: string|null, apiKey: string }} opts
 * @returns {Promise<object>} parsed tale JSON
 */
async function generateTaleText({ theme, feedback, apiKey }) {
  const { buildMessages } = require("./prompts");
  const resp = await axios.post(
    `${BASE_URL}/chat/completions`,
    {
      model: TEXT_MODEL,
      messages: buildMessages({ theme, feedback }),
      max_tokens: 8000,
    },
    { headers: { Authorization: `Bearer ${apiKey}` }, timeout: 120000 }
  );
  const content = resp.data.choices[0].message.content;
  let cleaned = content.trim();
  const jsonMatch = cleaned.match(/```(?:json)?\s*([\s\S]*?)```/i);
  if (jsonMatch) {
    cleaned = jsonMatch[1].trim();
  }
  
  let parsed;
  try {
    parsed = JSON.parse(cleaned);
  } catch (firstError) {
    // Attempt repair (handles literal newlines, unescaped quotes, etc.)
    console.warn("JSON parse failed, attempting repair...", firstError.message);
    try {
      const repaired = jsonrepair(cleaned);
      parsed = JSON.parse(repaired);
      console.warn("JSON repair succeeded.");
    } catch (repairError) {
      console.error("JSON Parse Error details:", firstError.message);
      console.error("Raw content starts with:", content.slice(0, 500));
      console.error("Raw content ends with:", content.slice(-500));
      throw new Error(`Model did not return valid tale JSON. Parse error: ${firstError.message}`);
    }
  }
  const required = [
    "name_es", "description_es", "specifications_es",
    "name_en", "description_en", "specifications_en",
    "image_prompt",
  ];
  for (const k of required) {
    if (!parsed[k]) throw new Error(`Missing field in tale JSON: ${k}`);
  }
  return parsed;
}

/**
 * @param {{ prompt: string, apiKey: string, feedback?: string|null }} opts
 * @returns {Promise<{ b64: string, mediaType?: string }>}
 */
async function generateImage({ prompt, feedback, apiKey }) {
  let finalPrompt = "";
  if (prompt && prompt.trim().length > 0) {
    finalPrompt = feedback && feedback.trim().length > 0
      ? `${prompt.trim()}. Style adjustment: ${feedback.trim().slice(0, 500)}`
      : prompt.trim();
  } else {
    finalPrompt = feedback ? feedback.trim().slice(0, 500) : "A beautiful illustration for a children's storybook, colorful, magic.";
  }
  
  const resp = await axios.post(
    `${BASE_URL}/images`,
    {
      model: IMAGE_MODEL,
      prompt: finalPrompt,
      resolution: "2K",
      aspect_ratio: "1:1",
      output_format: "png",
      response_format: "b64_json",
    },
    { headers: { Authorization: `Bearer ${apiKey}` }, timeout: 90000 }
  );
  const img = resp.data.data[0];
  
  if (!img.b64_json && img.url) {
    // If API ignores response_format and returns a URL instead, we fetch it and convert to b64.
    const imageResp = await axios.get(img.url, { responseType: 'arraybuffer' });
    return { b64: Buffer.from(imageResp.data).toString('base64'), mediaType: 'image/png' };
  }
  
  return { b64: img.b64_json, mediaType: img.media_type };
}

/**
 * @param {{ input: string, apiKey: string, lang?: "es"|"en", voice?: string }} opts
 * @returns {Promise<Buffer>}
 */
async function generateSpeech({ input, apiKey, lang = "en", voice }) {
  const model = lang === "es" ? TTS_ES_MODEL : TTS_EN_MODEL;
  const defaultVoice = lang === "es" ? TTS_ES_VOICE : TTS_EN_VOICE;
  const targetVoice = voice || defaultVoice;
  
  const escapedInput = escapeXml(input);
  const xmlLang = lang === "es" ? "es-MX" : "en-US";
  
  const ssmlInput = `
<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xmlns:mstts="https://www.w3.org/2001/mstts" xml:lang="${xmlLang}">
  <voice name="${targetVoice}">
    <mstts:express-as style="affectionate" styledegree="1.2">
      <prosody rate="-15%" pitch="-5%">
        ${escapedInput}
      </prosody>
    </mstts:express-as>
  </voice>
</speak>`.trim();

  const resp = await axios.post(
    `${BASE_URL}/audio/speech`,
    { model, input: ssmlInput, voice: targetVoice, response_format: "mp3" },
    {
      headers: { Authorization: `Bearer ${apiKey}` },
      responseType: "arraybuffer",
      timeout: 90000,
    }
  );
  return Buffer.from(resp.data);
}

module.exports = { generateTaleText, generateImage, generateSpeech, BASE_URL };
