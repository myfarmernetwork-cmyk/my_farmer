/**
 * Pl@ntNet API proxy — species + disease, mapped to Plant.id-shaped JSON for the app.
 *
 * Secret: PLANTNET_API_KEY
 * Free plan: 500 identification requests/day (shared quota per API key).
 */

const PLANTNET_BASE = "https://my-api.plantnet.org/v2";

function getPlantNetApiKey() {
  const key = process.env.PLANTNET_API_KEY || "";
  if (!key) {
    const err = new Error("PLANTNET_API_KEY is not configured on the server.");
    err.code = "failed-precondition";
    throw err;
  }
  return key;
}

function normalizeLanguage(raw) {
  const lang = (raw || "en").toString().split("_")[0].toLowerCase();
  const supported = new Set([
    "en",
    "fr",
    "de",
    "es",
    "it",
    "pt",
    "nl",
    "pl",
    "ru",
    "uk",
    "cs",
    "zh",
    "ar",
    "tr",
  ]);
  if (supported.has(lang)) return lang;
  if (lang === "hr" || lang === "bs" || lang === "sr") return "en";
  return "en";
}

function decodeBase64Image(base64Image) {
  const trimmed = base64Image.trim();
  const data = trimmed.includes(",")
    ? trimmed.split(",").pop()
    : trimmed;
  const buffer = Buffer.from(data, "base64");
  if (buffer.length < 32) {
    const err = new Error("Invalid image payload.");
    err.code = "invalid-argument";
    throw err;
  }
  return buffer;
}

function buildMultipartImage(buffer) {
  const form = new FormData();
  const blob = new Blob([buffer], { type: "image/jpeg" });
  form.append("images", blob, "scan.jpg");
  form.append("organs", "auto");
  return form;
}

async function plantNetFetch(path, { apiKey, form, searchParams = {} }) {
  const params = new URLSearchParams(searchParams);
  params.set("api-key", apiKey);
  const url = `${PLANTNET_BASE}${path}?${params.toString()}`;

  const response = await fetch(url, {
    method: "POST",
    body: form,
    signal: AbortSignal.timeout(45000),
  });

  if (response.status === 401 || response.status === 403) {
    const err = new Error(
      "Pl@ntNet API key rejected. On my.plantnet.org open API key settings and allow server access (disable client-only restriction or authorize server IPs).",
    );
    err.code = "failed-precondition";
    err.httpStatus = response.status;
    throw err;
  }

  if (response.status === 429) {
    const err = new Error("Pl@ntNet daily quota exceeded.");
    err.code = "resource-exhausted";
    err.httpStatus = 429;
    throw err;
  }

  if (!response.ok) {
    const text = await response.text();
    const err = new Error(`Pl@ntNet HTTP ${response.status}: ${text}`);
    err.code = "internal";
    err.httpStatus = response.status;
    throw err;
  }

  return response.json();
}

function mapSpeciesToSuggestion(top) {
  if (!top) return null;
  const species = top.species || {};
  const scientificName =
    species.scientificName ||
    [
      species.scientificNameWithoutAuthor,
      species.scientificNameAuthorship,
    ]
      .filter(Boolean)
      .join(" ")
      .trim();

  const commonNames = Array.isArray(species.commonNames)
    ? species.commonNames.map(String)
    : [];

  return {
    name: scientificName || "Unknown",
    probability: typeof top.score === "number" ? top.score : 0,
    details: {
      common_names: commonNames,
      description: commonNames[0] || scientificName || "",
      local_name: commonNames[0] || null,
    },
  };
}

function mapDiseaseSuggestions(results) {
  if (!Array.isArray(results)) return [];
  return results.slice(0, 5).map((item) => ({
    name: item.name || item.label || "Unknown",
    probability: typeof item.score === "number" ? item.score : 0,
    details: {
      description: item.description || item.label || "",
      local_name: item.description || item.label || null,
    },
  }));
}

function inferHealthFromDiseases(suggestions) {
  if (!suggestions.length) {
    return { binary: null, probability: null };
  }
  const top = suggestions[0];
  const score = top.probability ?? 0;
  const healthy = score < 0.35;
  return {
    binary: healthy,
    probability: healthy ? 1 - score : score,
  };
}

function toPlantIdShape({ speciesData, diseaseData }) {
  const speciesResults = Array.isArray(speciesData?.results)
    ? speciesData.results
    : [];
  const topSpecies = mapSpeciesToSuggestion(speciesResults[0]);

  const diseaseResults = Array.isArray(diseaseData?.results)
    ? diseaseData.results
    : [];
  const diseaseSuggestions = mapDiseaseSuggestions(diseaseResults);
  const health = inferHealthFromDiseases(diseaseSuggestions);

  return {
    result: {
      is_plant: { binary: true, probability: 1 },
      classification: {
        suggestions: topSpecies ? [topSpecies] : [],
      },
      disease: {
        is_healthy: health,
        suggestions: diseaseSuggestions,
      },
    },
    provider: "plantnet",
    remainingIdentificationRequests:
      diseaseData?.remainingIdentificationRequests ??
      speciesData?.remainingIdentificationRequests ??
      null,
  };
}

async function identifyPlantBody(body) {
  const images = body?.images;
  if (!Array.isArray(images) || images.length === 0) {
    const err = new Error("Missing images array.");
    err.code = "invalid-argument";
    throw err;
  }

  const base64Image = images[0];
  if (typeof base64Image !== "string") {
    const err = new Error("Invalid image payload.");
    err.code = "invalid-argument";
    throw err;
  }

  const apiKey = getPlantNetApiKey();
  const language = normalizeLanguage(body?.language);
  const buffer = decodeBase64Image(base64Image);
  const form = buildMultipartImage(buffer);

  let speciesData = null;
  let diseaseData = null;

  try {
    speciesData = await plantNetFetch("/identify/all", {
      apiKey,
      form: buildMultipartImage(buffer),
      searchParams: { lang: language, "include-related-images": "false" },
    });
  } catch (error) {
    if (error.code === "resource-exhausted" || error.code === "failed-precondition") {
      throw error;
    }
    console.warn("Pl@ntNet species identify failed:", error.message);
  }

  try {
    diseaseData = await plantNetFetch("/diseases/identify", {
      apiKey,
      form: buildMultipartImage(buffer),
      searchParams: {
        lang: language,
        "include-related-images": "false",
        "nb-results": "5",
      },
    });
  } catch (error) {
    if (error.code === "resource-exhausted") {
      throw error;
    }
    console.warn("Pl@ntNet disease identify failed:", error.message);
  }

  if (!speciesData && !diseaseData) {
    const err = new Error("Pl@ntNet identification failed.");
    err.code = "internal";
    throw err;
  }

  return toPlantIdShape({ speciesData, diseaseData });
}

module.exports = {
  identifyPlantBody,
};
