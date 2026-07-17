# Published Tale Lookup Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the admin panel's published-tale detail view and the "retirar" (retract) action work for every published tale, by looking up `tales` documents by field (`tale_id` + `lang`) instead of guessing the Firestore document ID.

**Architecture:** Two independent read sites (`lib/admin/services/drafts_service.dart::getPublishedTale` and `firebase/functions/src/retractTale.js::retractTaleHandler`) currently do `db.collection('tales').doc('${taleId}_es').get()`. That ID pattern only exists for tales published through the current `approveDraft.js` flow; all 30 tales published before that flow existed have random Firestore-assigned IDs, so both lookups return nothing for every real published tale today. Both sites switch to `where('tale_id', ==, taleId).where('lang', ==, lang).limit(1).get()`, mirroring the query `streamPublished()` already uses successfully. No data migration, no Firestore rules/index changes, no changes to `lib/backend` (the mobile app already queries by field, not by doc ID).

**Tech Stack:** Flutter/Dart (`cloud_firestore`), Node.js Firebase Cloud Functions (`firebase-admin`), Jest.

## Global Constraints

- No data migration of the 30 existing `tales`/`tales_common_data` documents.
- No changes to `lib/backend` (mobile consumer app) or to `firestore.rules`/`firestore.indexes.json`.
- No visual/redesign changes — `published_tale_detail_page.dart` already uses the shared `AppCard`/theme; once real data loads it needs no layout changes.
- Full spec: `docs/superpowers/specs/2026-07-17-published-tale-lookup-fix-design.md`.

---

### Task 1: Fix `retractTaleHandler` to look up tales by field, not by guessed ID

**Files:**
- Modify: `firebase/functions/src/retractTale.js`
- Test: `firebase/functions/__tests__/retractTale.test.js`

**Interfaces:**
- Consumes: `db` (Firestore instance), `bucket`, `requireAuth` from `./admin`; `moveFile` from `./storage` — all unchanged.
- Produces: `retractTaleHandler(req)` — same signature and return shape (`{ draftId: string }`) and same thrown errors (`invalid-argument`, `not-found`) as before. Callers (`firebase/functions/index.js`) need no changes.

- [ ] **Step 1: Rewrite the test file's mock and fixtures to use random-looking doc IDs (mirroring production) and support `.where()` queries**

Replace the entire contents of `firebase/functions/__tests__/retractTale.test.js` with:

```js
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
```

- [ ] **Step 2: Run the tests to verify they fail against the current implementation**

Run: `cd firebase/functions && npx jest retractTale.test.js`
Expected: FAIL — every test throws `Tale not found`, because the current code still guesses `.doc('31_es')`/`.doc('31_en')`, which the new mock's `doc().get()` always reports as `{ exists: false }`.

- [ ] **Step 3: Implement the fix in `retractTale.js`**

Replace lines 16-27 of `firebase/functions/src/retractTale.js` (currently):

```js
  const esSnap = await db.collection("tales").doc(`${taleId}_es`).get();
  const enSnap = await db.collection("tales").doc(`${taleId}_en`).get();
  const commonSnap = await db.collection("tales_common_data").doc(`${taleId}`).get();

  if (!esSnap.exists || !enSnap.exists) {
    const { HttpsError } = require("firebase-functions/v2/https");
    throw new HttpsError("not-found", "Tale not found");
  }

  const es = esSnap.data();
  const en = enSnap.data();
  const common = commonSnap.exists ? commonSnap.data() : null;
```

with:

```js
  const esQuery = await db.collection("tales").where("tale_id", "==", taleId).where("lang", "==", "es").limit(1).get();
  const enQuery = await db.collection("tales").where("tale_id", "==", taleId).where("lang", "==", "en").limit(1).get();

  if (esQuery.empty || enQuery.empty) {
    const { HttpsError } = require("firebase-functions/v2/https");
    throw new HttpsError("not-found", "Tale not found");
  }

  const esSnap = esQuery.docs[0];
  const enSnap = enQuery.docs[0];
  const es = esSnap.data();
  const en = enSnap.data();
  const commonSnap = es.tale_common_data_ref ? await es.tale_common_data_ref.get() : null;
```

Then replace lines 69-73 (currently):

