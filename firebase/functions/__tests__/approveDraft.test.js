// Corrected test for approveDraft.
// The brief's original test had three defects:
//  1. draftDoc lacked `status: "pending"`, so the handler threw failed-precondition.
//  2. db.collection(name) returned a NEW object on every call, so the
//     toHaveBeenCalledTimes assertions inspected fresh doc mocks (always 0 calls).
//  3. The runTransaction mock returned no `empty` field.
// This corrected mock memoizes per-collection objects (stable doc jest.fn),
// injects status, and adds edge-case + requireAuth tests.
const { approveDraftHandler } = require("../src/approveDraft");

const draftDoc = {
  name_es: "El Dragón", description_es: "de", specifications_es: "te_es",
  name_en: "The Dragon", description_en: "den", specifications_en: "te_en",
  audio_url_es: "https://storage.googleapis.com/b/drafts/d1/audio_es.mp3",
  audio_url_en: "https://storage.googleapis.com/b/drafts/d1/audio_en.mp3",
  image_url: "https://storage.googleapis.com/b/drafts/d1/image_1024.png",
  image_url_640px: "https://storage.googleapis.com/b/drafts/d1/image_640.png",
  image_prompt_es: "a dragon",
  step: "audio",
};

jest.mock("../src/admin", () => {
  const collections = {};
  const sets = [];
  const updates = [];
  let draftStatus = "pending";
  let draftExists = true;
  let draftStep = "audio";
  function getCollection(name) {
    if (!collections[name]) {
      collections[name] = {
        doc: jest.fn((id) => ({
          get: jest.fn(async () => ({
            exists: name === "tale_drafts" ? draftExists : true,
            id,
            data: () => (name === "tale_drafts" ? { ...draftDoc, status: draftStatus, step: draftStep } : {}),
          })),
          set: jest.fn(async (d) => { sets.push({ name, id, d }); }),
          update: jest.fn(async (d) => { updates.push({ name, id, d }); }),
        })),
        add: jest.fn(),
        orderBy: jest.fn(() => ({ limit: jest.fn(() => ({ get: jest.fn(async () => ({ docs: [], empty: true })) })) })),
      };
    }
    return collections[name];
  }
  return {
    db: {
      collection: jest.fn((name) => getCollection(name)),
      runTransaction: jest.fn(async (fn) =>
        fn({ get: jest.fn(async () => ({ docs: [{ data: () => ({ tale_id: 30 }) }], empty: false })) })
      ),
    },
    bucket: { name: "b" },
    requireAuth: jest.fn(),
    __sets: sets,
    __updates: updates,
    __collections: collections,
    __setDraft: (status, exists = true, step = "audio") => { draftStatus = status; draftExists = exists; draftStep = step; },
  };
});

jest.mock("../src/storage", () => ({
  moveFile: jest.fn(async ({ toPath }) => `https://storage.googleapis.com/b/${toPath}`),
}));

describe("approveDraft", () => {
  test("writes 2 tales docs + 1 common_data, marks draft approved, moves 4 files", async () => {
    const admin = require("../src/admin");
    admin.__setDraft("pending", true);
    const { moveFile } = require("../src/storage");
    moveFile.mockClear();

    const result = await approveDraftHandler({ data: { draftId: "d1" }, auth: { uid: "admin" } });

    expect(result.taleId).toBe(31);
    // tales collection: doc called twice (31_es, 31_en)
    expect(admin.__collections["tales"].doc).toHaveBeenCalledTimes(2);
    expect(admin.__collections["tales"].doc).toHaveBeenNthCalledWith(1, "31_es");
    expect(admin.__collections["tales"].doc).toHaveBeenNthCalledWith(2, "31_en");
    // tales_common_data: doc called once (31)
    expect(admin.__collections["tales_common_data"].doc).toHaveBeenCalledTimes(1);
    expect(admin.__collections["tales_common_data"].doc).toHaveBeenCalledWith("31");
    // 3 sets: 1 common_data + 2 tales
    const talesSets = admin.__sets.filter((s) => s.name === "tales");
    expect(talesSets).toHaveLength(2);
    expect(talesSets[0].d.lang).toBe("es");
    expect(talesSets[1].d.lang).toBe("en");
    expect(talesSets[0].d.tale_id).toBe(31);
    expect(talesSets[0].d.tale_common_data_ref).toBeDefined();
    expect(talesSets[0].d.audio_url).toContain("tales/31/audio_es.mp3");
    expect(talesSets[1].d.audio_url).toContain("tales/31/audio_en.mp3");
    const commonSets = admin.__sets.filter((s) => s.name === "tales_common_data");
    expect(commonSets).toHaveLength(1);
    expect(commonSets[0].d.image_url_1024px).toContain("tales/31/image_1024.png");
    // draft marked approved
    const draftUpdates = admin.__updates.filter((u) => u.name === "tale_drafts");
    expect(draftUpdates).toHaveLength(1);
    expect(draftUpdates[0].d.status).toBe("approved");
    expect(draftUpdates[0].d.assigned_tale_id).toBe(31);
    expect(draftUpdates[0].d.decided_by).toBe("admin");
    // moveFile called 4 times
    expect(moveFile).toHaveBeenCalledTimes(4);
  });

  test("requireAuth is called with the request", async () => {
    const admin = require("../src/admin");
    admin.requireAuth.mockClear();
    admin.__setDraft("pending", true);
    const req = { data: { draftId: "d1" }, auth: { uid: "admin" } };
    await approveDraftHandler(req);
    expect(admin.requireAuth).toHaveBeenCalledWith(req);
  });

  test("throws not-found when draft does not exist", async () => {
    const admin = require("../src/admin");
    admin.__setDraft("pending", false);
    await expect(
      approveDraftHandler({ data: { draftId: "missing" }, auth: { uid: "admin" } })
    ).rejects.toThrow("Draft not found");
    admin.__setDraft("pending", true);
  });

  test("throws failed-precondition when draft already approved", async () => {
    const admin = require("../src/admin");
    admin.__setDraft("approved", true);
    await expect(
      approveDraftHandler({ data: { draftId: "d1" }, auth: { uid: "admin" } })
    ).rejects.toThrow(/already/);
    admin.__setDraft("pending", true);
  });

  test("throws invalid-argument when draftId missing", async () => {
    await expect(
      approveDraftHandler({ data: {}, auth: { uid: "admin" } })
    ).rejects.toThrow("draftId required");
  });

  test("throws failed-precondition when draft has not reached the audio step", async () => {
    const admin = require("../src/admin");
    admin.__setDraft("pending", true, "image");
    await expect(
      approveDraftHandler({ data: { draftId: "d1" }, auth: { uid: "admin" } })
    ).rejects.toThrow(/missing image\/audio assets/);
    admin.__setDraft("pending", true, "audio");
  });
});
