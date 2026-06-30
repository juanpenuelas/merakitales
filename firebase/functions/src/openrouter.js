const axios = require("axios");

const BASE_URL = "https://openrouter.ai/api/v1";

const TEXT_MODEL = "nvidia/llama-3.1-nemotron-70b-instruct";
const IMAGE_MODEL = "bytedance-seed/seedream-4.5";
const TTS_MODEL = "openai/gpt-4o-mini-tts-2025-12-15";
const TTS_VOICE = "alloy";

/**
 * @param {{ theme?: string|null, apiKey: string }} opts
 * @returns {Promise<object>} parsed tale JSON
 */
async function generateTaleText({ theme, apiKey }) {
  const { buildMessages } = require("./prompts");
  const resp = await axios.post(
    `${BASE_URL}/chat/completions`,
    {
      model: TEXT_MODEL,
      messages: buildMessages(theme),
      response_format: { type: "json_object" },
    },
    { headers: { Authorization: `Bearer ${apiKey}` }, timeout: 60000 }
  );
  const content = resp.data.choices[0].message.content;
  const parsed = JSON.parse(content);
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
      resolution: "1K",
      aspect_ratio: "1:1",
      output_format: "png",
    },
    { headers: { Authorization: `Bearer ${apiKey}` }, timeout: 90000 }
  );
  const img = resp.data.data[0];
  return { b64: img.b64_json, mediaType: img.media_type };
}

/**
 * @param {{ input: string, apiKey: string, voice?: string }} opts
 * @returns {Promise<Buffer>}
 */
async function generateSpeech({ input, apiKey, voice = TTS_VOICE }) {
  const resp = await axios.post(
    `${BASE_URL}/audio/speech`,
    { model: TTS_MODEL, input, voice, response_format: "mp3" },
    {
      headers: { Authorization: `Bearer ${apiKey}` },
      responseType: "arraybuffer",
      timeout: 90000,
    }
  );
  return Buffer.from(resp.data);
}

module.exports = { generateTaleText, generateImage, generateSpeech, BASE_URL };
