const { retractTaleHandler } = require("../src/retractTale");

jest.mock("../src/admin", () => {
  const sets = [];
  const deletes = [];
  const esDoc = {
    name: "Los Dos Mejores Amigos", description: "de", specifications: "te_es",
    audio_url: "https://storage.googleapis.com/b/tales/31/audio_es.mp3",
    image_url: "https://storage.googleapis.com/b/tales/31/image_1024.png",
    image_url_640px: "https://storage.googleapis.com/b/tales/31/image_640.png",
  };
  const enDoc = {
    name: "The Best of Friends", description: "den", specifications: "te_en",
    audio_url: "https://storage.googleapis.com/b/tales/31/audio_en.mp3",
    image_url: "https://storage.googleapis.com/b/tales/31/image_1024.png",
    image_url_640px: "https://storage.googleapis.com/b/tales/31/image_640.png",
  };
  const commonDoc = {
    image_url_1024px: "https://storage.googleapis.com/b/tales/31/image_1024.png",
    image_url_640px: "https://storage.googleapis.com/b/tales/31/image_640.png",
  };
  // Memoize per-collection objects so set/delete counters are stable across calls.
  // (The brief's original mock had a duplicate `doc` property that shadowed the
  // first, so .doc(id).get() always returned { exists: false }. Fixed.)
  const collections = {};
  function getCollection(name) {
    if (!collections[name]) {
      collections[name] = {
        doc: jest.fn((id) => {
          const refId = id !== undefined ? id : "newAutoId";
          return {
            id: refId,
            _collectionName: name,
            get: jest.fn(async () => {
              if (name === "tales" && id === "31_es") return { exists: true, data: () => esDoc };
              if (name === "tales" && id === "31_en") return { exists: true, data: () => enDoc };
              if (name === "tales_common_data" && id === "31") return { exists: true, data: () => commonDoc };
              return { exists: false };
            }),
            set: jest.fn(async (d) => { sets.push({ name, id: refId, d }); }),
            delete: jest.fn(async () => { deletes.push({ name, id: refId }); }),
            update: jest.fn(),
          };
        }),
        add: jest.fn(),
      };
    }
    return collections[name];
  }
  function makeBatch() {
    const ops = [];
    return {
      set: jest.fn((ref, d) => { ops.push({ type: "set", ref, d }); }),
      delete: jest.fn((ref) => { ops.push({ type: "delete", ref }); }),
      commit: jest.fn(async () => {
        for (const op of ops) {
          if (op.type === "set") sets.push({ name: op.ref._collectionName, id: op.ref.id, d: op.d });
          if (op.type === "delete") deletes.push({ name: op.ref._collectionName, id: op.ref.id });
        }
      }),
    };
  }
  return {
    db: {
      collection: jest.fn((name) => getCollection(name)),
      runTransaction: undefined,
      batch: jest.fn(() => makeBatch()),
    },
    bucket: { name: "b" },
    requireAuth: jest.fn(),
    __sets: sets,
    __deletes: deletes,
    __esDoc: esDoc,
  };
});

jest.mock("../src/storage", () => ({
  moveFile: jest.fn(async ({ toPath }) => `https://storage.googleapis.com/b/${toPath}`),
}));

describe("retractTale", () => {
  test("moves tale to drafts and returns new draftId", async () => {
    const admin = require("../src/admin");
    admin.__sets.length = 0;
    admin.__deletes.length = 0;
    const result = await retractTaleHandler({ data: { taleId: 31 }, auth: { uid: "admin" } });
    expect(result.draftId).toBeDefined();
    // 1 draft created in tale_drafts
    const draftSets = admin.__sets.filter((s) => s.name === "tale_drafts");
    expect(draftSets).toHaveLength(1);
    const draft = draftSets[0].d;
    expect(draft.status).toBe("pending");
    expect(draft.retracted_from_tale_id).toBe(31);
    expect(draft.name_es).toBe("Los Dos Mejores Amigos");
    expect(draft.name_en).toBe("The Best of Friends");
    expect(draft.audio_url_es).toContain("drafts/");
    // 3 docs deleted: 31_es, 31_en, common_data 31
    expect(admin.__deletes).toHaveLength(3);
  });

  test("throws not-found when tale does not exist", async () => {
    await expect(
      retractTaleHandler({ data: { taleId: 999 }, auth: { uid: "admin" } })
    ).rejects.toThrow("Tale not found");
  });

  test("requireAuth is called with the request", async () => {
    const admin = require("../src/admin");
    admin.requireAuth.mockClear();
    const req = { data: { taleId: 31 }, auth: { uid: "admin" } };
    await retractTaleHandler(req);
    expect(admin.requireAuth).toHaveBeenCalledWith(req);
  });

  test("propagates is_premium_tale: true from the published tale to the new draft", async () => {
    const admin = require("../src/admin");
    admin.__sets.length = 0;
    admin.__deletes.length = 0;
    admin.__esDoc.is_premium_tale = true;
    try {
      await retractTaleHandler({ data: { taleId: 31 }, auth: { uid: "admin" } });
      const draftSets = admin.__sets.filter((s) => s.name === "tale_drafts");
      expect(draftSets[0].d.is_premium_tale).toBe(true);
    } finally {
      delete admin.__esDoc.is_premium_tale;
    }
  });

  test("defaults is_premium_tale to false when the published tale has no such field", async () => {
    const admin = require("../src/admin");
    admin.__sets.length = 0;
    admin.__deletes.length = 0;
    await retractTaleHandler({ data: { taleId: 31 }, auth: { uid: "admin" } });
    const draftSets = admin.__sets.filter((s) => s.name === "tale_drafts");
    expect(draftSets[0].d.is_premium_tale).toBe(false);
  });
});
