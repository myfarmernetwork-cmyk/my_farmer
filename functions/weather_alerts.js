const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

const FARMER_ROLES = new Set([
  "hobby_farmer",
  "professional_farmer",
  "farmer",
  "hobby farmer",
  "professional farmer",
]);

const PREMIUM_FARMER_TIERS = new Set([
  "hobby_farmer_premium",
  "professional_farmer_premium",
]);

const ALERT_COOLDOWN_MS = 6 * 60 * 60 * 1000;

const ALERT_MESSAGES = {
  hr: {
    title: "⚠️ Vremensko upozorenje",
    weather_alert_high_wind:
      "Jak vjetar ({wind} km/h)! Sigurno učvrstite plastenike, mreže i cerade prije nevremena.",
    weather_alert_extreme_heat:
      "Ekstremna vrućina ({temp}°C)! Navodnjavajte u ranim jutarnjim satima i zaklonite osjetljive kulture.",
    weather_alert_hail:
      "Rizik od tuče ({rain}% padalina)! Pokrijte voćke i povrće, po potrebi koristite anti-tuš mreže.",
    weather_alert_frost:
      "Rizik od mraza ({temp}°C)! Zaštitite mlade biljke i cvjetove folijom ili agrotekstilom.",
    weather_alert_storm:
      "Grmljavina i nepogoda! Po potrebi prekinite rad na polju, učvrstite cerade i zaštitite strojeve.",
    weather_alert_heavy_rain:
      "Jaka kiša ({rain}% padalina)! Provjerite odvodnju, zaštitite usjeve i odložite prskanje.",
  },
  en: {
    title: "⚠️ Weather warning",
    weather_alert_high_wind:
      "Strong wind ({wind} km/h)! Secure greenhouses, nets and tarps before the storm.",
    weather_alert_extreme_heat:
      "Extreme heat ({temp}°C)! Irrigate early morning and shade sensitive crops.",
    weather_alert_hail:
      "Hail risk ({rain}% precipitation)! Cover fruit trees and vegetables; use hail nets if needed.",
    weather_alert_frost:
      "Frost risk ({temp}°C)! Protect young plants and blossoms with foil or agrotextile.",
    weather_alert_storm:
      "Thunderstorm alert! Pause field work if needed, secure tarps and protect equipment.",
    weather_alert_heavy_rain:
      "Heavy rain ({rain}% precipitation)! Check drainage, protect crops and delay spraying.",
  },
  de: {
    title: "⚠️ Wetterwarnung",
    weather_alert_high_wind:
      "Starker Wind ({wind} km/h)! Gewächshäuser, Netze und Planen vor dem Unwetter sichern.",
    weather_alert_extreme_heat:
      "Extreme Hitze ({temp}°C)! Früh morgens bewässern und empfindliche Kulturen schützen.",
    weather_alert_hail:
      "Hagelrisiko ({rain}% Niederschlag)! Obst und Gemüse abdecken, Hagelnetze verwenden.",
    weather_alert_frost:
      "Frostgefahr ({temp}°C)! Junge Pflanzen und Blüten mit Folie oder Vlies schützen.",
    weather_alert_storm:
      "Gewitter! Feldarbeit bei Bedarf pausieren, Planen sichern und Geräte schützen.",
    weather_alert_heavy_rain:
      "Starkregen ({rain}% Niederschlag)! Drainage prüfen, Kulturen schützen, Spritzen verschieben.",
  },
};

function normalizeRole(role) {
  return (role || "").toString().trim().toLowerCase().replace(/\s+/g, "_");
}

function isFarmerRole(role) {
  const normalized = normalizeRole(role);
  return FARMER_ROLES.has(normalized) || normalized.includes("farmer");
}

