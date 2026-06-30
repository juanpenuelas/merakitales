const { generateTaleTextHandler } = require("../src/generateTaleText");

jest.mock("../src/admin", () => {
  const sets = [];
  return {
    db: {
      collection: jest.fn((name) => {
        const docRef = (id) => ({
          id: id || "draft1",
          set: jest.fn(async (d) => { sets.push({ name, id: id || "draft1", d }); return { id: id || "draft1" }; }),
          get: jest.fn(),
          update: jest.fn(),
        });
        return { doc: jest.fn(docRef), add: jest.fn() };
      }),
    },
    bucket: { name: "b" },
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
}));

describe("generateTaleText", () => {
  test("creates a draft with step=text and pending status", async () => {
    const admin = require("../src/admin");
    admin.__sets.length = 0;
    const result = await generateTaleTextHandler({ data: { theme: "courage" }, auth: { uid: "admin" } });
    expect(result.draftId).toBe("draft1");
    expect(admin.__sets).toHaveLength(1);
    const saved = admin.__sets[0].d;
    expect(saved.status).toBe("pending");
    expect(saved.step).toBe("text");
    expect(saved.name_es).toBe("El Dragón");
    expect(saved.name_en).toBe("The Dragon");
    expect(saved.image_url).toBe("");
    expect(saved.audio_url_es).toBe("");
    expect(saved.audio_url_en).toBe("");
    expect(saved.image_prompt).toBe("a dragon");
  });

  test("passes feedback to OpenRouter when provided", async () => {
    const { generateTaleText } = require("../src/openrouter");
    generateTaleText.mockClear();
    await generateTaleTextHandler({ data: { feedback: "hazlo más corto" }, auth: { uid: "admin" } });
    expect(generateTaleText).toHaveBeenCalledWith(
      expect.objectContaining({ feedback: "hazlo más corto" })
    );
  });

  test("requireAuth is called with the request", async () => {
    const admin = require("../src/admin");
    admin.requireAuth.mockClear();
    const req = { data: { theme: "x" }, auth: { uid: "admin" } };
    await generateTaleTextHandler(req);
    expect(admin.requireAuth).toHaveBeenCalledWith(req);
  });
});
