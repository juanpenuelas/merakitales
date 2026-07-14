const { db } = require("./admin");
const { publishDraft } = require("./approveDraft");

/**
 * Scheduled function to scan for scheduled drafts and publish them.
 * @param {import("firebase-functions/v2/scheduler").ScheduledEvent} event
 */
async function publishScheduledTalesHandler(event) {
  const now = new Date();
  
  // Find all drafts that are scheduled and the time has passed
  const snapshot = await db.collection("tale_drafts")
    .where("status", "==", "scheduled")
    .where("scheduled_at", "<=", now)
    .get();

  if (snapshot.empty) {
    console.log("No scheduled tales to publish at this time.");
    return;
  }

  console.log(`Found ${snapshot.size} scheduled tales to publish.`);

  for (const doc of snapshot.docs) {
    try {
      console.log(`Publishing draft ${doc.id}...`);
      const taleId = await publishDraft(doc.id, "system-cron");
      console.log(`Successfully published draft ${doc.id} as tale ${taleId}.`);
      
      // TODO: Here is where we will trigger Push Notifications to users in the future
      
    } catch (e) {
      console.error(`Failed to publish scheduled draft ${doc.id}:`, e);
      // Optional: Update draft to a "failed" status so it doesn't get stuck in a loop
      await doc.ref.update({ status: "pending", error_msg: e.message });
    }
  }
}

module.exports = { publishScheduledTalesHandler };
