// Corrected test for rejectDraft.
// The brief's original test asserted `db.collection().doc` was called, but
// db.collection() returned a NEW object per call, so the assertion inspected a
// fresh doc mock (always 0 calls). This corrected mock memoizes per-collection
// objects and tracks deletes in an array. Adds edge-case + requireAuth tests.
const { rejectDraftHandler } = require("../src/rejectDraft");

jest.mock("../src/admin", () => {
  const collections = {};
  const deletes = [];
  let draftExists = true;
  function getCollection(name) {
    if (!collections[name]) {
      collections[name] = {
        doc: jest.fn((id) => ({
          get: jest.fn(async () => ({ exists: name === "tale_drafts" ? draftExists : true, id, data: () => ({ status: "pending" }) })),
          delete: jest.fn(async () => { deletes.push({ name, id }); }),
        })),
      };
    }
    return collections[name];
  }
  return {
    db: { collection: jest.fn((name) => getCollection(name)) },
    bucket: { name: "b" },
    requireAuth: jest.fn(),
    __collections: collections,
    __deletes: deletes,
    __setDraftExists: (v) => { draftExists = v; },
  };
});

jest.mock("../src/storage", () => ({
  deletePrefix: jest.fn(async () => {}),
}));

describe("rejectDraft", () => {
  test("deletes draft doc and storage prefix", async () => {
    const admin = require("../src/admin");
    const { deletePrefix } = require("../src/storage");
    deletePrefix.mockClear();
    admin.__setDraftExists(true);

    const result = await rejectDraftHandler({ data: { draftId: "d1" }, auth: { uid: "admin" } });

    expect(result.ok).toBe(true);
    expect(admin.__collections["tale_drafts"].doc).toHaveBeenCalledWith("d1");
    expect(admin.__deletes).toContainEqual({ name: "tale_drafts", id: "d1" });
    expect(deletePrefix).toHaveBeenCalledWith({ bucket: expect.anything(), prefix: "drafts/d1" });
  });

  test("requireAuth is called with the request", async () => {
    const admin = require("../src/admin");
    admin.requireAuth.mockClear();
    admin.__setDraftExists(true);
    const req = { data: { draftId: "d1" }, auth: { uid: "admin" } };
    await rejectDraftHandler(req);
    expect(admin.requireAuth).toHaveBeenCalledWith(req);
  });

  test("throws not-found when draft does not exist", async () => {
    const admin = require("../src/admin");
    admin.__setDraftExists(false);
    await expect(
      rejectDraftHandler({ data: { draftId: "missing" }, auth: { uid: "admin" } })
    ).rejects.toThrow("Draft not found");
    admin.__setDraftExists(true);
  });

  test("throws invalid-argument when draftId missing", async () => {
    await expect(
      rejectDraftHandler({ data: {}, auth: { uid: "admin" } })
    ).rejects.toThrow("draftId required");
  });
});
