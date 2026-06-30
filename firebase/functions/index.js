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
