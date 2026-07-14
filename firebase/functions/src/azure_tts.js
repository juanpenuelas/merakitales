const axios = require("axios");

/**
 * Validates and sanitizes text for XML/SSML usage.
 * @param {string} text 
 * @returns {string}
 */
function escapeXml(text) {
  if (typeof text !== 'string') return '';
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;');
}

/**
 * Calls Azure Speech REST API with SSML to generate audio.
 * @param {Object} params
 * @param {string} params.input - The text to synthesize
 * @param {string} params.lang - "es" or "en"
 * @param {string} params.apiKey - Azure Speech Key
 * @param {string} params.region - Azure Speech Region (e.g., "westeurope")
 * @returns {Promise<Buffer>} The MP3 audio buffer
 */
async function generateSpeechFromAzure({ input, lang, apiKey, region }) {
  if (!apiKey || !region) {
    throw new Error("Missing Azure Speech credentials");
  }

  const endpoint = `https://${region}.tts.speech.microsoft.com/cognitiveservices/v1`;

  // Select Native Neural Voice based on language
  const voiceName = lang === "es" ? "es-ES-ElviraNeural" : "en-GB-SoniaNeural";
  const langCode = lang === "es" ? "es-ES" : "en-GB";

  // Build SSML string with prosody adjustments (calm storytelling)
  const escapedText = escapeXml(input);
  const ssml = `
<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xmlns:mstts="https://www.w3.org/2001/mstts" xml:lang="${langCode}">
  <voice name="${voiceName}">
    <prosody rate="-15%" pitch="-5%">
      ${escapedText}
    </prosody>
  </voice>
</speak>`.trim();

  try {
    const response = await axios.post(
      endpoint,
      ssml,
      {
        headers: {
          "Ocp-Apim-Subscription-Key": apiKey,
          "Content-Type": "application/ssml+xml",
          "X-Microsoft-OutputFormat": "audio-24khz-48kbitrate-mono-mp3",
          "User-Agent": "MerakiTales-TTS"
        },
        responseType: "arraybuffer", // Important for receiving binary audio
        timeout: 90000 // 90 seconds timeout for long tales
      }
    );

    return Buffer.from(response.data);
  } catch (error) {
    console.error("Azure TTS Error:", error.response?.data?.toString() || error.message);
    throw new Error(`Azure TTS generation failed: ${error.message}`);
  }
}

module.exports = { generateSpeechFromAzure };
