const nock = require("nock");
const { generateTaleText, generateImage, generateSpeech } = require("../src/openrouter");

const BASE = "https://openrouter.ai";
const KEY = "test-key";

describe("openrouter client", () => {
  afterEach(() => nock.cleanAll());

  test("generateTaleText parses JSON content into a tale object", async () => {
    const taleJson = JSON.stringify({
      name_es: "El Dragón Tímido",
      description_es: "Un dragón que aprende a ser valiente.",
      specifications_es: "Había una vez...",
      name_en: "The Timid Dragon",
      description_en: "A dragon who learns to be brave.",
      specifications_en: "Once upon a time...",
      image_prompt: "a shy dragon in a sunny meadow, soft watercolor",
    });
    nock(BASE)
      .post("/api/v1/chat/completions")
      .reply(200, {
        choices: [{ message: { content: taleJson } }],
      });

    const result = await generateTaleText({ theme: "courage", apiKey: KEY });
    expect(result.name_es).toBe("El Dragón Tímido");
    expect(result.image_prompt).toContain("dragon");
    expect(result.specifications_en).toBe("Once upon a time...");
  });

  test("generateTaleText throws on non-JSON content", async () => {
    nock(BASE)
      .post("/api/v1/chat/completions")
      .reply(200, { choices: [{ message: { content: "not json" } }] });
    await expect(generateTaleText({ apiKey: KEY })).rejects.toThrow();
  });

  test("generateImage returns base64 + media type", async () => {
    nock(BASE)
      .post("/api/v1/images")
      .reply(200, { data: [{ b64_json: "aGVsbG8=" }], usage: { cost: 0.05 } });

    const result = await generateImage({ prompt: "a cat", apiKey: KEY });
    expect(result.b64).toBe("aGVsbG8=");
  });

  test("generateSpeech returns a Buffer", async () => {
    nock(BASE)
      .post("/api/v1/audio/speech")
      .reply(200, Buffer.from("audio-bytes"), {
        "Content-Type": "audio/mpeg",
      });

    const result = await generateSpeech({ input: "hello", apiKey: KEY, voice: "alloy" });
    expect(Buffer.isBuffer(result)).toBe(true);
    expect(result.toString()).toBe("audio-bytes");
  });
});
