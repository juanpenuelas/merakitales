const { initializeApp, cert } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");

// Using default credentials
initializeApp({ projectId: "merakitales-5rltbl" });
const db = getFirestore();

async function fix() {
  await db.collection("tale_drafts").doc("KzIvgfAOQjoiof8HbAnC").update({ is_generating_text: false });
  console.log("Fixed!");
}
fix().catch(console.error);