function isPremiumFarmer(data) {
  if ((data.status || "").toString().toUpperCase() === "PENDING_DELETION") {
    return false;
  }
  if (data.weatherAlertsEnabled === false) return false;
  if (!isFarmerRole(data.role)) return false;

  if (data.premiumActive === true) return true;

  const approved =
    (data.premiumApprovalStatus || "").toString().toUpperCase() === "APPROVED";
  const tier = (data.subscriptionTier || "").toString();
  return approved && PREMIUM_FARMER_TIERS.has(tier);
}

function resolveLanguage(data) {
  const raw = (data.preferredLanguage || "hr").toString().split("_")[0];
  if (ALERT_MESSAGES[raw]) return raw;
  if (raw === "bs" || raw === "sr") return "hr";
  return "en";
}

function resolveFarmLocation(data) {
  const lat = data.farmLat;
  const lng = data.farmLng;
  if (typeof lat === "number" && typeof lng === "number" && lat !== 0 && lng !== 0) {
    return { lat, lng };
  }

  const location = data.location;
  if (location && typeof location === "object") {
    const locLat = location.lat;
    const locLng = location.lng;
    if (typeof locLat === "number" && typeof locLng === "number" && locLat !== 0 && locLng !== 0) {
      return { lat: locLat, lng: locLng };
    }
  }

  return null;
}

function mapOpenMeteoCode(code) {
  if (code === 0) return "sunny";
  if (code <= 3) return "cloudy";
  if (code >= 45 && code <= 48) return "cloudy";
  if (code >= 51 && code <= 67) return "rainy";
  if (code >= 80 && code <= 82) return "rainy";
  if (code >= 95) return "storm";
  return "cloudy";
}

function precipChanceFromCode(code) {
  if (code >= 95) return 90;
  if (code >= 80 && code <= 82) return 75;
  if (code >= 61 && code <= 67) return 80;
  if (code >= 51 && code <= 57) return 55;
  if (code >= 71 && code <= 77) return 40;
  if (code >= 3) return 25;
  return 5;
}

function evaluateWeatherAlerts(snapshot) {
  const alerts = [];
  const {
    temperatureC,
    windSpeedKmh,
    precipitationChance,
    frostRisk,
    hailRisk,
    condition,
  } = snapshot;

  if (windSpeedKmh > 40) alerts.push("weather_alert_high_wind");
  if (temperatureC > 35) alerts.push("weather_alert_extreme_heat");
  if (hailRisk) alerts.push("weather_alert_hail");
  if (frostRisk) alerts.push("weather_alert_frost");
  if (condition === "storm") alerts.push("weather_alert_storm");
  if (condition === "rainy" && precipitationChance >= 70) {
    alerts.push("weather_alert_heavy_rain");
  }

  return alerts;
}

function buildSnapshotFromOpenMeteo(current) {
  const temp = Number(current.temperature_2m ?? 15);
  const humidity = Number(current.relative_humidity_2m ?? 0);
  const windKmh = Number(current.wind_speed_10m ?? 0);
  const weatherCode = Number(current.weather_code ?? 0);
  const condition = mapOpenMeteoCode(weatherCode);
  const precipChance = precipChanceFromCode(weatherCode);
  const hailRisk = condition === "storm" || (precipChance > 75 && temp < 8);
  const frostRisk = temp <= 2;

  return {
    temperatureC: temp,
    windSpeedKmh: windKmh,
    humidityPercent: humidity,
    precipitationChance: precipChance,
    frostRisk,
    hailRisk,
    condition,
  };
}

async function fetchOpenMeteo(lat, lng) {
  const params = new URLSearchParams({
    latitude: String(lat),
    longitude: String(lng),
    current: "temperature_2m,relative_humidity_2m,wind_speed_10m,weather_code",
    wind_speed_unit: "kmh",
    timezone: "auto",
  });

  const response = await fetch(
    `https://api.open-meteo.com/v1/forecast?${params.toString()}`,
    { signal: AbortSignal.timeout(12000) },
  );

  if (!response.ok) return null;

  const data = await response.json();
  const current = data.current;
  if (!current) return null;

  return buildSnapshotFromOpenMeteo(current);
}

