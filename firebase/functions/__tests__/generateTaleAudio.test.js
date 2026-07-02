const { generateTaleAudioHandler } = require("../src/generateTaleAudio");

jest.mock("../src/admin", () => {
  const updates = [];
  let draftData = { status: "pending", step: "image", specifications_es: "texto es", specifications_en: "texto en" };
  return {
    db: {
      collection: jest.fn(() => ({
        doc: jest.fn((id) => ({
          get: jest.fn(async () => ({ exists: true, id, data: () => draftData })),
          update: jest.fn(async (d) => { updates.push({ id, d }); }),
        })),
      })),
    },
    bucket: { name: "b" },
    getOpenRouterApiKey: () => "test-key",
    requireAuth: jest.fn(),
    __updates: updates,
  };
});

jest.mock("../src/openrouter", () => ({
  generateSpeech: jest.fn(async () => Buffer.from("audio-data")),
}));

jest.mock("../src/storage", () => ({
  uploadBuffer: jest.fn(async ({ path }) => `https://storage.googleapis.com/b/${path}`),
  deletePrefix: jest.fn(async () => {}),
}));

describe("generateTaleAudio", () => {
  test("generates ES audio with Azure voice and updates step to audio", async () => {
    const admin = require("../src/admin");
    admin.__updates.length = 0;
    const { generateSpeech } = require("../src/openrouter");
    generateSpeech.mockClear();
    const result = await generateTaleAudioHandler({ data: { draftId: "d1", lang: "es" }, auth: { uid: "admin" } });
    expect(result.audioUrl).toContain("d1/audio_es.mp3");
    expect(generateSpeech).toHaveBeenCalledWith(
      expect.objectContaining({ input: "texto es", lang: "es" })
    );
    expect(admin.__updates).toHaveLength(1);
    expect(admin.__updates[0].d.audio_url_es).toContain("audio_es.mp3");
  });

  test("generates EN audio with Kokoro voice", async () => {
    const { generateSpeech } = require("../src/openrouter");
    generateSpeech.mockClear();
    await generateTaleAudioHandler({ data: { draftId: "d1", lang: "en" }, auth: { uid: "admin" } });
    expect(generateSpeech).toHaveBeenCalledWith(
      expect.objectContaining({ input: "texto en", lang: "en" })
    );
  });

  test("throws invalid-argument when lang is missing or invalid", async () => {
    await expect(
      generateTaleAudioHandler({ data: { draftId: "d1" }, auth: { uid: "admin" } })
    ).rejects.toThrow("lang required");
    await expect(
      generateTaleAudioHandler({ data: { draftId: "d1", lang: "fr" }, auth: { uid: "admin" } })
    ).rejects.toThrow("lang must be 'es' or 'en'");
  });

  test("requireAuth is called with the request", async () => {
    const admin = require("../src/admin");
    admin.requireAuth.mockClear();
    const req = { data: { draftId: "d1", lang: "es" }, auth: { uid: "admin" } };
    await generateTaleAudioHandler(req);
    expect(admin.requireAuth).toHaveBeenCalledWith(req);
  });
});
