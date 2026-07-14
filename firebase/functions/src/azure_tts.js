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
 * Compiles pseudo-SSML to valid Azure SSML without nesting.
 * @param {string} textWithTags - Text containing [style:X]...[/style] tags
 * @param {string} langCode - Language code, e.g., "es-MX"
 * @param {string} voiceName - Voice name, e.g., "es-MX-Valeria:MAI-Voice-2"
 * @returns {string} Compiled SSML
 */
function compileTextToSSML(textWithTags, langCode, voiceName) {
  const regex = /\[style:([a-zA-Z]+)\]([\s\S]*?)\[\/style\]/g;
  let lastIndex = 0;
  let parts = [];
  
  let match;
  while ((match = regex.exec(textWithTags)) !== null) {
    const textBefore = textWithTags.substring(lastIndex, match.index);
    if (textBefore.trim().length > 0) {
      parts.push({ style: 'softvoice', text: textBefore });
    }
    
    const style = match[1];
    const textInside = match[2];
    if (textInside.trim().length > 0) {
      parts.push({ style: style, text: textInside });
    }
    
    lastIndex = regex.lastIndex;
  }
  
  const remainingText = textWithTags.substring(lastIndex);
  if (remainingText.trim().length > 0) {
    parts.push({ style: 'softvoice', text: remainingText });
  }

  if (parts.length === 0) {
    parts.push({ style: 'softvoice', text: textWithTags });
  }

  let bodySsml = "";
  for (let i = 0; i < parts.length; i++) {
    const part = parts[i];
    const styleDegree = part.style === 'softvoice' ? "1.2" : "1.5";
    const escapedText = escapeXml(part.text);
    bodySsml += `
    <mstts:express-as style="${part.style}" styledegree="${styleDegree}">
      <prosody rate="-15%">
        ${escapedText}
      </prosody>
    </mstts:express-as>`;
  }

  const ssml = `
<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xmlns:mstts="https://www.w3.org/2001/mstts" xml:lang="${langCode}">
  <voice name="${voiceName}">
${bodySsml.replace(/^\n/, '')}
  </voice>
</speak>`.trim();

  return ssml;
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

  // Select Native NeuralHD (MAI-Voice-2) Voice based on language
  const voiceName = lang === "es" ? "es-MX-Valeria:MAI-Voice-2" : "en-AU-Isla:MAI-Voice-2";
  const langCode = lang === "es" ? "es-MX" : "en-AU";

  // Build SSML string with prosody adjustments
  const ssml = compileTextToSSML(input, langCode, voiceName);

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
    let errorMsg = error.message;
    if (error.response && error.response.data) {
        errorMsg = Buffer.from(error.response.data).toString('utf8');
    }
    console.error("Azure TTS Error:", errorMsg);
    throw new Error(`Azure TTS generation failed: ${errorMsg}`);
  }
}

module.exports = { generateSpeechFromAzure, compileTextToSSML };
