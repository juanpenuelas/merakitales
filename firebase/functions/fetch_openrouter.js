const axios = require("axios");

async function fetchModelInfo() {
  try {
    const response = await axios.get("https://openrouter.ai/api/v1/models");
    const maiModels = response.data.data.filter(m => m.id.includes("mai-voice"));
    console.log(JSON.stringify(maiModels, null, 2));
  } catch (e) {
    console.error(e.message);
  }
}

fetchModelInfo();
