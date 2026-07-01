# Creación manual de cuentos (sin IA) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a second draft-creation path in the admin panel where the admin writes the story text and uploads a pre-made image + ES/EN MP3 audio files by hand, then reuses the existing draft review/approve pipeline unchanged.

**Architecture:** One new Cloud Function (`resizeDraftImage`) that reuses the existing `resizeToWidth`/`uploadBuffer` helpers from `storage.js`. Everything else (draft creation/text edits, file uploads) writes directly from the Flutter client to Firestore/Storage, since `firestore.rules`/`storage.rules` already grant the admin uid full read/write on `tale_drafts` and `drafts/**`. A new page `draft_create_manual_page.dart` hosts the form; `draft_detail_page.dart` and `approveDraft.js` are untouched.

**Tech Stack:** Flutter Web (admin), Firebase Cloud Functions (Node.js, `firebase-functions/v2`), Firestore, Firebase Storage, Jest for backend tests.

## Global Constraints

- No new Firestore fields — the manual draft uses the exact same `tale_drafts` schema as an AI-generated draft (spec: "Modelo de datos").
- Storage paths for a draft's files are always `drafts/{draftId}/image_1024.png`, `image_640.png`, `audio_es.mp3`, `audio_en.mp3` — `approveDraft.js` hardcodes these and must not change.
- Accepted upload formats: image `.png`/`.jpg`/`.jpeg` only, audio `.mp3` only. Reject other formats client-side before upload with a clear message (spec: "Validación y manejo de errores").
- Max upload size: 15MB image, 30MB audio, enforced client-side before upload starts.
- Every input has a visible label (not placeholder-only); required fields are marked with `*` (spec: "UI y componentes").
- New Cloud Functions follow the existing pattern: `requireAuth(req)` first, `HttpsError` with `invalid-argument`/`not-found`/`failed-precondition` codes, region `europe-west1`.
- This repo has no automated Flutter widget tests today (`lib/admin` is verified via `flutter analyze` + manual walkthrough) — do not introduce a new test framework for this feature; follow the existing convention.
- Backend Cloud Functions get Jest tests following the exact mocking conventions already used in `firebase/functions/__tests__/generateTaleImage.test.js` and `approveDraft.test.js`.

---

### Task 1: Add the `file_picker` dependency

**Files:**
- Modify: `pubspec.yaml`

**Interfaces:**
- Produces: `package:file_picker/file_picker.dart` available for import in Task 5 and Task 6.

- [ ] **Step 1: Add the dependency**

Run from the repo root:
```bash
flutter pub add file_picker
```

Expected: command exits 0, `pubspec.yaml` gains a `file_picker: ^<version>` line under `dependencies`, and `pubspec.lock` is updated.

- [ ] **Step 2: Verify it resolves for the web target**

```bash
flutter pub get
```

Expected: `Got dependencies!` with no version conflicts reported.

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add file_picker for manual tale image/audio uploads"
```

---

### Task 2: `storage.js` helpers — `downloadFile` and `fileExists`

**Files:**
- Modify: `firebase/functions/src/storage.js`
- Test: `firebase/functions/__tests__/storage.test.js`

**Interfaces:**
- Produces: `downloadFile({ bucket, path }): Promise<Buffer>`, `fileExists({ bucket, path }): Promise<boolean>` — both exported from `storage.js`, consumed by Task 3's `resizeDraftImage.js`.
- Consumes: nothing new (same `bucket` shape already used by `moveFile`/`uploadBuffer` in this file: an object with a `.file(path)` method).

- [ ] **Step 1: Write the failing tests**

First, update the existing top import line in `firebase/functions/__tests__/storage.test.js` from:
```javascript
const { resizeToWidth } = require("../src/storage");
```
to:
```javascript
const { resizeToWidth, downloadFile, fileExists } = require("../src/storage");
```

Then append the following two `describe` blocks to the end of the file (after the existing `describe("storage helpers", ...)` block):

```javascript
describe("downloadFile", () => {
  test("returns the file's buffer contents", async () => {
    const mockBuffer = Buffer.from("hello");
    const bucket = { file: jest.fn(() => ({ download: jest.fn(async () => [mockBuffer]) })) };
    const result = await downloadFile({ bucket, path: "some/path.png" });
    expect(result).toBe(mockBuffer);
    expect(bucket.file).toHaveBeenCalledWith("some/path.png");
  });
});

