// Corrected test for generateTaleDraft.
// The brief's original test mocked collection().add(), but the (correct)
// implementation pre-allocates the draft id via collection().doc().id and
// writes with doc(id).set(). This corrected mock matches that pattern.
const { generateTaleDraftHandler } = require("../src/generateTaleDraft");

jest.mock("../src/admin", () => {
  const sets = [];
  const gets = [];
  const docRef = (id) => {
    const docId = id || "draft1";
    return {
      id: docId,
      set: jest.fn(async (d) => { sets.push({ id: docId, d }); return { id: docId }; }),
      get: jest.fn(async () => { gets.push(docId); return { exists: false }; }),
    };
  };
  const collectionObj = { doc: jest.fn(docRef) };
  return {
    db: { collection: jest.fn(() => collectionObj) },
    bucket: { name: "test-bucket" },
    getOpenRouterApiKey: () => "test-key",
    requireAuth: jest.fn(),
    __sets: sets,
  };
});

jest.mock("../src/openrouter", () => ({
  generateTaleText: jest.fn(async () => ({
    name_es: "El Dragón", description_es: "desc es", specifications_es: "texto es",
    name_en: "The Dragon", description_en: "desc en", specifications_en: "texto en",
    image_prompt: "a dragon",
  })),
  generateImage: jest.fn(async () => ({ b64: Buffer.from("img").toString("base64") })),
  generateSpeech: jest.fn(async () => Buffer.from("audio")),
}));

jest.mock("../src/storage", () => ({
  resizeToWidth: jest.fn(async ({ buffer }) => buffer),
  uploadBuffer: jest.fn(async ({ path }) => `https://storage.googleapis.com/test-bucket/${path}`),
  uploadBase64Image: jest.fn(async ({ path }) => `https://storage.googleapis.com/test-bucket/${path}`),
  deletePrefix: jest.fn(async () => {}),
}));

describe("generateTaleDraft", () => {
  test("writes a pending draft with all fields", async () => {
    const admin = require("../src/admin");
    const result = await generateTaleDraftHandler({ data: { theme: "courage" }, auth: { uid: "admin" } });
    expect(admin.db.collection).toHaveBeenCalledWith("tale_drafts");
    // doc() called twice: once (no arg) to pre-allocate id, once (draftId) to set
    expect(admin.db.collection("tale_drafts").doc).toHaveBeenCalledTimes(2);
    expect(admin.__sets).toHaveLength(1);
    const saved = admin.__sets[0].d;
    expect(saved.status).toBe("pending");
    expect(saved.name_es).toBe("El Dragón");
    expect(saved.name_en).toBe("The Dragon");
    expect(saved.audio_url_es).toContain("test-bucket");
    expect(saved.audio_url_en).toContain("test-bucket");
    expect(saved.image_url).toContain("test-bucket");
    expect(saved.image_url_640px).toContain("test-bucket");
    expect(saved.assigned_tale_id).toBeNull();
    expect(saved.decided_at).toBeNull();
    expect(result.draftId).toBe("draft1");
  });

  test("works without a theme", async () => {
    const result = await generateTaleDraftHandler({ data: {}, auth: { uid: "admin" } });
    expect(result.draftId).toBe("draft1");
  });

  test("calls requireAuth with the request", async () => {
    const admin = require("../src/admin");
    admin.requireAuth.mockClear();
    const req = { data: { theme: "courage" }, auth: { uid: "admin" } };
    await generateTaleDraftHandler(req);
    expect(admin.requireAuth).toHaveBeenCalledWith(req);
  });

  test("cleans up storage prefix and rethrows when generateImage rejects", async () => {
    const openrouter = require("../src/openrouter");
    const storage = require("../src/storage");
    openrouter.generateImage.mockRejectedValueOnce(new Error("image failed"));
    const req = { data: { theme: "courage" }, auth: { uid: "admin" } };
    await expect(generateTaleDraftHandler(req)).rejects.toThrow("image failed");
    expect(storage.deletePrefix).toHaveBeenCalledWith({ bucket: expect.anything(), prefix: "drafts/draft1" });
  });
});
