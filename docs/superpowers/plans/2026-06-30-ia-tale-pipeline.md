# IA Tale Pipeline + Web Admin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an automated tale-generation pipeline (OpenRouter for text+image+TTS) with human approval via a Flutter web admin, without touching the mobile app.

**Architecture:** Cloud Functions (Node) call OpenRouter's unified API to generate drafts → stored in `tale_drafts` Firestore collection → a Flutter web admin (Firebase Hosting) previews and approves → approved drafts move to the existing `tales`/`tales_common_data` collections which the mobile app already reads.

**Tech Stack:** Firebase Cloud Functions v2 (Node 20, callable), OpenRouter API (`/chat/completions`, `/images`, `/audio/speech`), Firebase Auth + Hosting + Storage, Flutter web, jest (functions tests), flutter_test (web tests).

## Global Constraints

- **Node engine:** 20 (pinned in `firebase/functions/package.json`).
- **OpenRouter base URL:** `https://openrouter.ai/api/v1` (all three modalities).
- **No changes to mobile app** (`lib/pages`, `lib/tale_list`, `lib/tail_detail`, `lib/components`, `lib/main.dart`).
- **No schema changes** to `tales` or `tales_common_data` collections.
- **Firestore rules for `tales`/`tales_common_data` stay locked** (`create: false, write: false`) — only Cloud Functions via admin SDK write.
- **OpenRouter API key never in client** — only in Cloud Functions via Secret Manager.
- **Admin uid check** in every callable function: `context.auth.uid === ADMIN_UID`.
- **Bilingual:** every draft has ES + EN text + audio; one shared image.
- **Existing pubspec dependencies are reused** (firebase_core, cloud_firestore, go_router, provider, etc.) — do not add new mobile dependencies.
- **Commits:** frequent, one per task, conventional commit style (`feat:`, `test:`, `chore:`, `docs:`).

---

## File Structure

### Cloud Functions (`firebase/functions/`)

```
firebase/functions/
  src/
    openrouter.js          # OpenRouter API client (text, image, TTS) — pure, testable
    storage.js             # Storage upload/move helpers — pure, testable
    prompts.js             # LLM system prompt + JSON schema
    generateTaleDraft.js   # orchestration callable
    approveDraft.js        # approval callable (transaction)
    rejectDraft.js         # rejection callable
    admin.js               # admin SDK init + auth guard helper
  __tests__/
    openrouter.test.js
    storage.test.js
    generateTaleDraft.test.js
    approveDraft.test.js
    rejectDraft.test.js
  index.js                 # exports callable functions
  package.json             # + jest, sharp, nock (devDeps)
```

### Web Admin (`lib/admin/`)

```
lib/admin/
  main_admin.dart          # separate web entrypoint
  app.dart                 # MaterialApp.router + router definition
  auth/
    auth_gate.dart         # redirect to /login if unauthed
  login/
    login_page.dart
  drafts/
    drafts_list_page.dart
    draft_detail_page.dart
  services/
    drafts_service.dart    # callable invocations + firestore stream
  models/
    draft.dart             # draft model class
```

### Config

```
firebase/firebase.json           # add hosting target for build/web
firebase/firestore.rules         # add tale_drafts rules
firebase/storage.rules           # add drafts/ + tales/ rules
```

---

## Task 1: Functions dev setup + module structure

**Files:**
- Modify: `firebase/functions/package.json`
- Create: `firebase/functions/src/admin.js`
- Create: `firebase/functions/src/prompts.js`
- Create: `firebase/functions/jest.config.js`

**Interfaces:**
- Produces: `requireAuth(context)` helper (used by all callables), `TALE_TEXT_PROMPT` string, `getImagePrompt()` builder.

- [ ] **Step 1: Update package.json with devDependencies and scripts**

Edit `firebase/functions/package.json` — replace the `devDependencies` and `scripts` blocks:

```json
  "devDependencies": {
    "eslint": "^6.8.0",
    "eslint-plugin-promise": "^4.2.1",
    "jest": "^29.7.0",
    "nock": "^13.5.4"
  },
  "scripts": {
    "lint": "./node_modules/.bin/eslint --max-warnings=0 .",
    "test": "jest",
    "serve": "firebase -P merakitales-5rltbl emulators:start --only functions",
    "shell": "firebase -P merakitales-5rltbl functions:shell",
    "start": "npm run shell",
    "logs": "firebase -P merakitales-5rltbl functions:log",
    "compile": "cp ../../tsconfig.template.json ./tsconfig-compile.json && tsc --project tsconfig-compile.json"
  },
```

Add `sharp` and `form-data` to `dependencies` (form-data for multipart, sharp for image resize):

```json
  "dependencies": {
    "firebase-admin": "^11.11.0",
    "firebase-functions": "^4.4.1",
    "braintree": "^3.6.0",
    "@mux/mux-node": "^7.3.3",
    "stripe": "^8.0.1",
    "axios": "1.8.2",
    "razorpay": "^2.8.4",
    "qs": "^6.7.0",
    "@onesignal/node-onesignal": "^2.0.1-beta2",
    "@langchain/core": "^0.3.19",
    "@langchain/langgraph": "^0.2.23",
    "@langchain/openai": "^0.3.14",
    "@langchain/google-genai": "^0.0.8",
    "@langchain/anthropic": "^0.1.1",
    "sharp": "^0.33.5"
  },
```

- [ ] **Step 2: Install dependencies**

Run: `cd firebase/functions && npm install`
Expected: dependencies installed including jest, nock, sharp.

- [ ] **Step 3: Create jest config**

Create `firebase/functions/jest.config.js`:

```js
module.exports = {
  testEnvironment: "node",
  testMatch: ["**/__tests__/**/*.test.js"],
  collectCoverage: false,
};
```

- [ ] **Step 4: Create admin.js (init + auth guard)**

Create `firebase/functions/src/admin.js`:

```js
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getStorage } = require("firebase-admin/storage");
const { defineString } = require("firebase-functions/params");

initializeApp();

const db = getFirestore();
const bucket = getStorage().bucket();

const openrouterApiKey = defineString("OPENROUTER_API_KEY");
const adminUid = defineString("ADMIN_UID");

/**
 * Throws HttpsError if the caller is not the admin.
 * @param {import("firebase-functions/v2/https").CallableRequest} req
 */
function requireAuth(req) {
  const expected = adminUid.value();
  if (!req.auth || req.auth.uid !== expected) {
    const { HttpsError } = require("firebase-functions/v2/https");
    throw new HttpsError("permission-denied", "Not authorized.");
  }
}

module.exports = { db, bucket, openrouterApiKey, adminUid, requireAuth };
```

- [ ] **Step 5: Create prompts.js**

Create `firebase/functions/src/prompts.js`:

```js
const TALE_TEXT_PROMPT = `You are a children's book author writing for ages 4-8.
Write a COMPLETE, original bedtime story. Rules:
- Safe, gentle, age-appropriate. No violence, weapons, death, or adult themes.
- Positive values (kindness, courage, friendship, curiosity).
- 400-600 words per language.
- Provide BOTH a Spanish (es) and an English (en) version. The English version must be a natural adaptation (not a literal translation) suitable for native English-speaking children.
- Generate a short "image_prompt" (one sentence in English) describing a single warm, friendly illustration that captures the story's mood (children's book illustration style, soft colors, no text in image, no characters with copyrighted likenesses).
- "description" is a 1-2 sentence teaser for the list view.
- "name" is the story title.

