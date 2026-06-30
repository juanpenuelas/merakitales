const { onCall } = require("firebase-functions/v2/https");
const { setGlobalOptions } = require("firebase-functions/v2/options");

const { generateTaleDraftHandler } = require("./src/generateTaleDraft");
const { approveDraftHandler } = require("./src/approveDraft");
const { rejectDraftHandler } = require("./src/rejectDraft");

setGlobalOptions({ maxInstances: 10 });

const SECRETS = ["OPENROUTER_API_KEY", "ADMIN_UID"];

exports.generateTaleDraft = onCall(
  { timeoutSeconds: 120, memory: "1GiB", region: "europe-west1", secrets: SECRETS },
  generateTaleDraftHandler
);

exports.approveDraft = onCall(
  { timeoutSeconds: 60, memory: "512MiB", region: "europe-west1", secrets: SECRETS },
  approveDraftHandler
);

exports.rejectDraft = onCall(
  { timeoutSeconds: 60, memory: "512MiB", region: "europe-west1", secrets: SECRETS },
  rejectDraftHandler
);
