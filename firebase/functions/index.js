const { onCall } = require("firebase-functions/v2/https");
const { setGlobalOptions } = require("firebase-functions/v2/options");

const { generateTaleTextHandler } = require("./src/generateTaleText");
const { generateTaleImageHandler } = require("./src/generateTaleImage");
const { generateTaleAudioHandler } = require("./src/generateTaleAudio");
const { approveDraftHandler } = require("./src/approveDraft");
const { rejectDraftHandler } = require("./src/rejectDraft");
const { retractTaleHandler } = require("./src/retractTale");
const { updateDraftTextHandler } = require("./src/updateDraftText");
const { resizeDraftImageHandler } = require("./src/resizeDraftImage");
const { scheduleDraftHandler } = require("./src/scheduleDraft");
const { publishScheduledTalesHandler } = require("./src/publishScheduledTales");
const { onSchedule } = require("firebase-functions/v2/scheduler");

setGlobalOptions({ maxInstances: 10 });

const SECRETS = ["OPENROUTER_API_KEY", "ADMIN_UID"];

exports.generateTaleText = onCall(
  { timeoutSeconds: 180, memory: "512MiB", region: "europe-west1", secrets: SECRETS },
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

exports.updateDraftText = onCall(
  { timeoutSeconds: 30, memory: "256MiB", region: "europe-west1", secrets: ["ADMIN_UID"] },
  updateDraftTextHandler
);

exports.resizeDraftImage = onCall(
  { timeoutSeconds: 60, memory: "512MiB", region: "europe-west1", secrets: ["ADMIN_UID"] },
  resizeDraftImageHandler
);

exports.scheduleDraft = onCall(
  { timeoutSeconds: 30, memory: "256MiB", region: "europe-west1", secrets: ["ADMIN_UID"] },
  scheduleDraftHandler
);

exports.publishScheduledTales = onSchedule(
  {
    schedule: "every 15 minutes",
    region: "europe-west1",
    timeZone: "Europe/Madrid", 
  },
  publishScheduledTalesHandler
);