describe("fileExists", () => {
  test("returns true when the file exists", async () => {
    const bucket = { file: jest.fn(() => ({ exists: jest.fn(async () => [true]) })) };
    expect(await fileExists({ bucket, path: "a" })).toBe(true);
  });

  test("returns false when the file does not exist", async () => {
    const bucket = { file: jest.fn(() => ({ exists: jest.fn(async () => [false]) })) };
    expect(await fileExists({ bucket, path: "a" })).toBe(false);
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd firebase/functions && npm test -- storage.test.js
```

Expected: FAIL — `downloadFile is not a function` / `fileExists is not a function`.

- [ ] **Step 3: Implement the helpers**

In `firebase/functions/src/storage.js`, add these two functions before the final `module.exports` line:

```javascript
/**
 * Download a file's contents as a Buffer.
 * @param {{ bucket, path: string }} opts
 * @returns {Promise<Buffer>}
 */
async function downloadFile({ bucket, path }) {
  const [buffer] = await bucket.file(path).download();
  return buffer;
}

/**
 * Check whether a file exists at the given path.
 * @param {{ bucket, path: string }} opts
 * @returns {Promise<boolean>}
 */
async function fileExists({ bucket, path }) {
  const [exists] = await bucket.file(path).exists();
  return exists;
}
```

Update the `module.exports` line at the bottom of the file from:
```javascript
module.exports = { resizeToWidth, uploadBuffer, uploadBase64Image, moveFile, deletePrefix };
```
to:
```javascript
module.exports = { resizeToWidth, uploadBuffer, uploadBase64Image, moveFile, deletePrefix, downloadFile, fileExists };
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd firebase/functions && npm test -- storage.test.js
```

Expected: PASS, all tests in `storage.test.js` green.

- [ ] **Step 5: Commit**

```bash
git add firebase/functions/src/storage.js firebase/functions/__tests__/storage.test.js
git commit -m "feat(functions): add downloadFile/fileExists storage helpers"
```

---

### Task 3: `resizeDraftImage` Cloud Function

**Files:**
- Create: `firebase/functions/src/resizeDraftImage.js`
- Test: `firebase/functions/__tests__/resizeDraftImage.test.js`
- Modify: `firebase/functions/index.js`

**Interfaces:**
- Consumes: `resizeToWidth({buffer, width}): Promise<Buffer>`, `uploadBuffer({bucket, path, buffer, contentType}): Promise<string>`, `downloadFile({bucket, path}): Promise<Buffer>`, `fileExists({bucket, path}): Promise<boolean>` (all from Task 2 / existing `storage.js`); `db`, `bucket`, `requireAuth` from `./admin`.
- Produces: `resizeDraftImageHandler(req): Promise<{imageUrl: string, imageUrl640: string}>`, exported as the Cloud Function `resizeDraftImage`, callable with `{draftId: string}`. Consumed by Task 4's `DraftsService.resizeDraftImage`.

- [ ] **Step 1: Write the failing test**

Create `firebase/functions/__tests__/resizeDraftImage.test.js`:

```javascript
const { resizeDraftImageHandler } = require("../src/resizeDraftImage");

jest.mock("../src/admin", () => {
  const updates = [];
  let draftExists = true;
  return {
    db: {
      collection: jest.fn(() => ({
        doc: jest.fn((id) => ({
          get: jest.fn(async () => ({ exists: draftExists, id, data: () => ({ status: "pending", step: "text" }) })),
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
    expect(admin.__updates[0].d.step).toBe("image");
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

- [ ] **Step 2: Run test to verify it fails**

```bash
cd firebase/functions && npm test -- resizeDraftImage.test.js
```

Expected: FAIL — `Cannot find module '../src/resizeDraftImage'`.

- [ ] **Step 3: Implement the handler**

Create `firebase/functions/src/resizeDraftImage.js`:

```javascript
const { db, bucket, requireAuth } = require("./admin");
const { resizeToWidth, uploadBuffer, downloadFile, fileExists } = require("./storage");

/**
 * @param {import("firebase-functions/v2/https").CallableRequest} req
 * @returns {Promise<{ imageUrl: string, imageUrl640: string }>}
 */
async function resizeDraftImageHandler(req) {
  requireAuth(req);
  const { draftId } = req.data || {};
  if (!draftId) {
    const { HttpsError } = require("firebase-functions/v2/https");
    throw new HttpsError("invalid-argument", "draftId required");
  }

  const draftRef = db.collection("tale_drafts").doc(draftId);
  const snap = await draftRef.get();
  if (!snap.exists) {
    const { HttpsError } = require("firebase-functions/v2/https");
    throw new HttpsError("not-found", "Draft not found");
  }

  const path1024 = `drafts/${draftId}/image_1024.png`;
  if (!(await fileExists({ bucket, path: path1024 }))) {
    const { HttpsError } = require("firebase-functions/v2/https");
    throw new HttpsError("failed-precondition", "Image not uploaded yet");
  }

  const buffer = await downloadFile({ bucket, path: path1024 });
  const imageUrl = await uploadBuffer({ bucket, path: path1024, buffer, contentType: "image/png" });

  const resized = await resizeToWidth({ buffer, width: 640 });
  const imageUrl640 = await uploadBuffer({
    bucket,
    path: `drafts/${draftId}/image_640.png`,
    buffer: resized,
    contentType: "image/png",
  });

  await draftRef.update({ step: "image", image_url: imageUrl, image_url_640px: imageUrl640 });

  return { imageUrl, imageUrl640 };
}

module.exports = { resizeDraftImageHandler };
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd firebase/functions && npm test -- resizeDraftImage.test.js
```

Expected: PASS, all 5 tests green.

- [ ] **Step 5: Register the callable in `index.js`**

In `firebase/functions/index.js`, add the import alongside the other handler imports:

```javascript
const { resizeDraftImageHandler } = require("./src/resizeDraftImage");
```

Then add the export after the `updateDraftText` export block:

```javascript
exports.resizeDraftImage = onCall(
  { timeoutSeconds: 60, memory: "512MiB", region: "europe-west1", secrets: ["ADMIN_UID"] },
  resizeDraftImageHandler
);
```

- [ ] **Step 6: Run the full backend test suite**

```bash
cd firebase/functions && npm test
```

Expected: PASS, all suites green (existing 43 tests + the 5 new ones from this task + the 3 new ones from Task 2 = 51 total).

- [ ] **Step 7: Commit**

```bash
git add firebase/functions/src/resizeDraftImage.js firebase/functions/__tests__/resizeDraftImage.test.js firebase/functions/index.js
git commit -m "feat(functions): add resizeDraftImage callable for manually uploaded images"
```

---

### Task 4: `DraftsService` — manual draft methods

**Files:**
- Modify: `lib/admin/services/drafts_service.dart`

**Interfaces:**
- Consumes: `FirebaseFirestore.instance`, `FirebaseFunctions.instanceFor(region: 'europe-west1')` (already used in this file); `FirebaseStorage.instance` (new import).
- Produces (all consumed by Task 5's `DraftCreateManualPage`):
  - `Future<String> createManualDraft({required String nameEs, required String descriptionEs, required String specificationsEs, required String nameEn, required String descriptionEn, required String specificationsEn}): Future<String>` — returns the new `draftId`.
  - `Future<void> updateManualDraftText({required String draftId, required String nameEs, required String descriptionEs, required String specificationsEs, required String nameEn, required String descriptionEn, required String specificationsEn})`.
  - `UploadTask uploadDraftImage(String draftId, Uint8List bytes)`.
  - `Future<void> resizeDraftImage(String draftId)`.
  - `UploadTask uploadDraftAudio(String draftId, String lang, Uint8List bytes)`.
  - `Future<void> saveManualDraftAudioUrl({required String draftId, required String lang, required String url, required bool bothLangsPresent})`.

- [ ] **Step 1: Add imports**

At the top of `lib/admin/services/drafts_service.dart`, add these two imports after the existing `cloud_functions` import:

```dart
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
```

(The `cloud_firestore`/`cloud_functions` lines already exist — just add the `dart:typed_data` and `firebase_storage` imports alongside them, keeping imports in that relative order.)

- [ ] **Step 2: Add the manual-draft methods**

In `lib/admin/services/drafts_service.dart`, insert the following methods immediately after the closing brace of `getPublishedTale` (i.e., right before the existing `updateDraftText` method):

```dart
  Future<String> createManualDraft({
    required String nameEs,
    required String descriptionEs,
    required String specificationsEs,
    required String nameEn,
    required String descriptionEn,
    required String specificationsEn,
  }) async {
    final ref = _db.collection('tale_drafts').doc();
    await ref.set({
      'status': 'pending',
      'step': 'text',
      'created_at': FieldValue.serverTimestamp(),
      'decided_at': null,
      'decided_by': null,
      'name_es': nameEs,
      'description_es': descriptionEs,
      'specifications_es': specificationsEs,
      'audio_url_es': '',
      'image_prompt': '',
      'name_en': nameEn,
      'description_en': descriptionEn,
      'specifications_en': specificationsEn,
      'audio_url_en': '',
      'image_url': '',
      'image_url_640px': '',
      'assigned_tale_id': null,
      'retracted_from_tale_id': null,
    });
    return ref.id;
  }

  Future<void> updateManualDraftText({
    required String draftId,
    required String nameEs,
    required String descriptionEs,
    required String specificationsEs,
    required String nameEn,
    required String descriptionEn,
    required String specificationsEn,
  }) async {
    await _db.collection('tale_drafts').doc(draftId).update({
      'name_es': nameEs,
      'description_es': descriptionEs,
      'specifications_es': specificationsEs,
      'name_en': nameEn,
      'description_en': descriptionEn,
      'specifications_en': specificationsEn,
    });
  }

  UploadTask uploadDraftImage(String draftId, Uint8List bytes) {
    final ref = FirebaseStorage.instance.ref('drafts/$draftId/image_1024.png');
    return ref.putData(bytes, SettableMetadata(contentType: 'image/png'));
  }

  Future<void> resizeDraftImage(String draftId) async {
    await _functions.httpsCallable('resizeDraftImage').call({'draftId': draftId});
  }

  UploadTask uploadDraftAudio(String draftId, String lang, Uint8List bytes) {
    final ref = FirebaseStorage.instance.ref('drafts/$draftId/audio_$lang.mp3');
    return ref.putData(bytes, SettableMetadata(contentType: 'audio/mpeg'));
  }

  Future<void> saveManualDraftAudioUrl({
    required String draftId,
    required String lang,
    required String url,
    required bool bothLangsPresent,
  }) async {
    final data = <String, dynamic>{'audio_url_$lang': url};
    if (bothLangsPresent) data['step'] = 'audio';
    await _db.collection('tale_drafts').doc(draftId).update(data);
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
git commit -m "feat(admin): add DraftsService methods for manual draft creation"
```

---

### Task 5: `DraftCreateManualPage` — text section and draft creation

**Files:**
- Create: `lib/admin/drafts/draft_create_manual_page.dart`

**Interfaces:**
- Consumes: `DraftsService.createManualDraft(...)`, `DraftsService.updateManualDraftText(...)`, `DraftsService.streamDraft(String id): Stream<Draft?>` (existing), `Draft` model fields `nameEs/descriptionEs/specificationsEs/nameEn/descriptionEn/specificationsEn/imageUrl/audioUrlEs/audioUrlEn/step` (existing, from `lib/admin/models/draft.dart`).
- Produces: `class DraftCreateManualPage extends StatefulWidget` with constructor `DraftCreateManualPage({Key? key, String? draftId})`. Consumed by Task 7's route registration. Internal state fields `String? _draftId` and `Draft? _draft` are extended by Task 6.

- [ ] **Step 1: Create the file with the text-only form**

Create `lib/admin/drafts/draft_create_manual_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/draft.dart';
import '../services/drafts_service.dart';

class DraftCreateManualPage extends StatefulWidget {
  const DraftCreateManualPage({super.key, this.draftId});
  final String? draftId;

  @override
  State<DraftCreateManualPage> createState() => _DraftCreateManualPageState();
}

class _DraftCreateManualPageState extends State<DraftCreateManualPage> {
  final _service = DraftsService();

  final _nameEsController = TextEditingController();
  final _descriptionEsController = TextEditingController();
  final _specificationsEsController = TextEditingController();
  final _nameEnController = TextEditingController();
  final _descriptionEnController = TextEditingController();
  final _specificationsEnController = TextEditingController();

  String? _draftId;
  Draft? _draft;
  bool _saving = false;
  bool _loadingExisting = false;

  @override
  void initState() {
    super.initState();
    _draftId = widget.draftId;
    if (_draftId != null) {
      _loadingExisting = true;
      _service.streamDraft(_draftId!).listen((draft) {
        if (!mounted || draft == null) return;
        final firstLoad = _draft == null;
        setState(() {
          _draft = draft;
          _loadingExisting = false;
          if (firstLoad) {
            _nameEsController.text = draft.nameEs;
            _descriptionEsController.text = draft.descriptionEs;
            _specificationsEsController.text = draft.specificationsEs;
            _nameEnController.text = draft.nameEn;
            _descriptionEnController.text = draft.descriptionEn;
            _specificationsEnController.text = draft.specificationsEn;
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _nameEsController.dispose();
    _descriptionEsController.dispose();
    _specificationsEsController.dispose();
    _nameEnController.dispose();
    _descriptionEnController.dispose();
    _specificationsEnController.dispose();
    super.dispose();
  }

  int _wordCount(String s) => s.trim().isEmpty ? 0 : s.trim().split(RegExp(r'\s+')).length;

  bool get _textComplete =>
      _nameEsController.text.trim().isNotEmpty &&
      _descriptionEsController.text.trim().isNotEmpty &&
      _specificationsEsController.text.trim().isNotEmpty &&
      _nameEnController.text.trim().isNotEmpty &&
      _descriptionEnController.text.trim().isNotEmpty &&
      _specificationsEnController.text.trim().isNotEmpty;

  Future<void> _save() async {
    if (!_textComplete) return;
    setState(() => _saving = true);
    try {
      if (_draftId == null) {
        final id = await _service.createManualDraft(
          nameEs: _nameEsController.text.trim(),
          descriptionEs: _descriptionEsController.text.trim(),
          specificationsEs: _specificationsEsController.text.trim(),
          nameEn: _nameEnController.text.trim(),
          descriptionEn: _descriptionEnController.text.trim(),
          specificationsEn: _specificationsEnController.text.trim(),
        );
        _draftId = id;
        if (mounted) context.go('/drafts/manual/$id');
      } else {
        await _service.updateManualDraftText(
          draftId: _draftId!,
          nameEs: _nameEsController.text.trim(),
          descriptionEs: _descriptionEsController.text.trim(),
          specificationsEs: _specificationsEsController.text.trim(),
          nameEn: _nameEnController.text.trim(),
          descriptionEn: _descriptionEnController.text.trim(),
          specificationsEn: _specificationsEnController.text.trim(),
        );
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Borrador guardado')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _textField({
    required String label,
    required TextEditingController controller,
    int maxLines = 1,
    bool showWordCount = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            maxLines: maxLines,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: '$label *'),
          ),
          if (showWordCount) ...[
            const SizedBox(height: 4),
            Text('${_wordCount(controller.text)} palabras', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            if (_wordCount(controller.text) > 0 &&
                (_wordCount(controller.text) < 200 || _wordCount(controller.text) > 600))
              const Text('⚠️ Los cuentos existentes tienen 300-500 palabras', style: TextStyle(fontSize: 12, color: Colors.orange)),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingExisting) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear a mano'),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => context.go('/drafts')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Texto — Español', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _textField(label: 'Nombre', controller: _nameEsController),
            _textField(label: 'Descripción', controller: _descriptionEsController, maxLines: 2),
            _textField(label: 'Cuento', controller: _specificationsEsController, maxLines: 10, showWordCount: true),
            const Divider(height: 32),
            const Text('Texto — English', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _textField(label: 'Nombre', controller: _nameEnController),
            _textField(label: 'Descripción', controller: _descriptionEnController, maxLines: 2),
            _textField(label: 'Cuento', controller: _specificationsEnController, maxLines: 10, showWordCount: true),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            onPressed: (_textComplete && !_saving) ? _save : null,
            icon: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save),
            label: Text(_textComplete ? 'Guardar borrador' : 'Completa ambos idiomas para guardar'),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify it compiles**

```bash
flutter analyze lib/admin/drafts/draft_create_manual_page.dart
```

Expected: `No issues found!`. (The file isn't reachable from any route yet — that's fine, `flutter analyze` checks the file in isolation; Task 7 wires the route.)

- [ ] **Step 3: Commit**

```bash
git add lib/admin/drafts/draft_create_manual_page.dart
git commit -m "feat(admin): manual draft creation page — text fields and save"
```

---

### Task 6: `DraftCreateManualPage` — image and audio upload sections

**Files:**
- Modify: `lib/admin/drafts/draft_create_manual_page.dart`

**Interfaces:**
- Consumes: `DraftsService.uploadDraftImage`, `DraftsService.resizeDraftImage`, `DraftsService.uploadDraftAudio`, `DraftsService.saveManualDraftAudioUrl` (all from Task 4); `Draft.imageUrl`, `Draft.audioUrlEs`, `Draft.audioUrlEn`, `Draft.step` (existing model fields); `FilePicker` from `package:file_picker/file_picker.dart` (Task 1).
- Produces: nothing new consumed by later tasks — this completes the page's functionality.

- [ ] **Step 1: Add imports**

In `lib/admin/drafts/draft_create_manual_page.dart`, change the top of the file from:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/draft.dart';
import '../services/drafts_service.dart';
```

to:

```dart
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/draft.dart';
import '../services/drafts_service.dart';
```

- [ ] **Step 2: Add upload state fields**

Add these fields to `_DraftCreateManualPageState`, right after the existing `bool _loadingExisting = false;` line:

```dart
  bool _uploadingImage = false;
  double? _imageUploadProgress;
  bool _uploadingAudioEs = false;
  double? _audioEsProgress;
  bool _uploadingAudioEn = false;
  double? _audioEnProgress;
```

- [ ] **Step 3: Add the upload methods**

Add these two methods to `_DraftCreateManualPageState`, right after the existing `_save` method and before `_textField`:

```dart
  Future<void> _pickAndUploadImage() async {
    if (_draftId == null) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;
    if (file.size > 15 * 1024 * 1024) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La imagen supera los 15MB')));
      return;
    }
    setState(() {
      _uploadingImage = true;
      _imageUploadProgress = 0;
    });
    try {
      final task = _service.uploadDraftImage(_draftId!, bytes);
      task.snapshotEvents.listen((snapshot) {
        if (snapshot.totalBytes > 0 && mounted) {
          setState(() => _imageUploadProgress = snapshot.bytesTransferred / snapshot.totalBytes);
        }
      });
      await task;
      await _service.resizeDraftImage(_draftId!);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Imagen subida')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error subiendo imagen: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _uploadingImage = false;
          _imageUploadProgress = null;
        });
      }
    }
  }

  Future<void> _pickAndUploadAudio(String lang) async {
    if (_draftId == null) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;
    if (file.size > 30 * 1024 * 1024) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El audio supera los 30MB')));
      return;
    }
    setState(() {
      if (lang == 'es') {
        _uploadingAudioEs = true;
        _audioEsProgress = 0;
      } else {
        _uploadingAudioEn = true;
        _audioEnProgress = 0;
      }
    });
    try {
      final task = _service.uploadDraftAudio(_draftId!, lang, bytes);
      task.snapshotEvents.listen((snapshot) {
        if (snapshot.totalBytes > 0 && mounted) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          setState(() {
            if (lang == 'es') {
              _audioEsProgress = progress;
            } else {
              _audioEnProgress = progress;
            }
          });
        }
      });
      await task;
      final url = await task.snapshot.ref.getDownloadURL();
      final otherUrl = lang == 'es' ? (_draft?.audioUrlEn ?? '') : (_draft?.audioUrlEs ?? '');
      await _service.saveManualDraftAudioUrl(
        draftId: _draftId!,
        lang: lang,
        url: url,
        bothLangsPresent: otherUrl.isNotEmpty,
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Audio subido')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error subiendo audio: $e')));
    } finally {
      if (mounted) {
        setState(() {
          if (lang == 'es') {
            _uploadingAudioEs = false;
            _audioEsProgress = null;
          } else {
            _uploadingAudioEn = false;
            _audioEnProgress = null;
          }
        });
      }
    }
  }

```

- [ ] **Step 4: Add the section-builder widgets**

Add these two methods to `_DraftCreateManualPageState`, right after the existing `_textField` method and before `build`:

```dart
  Widget _imageSection() {
    if (_draftId == null) {
      return const Text('Guarda el texto primero para poder subir la imagen.', style: TextStyle(color: Colors.grey));
    }
    final hasImage = _draft?.imageUrl.isNotEmpty ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasImage)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              _draft!.imageUrl,
              height: 200,
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) => Container(
                height: 200,
                color: Colors.grey.shade200,
                child: const Center(child: Icon(Icons.broken_image, size: 48)),
              ),
            ),
          ),
        const SizedBox(height: 8),
        if (_uploadingImage) LinearProgressIndicator(value: _imageUploadProgress),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _uploadingImage ? null : _pickAndUploadImage,
          icon: const Icon(Icons.upload_file),
          label: Text(hasImage ? 'Reemplazar imagen' : 'Subir imagen'),
        ),
      ],
    );
  }

  Widget _audioSection(String lang) {
    final label = lang == 'es' ? 'Audio Español' : 'Audio English';
    final url = lang == 'es' ? (_draft?.audioUrlEs ?? '') : (_draft?.audioUrlEn ?? '');
    final uploading = lang == 'es' ? _uploadingAudioEs : _uploadingAudioEn;
    final progress = lang == 'es' ? _audioEsProgress : _audioEnProgress;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(url.isEmpty ? 'Sin audio' : 'Audio subido ✓', style: const TextStyle(fontSize: 13)),
          if (uploading) ...[
            const SizedBox(height: 4),
            LinearProgressIndicator(value: progress),
          ],
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: (uploading || _draftId == null) ? null : () => _pickAndUploadAudio(lang),
            icon: const Icon(Icons.upload_file),
            label: Text(url.isEmpty ? 'Subir audio' : 'Reemplazar audio'),
          ),
        ],
      ),
    );
  }

```

- [ ] **Step 5: Wire the sections into `build`**

In `lib/admin/drafts/draft_create_manual_page.dart`, change the end of the `Column` inside `body` from:

```dart
            _textField(label: 'Nombre', controller: _nameEnController),
            _textField(label: 'Descripción', controller: _descriptionEnController, maxLines: 2),
            _textField(label: 'Cuento', controller: _specificationsEnController, maxLines: 10, showWordCount: true),
          ],
        ),
      ),
```

to:

```dart
            _textField(label: 'Nombre', controller: _nameEnController),
            _textField(label: 'Descripción', controller: _descriptionEnController, maxLines: 2),
            _textField(label: 'Cuento', controller: _specificationsEnController, maxLines: 10, showWordCount: true),
            const Divider(height: 32),
            const Text('Imagen', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _imageSection(),
            const Divider(height: 32),
            const Text('Audio', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _audioSection('es'),
            _audioSection('en'),
            if (_draft?.step == 'audio')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/drafts/${_draftId!}'),
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Ver borrador completo →'),
                ),
              ),
          ],
        ),
      ),
```

- [ ] **Step 6: Verify it compiles**

```bash
flutter analyze lib/admin/drafts/draft_create_manual_page.dart
```

Expected: `No issues found!`.

- [ ] **Step 7: Commit**

```bash
git add lib/admin/drafts/draft_create_manual_page.dart
git commit -m "feat(admin): manual draft creation page — image and audio uploads"
```

---

### Task 7: Wire the entry point and routes

**Files:**
- Modify: `lib/admin/drafts/drafts_list_page.dart`
- Modify: `lib/admin/app.dart`

**Interfaces:**
- Consumes: `DraftCreateManualPage` (Task 5/6).
- Produces: routes `/drafts/manual` and `/drafts/manual/:id`, reachable from the "Crear a mano" button.

- [ ] **Step 1: Add the "Crear a mano" button**

In `lib/admin/drafts/drafts_list_page.dart`, change:

```dart
              children: [
                FilledButton.icon(
                  onPressed: () => context.go('/drafts/new'),
                  icon: const Icon(Icons.add),
                  label: const Text('Nuevo cuento'),
                ),
                const Spacer(),
```

to:

```dart
              children: [
                FilledButton.icon(
                  onPressed: () => context.go('/drafts/new'),
                  icon: const Icon(Icons.add),
                  label: const Text('Nuevo cuento'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => context.go('/drafts/manual'),
                  icon: const Icon(Icons.edit_note),
                  label: const Text('Crear a mano'),
                ),
                const Spacer(),
```

- [ ] **Step 2: Register the routes**

In `lib/admin/app.dart`, add the import after the existing `draft_create_page.dart` import:

```dart
import 'drafts/draft_create_manual_page.dart';
```

Then change the `/drafts` route block from:

```dart
        GoRoute(
          path: '/drafts',
          builder: (c, s) => const DraftsListPage(),
          routes: [
            GoRoute(path: 'new', builder: (c, s) => const DraftCreatePage()),
            GoRoute(path: ':id', builder: (c, s) => DraftDetailPage(draftId: s.pathParameters['id']!)),
          ],
        ),
```

to:

```dart
        GoRoute(
          path: '/drafts',
          builder: (c, s) => const DraftsListPage(),
          routes: [
            GoRoute(path: 'new', builder: (c, s) => const DraftCreatePage()),
            GoRoute(
              path: 'manual',
              builder: (c, s) => const DraftCreateManualPage(),
              routes: [
                GoRoute(path: ':id', builder: (c, s) => DraftCreateManualPage(draftId: s.pathParameters['id'])),
              ],
            ),
            GoRoute(path: ':id', builder: (c, s) => DraftDetailPage(draftId: s.pathParameters['id']!)),
          ],
        ),
```

- [ ] **Step 3: Verify it compiles**

```bash
flutter analyze lib/admin
```

Expected: only the 5 pre-existing unused-import warnings (`auth/auth_gate.dart`, and the 4 unused imports in `main_admin.dart`) — 0 new issues, 0 errors.

- [ ] **Step 4: Commit**

```bash
git add lib/admin/drafts/drafts_list_page.dart lib/admin/app.dart
git commit -m "feat(admin): wire up manual draft creation entry point and routes"
```

---

### Task 8: End-to-end verification

**Files:** none (verification only).

**Interfaces:** none.

- [ ] **Step 1: Run the full backend test suite**

```bash
cd firebase/functions && npm test
```

Expected: PASS, all suites green (51 tests: the pre-existing 43 + 3 from Task 2 + 5 from Task 3).

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

- [ ] **Step 4: Deploy the new Cloud Function**

```bash
cd firebase && firebase deploy --only functions:resizeDraftImage -P merakitales-5rltbl
```

Expected: deploy succeeds, `resizeDraftImage` appears in the Firebase console function list.

- [ ] **Step 5: Manual walkthrough (requires a human or a connected browser tool — cannot be automated in this repo, which has no Flutter widget-test harness)**

Serve the built admin app and, in a real browser, verify:
1. `/drafts` shows a new "Crear a mano" button next to "Nuevo cuento"
2. Clicking it opens `/drafts/manual` with all 6 text fields empty and "Guardar borrador" disabled
3. Filling all 6 fields enables "Guardar borrador"; clicking it navigates to `/drafts/manual/<id>` and shows a "Borrador guardado" snackbar
4. Reloading `/drafts/manual/<id>` reloads the same page with all 6 fields pre-filled (not the read-only detail page)
5. Uploading a PNG/JPG image shows a progress bar, then a preview, then the draft's `step` becomes `image` (visible in `/drafts` list as "🖼️ Imagen")
6. Uploading a non-image file is rejected with a clear error before any upload starts
7. Uploading both MP3 audio files advances `step` to `audio` (visible in `/drafts` list as "🎵 Audio"), and a "Ver borrador completo →" link appears
8. That link opens `/drafts/<id>` (`draft_detail_page.dart`) with "Aprobar y publicar" enabled
9. Approving publishes the tale; it appears in `/published` with working image and audio links

- [ ] **Step 6: Commit (only if Step 5 surfaced fixes)**

If the manual walkthrough required any code fixes, commit them individually with descriptive messages before considering this plan complete. If no fixes were needed, this step is a no-op — the plan is done as of Task 7's commit.

---

## Self-Review Notes

- **Spec coverage:** every section of `docs/superpowers/specs/2026-07-01-manual-tale-creation-design.md` maps to a task — Arquitectura/Modelo de datos → Task 4; Cloud Functions → Tasks 2-3; UI y componentes → Tasks 5-6; Flujo de datos → Tasks 4-6; Validación y manejo de errores → Task 6 (size/format checks) and Task 5 (text-completeness gating); Testing → Tasks 2, 3, 8.
- **Type consistency checked:** `DraftsService` method names/signatures defined in Task 4 (`createManualDraft`, `updateManualDraftText`, `uploadDraftImage`, `resizeDraftImage`, `uploadDraftAudio`, `saveManualDraftAudioUrl`) match exactly what Tasks 5-6 call. `resizeDraftImageHandler`'s return shape (`{imageUrl, imageUrl640}`) matches the `image_url`/`image_url_640px` Firestore fields the `Draft` model already reads (`lib/admin/models/draft.dart`, unchanged). Route `/drafts/manual/:id` in Task 7 matches the `context.go('/drafts/manual/$id')` call in Task 5.
- **No placeholders:** confirmed no TBD/TODO markers; every step has runnable code or an exact command with expected output.
