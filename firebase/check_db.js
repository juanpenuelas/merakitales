const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
initializeApp();
const db = getFirestore();

async function check() {
  const drafts = await db.collection('tale_drafts').get();
  console.log("DRAFTS:");
  drafts.forEach(d => {
    const data = d.data();
    if (data.name_es && data.name_es.includes("Estrellas Caídas")) {
       console.log(`Draft ${d.id} - status: ${data.status}, name: ${data.name_es}`);
    }
  });

  const tales = await db.collection('tales').get();
  console.log("TALES:");
  tales.forEach(d => {
    const data = d.data();
    if (data.name && data.name.includes("Estrellas Caídas")) {
       console.log(`Tale ${d.id} - lang: ${data.lang}, name: ${data.name}`);
    }
  });
}
check().catch(console.error);