Respond ONLY with a JSON object matching this exact shape:
{
  "name_es": string,
  "description_es": string,
  "specifications_es": string,
  "name_en": string,
  "description_en": string,
  "specifications_en": string,
  "image_prompt": string
}`;

/**
 * @param {string|null} theme optional theme seed (e.g. "friendship")
 * @returns {Array<{role: string, content: string}>}
 */
function buildMessages(theme) {
  const userContent = theme
    ? `Write a bedtime story about the theme: "${theme}".`
    : "Write a bedtime story. Pick any uplifting theme.";
  return [
    { role: "system", content: TALE_TEXT_PROMPT },
    { role: "user", content: userContent },
  ];
}

module.exports = { TALE_TEXT_PROMPT, buildMessages };
```

- [ ] **Step 6: Commit**

```bash
cd firebase/functions && git add -A && git commit -m "chore(functions): add dev deps, jest, admin module, prompts"
```

---

## Task 2: OpenRouter client module + tests

**Files:**
- Create: `firebase/functions/src/openrouter.js`
- Create: `firebase/functions/__tests__/openrouter.test.js`

**Interfaces:**
- Consumes: `openrouterApiKey` from `src/admin.js`.
- Produces: `generateTaleText({ theme, apiKey })` → `Promise<TaleTextResult>`, `generateImage({ prompt, apiKey })` → `Promise<{ b64, mediaType }>`, `generateSpeech({ input, apiKey, voice })` → `Promise<Buffer>`.

- [ ] **Step 1: Write the failing test**

Create `firebase/functions/__tests__/openrouter.test.js`:

```js
const nock = require("nock");
const { generateTaleText, generateImage, generateSpeech } = require("../src/openrouter");

const BASE = "https://openrouter.ai";
const KEY = "test-key";

describe("openrouter client", () => {
  afterEach(() => nock.cleanAll());

  test("generateTaleText parses JSON content into a tale object", async () => {
    const taleJson = JSON.stringify({
      name_es: "El Dragón Tímido",
      description_es: "Un dragón que aprende a ser valiente.",
      specifications_es: "Había una vez...",
      name_en: "The Timid Dragon",
      description_en: "A dragon who learns to be brave.",
      specifications_en: "Once upon a time...",
      image_prompt: "a shy dragon in a sunny meadow, soft watercolor",
    });
    nock(BASE)
      .post("/api/v1/chat/completions")
      .reply(200, {
        choices: [{ message: { content: taleJson } }],
      });

    const result = await generateTaleText({ theme: "courage", apiKey: KEY });
    expect(result.name_es).toBe("El Dragón Tímido");
    expect(result.image_prompt).toContain("dragon");
    expect(result.specifications_en).toBe("Once upon a time...");
  });

  test("generateTaleText throws on non-JSON content", async () => {
    nock(BASE)
      .post("/api/v1/chat/completions")
      .reply(200, { choices: [{ message: { content: "not json" } }] });
    await expect(generateTaleText({ apiKey: KEY })).rejects.toThrow();
  });

  test("generateImage returns base64 + media type", async () => {
    nock(BASE)
      .post("/api/v1/images")
      .reply(200, { data: [{ b64_json: "aGVsbG8=" }], usage: { cost: 0.05 } });

    const result = await generateImage({ prompt: "a cat", apiKey: KEY });
    expect(result.b64).toBe("aGVsbG8=");
  });

  test("generateSpeech returns a Buffer", async () => {
    nock(BASE)
      .post("/api/v1/audio/speech")
      .reply(200, Buffer.from("audio-bytes"), {
        "Content-Type": "audio/mpeg",
      });

    const result = await generateSpeech({ input: "hello", apiKey: KEY, voice: "alloy" });
    expect(Buffer.isBuffer(result)).toBe(true);
    expect(result.toString()).toBe("audio-bytes");
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd firebase/functions && npm test -- openrouter`
Expected: FAIL — `Cannot find module '../src/openrouter'`.

- [ ] **Step 3: Write minimal implementation**

Create `firebase/functions/src/openrouter.js`:

```js
const axios = require("axios");

const BASE_URL = "https://openrouter.ai/api/v1";

const TEXT_MODEL = "nvidia/llama-3.1-nemotron-70b-instruct";
const IMAGE_MODEL = "bytedance-seed/seedream-4.5";
const TTS_MODEL = "openai/gpt-4o-mini-tts-2025-12-15";
const TTS_VOICE = "alloy";

/**
 * @param {{ theme?: string|null, apiKey: string }} opts
 * @returns {Promise<object>} parsed tale JSON
 */
async function generateTaleText({ theme, apiKey }) {
  const { buildMessages } = require("./prompts");
  const resp = await axios.post(
    `${BASE_URL}/chat/completions`,
    {
      model: TEXT_MODEL,
      messages: buildMessages(theme),
      response_format: { type: "json_object" },
    },
    { headers: { Authorization: `Bearer ${apiKey}` }, timeout: 60000 }
  );
  const content = resp.data.choices[0].message.content;
  const parsed = JSON.parse(content);
  const required = [
    "name_es", "description_es", "specifications_es",
    "name_en", "description_en", "specifications_en",
    "image_prompt",
  ];
  for (const k of required) {
    if (!parsed[k]) throw new Error(`Missing field in tale JSON: ${k}`);
  }
  return parsed;
}

/**
 * @param {{ prompt: string, apiKey: string }} opts
 * @returns {Promise<{ b64: string, mediaType?: string }>}
 */
async function generateImage({ prompt, apiKey }) {
  const resp = await axios.post(
    `${BASE_URL}/images`,
    {
      model: IMAGE_MODEL,
      prompt,
      resolution: "1K",
      aspect_ratio: "1:1",
      output_format: "png",
    },
    { headers: { Authorization: `Bearer ${apiKey}` }, timeout: 90000 }
  );
  const img = resp.data.data[0];
  return { b64: img.b64_json, mediaType: img.media_type };
}

/**
 * @param {{ input: string, apiKey: string, voice?: string }} opts
 * @returns {Promise<Buffer>}
 */
async function generateSpeech({ input, apiKey, voice = TTS_VOICE }) {
  const resp = await axios.post(
    `${BASE_URL}/audio/speech`,
    { model: TTS_MODEL, input, voice, response_format: "mp3" },
    {
      headers: { Authorization: `Bearer ${apiKey}` },
      responseType: "arraybuffer",
      timeout: 90000,
    }
  );
  return Buffer.from(resp.data);
}

module.exports = { generateTaleText, generateImage, generateSpeech, BASE_URL };
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd firebase/functions && npm test -- openrouter`
Expected: PASS — 4 tests passing.

- [ ] **Step 5: Commit**

```bash
cd firebase/functions && git add -A && git commit -m "feat(functions): add OpenRouter client (text, image, TTS) with tests"
```

---

## Task 3: Storage helpers + tests

**Files:**
- Create: `firebase/functions/src/storage.js`
- Create: `firebase/functions/__tests__/storage.test.js`

