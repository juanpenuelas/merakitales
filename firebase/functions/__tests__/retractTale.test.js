const { retractTaleHandler } = require("../src/retractTale");

jest.mock("../src/admin", () => {
  const sets = [];
  const deletes = [];

  // Fixtures use random-looking doc IDs (not `${taleId}_es`/`${taleId}_en`)
  // on purpose: every tale published before the admin's `_es`/`_en` doc-id
  // convention existed has an auto-generated Firestore ID, and that's still
  // true for all 30 tales in production today. The handler must find these
  // by field (tale_id + lang), never by guessing the doc id.
  const esDoc = {
    tale_id: 31, lang: "es",
    name: "Los Dos Mejores Amigos", description: "de", specifications: "te_es",
    audio_url: "https://storage.googleapis.com/b/tales/31/audio_es.mp3",
    image_url: "https://storage.googleapis.com/b/tales/31/image_1024.png",
    image_url_640px: "https://storage.googleapis.com/b/tales/31/image_640.png",
  };
  const enDoc = {
    tale_id: 31, lang: "en",
    name: "The Best of Friends", description: "den", specifications: "te_en",
    audio_url: "https://storage.googleapis.com/b/tales/31/audio_en.mp3",
    image_url: "https://storage.googleapis.com/b/tales/31/image_1024.png",
    image_url_640px: "https://storage.googleapis.com/b/tales/31/image_640.png",
  };
  const commonDoc = {
    image_url_1024px: "https://storage.googleapis.com/b/tales/31/image_1024.png",
    image_url_640px: "https://storage.googleapis.com/b/tales/31/image_640.png",
  };
  const commonRef = {
    id: "randomCommonId31",
    _collectionName: "tales_common_data",
    get: jest.fn(async () => ({
      exists: true,
      id: "randomCommonId31",
      ref: commonRef,
      data: () => commonDoc,
    })),
  };
  esDoc.tale_common_data_ref = commonRef;
  enDoc.tale_common_data_ref = commonRef;

  const talesDocs = { randomEsId31: esDoc, randomEnId31: enDoc };
  const commonDocs = { randomCommonId31: commonDoc };
  function docsForCollection(name) {
    if (name === "tales") return talesDocs;
    if (name === "tales_common_data") return commonDocs;
    return {};
  }

  function makeDocSnap(name, id, data) {
    return { exists: true, id, ref: { id, _collectionName: name }, data: () => data };
  }

  function makeQuery(name, filters) {
    return {
      where: jest.fn((field, _op, value) => makeQuery(name, [...filters, { field, value }])),
      limit: jest.fn(() => makeQuery(name, filters)),
      get: jest.fn(async () => {
        const all = docsForCollection(name);
        const docs = Object.entries(all)
          .filter(([, data]) => filters.every((f) => data[f.field] === f.value))
          .map(([id, data]) => makeDocSnap(name, id, data));
        return { empty: docs.length === 0, docs };
      }),
    };
  }

  // Memoize per-collection objects so set/delete counters are stable across calls.
  const collections = {};
  function getCollection(name) {
    if (!collections[name]) {
      collections[name] = {
        // Legacy-style doc-id guesses (`${taleId}_es`) must never match —
        // that's the bug this fix removes. Kept only for `tale_drafts`
        // (doc creation/lookup by known id, unaffected by this fix).
        doc: jest.fn((id) => {
          const refId = id !== undefined ? id : "newAutoId";
          return {
            id: refId,
            _collectionName: name,
            get: jest.fn(async () => ({ exists: false })),
            set: jest.fn(async (d) => { sets.push({ name, id: refId, d }); }),
            delete: jest.fn(async () => { deletes.push({ name, id: refId }); }),
            update: jest.fn(),
          };
        }),
        add: jest.fn(),
        where: jest.fn((field, _op, value) => makeQuery(name, [{ field, value }])),
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
    const draftSets = admin.__sets.filter((s) => s.name === "tale_drafts");
    expect(draftSets).toHaveLength(1);
    const draft = draftSets[0].d;
    expect(draft.status).toBe("pending");
    expect(draft.retracted_from_tale_id).toBe(31);
    expect(draft.name_es).toBe("Los Dos Mejores Amigos");
    expect(draft.name_en).toBe("The Best of Friends");
    expect(draft.audio_url_es).toContain("drafts/");
    // 3 docs deleted: es tale, en tale, common data
    expect(admin.__deletes).toHaveLength(3);
  });

  test("finds tale docs by tale_id+lang even though their Firestore IDs are random", async () => {
    const admin = require("../src/admin");
    admin.__sets.length = 0;
    admin.__deletes.length = 0;
    await retractTaleHandler({ data: { taleId: 31 }, auth: { uid: "admin" } });
    const deletedIds = admin.__deletes.map((d) => d.id);
    expect(deletedIds).toEqual(
      expect.arrayContaining(["randomEsId31", "randomEnId31", "randomCommonId31"])
    );
    expect(deletedIds).not.toContain("31_es");
    expect(deletedIds).not.toContain("31_en");
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
