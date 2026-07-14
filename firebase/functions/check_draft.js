const { initializeApp, cert } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");

// Using default credentials
initializeApp({ projectId: "merakitales-5rltbl" });
const db = getFirestore();

async function checkDrafts() {
  const snapshot = await db.collection("tale_drafts").orderBy("created_at", "desc").limit(3).get();
  if (snapshot.empty) {
    console.log("No drafts found.");
    return;
  }
  snapshot.docs.forEach((doc, i) => {
    const draft = doc.data();
    console.log(`\nDraft ${i + 1} (${doc.id}):`);
    console.log("- name_es:", draft.name_es);
    console.log("- image_url:", draft.image_url);
    console.log("- is_generating_image:", draft.is_generating_image);
    console.log("- is_generating_text:", draft.is_generating_text);
    console.log("- image_prompt:", draft.image_prompt);
  });
}

checkDrafts().catch(console.error);
