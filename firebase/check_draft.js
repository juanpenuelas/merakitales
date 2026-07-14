const { initializeApp, cert } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");

initializeApp();
const db = getFirestore();

async function checkDrafts() {
  const snapshot = await db.collection("tale_drafts").orderBy("created_at", "desc").limit(1).get();
  if (snapshot.empty) {
    console.log("No drafts found.");
    return;
  }
  const draft = snapshot.docs[0].data();
  console.log("Latest Draft:", {
    id: snapshot.docs[0].id,
    image_url: draft.image_url,
    image_prompt: draft.image_prompt,
    is_generating_image: draft.is_generating_image,
    is_generating_text: draft.is_generating_text
  });
}

checkDrafts().catch(console.error);
