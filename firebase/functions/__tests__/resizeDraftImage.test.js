const { resizeDraftImageHandler } = require("../src/resizeDraftImage");

jest.mock("../src/admin", () => {
  const updates = [];
  let draftExists = true;
  let draftData = { status: "pending", step: "text" };
  return {
    db: {
      collection: jest.fn(() => ({
        doc: jest.fn((id) => ({
          get: jest.fn(async () => ({ exists: draftExists, id, data: () => draftData })),
          update: jest.fn(async (d) => { updates.push({ id, d }); }),
        })),
      })),
      runTransaction: jest.fn(async (fn) =>
        fn({
          get: jest.fn(async () => ({ exists: draftExists, data: () => draftData })),
          update: jest.fn((ref, d) => { updates.push({ id: undefined, d }); }),
        })
      ),
    },
    bucket: { name: "b" },
    requireAuth: jest.fn(),
    __updates: updates,
    __setDraftExists: (v) => { draftExists = v; },
    __setDraftData: (d) => { draftData = d; },
  };
});

jest.mock("../src/storage", () => ({
  resizeToWidth: jest.fn(async ({ buffer }) => buffer),
  uploadBuffer: jest.fn(async ({ path }) => `https://storage.googleapis.com/b/${path}`),
  downloadFile: jest.fn(async () => Buffer.from("fake-image-bytes")),
  fileExists: jest.fn(async () => true),
}));

describe("resizeDraftImage", () => {
  test("resizes the uploaded image and updates the draft", async () => {
    const admin = require("../src/admin");
    admin.__updates.length = 0;
    const result = await resizeDraftImageHandler({ data: { draftId: "d1" }, auth: { uid: "admin" } });
    expect(result.imageUrl).toContain("d1/image_1024.png");
    expect(result.imageUrl640).toContain("d1/image_640.png");
    expect(admin.__updates).toHaveLength(1);
    expect(admin.__updates[0].d.step).toBe("image");
    expect(admin.__updates[0].d.image_url).toContain("image_1024.png");
    expect(admin.__updates[0].d.image_url_640px).toContain("image_640.png");
  });

  test("promotes step to 'audio' instead of 'image' when both audio URLs already exist on the draft", async () => {
    const admin = require("../src/admin");
    admin.__updates.length = 0;
    admin.__setDraftData({
      status: "pending",
      step: "text",
      audio_url_es: "https://storage.googleapis.com/b/drafts/d1/audio_es.mp3",
      audio_url_en: "https://storage.googleapis.com/b/drafts/d1/audio_en.mp3",
    });
    try {
      const result = await resizeDraftImageHandler({ data: { draftId: "d1" }, auth: { uid: "admin" } });
      expect(result.imageUrl).toContain("d1/image_1024.png");
      expect(admin.__updates).toHaveLength(1);
      expect(admin.__updates[0].d.step).toBe("audio");
      expect(admin.__updates[0].d.image_url).toContain("image_1024.png");
      expect(admin.__updates[0].d.image_url_640px).toContain("image_640.png");
    } finally {
      admin.__setDraftData({ status: "pending", step: "text" });
    }
  });

  test("requireAuth is called with the request", async () => {
    const admin = require("../src/admin");
    admin.requireAuth.mockClear();
    const req = { data: { draftId: "d1" }, auth: { uid: "admin" } };
    await resizeDraftImageHandler(req);
    expect(admin.requireAuth).toHaveBeenCalledWith(req);
  });

  test("throws invalid-argument when draftId missing", async () => {
    await expect(
      resizeDraftImageHandler({ data: {}, auth: { uid: "admin" } })
    ).rejects.toThrow("draftId required");
  });

  test("throws not-found when draft does not exist", async () => {
    const admin = require("../src/admin");
    admin.__setDraftExists(false);
    await expect(
      resizeDraftImageHandler({ data: { draftId: "missing" }, auth: { uid: "admin" } })
    ).rejects.toThrow("Draft not found");
    admin.__setDraftExists(true);
  });

  test("throws failed-precondition when the image has not been uploaded yet", async () => {
    const { fileExists } = require("../src/storage");
    fileExists.mockResolvedValueOnce(false);
    await expect(
      resizeDraftImageHandler({ data: { draftId: "d1" }, auth: { uid: "admin" } })
    ).rejects.toThrow("Image not uploaded yet");
  });
});
