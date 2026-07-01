const { updateDraftTextHandler } = require("../src/updateDraftText");

jest.mock("../src/admin", () => {
  const collections = {};
  const updates = [];
  let draftStatus = "pending";
  let draftExists = true;
  function getCollection(name) {
    if (!collections[name]) {
      collections[name] = {
        doc: jest.fn((id) => ({
          get: jest.fn(async () => ({
            exists: draftExists,
            id,
            data: () => ({ status: draftStatus }),
          })),
          update: jest.fn(async (d) => { updates.push({ name, id, d }); }),
        })),
      };
    }
    return collections[name];
  }
  return {
    db: { collection: jest.fn((name) => getCollection(name)) },
    requireAuth: jest.fn(),
    __collections: collections,
    __updates: updates,
    __setDraft: (status, exists = true) => { draftStatus = status; draftExists = exists; },
  };
});

describe("updateDraftText", () => {
  test("updates specifications_es directly, no LLM call", async () => {
    const admin = require("../src/admin");
    admin.__setDraft("pending", true);

    const result = await updateDraftTextHandler({
      data: { draftId: "d1", lang: "es", text: "  Nuevo texto  " },
      auth: { uid: "admin" },
    });

    expect(result.ok).toBe(true);
    expect(admin.__collections["tale_drafts"].doc).toHaveBeenCalledWith("d1");
    expect(admin.__updates).toContainEqual({
      name: "tale_drafts",
      id: "d1",
      d: { specifications_es: "Nuevo texto" },
    });
  });

  test("updates specifications_en for lang=en", async () => {
    const admin = require("../src/admin");
    admin.__setDraft("pending", true);
    admin.__updates.length = 0;

    await updateDraftTextHandler({ data: { draftId: "d1", lang: "en", text: "New text" }, auth: { uid: "admin" } });

    expect(admin.__updates).toContainEqual({ name: "tale_drafts", id: "d1", d: { specifications_en: "New text" } });
  });

  test("requireAuth is called with the request", async () => {
    const admin = require("../src/admin");
    admin.requireAuth.mockClear();
    admin.__setDraft("pending", true);
    const req = { data: { draftId: "d1", lang: "es", text: "x" }, auth: { uid: "admin" } };
    await updateDraftTextHandler(req);
    expect(admin.requireAuth).toHaveBeenCalledWith(req);
  });

  test("throws invalid-argument when draftId missing", async () => {
    await expect(
      updateDraftTextHandler({ data: { lang: "es", text: "x" }, auth: { uid: "admin" } })
    ).rejects.toThrow("draftId required");
  });

  test("throws invalid-argument when lang is invalid", async () => {
    await expect(
      updateDraftTextHandler({ data: { draftId: "d1", lang: "fr", text: "x" }, auth: { uid: "admin" } })
    ).rejects.toThrow("lang must be");
  });

  test("throws invalid-argument when text is empty", async () => {
    await expect(
      updateDraftTextHandler({ data: { draftId: "d1", lang: "es", text: "   " }, auth: { uid: "admin" } })
    ).rejects.toThrow("text required");
  });

  test("throws not-found when draft does not exist", async () => {
    const admin = require("../src/admin");
    admin.__setDraft("pending", false);
    await expect(
      updateDraftTextHandler({ data: { draftId: "missing", lang: "es", text: "x" }, auth: { uid: "admin" } })
    ).rejects.toThrow("Draft not found");
    admin.__setDraft("pending", true);
  });

  test("throws failed-precondition when draft is not pending", async () => {
    const admin = require("../src/admin");
    admin.__setDraft("approved", true);
    await expect(
      updateDraftTextHandler({ data: { draftId: "d1", lang: "es", text: "x" }, auth: { uid: "admin" } })
    ).rejects.toThrow(/already/);
    admin.__setDraft("pending", true);
  });
});
