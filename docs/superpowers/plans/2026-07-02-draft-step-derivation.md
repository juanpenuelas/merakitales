# `step` deja de guardarse: se deriva siempre al leer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate `tale_drafts.step` as a stored Firestore field across all 6 write sites (4 AI-pipeline Cloud Functions + 2 manual-flow write paths); derive it instead, at read time, purely from whether `image_url`/`audio_url_es`/`audio_url_en` are present.

**Architecture:** A pure `computeStep(draft)` function, implemented once in `firebase/functions/src/draftStep.js` (used by `approveDraft.js`'s publish guard) and once as a computed `Draft.step` getter in Dart (used unchanged by every existing UI read site, since the property name/type don't change). Every function that currently writes `step` stops doing so; `resizeDraftImage.js`'s transaction from the previous fix is reverted since there's no longer a derived field to protect from races.

**Tech Stack:** Firebase Cloud Functions (Node.js, Jest), Flutter Web (Dart), Firestore.

## Global Constraints

- `step` is never stored in Firestore from this point forward — only computed at read time. No migration: old documents keep their stale stored `step` field, but nothing reads it anymore.
- Formula (identical in both languages): `image_url && audio_url_es && audio_url_en → "audio"`; else `image_url → "image"`; else `"text"`.
- Documented edge case, not a bug: both audio URLs present but no image → `"text"` (not an intermediate state). This reflects "not yet publishable," which is the signal that matters.
- `draft_create_page.dart`'s publish button already checks `audioUrlEs`/`audioUrlEn` directly rather than `step`, so it's out of scope. However, its progression waits (`_generateAudio`, `_approveTextAndGenerateImage`, `_regenerateImage`) do read `d?.step` while polling `streamDraft` for completion, so they are not out of scope in the same way. `_generateAudio`'s wait was fixed separately (see commit "fix(admin): wait on the specific audio URL instead of step in AI wizard") to check the language's own `audioUrlEs`/`audioUrlEn` field instead of `step`, precisely because `step` requiring both languages made the old step-based wait time out for whichever language finished first.
- No Cloud Function gains or loses its region/auth/secrets configuration in `index.js` — this plan only changes function bodies, not their `onCall` registration.

---

### Task 1: `computeStep` pure function

**Files:**
- Create: `firebase/functions/src/draftStep.js`
- Test: `firebase/functions/__tests__/draftStep.test.js`

**Interfaces:**
- Produces: `computeStep({ image_url, audio_url_es, audio_url_en }): "text" | "image" | "audio"`, exported from `draftStep.js`. Consumed by Task 2's `approveDraft.js`.

- [ ] **Step 1: Write the failing test**

Create `firebase/functions/__tests__/draftStep.test.js`:

```javascript
const { computeStep } = require("../src/draftStep");

describe("computeStep", () => {
  test("returns 'text' when nothing is uploaded", () => {
    expect(computeStep({})).toBe("text");
  });

  test("returns 'text' when called with no argument", () => {
    expect(computeStep()).toBe("text");
  });

  test("returns 'image' when only the image is present", () => {
    expect(computeStep({ image_url: "https://x/image_1024.png" })).toBe("image");
  });

  test("returns 'image' when image + only one audio language are present", () => {
    expect(computeStep({ image_url: "https://x/image_1024.png", audio_url_es: "https://x/audio_es.mp3" })).toBe("image");
  });

  test("returns 'audio' when image + both audio languages are present", () => {
    expect(computeStep({
      image_url: "https://x/image_1024.png",
      audio_url_es: "https://x/audio_es.mp3",
      audio_url_en: "https://x/audio_en.mp3",
    })).toBe("audio");
  });

  test("returns 'text' when both audios exist but the image does not (documented edge case)", () => {
    expect(computeStep({
      audio_url_es: "https://x/audio_es.mp3",
      audio_url_en: "https://x/audio_en.mp3",
    })).toBe("text");
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd firebase/functions && npm test -- draftStep.test.js
```

Expected: FAIL — `Cannot find module '../src/draftStep'`.

- [ ] **Step 3: Write the implementation**

Create `firebase/functions/src/draftStep.js`:

```javascript
/**
 * Derives a draft's pipeline step purely from which assets exist.
 * Never stored — always computed from the draft's current fields, so it
 * can never disagree with reality.
 * @param {{ image_url?: string, audio_url_es?: string, audio_url_en?: string }} [draft]
 * @returns {"text" | "image" | "audio"}
 */
function computeStep({ image_url, audio_url_es, audio_url_en } = {}) {
  if (image_url && audio_url_es && audio_url_en) return "audio";
  if (image_url) return "image";
  return "text";
}

module.exports = { computeStep };
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd firebase/functions && npm test -- draftStep.test.js
```

