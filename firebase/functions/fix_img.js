const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");

initializeApp({ projectId: "merakitales-5rltbl" });
const db = getFirestore();

async function fix() {
  const doc = await db.collection("tale_drafts").doc("KzIvgfAOQjoiof8HbAnC").get();
  const data = doc.data();
  const ts = Date.now();
  
  if (data.image_url && !data.image_url.includes("?v=")) {
    await doc.ref.update({
      image_url: `${data.image_url}?v=${ts}`,
      image_url_640px: data.image_url_640px ? `${data.image_url_640px}?v=${ts}` : ""
    });
    console.log("Updated URLs with timestamp!");
  } else {
    console.log("Already has timestamp or empty.");
  }
}
fix().catch(console.error);
