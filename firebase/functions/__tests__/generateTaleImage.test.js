const { generateTaleImageHandler } = require("../src/generateTaleImage");

jest.mock("../src/admin", () => {
  const updates = [];
  const gets = [];
  let draftStatus = "pending";
  let draftStep = "text";
  let draftImagePrompt = "a dragon";
  return {
    db: {
      collection: jest.fn(() => ({
        doc: jest.fn((id) => ({
          get: jest.fn(async () => ({
            exists: true,
            id,
            data: () => ({ status: draftStatus, step: draftStep, image_prompt: draftImagePrompt }),
          })),
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
  generateImage: jest.fn(async () => ({ b64: Buffer.from("img").toString("base64") })),
}));

jest.mock("../src/storage", () => ({
  resizeToWidth: jest.fn(async ({ buffer }) => buffer),
  uploadBase64Image: jest.fn(async ({ path }) => `https://storage.googleapis.com/b/${path}`),
  uploadBuffer: jest.fn(async ({ path }) => `https://storage.googleapis.com/b/${path}`),
  deletePrefix: jest.fn(async () => {}),
}));

describe("generateTaleImage", () => {
  test("adds image to draft and updates step to image", async () => {
    const admin = require("../src/admin");
    admin.__updates.length = 0;
    const result = await generateTaleImageHandler({ data: { draftId: "d1" }, auth: { uid: "admin" } });
    expect(result.imageUrl).toContain("d1/image_1024.png");
    expect(admin.__updates).toHaveLength(1);
    const upd = admin.__updates[0].d;
    expect(upd.step).toBe("image");
    expect(upd.image_url).toContain("image_1024.png");
    expect(upd.image_url_640px).toContain("image_640.png");
  });

  test("passes feedback to image generation when provided", async () => {
    const { generateImage } = require("../src/openrouter");
    generateImage.mockClear();
    await generateTaleImageHandler({ data: { draftId: "d1", feedback: "make it brighter" }, auth: { uid: "admin" } });
    expect(generateImage).toHaveBeenCalledWith(
      expect.objectContaining({ feedback: "make it brighter" })
    );
  });

  test("requireAuth is called with the request", async () => {
    const admin = require("../src/admin");
    admin.requireAuth.mockClear();
    const req = { data: { draftId: "d1" }, auth: { uid: "admin" } };
    await generateTaleImageHandler(req);
    expect(admin.requireAuth).toHaveBeenCalledWith(req);
  });

  test("throws when draft not found", async () => {
    const { db } = require("../src/admin");
    db.collection = jest.fn(() => ({
      doc: jest.fn(() => ({
        get: jest.fn(async () => ({ exists: false })),
        update: jest.fn(),
      })),
    }));
    await expect(
      generateTaleImageHandler({ data: { draftId: "missing" }, auth: { uid: "admin" } })
    ).rejects.toThrow("Draft not found");
  });

  test("throws when image_prompt is empty and no feedback provided", async () => {
    const { db } = require("../src/admin");
    db.collection = jest.fn(() => ({
      doc: jest.fn(() => ({
        get: jest.fn(async () => ({
          exists: true,
          id: "d_empty",
          data: () => ({ status: "pending", step: "text", image_prompt: "" }),
        })),
        update: jest.fn(),
      })),
    }));
    await expect(
      generateTaleImageHandler({ data: { draftId: "d_empty" }, auth: { uid: "admin" } })
    ).rejects.toThrow("Cannot regenerate image");
  });
});