```js
  batch.delete(db.collection("tales").doc(`${taleId}_es`));
  batch.delete(db.collection("tales").doc(`${taleId}_en`));
  if (commonSnap.exists) {
    batch.delete(db.collection("tales_common_data").doc(`${taleId}`));
  }
```

with:

```js
  batch.delete(esSnap.ref);
  batch.delete(enSnap.ref);
  if (commonSnap && commonSnap.exists) {
    batch.delete(commonSnap.ref);
  }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd firebase/functions && npx jest retractTale.test.js`
Expected: PASS — all 6 tests green.

- [ ] **Step 5: Run the full functions test suite to check for regressions**

Run: `cd firebase/functions && npm test`
Expected: PASS — `approveDraft.test.js` still uses `${taleId}_es`/`${taleId}_en` because `approveDraft.js` (the write path) is unchanged by this fix and keeps writing those ids for newly-published tales; only the read paths in `retractTale.js` and (Task 2) `drafts_service.dart` stop assuming that id shape on read.

- [ ] **Step 6: Commit**

```bash
git add firebase/functions/src/retractTale.js firebase/functions/__tests__/retractTale.test.js
git commit -m "fix(functions): look up published tale docs by tale_id+lang instead of guessed id

retractTale assumed every published tale's Firestore doc id follows the
\`\${taleId}_es\`/\`\${taleId}_en\` pattern. All 30 tales published before
that convention existed have random Firestore ids, so retract has never
worked for any of them. Query by tale_id+lang instead, same pattern
streamPublished() already uses."
```

---

### Task 2: Fix `getPublishedTale` in the admin's Flutter service

**Files:**
- Modify: `lib/admin/services/drafts_service.dart:37-48`

**Interfaces:**
- Consumes: `_db` (`FirebaseFirestore.instance`, already a field on `DraftsService`); `PublishedTaleFull.fromDocs({required int taleId, required Map<String, dynamic>? esData, required Map<String, dynamic>? enData})` from `../models/published_tale.dart` — signature unchanged.
- Produces: `Future<PublishedTaleFull> getPublishedTale(int taleId)` — same signature, same return type. `published_tale_detail_page.dart` (`initState`: `_future = _service.getPublishedTale(widget.taleId);`) needs no changes.

- [ ] **Step 1: Replace the doc-id guessing with a field query**

In `lib/admin/services/drafts_service.dart`, replace:

```dart
  /// Loads the full bilingual content (ES + EN) for one published tale.
  Future<PublishedTaleFull> getPublishedTale(int taleId) async {
    final snaps = await Future.wait([
      _db.collection('tales').doc('${taleId}_es').get(),
      _db.collection('tales').doc('${taleId}_en').get(),
    ]);
    return PublishedTaleFull.fromDocs(
      taleId: taleId,
      esData: snaps[0].data(),
      enData: snaps[1].data(),
    );
  }
```

with:

```dart
  /// Loads the full bilingual content (ES + EN) for one published tale.
  /// Looks up by `tale_id`+`lang` fields rather than the doc id: published
  /// tales predating the admin's `${taleId}_es`/`${taleId}_en` doc-id
  /// convention have random Firestore ids, so guessing the id misses them.
  Future<PublishedTaleFull> getPublishedTale(int taleId) async {
    Future<Map<String, dynamic>?> fetchByLang(String lang) async {
      final q = await _db
          .collection('tales')
          .where('tale_id', isEqualTo: taleId)
          .where('lang', isEqualTo: lang)
          .limit(1)
          .get();
      return q.docs.isEmpty ? null : q.docs.first.data();
    }

    final snaps = await Future.wait([fetchByLang('es'), fetchByLang('en')]);
    return PublishedTaleFull.fromDocs(
      taleId: taleId,
      esData: snaps[0],
      enData: snaps[1],
    );
  }
```

- [ ] **Step 2: Static analysis**

Run: `flutter analyze lib/admin`
Expected: no new errors (the 5 pre-existing unused-import warnings, unrelated to this file, are fine).

- [ ] **Step 3: Commit**

