const axios = require("axios");

const BASE_URL = "https://openrouter.ai/api/v1";

const TEXT_MODEL = "openai/gpt-4o-mini";
const IMAGE_MODEL = "bytedance-seed/seedream-4.5";
const TTS_EN_MODEL = "hexgrad/kokoro-82m";
const TTS_EN_VOICE = "am_adam";
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
      response_format: { type: "json_object" },
    },
    { headers: { Authorization: `Bearer ${apiKey}` }, timeout: 120000 }
  );
  const content = resp.data.choices[0].message.content;
  const cleaned = content.replace(/^```json\s*/i, "").replace(/```\s*$/, "").trim();
  let parsed;
  try {
    parsed = JSON.parse(cleaned);
  } catch (e) {
    throw new Error("Model did not return valid tale JSON: " + content.slice(0, 200));
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
 * @param {{ prompt: string, apiKey: string }} opts
 * @returns {Promise<{ b64: string, mediaType?: string }>}
 */
async function generateImage({ prompt, apiKey }) {
  const resp = await axios.post(
    `${BASE_URL}/images`,
    {
      model: IMAGE_MODEL,
      prompt,
      resolution: "2K",
      aspect_ratio: "1:1",
      output_format: "png",
    },
    { headers: { Authorization: `Bearer ${apiKey}` }, timeout: 90000 }
  );
  const img = resp.data.data[0];
  return { b64: img.b64_json, mediaType: img.media_type };
}

/**
 * @param {{ input: string, apiKey: string, lang?: "es"|"en", voice?: string }} opts
 * @returns {Promise<Buffer>}
 */
async function generateSpeech({ input, apiKey, lang = "en", voice }) {
  const model = lang === "es" ? TTS_ES_MODEL : TTS_EN_MODEL;
  const defaultVoice = lang === "es" ? TTS_ES_VOICE : TTS_EN_VOICE;
  const resp = await axios.post(
    `${BASE_URL}/audio/speech`,
    { model, input, voice: voice || defaultVoice, response_format: "mp3" },
    {
      headers: { Authorization: `Bearer ${apiKey}` },
      responseType: "arraybuffer",
      timeout: 90000,
    }
  );
  return Buffer.from(resp.data);
}

module.exports = { generateTaleText, generateImage, generateSpeech, BASE_URL };