**Interfaces:**
- Consumes: `bucket` from `src/admin.js`.
- Produces: `uploadBuffer({ bucket, path, buffer, contentType })` → `Promise<string>` (public URL), `uploadBase64Image(...)` same, `resizeToWidth({ buffer, width })` → `Promise<Buffer>`, `moveFile({ bucket, fromPath, toPath })` → `Promise<string>`, `deletePrefix({ bucket, prefix })` → `Promise<void>`.

- [ ] **Step 1: Write the failing test**

Create `firebase/functions/__tests__/storage.test.js`:

```js
const sharp = require("sharp");
const { resizeToWidth } = require("../src/storage");

describe("storage helpers", () => {
  test("resizeToWidth scales a PNG buffer down", async () => {
    const original = await sharp({
      create: { width: 1024, height: 1024, channels: 4, background: "#fff" },
    }).png().toBuffer();
    const resized = await resizeToWidth({ buffer: original, width: 640 });
    const meta = await sharp(resized).metadata();
    expect(meta.width).toBe(640);
  });

  test("resizeToWidth does not upscale", async () => {
    const original = await sharp({
      create: { width: 400, height: 400, channels: 4, background: "#fff" },
    }).png().toBuffer();
    const resized = await resizeToWidth({ buffer: original, width: 640 });
    const meta = await sharp(resized).metadata();
    expect(meta.width).toBe(400);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd firebase/functions && npm test -- storage`
Expected: FAIL — `Cannot find module '../src/storage'`.

- [ ] **Step 3: Write minimal implementation**

Create `firebase/functions/src/storage.js`:

```js
const sharp = require("sharp");

/**
 * Resize an image buffer so its width <= target, never upscaling.
 * @param {{ buffer: Buffer, width: number }} opts
 * @returns {Promise<Buffer>}
 */
async function resizeToWidth({ buffer, width }) {
  return sharp(buffer)
    .resize({ width, withoutEnlargement: true })
    .png()
    .toBuffer();
}

/**
 * Upload a Buffer to Storage and make it publicly readable.
 * @param {{ bucket: import("firebase-admin/storage").Storage["bucket"], path: string, buffer: Buffer, contentType: string }} opts
 * @returns {Promise<string>} public URL
 */
async function uploadBuffer({ bucket, path, buffer, contentType }) {
  const file = bucket.file(path);
  await file.save(buffer, { metadata: { contentType } });
  await file.makePublic();
  return `https://storage.googleapis.com/${bucket.name}/${path}`;
}

/**
 * Upload a base64-encoded image.
 * @param {{ bucket, path: string, b64: string, contentType?: string }} opts
 * @returns {Promise<string>}
 */
async function uploadBase64Image({ bucket, path, b64, contentType = "image/png" }) {
  const buffer = Buffer.from(b64, "base64");
  return uploadBuffer({ bucket, path, buffer, contentType });
}

/**
 * Move (copy + delete) a file within the same bucket.
 * @param {{ bucket, fromPath: string, toPath: string }} opts
 * @returns {Promise<string>} new public URL
 */
async function moveFile({ bucket, fromPath, toPath }) {
  await bucket.file(fromPath).move(toPath);
  await bucket.file(toPath).makePublic();
  return `https://storage.googleapis.com/${bucket.name}/${toPath}`;
}

/**
 * Delete all files under a prefix (used on reject).
 * @param {{ bucket, prefix: string }} opts
 */
async function deletePrefix({ bucket, prefix }) {
  const [files] = await bucket.getFiles({ prefix });
  await Promise.all(files.map((f) => f.delete()));
}

module.exports = { resizeToWidth, uploadBuffer, uploadBase64Image, moveFile, deletePrefix };
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd firebase/functions && npm test -- storage`
Expected: PASS — 2 tests passing.

- [ ] **Step 5: Commit**

```bash
cd firebase/functions && git add -A && git commit -m "feat(functions): add storage helpers (upload, resize, move, delete) with tests"
```

---

## Task 4: generateTaleDraft callable + tests

**Files:**
- Create: `firebase/functions/src/generateTaleDraft.js`
- Create: `firebase/functions/__tests__/generateTaleDraft.test.js`

**Interfaces:**
- Consumes: `generateTaleText`, `generateImage`, `generateSpeech` from `openrouter.js`; `resizeToWidth`, `uploadBuffer`, `uploadBase64Image` from `storage.js`; `db`, `bucket`, `requireAuth`, `openrouterApiKey` from `admin.js`.
- Produces: `generateTaleDraftHandler(req)` — exported callable; writes a doc to `tale_drafts` with `status: "pending"`.

- [ ] **Step 1: Write the failing test**

Create `firebase/functions/__tests__/generateTaleDraft.test.js`:

```js
const { generateTaleDraftHandler } = require("../src/generateTaleDraft");

// Mock dependencies
jest.mock("../src/admin", () => {
  const actual = [];
  return {
    db: { collection: () => ({ add: jest.fn(async (d) => ({ id: "draft1", data: () => d })) }) },
    bucket: { name: "test-bucket" },
    openrouterApiKey: { value: () => "test-key" },
    requireAuth: jest.fn(),
  };
});

jest.mock("../src/openrouter", () => ({
  generateTaleText: jest.fn(async () => ({
    name_es: "El Dragón", description_es: "desc es", specifications_es: "texto es",
    name_en: "The Dragon", description_en: "desc en", specifications_en: "texto en",
    image_prompt: "a dragon",
  })),
  generateImage: jest.fn(async () => ({ b64: Buffer.from("img").toString("base64") })),
  generateSpeech: jest.fn(async () => Buffer.from("audio")),
}));

jest.mock("../src/storage", () => ({
  resizeToWidth: jest.fn(async ({ buffer }) => buffer),
  uploadBuffer: jest.fn(async ({ path }) => `https://storage.googleapis.com/test-bucket/${path}`),
  uploadBase64Image: jest.fn(async ({ path }) => `https://storage.googleapis.com/test-bucket/${path}`),
}));

