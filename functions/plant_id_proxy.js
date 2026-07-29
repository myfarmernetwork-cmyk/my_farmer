/**
 * Plant.id (Kindwise) proxy — API ključ ostaje na serveru.
 *
 * Secret: PLANT_ID_API_KEY
 */

const PLANT_ID_BASE = "https://api.plant.id/v3";

function getPlantIdApiKey() {
  const key = process.env.PLANT_ID_API_KEY || "";
  if (!key) {
    const err = new Error("PLANT_ID_API_KEY is not configured on the server.");
    err.code = "failed-precondition";
    throw err;
  }
  return key;
}

function normalizeLanguage(raw) {
  const lang = (raw || "en").toString().split("_")[0].toLowerCase();
  const supported = new Set([
    "en",
    "hr",
    "de",
    "cs",
    "zh",
    "pl",
    "fr",
    "es",
    "ru",
    "uk",
  ]);
  if (supported.has(lang)) return lang;
  if (lang === "bs" || lang === "sr") return "hr";
  return "en";
}

async function identifyPlantBody(body) {
  const images = body?.images;
  if (!Array.isArray(images) || images.length === 0) {
    const err = new Error("Missing images array.");
    err.code = "invalid-argument";
    throw err;
  }

  const base64Image = images[0];
  if (typeof base64Image !== "string" || base64Image.length < 32) {
    const err = new Error("Invalid image payload.");
    err.code = "invalid-argument";
    throw err;
  }

  const language = normalizeLanguage(body?.language);
  const params = new URLSearchParams({
    details: "common_names,description,treatment,local_name",
    language,
  });

  const response = await fetch(
    `${PLANT_ID_BASE}/identification?${params.toString()}`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Api-Key": getPlantIdApiKey(),
      },
      body: JSON.stringify({
        images: [base64Image],
        similar_images: true,
        health: "all",
      }),
      signal: AbortSignal.timeout(45000),
    },
  );

  if (response.status !== 200 && response.status !== 201) {
    const text = await response.text();
    const err = new Error(`Plant.id HTTP ${response.status}: ${text}`);
    err.code = "internal";
    err.httpStatus = response.status;
    throw err;
  }

  return response.json();
}

module.exports = {
  identifyPlantBody,
};
