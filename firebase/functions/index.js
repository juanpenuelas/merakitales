const { onCall } = require("firebase-functions/v2/https");
const { setGlobalOptions } = require("firebase-functions/v2/options");

const { generateTaleTextHandler } = require("./src/generateTaleText");
const { generateTaleImageHandler } = require("./src/generateTaleImage");
const { generateTaleAudioHandler } = require("./src/generateTaleAudio");
const { approveDraftHandler } = require("./src/approveDraft");
const { rejectDraftHandler } = require("./src/rejectDraft");
const { retractTaleHandler } = require("./src/retractTale");

setGlobalOptions({ maxInstances: 10 });

const SECRETS = ["OPENROUTER_API_KEY", "ADMIN_UID"];

exports.generateTaleText = onCall(
  { timeoutSeconds: 60, memory: "512MiB", region: "europe-west1", secrets: SECRETS },
  generateTaleTextHandler
);

exports.generateTaleImage = onCall(
  { timeoutSeconds: 120, memory: "1GiB", region: "europe-west1", secrets: SECRETS },
  generateTaleImageHandler
);

exports.generateTaleAudio = onCall(
  { timeoutSeconds: 60, memory: "512MiB", region: "europe-west1", secrets: SECRETS },
  generateTaleAudioHandler
);

exports.approveDraft = onCall(
  { timeoutSeconds: 60, memory: "512MiB", region: "europe-west1", secrets: SECRETS },
  approveDraftHandler
);

exports.rejectDraft = onCall(
  { timeoutSeconds: 60, memory: "512MiB", region: "europe-west1", secrets: SECRETS },
  rejectDraftHandler
);

exports.retractTale = onCall(
  { timeoutSeconds: 60, memory: "512MiB", region: "europe-west1", secrets: SECRETS },
  retractTaleHandler
);