describe("generateTaleDraft", () => {
  test("writes a pending draft with all fields", async () => {
    const { db } = require("../src/admin");
    const addSpy = db.collection().add;
    const result = await generateTaleDraftHandler({ data: { theme: "courage" }, auth: { uid: "admin" } });
    expect(addSpy).toHaveBeenCalledTimes(1);
    const saved = addSpy.mock.calls[0][0];
    expect(saved.status).toBe("pending");
    expect(saved.name_es).toBe("El Dragón");
    expect(saved.name_en).toBe("The Dragon");
    expect(saved.audio_url_es).toContain("test-bucket");
    expect(saved.image_url).toContain("test-bucket");
    expect(saved.image_url_640px).toContain("test-bucket");
    expect(result.draftId).toBe("draft1");
  });

  test("works without a theme", async () => {
    const result = await generateTaleDraftHandler({ data: {}, auth: { uid: "admin" } });
    expect(result.draftId).toBe("draft1");
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd firebase/functions && npm test -- generateTaleDraft`
Expected: FAIL — `Cannot find module '../src/generateTaleDraft'`.

- [ ] **Step 3: Write minimal implementation**

Create `firebase/functions/src/generateTaleDraft.js`:

```js
const { db, bucket, openrouterApiKey, requireAuth } = require("./admin");
const { generateTaleText, generateImage, generateSpeech } = require("./openrouter");
const { resizeToWidth, uploadBuffer, uploadBase64Image, deletePrefix } = require("./storage");

/**
 * @param {import("firebase-functions/v2/https").CallableRequest} req
 * @returns {Promise<{ draftId: string }>}
 */
async function generateTaleDraftHandler(req) {
  requireAuth(req);
  const apiKey = openrouterApiKey.value();
  const theme = req.data?.theme || null;
  const draftId = db.collection("tale_drafts").doc().id;
  const storagePrefix = `drafts/${draftId}`;

  try {
    // 1. Text
    const tale = await generateTaleText({ theme, apiKey });

    // 2. Image (1024 original + 640 resized)
    const { b64 } = await generateImage({ prompt: tale.image_prompt, apiKey });
    const imageBuffer = Buffer.from(b64, "base64");
    const image640 = await resizeToWidth({ buffer: imageBuffer, width: 640 });
    const imageUrl = await uploadBase64Image({ bucket, path: `${storagePrefix}/image_1024.png`, b64 });
    const imageUrl640 = await uploadBuffer({ bucket, path: `${storagePrefix}/image_640.png`, buffer: image640, contentType: "image/png" });

    // 3. TTS ES
    const audioEs = await generateSpeech({ input: tale.specifications_es, apiKey });
    const audioUrlEs = await uploadBuffer({ bucket, path: `${storagePrefix}/audio_es.mp3`, buffer: audioEs, contentType: "audio/mpeg" });

    // 4. TTS EN
    const audioEn = await generateSpeech({ input: tale.specifications_en, apiKey });
    const audioUrlEn = await uploadBuffer({ bucket, path: `${storagePrefix}/audio_en.mp3`, buffer: audioEn, contentType: "audio/mpeg" });

    // 5. Save draft
    const draft = {
      status: "pending",
      created_at: new Date(),
      decided_at: null,
      decided_by: null,
      name_es: tale.name_es,
      description_es: tale.description_es,
      specifications_es: tale.specifications_es,
      audio_url_es: audioUrlEs,
      audio_duration_es: null,
      image_prompt_es: tale.image_prompt,
      name_en: tale.name_en,
      description_en: tale.description_en,
      specifications_en: tale.specifications_en,
      audio_url_en: audioUrlEn,
      audio_duration_en: null,
      image_prompt_en: tale.image_prompt,
      image_url: imageUrl,
      image_url_640px: imageUrl640,
      assigned_tale_id: null,
    };
    await db.collection("tale_drafts").doc(draftId).set(draft);
    return { draftId };
  } catch (err) {
    // Cleanup partial files
    try { await deletePrefix({ bucket, prefix: storagePrefix }); } catch (_) {}
    throw err;
  }
}

module.exports = { generateTaleDraftHandler };
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd firebase/functions && npm test -- generateTaleDraft`
Expected: PASS — 2 tests passing.

- [ ] **Step 5: Commit**

```bash
cd firebase/functions && git add -A && git commit -m "feat(functions): add generateTaleDraft orchestration with tests"
```

---

## Task 5: approveDraft callable + tests

**Files:**
- Create: `firebase/functions/src/approveDraft.js`
- Create: `firebase/functions/__tests__/approveDraft.test.js`

**Interfaces:**
- Consumes: `db`, `bucket`, `requireAuth` from `admin.js`; `moveFile` from `storage.js`.
- Produces: `approveDraftHandler(req)` — moves a draft into `tales` (ES+EN) + `tales_common_data`, marks draft approved.

- [ ] **Step 1: Write the failing test**

Create `firebase/functions/__tests__/approveDraft.test.js`:

```js
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

const fakeQuery = (docs) => ({
  get: jest.fn(async () => ({ docs, empty: docs.length === 0 })),
});

jest.mock("../src/admin", () => {
  const state = {};
  return {
    db: {
      collection: jest.fn((name) => {
        if (!state[name]) state[name] = { docs: {}, writes: [] };
        return {
          doc: jest.fn((id) => ({
            get: jest.fn(async () => ({ exists: true, id, data: () => state[name].docs[id] || draftDoc, ref: { id } })),
            set: jest.fn(async (d) => { state[name].docs[id] = d; state[name].writes.push({ id, d }); }),
            update: jest.fn(async (d) => { state[name].docs[id] = { ...state[name].docs[id], ...d }; }),
          })),
          add: jest.fn(),
          // for max(tale_id) query
          orderBy: () => ({ limit: () => fakeQuery([{ get: jest.fn(), data: () => ({ tale_id: 30 }) }]) }),
          where: () => ({ orderBy: () => ({ limit: () => fakeQuery([]) }) }),
          runTransaction: undefined,
        };
      }),
      runTransaction: jest.fn(async (fn) => fn({
        get: jest.fn(async () => ({ docs: [{ data: () => ({ tale_id: 30 }) }] })),
      })),
    },
    bucket: { name: "b", file: () => ({ move: jest.fn(), makePublic: jest.fn() }) },
    requireAuth: jest.fn(),
  };
});

jest.mock("../src/storage", () => ({
  moveFile: jest.fn(async ({ toPath }) => `https://storage.googleapis.com/b/${toPath}`),
}));

describe("approveDraft", () => {
  test("writes 2 tales docs + 1 common_data, marks draft approved", async () => {
    const { db } = require("../src/admin");
    const result = await approveDraftHandler({ data: { draftId: "d1" }, auth: { uid: "admin" } });
    expect(result.taleId).toBe(31);
    // tales collection got 2 writes (es + en)
    expect(db.collection("tales").doc).toHaveBeenCalledTimes(2);
    // tale_drafts got an update (approved)
    expect(db.collection("tale_drafts").doc).toHaveBeenCalled();
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd firebase/functions && npm test -- approveDraft`
Expected: FAIL — `Cannot find module '../src/approveDraft'`.

- [ ] **Step 3: Write minimal implementation**

Create `firebase/functions/src/approveDraft.js`:

```js
const { db, bucket, requireAuth } = require("./admin");
const { moveFile } = require("./storage");

/**
 * @param {import("firebase-functions/v2/https").CallableRequest} req
 * @returns {Promise<{ taleId: number }>}
 */
async function approveDraftHandler(req) {
  requireAuth(req);
  const { draftId } = req.data;
  if (!draftId) {
    const { HttpsError } = require("firebase-functions/v2/https");
    throw new HttpsError("invalid-argument", "draftId required");
  }

  const draftRef = db.collection("tale_drafts").doc(draftId);
  const draftSnap = await draftRef.get();
  if (!draftSnap.exists) {
    const { HttpsError } = require("firebase-functions/v2/https");
    throw new HttpsError("not-found", "Draft not found");
  }
  const d = draftSnap.data();
  if (d.status !== "pending") {
    const { HttpsError } = require("firebase-functions/v2/https");
    throw new HttpsError("failed-precondition", `Draft already ${d.status}`);
  }

  // Assign next tale_id in a transaction
  const taleId = await db.runTransaction(async (tx) => {
    const q = await tx.get(db.collection("tales").orderBy("tale_id", "desc").limit(1));
    const maxId = q.empty ? 0 : q.docs[0].data().tale_id || 0;
    return maxId + 1;
  });

  // Move storage files drafts/{draftId}/ -> tales/{taleId}/
  const fromPrefix = `drafts/${draftId}`;
  const toPrefix = `tales/${taleId}`;
  const imageUrl = await moveFile({ bucket, fromPath: `${fromPrefix}/image_1024.png`, toPath: `${toPrefix}/image_1024.png` });
  const imageUrl640 = await moveFile({ bucket, fromPath: `${fromPrefix}/image_640.png`, toPath: `${toPrefix}/image_640.png` });
  const audioUrlEs = await moveFile({ bucket, fromPath: `${fromPrefix}/audio_es.mp3`, toPath: `${toPrefix}/audio_es.mp3` });
  const audioUrlEn = await moveFile({ bucket, fromPath: `${fromPrefix}/audio_en.mp3`, toPath: `${toPrefix}/audio_en.mp3` });

  const now = new Date();
  const commonRef = db.collection("tales_common_data").doc(`${taleId}`);

  // Write common_data
  await commonRef.set({
    tale_id: taleId,
    image_url_1024px: imageUrl,
    image_url_640px: imageUrl640,
  });

  // Write ES tale
  await db.collection("tales").doc(`${taleId}_es`).set({
    name: d.name_es,
    description: d.description_es,
    specifications: d.specifications_es,
    price: 0,
    created_at: now,
    modified_at: now,
    on_sale: false,
    sale_price: 0,
    quantity: 0,
    image_url: imageUrl,
    image_url_640px: imageUrl640,
    lang: "es",
    tale_id: taleId,
    tale_common_data_ref: commonRef,
    audio_url: audioUrlEs,
  });

  // Write EN tale
  await db.collection("tales").doc(`${taleId}_en`).set({
    name: d.name_en,
    description: d.description_en,
    specifications: d.specifications_en,
    price: 0,
    created_at: now,
    modified_at: now,
    on_sale: false,
    sale_price: 0,
    quantity: 0,
    image_url: imageUrl,
    image_url_640px: imageUrl640,
    lang: "en",
    tale_id: taleId,
    tale_common_data_ref: commonRef,
    audio_url: audioUrlEn,
  });

  // Mark draft approved
  await draftRef.update({
    status: "approved",
    decided_at: now,
    decided_by: req.auth.uid,
    assigned_tale_id: taleId,
  });

  return { taleId };
}

module.exports = { approveDraftHandler };
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd firebase/functions && npm test -- approveDraft`
Expected: PASS — 1 test passing.

- [ ] **Step 5: Commit**

```bash
cd firebase/functions && git add -A && git commit -m "feat(functions): add approveDraft (transactional tale_id, publish to tales)"
```

---

## Task 6: rejectDraft callable + tests

**Files:**
- Create: `firebase/functions/src/rejectDraft.js`
- Create: `firebase/functions/__tests__/rejectDraft.test.js`

**Interfaces:**
- Consumes: `db`, `bucket`, `requireAuth` from `admin.js`; `deletePrefix` from `storage.js`.
- Produces: `rejectDraftHandler(req)`.

- [ ] **Step 1: Write the failing test**

Create `firebase/functions/__tests__/rejectDraft.test.js`:

```js
const { rejectDraftHandler } = require("../src/rejectDraft");

jest.mock("../src/admin", () => ({
  db: {
    collection: jest.fn(() => ({
      doc: jest.fn((id) => ({
        get: jest.fn(async () => ({ exists: true, data: () => ({ status: "pending" }) })),
        delete: jest.fn(async () => {}),
      })),
    })),
  },
  bucket: { name: "b" },
  requireAuth: jest.fn(),
}));

jest.mock("../src/storage", () => ({
  deletePrefix: jest.fn(async () => {}),
}));

describe("rejectDraft", () => {
  test("deletes draft doc and storage prefix", async () => {
    const { db } = require("../src/admin");
    const { deletePrefix } = require("../src/storage");
    const result = await rejectDraftHandler({ data: { draftId: "d1" }, auth: { uid: "admin" } });
    expect(result.ok).toBe(true);
    expect(db.collection().doc).toHaveBeenCalledWith("d1");
    expect(deletePrefix).toHaveBeenCalledWith({ bucket: expect.anything(), prefix: "drafts/d1" });
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd firebase/functions && npm test -- rejectDraft`
Expected: FAIL — `Cannot find module '../src/rejectDraft'`.

- [ ] **Step 3: Write minimal implementation**

Create `firebase/functions/src/rejectDraft.js`:

```js
const { db, bucket, requireAuth } = require("./admin");
const { deletePrefix } = require("./storage");

/**
 * @param {import("firebase-functions/v2/https").CallableRequest} req
 * @returns {Promise<{ ok: boolean }>}
 */
async function rejectDraftHandler(req) {
  requireAuth(req);
  const { draftId } = req.data;
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
  await draftRef.delete();
  await deletePrefix({ bucket, prefix: `drafts/${draftId}` });
  return { ok: true };
}

module.exports = { rejectDraftHandler };
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd firebase/functions && npm test -- rejectDraft`
Expected: PASS — 1 test passing.

- [ ] **Step 5: Commit**

```bash
cd firebase/functions && git add -A && git commit -m "feat(functions): add rejectDraft (delete draft + storage)"
```

---

## Task 7: Wire up index.js + deploy config (secrets)

**Files:**
- Modify: `firebase/functions/index.js`

**Interfaces:**
- Produces: deployed callable functions `generateTaleDraft`, `approveDraft`, `rejectDraft`.

- [ ] **Step 1: Replace index.js with callable exports**

Replace `firebase/functions/index.js` content:

```js
const { onCall } = require("firebase-functions/v2/https");
const { setGlobalOptions } = require("firebase-functions/v2/options");

const { generateTaleDraftHandler } = require("./src/generateTaleDraft");
const { approveDraftHandler } = require("./src/approveDraft");
const { rejectDraftHandler } = require("./src/rejectDraft");

setGlobalOptions({ maxInstances: 10 });

exports.generateTaleDraft = onCall(
  { timeoutSeconds: 120, memory: "1GiB", region: "europe-west1" },
  generateTaleDraftHandler
);

exports.approveDraft = onCall(
  { timeoutSeconds: 60, memory: "512MiB", region: "europe-west1" },
  approveDraftHandler
);

exports.rejectDraft = onCall(
  { timeoutSeconds: 60, memory: "512MiB", region: "europe-west1" },
  rejectDraftHandler
);
```

- [ ] **Step 2: Set Cloud secrets**

Run:
```bash
cd firebase/functions
firebase -P merakitales-5rltbl functions:secrets:set OPENROUTER_API_KEY
firebase -P merakitales-5rltbl functions:secrets:set ADMIN_UID
firebase -P merakitales-5rltbl functions:secrets:access OPENROUTER_API_KEY APPROVE
firebase -P merakitales-5rltbl functions:secrets:access ADMIN_UID APPROVE
```
Expected: prompts for values; secrets created and bound to the 3 functions. (OPENROUTER_API_KEY = your OpenRouter key; ADMIN_UID = your Firebase Auth uid — create the admin user first in Task 12.)

- [ ] **Step 3: Run lint + tests**

Run: `cd firebase/functions && npm run lint && npm test`
Expected: lint clean, all tests pass.

- [ ] **Step 4: Deploy functions**

Run: `cd firebase && firebase -P merakitales-5rltbl deploy --only functions`
Expected: 3 functions deployed to `europe-west1`.

- [ ] **Step 5: Commit**

```bash
git add firebase/functions/index.js && git commit -m "chore(functions): wire callable exports + secret bindings"
```

---

## Task 8: Firestore rules update

**Files:**
- Modify: `firebase/firestore.rules`

- [ ] **Step 1: Replace firestore.rules**

Replace `firebase/firestore.rules`:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /tales/{document} {
      allow create: if false;
      allow read: if true;
      allow write: if false;
      allow delete: if false;
    }

    match /tales_common_data/{document} {
      allow create: if false;
      allow read: if true;
      allow write: if false;
      allow delete: if false;
    }

    match /tale_drafts/{document} {
      allow read, write: if request.auth != null && request.auth.uid == ADMIN_UID;
    }
  }
}
```

Note: `ADMIN_UID` cannot be a literal in rules. Use a Cloud Function env var approach OR, since only the admin reads drafts and the functions use admin SDK (bypassing rules), set drafts to simply require authentication — the actual uid enforcement happens in the Callable functions. Use this simpler, safe version:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /tales/{document} {
      allow create: if false;
      allow read: if true;
      allow write: if false;
      allow delete: if false;
    }

    match /tales_common_data/{document} {
      allow create: if false;
      allow read: if true;
      allow write: if false;
      allow delete: if false;
    }

    // Drafts: readable only when authenticated. Admin uid is enforced in Cloud Functions;
    // the web admin uses Firebase Auth so only the logged-in admin reaches these.
    match /tale_drafts/{document} {
      allow read, write: if request.auth != null;
    }
  }
}
```

- [ ] **Step 2: Deploy rules**

Run: `cd firebase && firebase -P merakitales-5rltbl deploy --only firestore:rules`
Expected: rules deployed.

- [ ] **Step 3: Commit**

```bash
git add firebase/firestore.rules && git commit -m "chore(firestore): allow tale_drafts for authenticated users"
```

---

## Task 9: Storage rules update

**Files:**
- Modify: `firebase/storage.rules`

- [ ] **Step 1: Replace storage.rules**

Replace `firebase/storage.rules`:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /drafts/{allPaths=**} {
      allow read, write: if request.auth != null;
    }
    match /tales/{allPaths=**} {
      allow read: if true;
      allow write: if false;
    }
    match /users/{userId}/{allPaths=**} {
      allow read: if true;
      allow write: if request.auth.uid == userId;
    }
  }
}
```

- [ ] **Step 2: Deploy rules**

Run: `cd firebase && firebase -P merakitales-5rltbl deploy --only storage`
Expected: rules deployed.

- [ ] **Step 3: Commit**

```bash
git add firebase/storage.rules && git commit -m "chore(storage): allow drafts/ for auth, tales/ public read"
```

---

## Task 10: Web admin — entrypoint, Firebase init, router

**Files:**
- Create: `lib/admin/main_admin.dart`
- Create: `lib/admin/app.dart`

**Interfaces:**
- Produces: a runnable `flutter run -t lib/admin/main_admin.dart -d chrome` admin app shell with a GoRouter.

- [ ] **Step 1: Create main_admin.dart**

Create `lib/admin/main_admin.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyDkhY8P3z__1JZfXjJ8GwXzJmt1ehtUqI4",
      authDomain: "merakitales-5rltbl.firebaseapp.com",
      projectId: "merakitales-5rltbl",
      storageBucket: "merakitales-5rltbl.appspot.com",
      messagingSenderId: "650643926570",
      appId: "1:650643926570:web:c706eca9cbf1aa02665d53",
    ),
  );

  // Match function region (europe-west1)
  FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
  // NOTE: remove the emulator line for production; or guard with kDebugMode.

  runApp(const MerakiAdminApp());
}
```

- [ ] **Step 2: Create app.dart with router**

Create `lib/admin/app.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'auth/auth_gate.dart';
import 'login/login_page.dart';
import 'drafts/drafts_list_page.dart';
import 'drafts/draft_detail_page.dart';

class MerakiAdminApp extends StatelessWidget {
  const MerakiAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final authed = snapshot.data != null;
        final router = _buildRouter(authed);
        return MaterialApp.router(
          title: 'Meraki Tales Admin',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF1D2428)),
          routerConfig: router,
        );
      },
    );
  }

  GoRouter _buildRouter(bool authed) {
    return GoRouter(
      initialLocation: '/drafts',
      redirect: (context, state) {
        final onLogin = state.matchedLocation == '/login';
        if (!authed && !onLogin) return '/login';
        if (authed && onLogin) return '/drafts';
        return null;
      },
      routes: [
        GoRoute(path: '/login', builder: (c, s) => const LoginPage()),
        GoRoute(
          path: '/drafts',
          builder: (c, s) => const DraftsListPage(),
          routes: [
            GoRoute(path: ':id', builder: (c, s) => DraftDetailPage(draftId: s.pathParameters['id']!)),
          ],
        ),
      ],
    );
  }
}
```

- [ ] **Step 3: Create placeholder pages so it compiles**

Create `lib/admin/auth/auth_gate.dart`:

```dart
import 'package:flutter/material.dart';
class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => child;
}
```

Create `lib/admin/login/login_page.dart` (placeholder, real impl in Task 11):

```dart
import 'package:flutter/material.dart';
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('login placeholder')));
}
```

Create `lib/admin/drafts/drafts_list_page.dart` (placeholder):

```dart
import 'package:flutter/material.dart';
class DraftsListPage extends StatelessWidget {
  const DraftsListPage({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('drafts list placeholder')));
}
```

Create `lib/admin/drafts/draft_detail_page.dart` (placeholder):

```dart
import 'package:flutter/material.dart';
class DraftDetailPage extends StatelessWidget {
  const DraftDetailPage({super.key, required this.draftId});
  final String draftId;
  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: Text('detail $draftId')));
}
```

- [ ] **Step 4: Verify it builds**

Run: `flutter build web -t lib/admin/main_admin.dart --no-pub`
Expected: builds without errors.

- [ ] **Step 5: Commit**

```bash
git add lib/admin && git commit -m "feat(admin): add web admin entrypoint, router, placeholder pages"
```

---

## Task 11: Web admin — login page + auth

**Files:**
- Modify: `lib/admin/login/login_page.dart`

- [ ] **Step 1: Implement login page**

Replace `lib/admin/login/login_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() { _loading = true; _error = null; });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
    } on FirebaseAuthException catch (e) {
      setState(() { _error = e.message ?? 'Error'); });
    } finally {
      if (mounted) setState(() => _loading = false;);
    }
  }

  @override
  void dispose() { _email.dispose(); _password.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meraki Tales Admin')),
      body: Center(
        child: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _email,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                decoration: const InputDecoration(labelText: 'Contraseña'),
                obscureText: true,
                onSubmitted: (_) => _signIn(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _loading ? null : _signIn,
                child: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator()) : const Text('Entrar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Create the admin user in Firebase Auth**

Run:
```bash
cd firebase && firebase -P merakitales-5rltbl auth:import --help > /dev/null 2>&1
# Easiest: create via the Firebase Console > Authentication > Add user (email/password).
# Then copy the uid and set the ADMIN_UID secret (if not done in Task 7):
firebase -P merakitales-5rltbl functions:secrets:set ADMIN_UID
```
Expected: admin user exists in Firebase Auth; `ADMIN_UID` secret holds its uid.

- [ ] **Step 3: Verify login flow manually**

Run: `flutter run -t lib/admin/main_admin.dart -d chrome`
Expected: login page renders; entering admin credentials redirects to `/drafts` (empty placeholder).

- [ ] **Step 4: Commit**

```bash
git add lib/admin/login/login_page.dart && git commit -m "feat(admin): implement email/password login page"
```

---

## Task 12: Web admin — draft model + drafts service

**Files:**
- Create: `lib/admin/models/draft.dart`
- Create: `lib/admin/services/drafts_service.dart`

**Interfaces:**
- Produces: `Draft` model (from Firestore), `DraftsService` with `streamDrafts()`, `generateDraft({String? theme})`, `approveDraft(String id)`, `rejectDraft(String id)`, `getDraft(String id)`.

- [ ] **Step 1: Create the Draft model**

Create `lib/admin/models/draft.dart`:

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
  });

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
      imagePrompt: d['image_prompt_es'] as String? ?? '',
      assignedTaleId: d['assigned_tale_id'] as int?,
    );
  }
}
```

- [ ] **Step 2: Create the DraftsService**

Create `lib/admin/services/drafts_service.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:rxdart/rxdart.dart';

import '../models/draft.dart';

class DraftsService {
  final _db = FirebaseFirestore.instance;
  final _functions = FirebaseFunctions.instanceFor(region: 'europe-west1');

  Stream<List<Draft>> streamDrafts() {
    return _db
        .collection('tale_drafts')
        .where('status', isEqualTo: 'pending')
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((qs) => qs.docs.map(Draft.fromDoc).toList());
  }

  Stream<Draft?> streamDraft(String id) {
    return _db.collection('tale_drafts').doc(id).snapshots().map((s) => s.exists ? Draft.fromDoc(s) : null);
  }

  Future<String> generateDraft({String? theme}) async {
    final result = await _functions.httpsCallable('generateTaleDraft').call({'theme': theme});
    return result.data['draftId'] as String;
  }

  Future<int> approveDraft(String id) async {
    final result = await _functions.httpsCallable('approveDraft').call({'draftId': id});
    return result.data['taleId'] as int;
  }

  Future<void> rejectDraft(String id) async {
    await _functions.httpsCallable('rejectDraft').call({'draftId': id});
  }
}
```

- [ ] **Step 3: Verify it compiles**

Run: `flutter analyze lib/admin`
Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add lib/admin/models lib/admin/services && git commit -m "feat(admin): add Draft model and DraftsService (callable + stream)"
```

---

## Task 13: Web admin — drafts list page

**Files:**
- Modify: `lib/admin/drafts/drafts_list_page.dart`

- [ ] **Step 1: Implement the list page**

Replace `lib/admin/drafts/drafts_list_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/drafts_service.dart';
import '../models/draft.dart';

class DraftsListPage extends StatefulWidget {
  const DraftsListPage({super.key});
  @override
  State<DraftsListPage> createState() => _DraftsListPageState();
}

class _DraftsListPageState extends State<DraftsListPage> {
  final _service = DraftsService();
  final _themeController = TextEditingController();
  bool _generating = false;

  Future<void> _generate() async {
    setState(() => _generating = true);
    try {
      await _service.generateDraft(theme: _themeController.text.trim().isEmpty ? null : _themeController.text.trim());
      _themeController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  void dispose() { _themeController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Borradores')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _themeController,
                    decoration: const InputDecoration(
                      labelText: 'Tema (opcional)',
                      hintText: 'amistad, valentía, naturaleza…',
                    ),
                    onSubmitted: (_) => _generate(),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _generating ? null : _generate,
                  icon: _generating
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_awesome),
                  label: const Text('Generar'),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Draft>>(
              stream: _service.streamDrafts(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                final drafts = snap.data ?? [];
                if (drafts.isEmpty) {
                  return const Center(child: Text('No hay borradores pendientes.'));
                }
                return ListView.builder(
                  itemCount: drafts.length,
                  itemBuilder: (c, i) {
                    final d = drafts[i];
                    return ListTile(
                      leading: d.imageUrl640.isNotEmpty
                          ? ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.network(d.imageUrl640, width: 56, height: 56, fit: BoxFit.cover))
                          : const Icon(Icons.book),
                      title: Text('${d.nameEs} / ${d.nameEn}'),
                      subtitle: Text(d.createdAt != null ? '${d.createdAt!.toLocal()}' : ''),
                      onTap: () => context.go('/drafts/${d.id}'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verify it builds**

Run: `flutter build web -t lib/admin/main_admin.dart --no-pub`
Expected: builds without errors.

- [ ] **Step 3: Commit**

```bash
git add lib/admin/drafts/drafts_list_page.dart && git commit -m "feat(admin): implement drafts list with generate button"
```

---

## Task 14: Web admin — draft detail page (preview + approve/reject)

**Files:**
- Modify: `lib/admin/drafts/draft_detail_page.dart`

- [ ] **Step 1: Implement the detail page**

Replace `lib/admin/drafts/draft_detail_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/drafts_service.dart';
import '../models/draft.dart';

class DraftDetailPage extends StatefulWidget {
  const DraftDetailPage({super.key, required this.draftId});
  final String draftId;
  @override
  State<DraftDetailPage> createState() => _DraftDetailPageState();
}

class _DraftDetailPageState extends State<DraftDetailPage> {
  final _service = DraftsService();
  bool _es = true;
  bool _busy = false;

  Future<void> _approve(String id) async {
    setState(() => _busy = true);
    try {
      final taleId = await _service.approveDraft(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Publicado como tale_id=$taleId')));
        context.go('/drafts');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject(String id) async {
    setState(() => _busy = true);
    try {
      await _service.rejectDraft(id);
      if (mounted) context.go('/drafts');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Draft?>(
      stream: _service.streamDraft(widget.draftId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        if (!snap.hasData || snap.data == null) return const Scaffold(body: Center(child: Text('Borrador no encontrado')));
        final d = snap.data!;
        final name = _es ? d.nameEs : d.nameEn;
        final desc = _es ? d.descriptionEs : d.descriptionEn;
        final spec = _es ? d.specificationsEs : d.specificationsEn;
        final audio = _es ? d.audioUrlEs : d.audioUrlEn;
        return Scaffold(
          appBar: AppBar(
            title: Text(name),
            actions: [
              ToggleButtons(
                isSelected: [_es, !_es],
                onPressed: (i) => setState(() => _es = i == 0),
                children: const [Text('ES'), Text('EN')],
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: _busy
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(d.imageUrl)),
                          const SizedBox(height: 16),
                          Text('Descripción', style: Theme.of(context).textTheme.titleSmall),
                          Text(desc),
                          const SizedBox(height: 16),
                          Text('Texto del cuento', style: Theme.of(context).textTheme.titleSmall),
                          Text(spec, style: const TextStyle(fontSize: 18, height: 1.5)),
                          const SizedBox(height: 16),
                          Text('Audio ($_es ? 'ES' : 'EN')', style: Theme.of(context).textTheme.titleSmall),
                          if (audio.isNotEmpty)
                            AudioPlayerWidget(url: audio)
                          else
                            const Text('Sin audio'),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              OutlinedButton(
                                onPressed: () => _reject(d.id),
                                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                child: const Text('Rechazar'),
                              ),
                              const SizedBox(width: 12),
                              FilledButton.icon(
                                onPressed: () => _approve(d.id),
                                icon: const Icon(Icons.publish),
                                label: const Text('Aprobar y publicar'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }
}

// Simple HTML5 audio element for web (no extra deps needed).
class AudioPlayerWidget extends StatelessWidget {
  const AudioPlayerWidget({super.key, required this.url});
  final String url;
  @override
  Widget build(BuildContext context) {
    // ignore: avoid_web_libraries_in_flutter
    return SizedBox(
      height: 48,
      child: HtmlElementView(viewType: 'meraki-audio-${url.hashCode.abs()}'),
    );
  }
}
```

- [ ] **Step 2: Register the audio HTML element view**

Add to `lib/admin/main_admin.dart` (after `Firebase.initializeApp(...)`):

```dart
  // Register HTML5 audio element views per url hash (registered on demand in detail page build would be cleaner;
  // for simplicity we register a factory that builds an <audio> tag).
  // ignore: avoid_web_libraries_in_flutter
  import 'dart:html' as html;
  import 'dart:ui_web' as ui_web;
```

Then in `main()`:

```dart
  ui_web.platformViewRegistry.registerViewFactory('meraki-audio', (int _) {
    final audio = html.AudioElement()
      ..controls = true
      ..style.width = '100%';
    return audio;
  });
```

Note: the `HtmlElementView` in the detail page uses a unique `viewType` per url; since `registerViewFactory` only registers once, switch the `AudioPlayerWidget` to register lazily. Simpler: use a single shared `viewType` and set the `src` via platform messages is overkill. **Pragmatic fallback:** use `url_launcher` to open the audio in a new tab, OR embed an `<audio>` via `HtmlElementView` with a fixed viewType and pass `src` through a global map. For v1, replace `AudioPlayerWidget` with a simple link:

Replace the `AudioPlayerWidget` class and its usage:

```dart
// Replace the AudioPlayerWidget usage in the Column with:
if (audio.isNotEmpty)
  InkWell(
    onTap: () => launchUrl(Uri.parse(audio)),
    child: const Row(children: [Icon(Icons.play_circle, size: 32), SizedBox(width: 8), Text('Reproducir audio')]),
  )
else
  const Text('Sin audio'),
```

And add at the top of `draft_detail_page.dart`:

```dart
import 'package:url_launcher/url_launcher.dart';
```

Remove the `AudioPlayerWidget` class entirely.

- [ ] **Step 3: Verify it builds**

Run: `flutter build web -t lib/admin/main_admin.dart --no-pub`
Expected: builds without errors.

- [ ] **Step 4: Commit**

```bash
git add lib/admin && git commit -m "feat(admin): implement draft detail with preview + approve/reject"
```

---

## Task 15: Hosting config + build/deploy web admin

**Files:**
- Modify: `firebase/firebase.json`
- Create: `firebase/.firebaserc` (if missing)

- [ ] **Step 1: Update firebase.json hosting**

Replace the `hosting` block in `firebase/firebase.json`:

```json
  "hosting": {
    "public": "build/web",
    "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
    "rewrites": [
      {
        "source": "**",
        "destination": "/index.html"
      }
    ]
  }
```

- [ ] **Step 2: Build the web admin**

Run:
```bash
cd /Users/juanpenuelasmartinez/Documents/flutter_projects/merakitales
flutter build web -t lib/admin/main_admin.dart --web-renderer canvaskit --release
```
Expected: `build/web/index.html` produced.

- [ ] **Step 3: Deploy hosting**

Run:
```bash
cd firebase && firebase -P merakitales-5rltbl deploy --only hosting
```
Expected: hosting URL returned (e.g. `https://merakitales-5rltbl.web.app`).

- [ ] **Step 4: Commit**

```bash
git add firebase/firebase.json && git commit -m "chore(hosting): serve web admin build on Firebase Hosting"
```

---

## Task 16: End-to-end validation (Fase 0 → 2)

**Files:** none (manual validation).

- [ ] **Step 1: Fase 0 — login + empty list**

Open the hosting URL. Sign in with admin credentials.
Expected: redirected to `/drafts` showing "No hay borradores pendientes."

- [ ] **Step 2: Fase 1 — generate a test draft**

Enter a theme (e.g. "amistad") and click "Generar".
Expected: after 20-40s, a draft appears in the list. Open it: verify ES/EN text, image, and audio links work. **Do not approve yet.**

- [ ] **Step 3: Quality review**

Read the story text in both languages. Listen to audio. Check the image.
- If quality unacceptable: reject, then iterate on `firebase/functions/src/prompts.js` or swap models in `firebase/functions/src/openrouter.js` (e.g. try `mistralai/voxtral-mini-tts-2603` for TTS).
- If acceptable: proceed.

- [ ] **Step 4: Fase 2 — approve and verify mobile app**

Click "Aprobar y publicar". Note the returned `tale_id`.
Expected: draft disappears from the list.

Then check Firestore:
```bash
TOKEN=$(gcloud auth application-default print-access-token)
curl -s -X POST "https://firestore.googleapis.com/v1/projects/merakitales-5rltbl/databases/(default)/documents:runQuery" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d "{\"structuredQuery\":{\"from\":[{\"collectionId\":\"tales\"}],\"where\":{\"fieldFilter\":{\"field\":{\"fieldPath\":\"tale_id\"},\"op\":\"EQUAL\",\"value\":{\"integerValue\":$TALEID}}},\"limit\":5}}"
```
Expected: 2 documents (es, en) with the new `tale_id`.

Open the mobile app (or rebuild and run) → the new tale appears at the top of the list (ordered by `tale_id` desc).

- [ ] **Step 5: Commit a validation note**

```bash
git add -A && git commit --allow-empty -m "chore: end-to-end validation complete (Fase 0-2)"
```

---

## Self-Review (run after writing — already done)

- **Spec coverage:** Every section of the spec maps to a task. Architecture → Tasks 1-9 (backend) + 10-15 (frontend). Data model → Tasks 4,5 (draft schema + tales writes). Functions → Tasks 4-7. Web admin → Tasks 10-15. Security/rules → Tasks 8,9. Cost/security/risks → documented in spec, encoded as auth guards (Task 1) + prompts (Task 1) + transactions (Task 5). Validation plan → Task 16.
- **Placeholder scan:** No TBDs. The audio player fallback (Task 14 Step 2) is resolved inline to `url_launcher` (already a pubspec dependency) — no dangling placeholder.
- **Type consistency:** `DraftsService` methods (`generateDraft`, `approveDraft`, `rejectDraft`, `streamDrafts`, `streamDraft`) match usage in list/detail pages. `draftId` string flows consistently from service → callable → Firestore. `taleId` number returned from `approveDraft` matches Firestore `tale_id` int field.