Expected: PASS, all 6 tests green.

- [ ] **Step 5: Commit**

```bash
git add firebase/functions/src/draftStep.js firebase/functions/__tests__/draftStep.test.js
git commit -m "feat(functions): add pure computeStep helper"
```

---

### Task 2: `approveDraft.js` uses `computeStep`

**Files:**
- Modify: `firebase/functions/src/approveDraft.js`
- Test: `firebase/functions/__tests__/approveDraft.test.js` (full rewrite)

**Interfaces:**
- Consumes: `computeStep({ image_url, audio_url_es, audio_url_en }): "text"|"image"|"audio"` (Task 1).

- [ ] **Step 1: Update the import and the guard**

In `firebase/functions/src/approveDraft.js`, change the top import line from:
```javascript
const { db, bucket, requireAuth } = require("./admin");
const { moveFile } = require("./storage");
```
to:
```javascript
const { db, bucket, requireAuth } = require("./admin");
const { moveFile } = require("./storage");
const { computeStep } = require("./draftStep");
```

Then change:
```javascript
  if (d.step !== "audio" || !d.audio_url_es || !d.audio_url_en) {
    const { HttpsError } = require("firebase-functions/v2/https");
    throw new HttpsError("failed-precondition", "Draft is missing image/audio assets and cannot be published yet");
  }
```
to:
```javascript
  if (computeStep(d) !== "audio") {
    const { HttpsError } = require("firebase-functions/v2/https");
    throw new HttpsError("failed-precondition", "Draft is missing image/audio assets and cannot be published yet");
  }
```

- [ ] **Step 2: Replace the test file**

`approveDraft.test.js`'s mock currently hardcodes `step: "audio"` on the draft data and lets tests override it via a `step` param on `__setDraft`. Since `approveDraft.js` no longer reads `d.step` at all, replace the whole file with this version — the happy-path `draftDoc` already has `image_url`/`audio_url_es`/`audio_url_en` populated, so `computeStep` naturally returns `"audio"` for it without needing a `step` field; the failing-precondition test now simulates "not ready" by blanking `image_url` instead of overriding a `step` field that no longer exists:

Write `firebase/functions/__tests__/approveDraft.test.js`:

```javascript
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
};

jest.mock("../src/admin", () => {
  const collections = {};
  const sets = [];
  const updates = [];
  let draftStatus = "pending";
  let draftExists = true;
  let draftOverrides = {};
  function getCollection(name) {
    if (!collections[name]) {
      collections[name] = {
        doc: jest.fn((id) => ({
          get: jest.fn(async () => ({
            exists: name === "tale_drafts" ? draftExists : true,
            id,
            data: () => (name === "tale_drafts" ? { ...draftDoc, status: draftStatus, ...draftOverrides } : {}),
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
    __setDraft: (status, exists = true) => { draftStatus = status; draftExists = exists; },
    __setDraftOverrides: (overrides) => { draftOverrides = overrides; },
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

  test("throws failed-precondition when the draft is missing an asset (e.g. no image yet)", async () => {
    const admin = require("../src/admin");
    admin.__setDraft("pending", true);
    admin.__setDraftOverrides({ image_url: "" });
    await expect(
      approveDraftHandler({ data: { draftId: "d1" }, auth: { uid: "admin" } })
    ).rejects.toThrow(/missing image\/audio assets/);
    admin.__setDraftOverrides({});
  });
});
```

- [ ] **Step 3: Run the test**

```bash
cd firebase/functions && npm test -- approveDraft.test.js
```

Expected: PASS, all 6 tests green.

- [ ] **Step 4: Commit**

```bash
git add firebase/functions/src/approveDraft.js firebase/functions/__tests__/approveDraft.test.js
git commit -m "refactor(functions): approveDraft uses computeStep instead of stored step"
```

---

### Task 3: Strip `step` from the 4 remaining AI-pipeline Cloud Functions

**Files:**
- Modify: `firebase/functions/src/generateTaleText.js`
- Modify: `firebase/functions/src/generateTaleImage.js`
- Modify: `firebase/functions/src/generateTaleAudio.js`
- Modify: `firebase/functions/src/retractTale.js`
- Test: `firebase/functions/__tests__/generateTaleText.test.js`
- Test: `firebase/functions/__tests__/generateTaleImage.test.js`
- Test: `firebase/functions/__tests__/generateTaleAudio.test.js`
- Test: `firebase/functions/__tests__/retractTale.test.js`