function formatAlertBody(template, snapshot) {
  return template
    .replace("{temp}", Math.round(snapshot.temperatureC).toString())
    .replace("{wind}", Math.round(snapshot.windSpeedKmh).toString())
    .replace("{rain}", String(snapshot.precipitationChance));
}

async function shouldSendAlert(db, uid, alertKey) {
  const doc = await db
    .collection("users")
    .doc(uid)
    .collection("weather_alert_state")
    .doc(alertKey)
    .get();

  if (!doc.exists) return true;

  const lastSent = doc.data()?.lastSentAt;
  if (!lastSent || typeof lastSent.toMillis !== "function") return true;

  return Date.now() - lastSent.toMillis() >= ALERT_COOLDOWN_MS;
}

async function markAlertSent(db, uid, alertKey) {
  await db
    .collection("users")
    .doc(uid)
    .collection("weather_alert_state")
    .doc(alertKey)
    .set({ lastSentAt: FieldValue.serverTimestamp() }, { merge: true });
}

async function sendWeatherAlert({ token, lang, alertKey, snapshot }) {
  const messages = ALERT_MESSAGES[lang] || ALERT_MESSAGES.en;
  const template = messages[alertKey] || ALERT_MESSAGES.en[alertKey];
  if (!template) return;

  const body = formatAlertBody(template, snapshot);

  await getMessaging().send({
    token,
    notification: {
      title: messages.title,
      body,
    },
    data: {
      type: "weather_alert",
      alertKey,
    },
    android: {
      priority: "high",
      notification: {
        channelId: "weather_alerts_channel",
      },
    },
  });
}

async function processPremiumFarmer(db, uid, data) {
  if (!isPremiumFarmer(data)) return { skipped: true };

  const fcmToken = data.fcmToken;
  if (!fcmToken) return { skipped: true, reason: "no_token" };

  const coords = resolveFarmLocation(data);
  if (!coords) return { skipped: true, reason: "no_location" };

  const snapshot = await fetchOpenMeteo(coords.lat, coords.lng);
  if (!snapshot) return { skipped: true, reason: "weather_fetch_failed" };

  const alertKeys = evaluateWeatherAlerts(snapshot);
  if (alertKeys.length === 0) return { skipped: true, reason: "no_alerts" };

  const lang = resolveLanguage(data);
  let sent = 0;

  for (const alertKey of alertKeys) {
    const ok = await shouldSendAlert(db, uid, alertKey);
    if (!ok) continue;

    try {
      await sendWeatherAlert({
        token: fcmToken,
        lang,
        alertKey,
        snapshot,
      });
      await markAlertSent(db, uid, alertKey);
      sent += 1;
    } catch (error) {
      console.warn(`Weather alert failed for ${uid} (${alertKey}):`, error.message);
    }
  }

  return { sent, alertKeys };
}

async function runPremiumWeatherAlerts() {
  const db = getFirestore();
  const usersSnap = await db.collection("users").where("premiumActive", "==", true).get();

  let processed = 0;
  let notified = 0;

  for (const doc of usersSnap.docs) {
    processed += 1;
    const result = await processPremiumFarmer(db, doc.id, doc.data());
    if (result.sent) notified += result.sent;
  }

  const legacySnap = await db
    .collection("users")
    .where("premiumApprovalStatus", "==", "APPROVED")
    .get();

  for (const doc of legacySnap.docs) {
    const data = doc.data();
    if (data.premiumActive === true) continue;
    if (!PREMIUM_FARMER_TIERS.has((data.subscriptionTier || "").toString())) continue;

    processed += 1;
    const result = await processPremiumFarmer(db, doc.id, data);
    if (result.sent) notified += result.sent;
  }

  console.log(
    `Premium weather alerts done. Users processed: ${processed}, notifications sent: ${notified}.`,
  );

  return { processed, notified };
}

module.exports = {
  runPremiumWeatherAlerts,
};