```bash
git add lib/admin/services/drafts_service.dart
git commit -m "fix(admin): look up published tale docs by tale_id+lang instead of guessed id

getPublishedTale assumed every published tale's Firestore doc id follows
the \`\${taleId}_es\`/\`\${taleId}_en\` pattern, same bug as retractTale.
All 30 tales published today predate that convention and have random
Firestore ids, so the detail page has been rendering blank for every
published tale. Query by tale_id+lang instead, same pattern
streamPublished() already uses."
```

---

### Task 3: Manual end-to-end verification against the real published tales

**Files:** none (verification only, no code changes).

**Interfaces:** none — this task exercises the code from Tasks 1-2 against live Firestore data.

- [ ] **Step 1: Deploy the fixed function to a point where it can be tested**

This step touches production Cloud Functions — confirm with the user before running it (it's a live-infra change, not a local one):

```bash
cd firebase/functions && firebase deploy --only functions:retractTale --project merakitales-5rltbl
```

- [ ] **Step 2: Run the admin panel locally against the real Firebase project**

```bash
flutter run -d chrome -t lib/admin/main_admin.dart
```

- [ ] **Step 3: Verify the detail view for a real published tale**

In the running admin panel, go to "Publicados" → open `tale_id=30` (or any published tale). Confirm the name, description, "Texto del cuento", and ES/EN toggle all show real content, and the image and "Reproducir audio" link appear (matching what's in Firestore for that tale).

- [ ] **Step 4: Verify "Retirar de la app" works end-to-end**

On the same tale's detail page, click "Retirar de la app", confirm the dialog, and confirm:
- A snackbar shows a new draft id.
- The app navigates to `/drafts` and the retracted tale's content appears there as a pending draft.
- The tale no longer appears in "Publicados".

- [ ] **Step 5: Report back**

Summarize pass/fail for Steps 3-4 before considering this plan complete. If Step 4 is run against a real production tale, note that it's a one-way action (the tale is unpublished) — pick a low-stakes tale to test with, or confirm with the user first.

---

## Notes for execution

- This work should happen on an isolated branch/worktree, per the user's request to start a new branch before implementing. Create it via the `superpowers:using-git-worktrees` skill at the start of execution (not part of this plan's tasks — that skill handles it).
- Task 3's Steps 1 and 4 touch production (a function deploy, and retracting a real published tale). Both are hard-to-reverse/live-system actions — get explicit user confirmation before running them, per standard operating practice.

---

### Task 4 (discovered during Task 3 verification): Fix `approveDraft.js` to tolerate a missing storage file when re-publishing a retracted legacy tale

**Why this exists:** Task 3's manual E2E test retracted `tale_id=30` (a legacy tale). The retract succeeded — `retractTaleHandler` already tolerates its storage move failing (the legacy asset never lived at the `tales/{taleId}/...` path `moveIfExists` guesses) and falls back to the tale's existing asset URL, same as designed. But publishing that draft back then failed with `[firebase_functions/failed-precondition] file#copy failed with an error - No such object: .../drafts/{draftId}/image_1024.png`, because `publishDraft()` in `approveDraft.js` calls `moveFile` directly (no try/catch, no fallback) — it assumes a file always exists at `drafts/{draftId}/...` to move. For a retracted legacy tale, no such file was ever created there (retract had nothing to move either), so the move throws and publishing fails outright, even though the draft already holds working asset URLs. This blocks completing the retract→republish round trip for any legacy tale, including the specific one just retracted during Task 3 verification (`tale_id=30`, draft id `TJAZHvULsnIJMfk3Lo5B`).

The original design spec's "Storage (sin cambios)" section verified this fallback only from the retract side; it missed that `approveDraft.js`'s publish side has no equivalent tolerance, so this task extends scope to close that gap, mirroring the already-accepted `moveIfExists` pattern from `retractTale.js`.

**Files:**
- Modify: `firebase/functions/src/approveDraft.js:29-33`
- Test: `firebase/functions/__tests__/approveDraft.test.js`

**Interfaces:**
- Consumes: `moveFile` from `./storage` (unchanged signature). `d` (the draft's Firestore data, already loaded at `approveDraft.js:15`) — uses its existing `image_url`, `image_url_640px`, `audio_url_es`, `audio_url_en` fields as fallbacks.
- Produces: `publishDraft(draftId, decidedByUid)` — same signature and return value (`taleId`). `approveDraftHandler(req)` — same signature, same thrown errors. No caller changes needed.

- [ ] **Step 1: Add a failing test for the fallback behavior**

The existing `moveFile` mock (`jest.fn(async ({ toPath }) => ...)`, unchanged) already supports per-test failure injection via `mockRejectedValueOnce` — no change needed to the mock declaration itself. Add this new test in `firebase/functions/__tests__/approveDraft.test.js`, at the end of the `describe("approveDraft", ...)` block, after the "defaults is_premium_tale to false..." test:

```js
  test("falls back to the draft's existing asset URL when the storage move fails (e.g. a re-published legacy tale with no file at drafts/{id}/)", async () => {
    const admin = require("../src/admin");
    const { moveFile } = require("../src/storage");
    admin.__setDraft("pending", true);
    moveFile.mockRejectedValueOnce(new Error("No such object: drafts/d1/image_1024.png"));

    await approveDraftHandler({ data: { draftId: "d1" }, auth: { uid: "admin" } });

    const talesSets = admin.__sets.filter((s) => s.name === "tales").slice(-2);
    // image_1024.png move failed -> falls back to draftDoc.image_url; the other 3 moves still succeeded normally
    expect(talesSets[0].d.image_url).toBe("https://storage.googleapis.com/b/drafts/d1/image_1024.png");
    expect(talesSets[0].d.audio_url).toContain("tales/31/audio_es.mp3");
    const commonSets = admin.__sets.filter((s) => s.name === "tales_common_data").slice(-1);
    expect(commonSets[0].d.image_url_1024px).toBe("https://storage.googleapis.com/b/drafts/d1/image_1024.png");
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd firebase/functions && npx jest approveDraft.test.js`
Expected: FAIL on the new test — `moveFile` rejects on its first call (the image_1024.png move), and `publishDraft` currently has no try/catch around that call, so `approveDraftHandler` rejects with `failed-precondition` instead of completing.

- [ ] **Step 3: Implement the fallback in `approveDraft.js`**

Replace lines 29-33 of `firebase/functions/src/approveDraft.js` (currently):

```js
  // Move storage files drafts/{draftId}/ -> tales/{taleId}/
  const fromPrefix = `drafts/${draftId}`;
  const toPrefix = `tales/${taleId}`;
  const imageUrl = await moveFile({ bucket, fromPath: `${fromPrefix}/image_1024.png`, toPath: `${toPrefix}/image_1024.png` });
  const imageUrl640 = await moveFile({ bucket, fromPath: `${fromPrefix}/image_640.png`, toPath: `${toPrefix}/image_640.png` });
  const audioUrlEs = await moveFile({ bucket, fromPath: `${fromPrefix}/audio_es.mp3`, toPath: `${toPrefix}/audio_es.mp3` });
  const audioUrlEn = await moveFile({ bucket, fromPath: `${fromPrefix}/audio_en.mp3`, toPath: `${toPrefix}/audio_en.mp3` });
```

with:

```js
  // Move storage files drafts/{draftId}/ -> tales/{taleId}/. If there's nothing
  // to move (e.g. a re-published legacy tale whose asset was never placed at
  // drafts/{draftId}/... in the first place), keep the draft's existing URL —
  // same tolerance retractTale.js already applies on the way out.
  const fromPrefix = `drafts/${draftId}`;
  const toPrefix = `tales/${taleId}`;
  const moveOrKeep = async (filename, fallback) => {
    try {
      return await moveFile({ bucket, fromPath: `${fromPrefix}/${filename}`, toPath: `${toPrefix}/${filename}` });
    } catch (_) {
      return fallback;
    }
  };
  const imageUrl = await moveOrKeep("image_1024.png", d.image_url);
  const imageUrl640 = await moveOrKeep("image_640.png", d.image_url_640px);
  const audioUrlEs = await moveOrKeep("audio_es.mp3", d.audio_url_es);
  const audioUrlEn = await moveOrKeep("audio_en.mp3", d.audio_url_en);
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd firebase/functions && npx jest approveDraft.test.js`
Expected: PASS — all tests including the new one.

- [ ] **Step 5: Run the full functions test suite to check for regressions**

Run: `cd firebase/functions && npm test`
Expected: PASS on all suites except the 2 pre-existing unrelated failures (`generateTaleImage.test.js`, `generateTaleAudio.test.js`).

- [ ] **Step 6: Commit**

```bash
git add firebase/functions/src/approveDraft.js firebase/functions/__tests__/approveDraft.test.js
git commit -m "fix(functions): tolerate missing storage file when re-publishing a retracted legacy tale

publishDraft moved drafts/{draftId}/... -> tales/{taleId}/... unconditionally,
with no fallback if the source file doesn't exist. Legacy tales retracted via
retractTale never had a file placed at drafts/{draftId}/... in the first
place (their original assets live at non-standard storage paths), so
re-publishing one failed outright with a raw GCS 'No such object' error.
Fall back to the draft's already-stored asset URL when the move fails, same
tolerance retractTale.js already applies."
```

- [ ] **Step 7: Deploy and verify against the real stuck draft**

This touches production — confirm with the user before running (already confirmed for this specific fix). Deploy:

```bash
cd firebase/functions && firebase deploy --only functions:functions:approveDraft --project merakitales-5rltbl
```

Then ask the user to retry "Aprobar y Publicar Cuento" on the draft that got stuck during Task 3 verification (workspace URL contained draft id `TJAZHvULsnIJMfk3Lo5B`, tale "El Tren de la Noche") and confirm it now succeeds and the tale reappears in "Publicados".

---

### Task 5 (requested by user after seeing the fix): Stop assigning deterministic `${taleId}_es`/`${taleId}_en` doc ids on publish — let Firestore auto-generate them, like every other tale already has

**Why this exists:** After Tasks 1-4, a full repo grep (`lib/admin`, `firebase/functions/src`, `lib/backend`) confirms nothing reads a `tales` document by reconstructing `${taleId}_lang` from its id anymore — every reader queries by the `tale_id`+`lang` fields (Tasks 1-2), or follows the `tale_common_data_ref` reference field (Task 1) rather than guessing `tales_common_data/{taleId}`. The only remaining place that *writes* the deterministic id pattern is `approveDraft.js`'s two `.set()` calls when publishing a new tale — a vestigial convention that serves no purpose now and only exists because it predates the field-query fix. The user asked, correctly: since nothing depends on this id shape, why not let Firestore assign a random id on publish, exactly like the 30 legacy tales already have and always have had? This task removes the last id-guessing write path, so every tale (past and future) is created and found the same way.

**Files:**
- Modify: `firebase/functions/src/approveDraft.js:49,59,79`
- Test: `firebase/functions/__tests__/approveDraft.test.js`
- Modify (doc-comment accuracy only): `lib/admin/services/drafts_service.dart:38-40`

**Interfaces:**
- Consumes: nothing new.
- Produces: `publishDraft(draftId, decidedByUid)` — same signature and return value (`taleId`, a number — unaffected, this is Firestore's own `tale_id` *field*, assigned earlier in the function via the existing transaction; only the *document id* changes). No caller needs changes.

- [ ] **Step 1: Update the test's assertions for auto-generated ids**

In `firebase/functions/__tests__/approveDraft.test.js`, the mock's `doc: jest.fn((id) => ({...}))` (inside `getCollection`, around line 31) already tolerates `id === undefined` (it just tracks whatever `id` it's called with — `undefined` is a valid value in the `sets` array entries). No change needed to the mock itself. Replace only the assertions in the first test (`"writes 2 tales docs + 1 common_data, marks draft approved, moves 4 files"`) that check the specific guessed ids — replace:

```js
    // tales collection: doc called twice (31_es, 31_en)
    expect(admin.__collections["tales"].doc).toHaveBeenCalledTimes(2);
    expect(admin.__collections["tales"].doc).toHaveBeenNthCalledWith(1, "31_es");
    expect(admin.__collections["tales"].doc).toHaveBeenNthCalledWith(2, "31_en");
    // tales_common_data: doc called once (31)
    expect(admin.__collections["tales_common_data"].doc).toHaveBeenCalledTimes(1);
    expect(admin.__collections["tales_common_data"].doc).toHaveBeenCalledWith("31");
```

with:

```js
    // tales collection: doc() called twice, both times with no id (Firestore auto-generates), not a guessed "31_es"/"31_en"
    expect(admin.__collections["tales"].doc).toHaveBeenCalledTimes(2);
    expect(admin.__collections["tales"].doc).toHaveBeenNthCalledWith(1);
    expect(admin.__collections["tales"].doc).toHaveBeenNthCalledWith(2);
    // tales_common_data: doc() called once, no id
    expect(admin.__collections["tales_common_data"].doc).toHaveBeenCalledTimes(1);
    expect(admin.__collections["tales_common_data"].doc).toHaveBeenCalledWith();
```

(Every other assertion in this test file — `talesSets[0].d.tale_id`, `.d.tale_common_data_ref`, `.d.audio_url`, `commonSets[0].d.image_url_1024px`, the `is_premium_tale` tests, etc. — reads from `sets`/`d` by content, not by id, so none of them need to change.)

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd firebase/functions && npx jest approveDraft.test.js`
Expected: FAIL on the first test — the current code still calls `.doc("31_es")`/`.doc("31_en")`/`.doc("31")` with explicit ids, so `toHaveBeenNthCalledWith(1)` (expecting zero arguments) does not match.

- [ ] **Step 3: Remove the guessed ids in `approveDraft.js`**

Replace line 49:

```js
  const commonRef = db.collection("tales_common_data").doc(`${taleId}`);
```

with:

```js
  const commonRef = db.collection("tales_common_data").doc();
```

Replace line 59:

```js
  await db.collection("tales").doc(`${taleId}_es`).set({
```

with:

```js
  await db.collection("tales").doc().set({
```

Replace line 79:

```js
  await db.collection("tales").doc(`${taleId}_en`).set({
```

with:

```js
  await db.collection("tales").doc().set({
```

Nothing else in the function changes — `taleId` (the numeric `tale_id` field) is still assigned by the existing transaction and still written into both docs' `tale_id` field exactly as before; only the Firestore *document id* stops being derived from it.

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd firebase/functions && npx jest approveDraft.test.js`
Expected: PASS — all tests including the updated assertions.

- [ ] **Step 5: Run the full functions test suite to check for regressions**

Run: `cd firebase/functions && npm test`
Expected: PASS on all suites except the 2 pre-existing unrelated failures (`generateTaleImage.test.js`, `generateTaleAudio.test.js`).

- [ ] **Step 6: Fix the now-inaccurate doc-comment in `drafts_service.dart`**

In `lib/admin/services/drafts_service.dart`, the comment above `getPublishedTale` currently reads:

```dart
  /// Loads the full bilingual content (ES + EN) for one published tale.
  /// Looks up by `tale_id`+`lang` fields rather than the doc id: published
  /// tales predating the admin's `${taleId}_es`/`${taleId}_en` doc-id
  /// convention have random Firestore ids, so guessing the id misses them.
```

Replace with:

```dart
  /// Loads the full bilingual content (ES + EN) for one published tale.
  /// Looks up by `tale_id`+`lang` fields rather than the doc id: every
  /// published tale (old and new) has a Firestore auto-generated doc id,
  /// never a predictable one, so nothing may ever look it up by guessing.
```

- [ ] **Step 7: Static analysis**

Run: `flutter analyze lib/admin`
Expected: no new errors (7 pre-existing issues unrelated to this file).

- [ ] **Step 8: Commit**

```bash
git add firebase/functions/src/approveDraft.js firebase/functions/__tests__/approveDraft.test.js lib/admin/services/drafts_service.dart
git commit -m "fix(functions): stop guessing tale doc ids on publish, let Firestore assign them

Nothing reads a tales/ document by reconstructing \${taleId}_es/\${taleId}_en
from its id anymore (Tasks 1-2 moved every reader to field queries and
reference-following). The deterministic id this function assigned on publish
was therefore serving no purpose - just a vestige of the convention the
earlier bug depended on. Let Firestore auto-generate the doc id instead, same
as the 30 legacy tales already have, so id generation is uniform everywhere
going forward."
```

- [ ] **Step 9: Deploy**

This touches production — confirm with the user before running (already directed by the user to make this change; deploying the resulting code still touches a live function).

```bash
cd firebase/functions && firebase deploy --only functions:functions:approveDraft --project merakitales-5rltbl
```

No further manual verification needed beyond what Task 3 already covered — the publish path's behavior for the admin/mobile app is unchanged (same fields, same values), only the invisible-to-everyone document id generation changed.