**Interfaces:** None — this task only removes a field from 4 write operations. No signatures change.

- [ ] **Step 1: `generateTaleText.js`**

Change:
```javascript
  const draft = {
    status: "pending",
    step: "text",
    created_at: new Date(),
```
to:
```javascript
  const draft = {
    status: "pending",
    created_at: new Date(),
```

- [ ] **Step 2: `generateTaleText.test.js`**

Remove this line from the `"creates a draft with step=text and pending status"` test:
```javascript
    expect(saved.step).toBe("text");
```
(Leave every other assertion in that test unchanged.)

- [ ] **Step 3: `generateTaleImage.js`**

Change:
```javascript
  await draftRef.update({
    step: "image",
    image_url: imageUrl,
    image_url_640px: imageUrl640,
  });
```
to:
```javascript
  await draftRef.update({
    image_url: imageUrl,
    image_url_640px: imageUrl640,
  });
```

- [ ] **Step 4: `generateTaleImage.test.js`**

Remove this line from the `"adds image to draft and updates step to image"` test:
```javascript
    expect(upd.step).toBe("image");
```
(Leave every other assertion in that test unchanged, including the test's name.)

- [ ] **Step 5: `generateTaleAudio.js`**

Change:
```javascript
  const update = lang === "es" ? { audio_url_es: audioUrl } : { audio_url_en: audioUrl };
  await draftRef.update({ ...update, step: "audio" });
```
to:
```javascript
  const update = lang === "es" ? { audio_url_es: audioUrl } : { audio_url_en: audioUrl };
  await draftRef.update(update);
```

- [ ] **Step 6: `generateTaleAudio.test.js`**

Remove this line from the `"generates ES audio with Azure voice and updates step to audio"` test:
```javascript
    expect(admin.__updates[0].d.step).toBe("audio");
```
(Leave every other assertion in that test unchanged, including the test's name.)

- [ ] **Step 7: `retractTale.js`**

Change:
```javascript
  batch.set(db.collection("tale_drafts").doc(draftId), {
    status: "pending",
    step: "audio",
    created_at: new Date(),
```
to:
```javascript
  batch.set(db.collection("tale_drafts").doc(draftId), {
    status: "pending",
    created_at: new Date(),
```

- [ ] **Step 8: `retractTale.test.js`**

Remove this line from the `"moves tale to drafts and returns new draftId"` test:
```javascript
    expect(draft.step).toBe("audio");
```
(Leave every other assertion in that test unchanged.)

- [ ] **Step 9: Run the full backend test suite**

```bash
cd firebase/functions && npm test
```

Expected: PASS, all suites green.

- [ ] **Step 10: Commit**

```bash
git add firebase/functions/src/generateTaleText.js firebase/functions/src/generateTaleImage.js firebase/functions/src/generateTaleAudio.js firebase/functions/src/retractTale.js firebase/functions/__tests__/generateTaleText.test.js firebase/functions/__tests__/generateTaleImage.test.js firebase/functions/__tests__/generateTaleAudio.test.js firebase/functions/__tests__/retractTale.test.js
git commit -m "refactor(functions): stop writing step in text/image/audio/retract handlers"
```

---

### Task 4: Revert `resizeDraftImage.js` to a plain update

**Files:**
- Modify: `firebase/functions/src/resizeDraftImage.js`
- Test: `firebase/functions/__tests__/resizeDraftImage.test.js` (full rewrite)

**Interfaces:**
- Produces: `resizeDraftImageHandler(req): Promise<{imageUrl: string, imageUrl640: string}>` — return shape unchanged, only the internal write changes.

- [ ] **Step 1: Simplify the handler**

In `firebase/functions/src/resizeDraftImage.js`, change:
```javascript
  await db.runTransaction(async (tx) => {
    const freshSnap = await tx.get(draftRef);
    const d = freshSnap.data() || {};
    const step = d.audio_url_es && d.audio_url_en ? "audio" : "image";
    tx.update(draftRef, { step, image_url: imageUrl, image_url_640px: imageUrl640 });
  });
```
to:
```javascript
  await draftRef.update({ image_url: imageUrl, image_url_640px: imageUrl640 });
```

- [ ] **Step 2: Replace the test file**

The current test file mocks `db.runTransaction` and has a test specifically for the step-promotion behavior being removed in Step 1 above — that test no longer applies (the equivalent logic is now covered by Task 1's `draftStep.test.js`) and is deleted. Write `firebase/functions/__tests__/resizeDraftImage.test.js`:

```javascript
const { resizeDraftImageHandler } = require("../src/resizeDraftImage");

jest.mock("../src/admin", () => {
  const updates = [];
  let draftExists = true;
  return {
    db: {
      collection: jest.fn(() => ({
        doc: jest.fn((id) => ({
          get: jest.fn(async () => ({ exists: draftExists, id, data: () => ({ status: "pending" }) })),
          update: jest.fn(async (d) => { updates.push({ id, d }); }),
        })),
      })),
    },
    bucket: { name: "b" },
    requireAuth: jest.fn(),
    __updates: updates,
    __setDraftExists: (v) => { draftExists = v; },
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
    expect(admin.__updates[0].d.image_url).toContain("image_1024.png");
    expect(admin.__updates[0].d.image_url_640px).toContain("image_640.png");
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
```

- [ ] **Step 3: Run the test**

```bash
cd firebase/functions && npm test -- resizeDraftImage.test.js
```

Expected: PASS, all 5 tests green.

- [ ] **Step 4: Run the full backend suite**

```bash
cd firebase/functions && npm test
```

Expected: PASS, all suites green.

- [ ] **Step 5: Commit**

```bash
git add firebase/functions/src/resizeDraftImage.js firebase/functions/__tests__/resizeDraftImage.test.js
git commit -m "refactor(functions): revert resizeDraftImage to a plain update, no derived step to protect"
```

---

### Task 5: `Draft` model — `step` becomes a computed getter

**Files:**
- Modify: `lib/admin/models/draft.dart` (full rewrite)

**Interfaces:**
- Produces: `Draft.step` — a `String` getter (was a stored `final String` field; same name and type, so every existing read site keeps working unchanged). Consumed unchanged by `drafts_list_page.dart`, `draft_detail_page.dart` (modified in Task 7), `draft_create_manual_page.dart`.

- [ ] **Step 1: Rewrite the file**

Write `lib/admin/models/draft.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Draft {
  final String id;
  final String status;
  final DateTime? createdAt;
  final String nameEs;
  final String descriptionEs;
  final String specificationsEs;
  final String audioUrlEs;
  final String nameEn;
  final String descriptionEn;
  final String specificationsEn;
  final String audioUrlEn;
  final String imageUrl;
  final String imageUrl640;
  final String imagePrompt;
  final int? assignedTaleId;
  final int? retractedFromTaleId;

  Draft({
    required this.id,
    required this.status,
    this.createdAt,
    required this.nameEs,
    required this.descriptionEs,
    required this.specificationsEs,
    required this.audioUrlEs,
    required this.nameEn,
    required this.descriptionEn,
    required this.specificationsEn,
    required this.audioUrlEn,
    required this.imageUrl,
    required this.imageUrl640,
    required this.imagePrompt,
    this.assignedTaleId,
    this.retractedFromTaleId,
  });

  /// Derived purely from which assets exist — never stored, so it can
  /// never disagree with the draft's actual Firestore fields.
  String get step {
    if (imageUrl.isNotEmpty && audioUrlEs.isNotEmpty && audioUrlEn.isNotEmpty) return 'audio';
    if (imageUrl.isNotEmpty) return 'image';
    return 'text';
  }

  factory Draft.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Draft(
      id: doc.id,
      status: d['status'] as String? ?? 'pending',
      createdAt: (d['created_at'] as Timestamp?)?.toDate(),
      nameEs: d['name_es'] as String? ?? '',
      descriptionEs: d['description_es'] as String? ?? '',
      specificationsEs: d['specifications_es'] as String? ?? '',
      audioUrlEs: d['audio_url_es'] as String? ?? '',
      nameEn: d['name_en'] as String? ?? '',
      descriptionEn: d['description_en'] as String? ?? '',
      specificationsEn: d['specifications_en'] as String? ?? '',
      audioUrlEn: d['audio_url_en'] as String? ?? '',
      imageUrl: d['image_url'] as String? ?? '',
      imageUrl640: d['image_url_640px'] as String? ?? '',
      imagePrompt: d['image_prompt'] as String? ?? '',
      assignedTaleId: d['assigned_tale_id'] as int?,
      retractedFromTaleId: d['retracted_from_tale_id'] as int?,
    );
  }
}
```

- [ ] **Step 2: Verify it compiles**

```bash
flutter analyze lib/admin/models/draft.dart
```

Expected: `No issues found!`.

- [ ] **Step 3: Commit**

```bash
git add lib/admin/models/draft.dart
git commit -m "refactor(admin): Draft.step becomes a computed getter, not a stored field"
```

---

### Task 6: `DraftsService` — stop writing `step`

**Files:**
- Modify: `lib/admin/services/drafts_service.dart`

**Interfaces:**
- Produces: `saveManualDraftAudioUrl({required String draftId, required String lang, required String url})` — same signature as before, simplified body (no longer needs a transaction since it no longer writes a derived field).

- [ ] **Step 1: Remove `step` from `createManualDraft`**

In `lib/admin/services/drafts_service.dart`, change:
```dart
    await ref.set({
      'status': 'pending',
      'step': 'text',
      'created_at': FieldValue.serverTimestamp(),
```
to:
```dart
    await ref.set({
      'status': 'pending',
      'created_at': FieldValue.serverTimestamp(),
```

- [ ] **Step 2: Simplify `saveManualDraftAudioUrl`**

Change:
```dart
  Future<void> saveManualDraftAudioUrl({
    required String draftId,
    required String lang,
    required String url,
  }) async {
    final ref = _db.collection('tale_drafts').doc(draftId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() ?? {};
      final imageUrl = data['image_url'] as String? ?? '';
      final audioEs = lang == 'es' ? url : (data['audio_url_es'] as String? ?? '');
      final audioEn = lang == 'en' ? url : (data['audio_url_en'] as String? ?? '');
      final update = <String, dynamic>{'audio_url_$lang': url};
      if (imageUrl.isNotEmpty && audioEs.isNotEmpty && audioEn.isNotEmpty) {
        update['step'] = 'audio';
      } else if (imageUrl.isNotEmpty) {
        update['step'] = 'image';
      }
      tx.update(ref, update);
    });
  }
```
to:
```dart
  Future<void> saveManualDraftAudioUrl({
    required String draftId,
    required String lang,
    required String url,
  }) async {
    await _db.collection('tale_drafts').doc(draftId).update({'audio_url_$lang': url});
  }
```

- [ ] **Step 3: Verify it compiles**

```bash
flutter analyze lib/admin/services/drafts_service.dart
```

Expected: `No issues found!`.

- [ ] **Step 4: Commit**

```bash
git add lib/admin/services/drafts_service.dart
git commit -m "refactor(admin): DraftsService stops writing the derived step field"
```

---

### Task 7: `draft_detail_page.dart` — simplify the publish gate

**Files:**
- Modify: `lib/admin/drafts/draft_detail_page.dart`

**Interfaces:**
- Consumes: `Draft.step` (Task 5's computed getter — now trustworthy by construction, so the redundant `audioUrlEs`/`audioUrlEn` double-check is removed).

- [ ] **Step 1: Simplify both gate conditions**

In `lib/admin/drafts/draft_detail_page.dart`, change:
```dart
                          const SizedBox(height: 24),
                          if (d.step != 'audio' || d.audioUrlEs.isEmpty || d.audioUrlEn.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                'Este borrador aún no ha completado los 3 pasos (texto, imagen, audio ES/EN) y no se puede publicar todavía.',
                                style: TextStyle(color: Colors.orange.shade800, fontSize: 12),
                              ),
                            ),
                          Row(
                            children: [
                              OutlinedButton(
                                onPressed: () => _reject(d.id),
                                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                child: const Text('Rechazar'),
                              ),
                              const SizedBox(width: 12),
                              if (d.step == 'audio' && d.audioUrlEs.isNotEmpty && d.audioUrlEn.isNotEmpty)
                                FilledButton.icon(
                                  onPressed: () => _approve(d.id),
                                  icon: const Icon(Icons.publish),
                                  label: const Text('Aprobar y publicar'),
                                ),
                            ],
                          ),
```
to:
```dart
                          const SizedBox(height: 24),
                          if (d.step != 'audio')
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                'Este borrador aún no ha completado los 3 pasos (texto, imagen, audio ES/EN) y no se puede publicar todavía.',
                                style: TextStyle(color: Colors.orange.shade800, fontSize: 12),
                              ),
                            ),
                          Row(
                            children: [
                              OutlinedButton(
                                onPressed: () => _reject(d.id),
                                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                child: const Text('Rechazar'),
                              ),
                              const SizedBox(width: 12),
                              if (d.step == 'audio')
                                FilledButton.icon(
                                  onPressed: () => _approve(d.id),
                                  icon: const Icon(Icons.publish),
                                  label: const Text('Aprobar y publicar'),
                                ),
                            ],
                          ),
```

- [ ] **Step 2: Verify it compiles**

```bash
flutter analyze lib/admin
```

Expected: only the 5 pre-existing unused-import warnings, 0 new issues, 0 errors.

- [ ] **Step 3: Commit**

```bash
git add lib/admin/drafts/draft_detail_page.dart
git commit -m "refactor(admin): simplify publish gate now that step is trustworthy by construction"
```

---

### Task 8: End-to-end verification

**Files:** none (verification only).

**Interfaces:** none.

- [ ] **Step 1: Run the full backend test suite**

```bash
cd firebase/functions && npm test
```

Expected: PASS, all suites green.

- [ ] **Step 2: Run `flutter analyze` on the whole admin app**

```bash
flutter analyze lib/admin
```

Expected: only the 5 pre-existing unused-import warnings, 0 errors.

- [ ] **Step 3: Build the admin web app**

```bash
flutter build web -t lib/admin/main_admin.dart --release
```

Expected: `✓ Built build/web` with no compile errors.

- [ ] **Step 4: Deploy the changed Cloud Functions**

This task changes 6 of the 8 deployed callables (`generateTaleText`, `generateTaleImage`, `generateTaleAudio`, `retractTale`, `approveDraft`, `resizeDraftImage`). Deploy the whole `functions` codebase rather than listing each name individually:

```bash
cd firebase && firebase deploy --only functions -P merakitales-5rltbl
```

Expected: deploy succeeds, all 8 functions show as updated in the Firebase console.

**Production deploy — requires explicit user confirmation before running**, same as the manual-tale-creation plan's Task 8. Do not run this without the user confirming first in chat.

- [ ] **Step 5: Deploy the admin web app (hosting)**

The `Draft` model, `DraftsService`, and `draft_detail_page.dart` all changed, so the previously-deployed hosting build is stale.

```bash
cd firebase && firebase deploy --only hosting -P merakitales-5rltbl
```

Expected: deploy succeeds, `Hosting URL: https://merakitales-5rltbl.web.app`.

**Also requires explicit user confirmation before running.**

- [ ] **Step 6: Manual walkthrough (requires a human or a connected browser tool)**

At `https://merakitales-5rltbl.web.app/#/drafts`, verify:
1. An AI-generated draft still progresses through 📝→🖼️→🎵 in the drafts list as before.
2. A manual draft with audios uploaded before the image does NOT show "Aprobar y publicar" until the image is also uploaded (this was the bug the previous plan's final review caught — confirm it stays fixed under the new derivation).
3. A manual draft with the image uploaded after both audios correctly shows "Aprobar y publicar" (no step regression).
4. An existing already-published tale (retracted via "Retirar") still shows as immediately publishable (`step` computes to `"audio"` since a retracted draft already has all three assets).

- [ ] **Step 7: Commit (only if Step 6 surfaced fixes)**

If the manual walkthrough required any code fixes, commit them individually with descriptive messages. If no fixes were needed, this step is a no-op — the plan is done as of Task 7's commit.

---

## Self-Review Notes

- **Spec coverage:** every section of `docs/superpowers/specs/2026-07-02-draft-step-derivation-design.md` maps to a task — La fórmula → Task 1; Backend write-site removals → Tasks 2-4; Frontend (`Draft` model, `DraftsService`) → Tasks 5-6; Guardia de publicación simplificada → Task 7; Testing → Tasks 1-4 (backend) and Task 8 (manual, Dart has no automated tests per existing convention); Compatibilidad hacia atrás (no migration) → implicitly satisfied by never reading the old stored field anywhere in Tasks 5-7.
- **Type consistency checked:** `computeStep`'s parameter shape (`{image_url, audio_url_es, audio_url_en}`) matches the raw Firestore field names used identically in `approveDraft.js` (Task 2) and `draftStep.test.js` (Task 1). `Draft.step`'s getter formula (Task 5) is the same three-branch logic as `computeStep`, just using the Dart camelCase field names (`imageUrl`, `audioUrlEs`, `audioUrlEn`) already defined on the same class. `saveManualDraftAudioUrl`'s signature (Task 6) is unchanged from what Task 6 of the previous plan produced, so `draft_create_manual_page.dart` (not touched by this plan) keeps calling it correctly with no changes needed there.
- **No placeholders:** confirmed no TBD/TODO markers; every step has runnable code, exact before/after snippets, or an exact command with expected output.
