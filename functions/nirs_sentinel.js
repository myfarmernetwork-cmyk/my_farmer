/**
 * Sentinel-2 NIRS/NDVI — Copernicus STAC (datum snimke) + Sentinel Hub (NDVI).
 *
 * Env (Firebase Functions secrets / .env):
 *   NIRS_API_KEY              — Bearer token iz Flutter builda (SENTINEL2_API_KEY)
 *   SENTINEL_HUB_CLIENT_ID    — OAuth client ID (sentinel-hub.com)
 *   SENTINEL_HUB_CLIENT_SECRET
 */

const COPERNICUS_STAC =
  "https://catalogue.dataspace.copernicus.eu/stac/collections/sentinel-2-l2a/items";

const NDVI_EVALSCRIPT = `
//VERSION=3
function setup() {
  return {
    input: [{ bands: ["B04", "B08"] }],
    output: { bands: 1, sampleType: "FLOAT32" },
  };
}
function evaluatePixel(sample) {
  const denom = sample.B08 + sample.B04;
  if (denom === 0) return [0];
  return [(sample.B08 - sample.B04) / denom];
}
`;

function bboxFromPoints(points) {
  let minLat = 90;
  let maxLat = -90;
  let minLng = 180;
  let maxLng = -180;

  for (const p of points) {
    const lat = Number(p.lat);
    const lng = Number(p.lng);
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) continue;
    minLat = Math.min(minLat, lat);
    maxLat = Math.max(maxLat, lat);
    minLng = Math.min(minLng, lng);
    maxLng = Math.max(maxLng, lng);
  }

  return [minLng, minLat, maxLng, maxLat];
}

function closedPolygonCoordinates(points) {
  if (!Array.isArray(points) || points.length < 3) {
    throw new Error("Parcel must have at least 3 points.");
  }

  const ring = points.map((p) => [Number(p.lng), Number(p.lat)]);
  const first = ring[0];
  const last = ring[ring.length - 1];
  if (first[0] !== last[0] || first[1] !== last[1]) {
    ring.push([first[0], first[1]]);
  }
  return [ring];
}

function estimateMoistureFromNdvi(ndvi) {
  return Math.min(92, Math.max(35, 42 + ndvi * 38));
}

async function findLatestClearScene(bbox, maxCloud = 40) {
  const params = new URLSearchParams({
    bbox: bbox.join(","),
    sortby: "-datetime",
    limit: "10",
  });

  const now = new Date();
  const from = new Date(now);
  from.setDate(from.getDate() - 21);

  params.set(
    "datetime",
    `${from.toISOString().slice(0, 10)}T00:00:00Z/${now.toISOString()}`,
  );

  const response = await fetch(`${COPERNICUS_STAC}?${params.toString()}`);
  if (!response.ok) {
    throw new Error(`Copernicus STAC HTTP ${response.status}`);
  }

  const payload = await response.json();
  const features = payload.features || [];

  for (const feature of features) {
    const cloud =
      feature.properties?.["eo:cloud_cover"] ??
      feature.properties?.cloudCover ??
      100;
    if (cloud <= maxCloud) {
      return {
        captureDate: feature.properties.datetime,
        cloudCover: cloud,
      };
    }
  }

  if (features.length > 0) {
    const feature = features[0];
    return {
      captureDate: feature.properties.datetime,
      cloudCover:
        feature.properties?.["eo:cloud_cover"] ??
        feature.properties?.cloudCover ??
        null,
    };
  }

  throw new Error("No Sentinel-2 L2A scene found for this parcel in the last 21 days.");
}

async function getSentinelHubToken(clientId, clientSecret) {
  const body = new URLSearchParams({
    grant_type: "client_credentials",
    client_id: clientId,
    client_secret: clientSecret,
  });

  const response = await fetch("https://services.sentinel-hub.com/oauth/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body,
  });

  if (!response.ok) {
    throw new Error(`Sentinel Hub OAuth HTTP ${response.status}`);
  }

  const data = await response.json();
  if (!data.access_token) {
    throw new Error("Sentinel Hub OAuth: missing access_token");
  }
  return data.access_token;
}

async function fetchNdviMeanFromSentinelHub({
  accessToken,
  points,
  captureDateIso,
}) {
  const captureDate = new Date(captureDateIso);
  const from = new Date(captureDate);
  from.setUTCDate(from.getUTCDate() - 2);
  const to = new Date(captureDate);
  to.setUTCDate(to.getUTCDate() + 2);

  const body = {
    input: {
      bounds: {
        geometry: {
          type: "Polygon",
          coordinates: closedPolygonCoordinates(points),
        },
      },
      data: [
        {
          type: "sentinel-2-l2a",
          dataFilter: {
            timeRange: {
              from: from.toISOString(),
              to: to.toISOString(),
            },
            maxCloudCoverage: 50,
          },
        },
      ],
    },
    aggregation: {
      timeRange: {
        from: from.toISOString(),
        to: to.toISOString(),
      },
      aggregationInterval: { of: "P1D" },
      evalscript: NDVI_EVALSCRIPT,
      resx: "10m",
      resy: "10m",
    },
    calculations: {
      default: {
        statistics: {
          default: {
            percentiles: { k: [50] },
          },
        },
      },
    },
  };

  const response = await fetch(
    "https://services.sentinel-hub.com/api/v1/statistics",
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
        Accept: "application/json",
      },
      body: JSON.stringify(body),
    },
  );

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Sentinel Hub statistics HTTP ${response.status}: ${text}`);
  }

  const payload = await response.json();
  const intervals = payload?.data?.[0]?.intervals;
  if (!intervals?.length) {
    throw new Error("Sentinel Hub: no NDVI intervals returned");
  }

  for (const interval of intervals) {
    const stats = interval?.outputs?.default?.bands?.B0?.stats;
    const mean = stats?.mean;
    if (typeof mean === "number" && Number.isFinite(mean)) {
      return mean;
    }
    const p50 = stats?.percentiles?.p50;
    if (typeof p50 === "number" && Number.isFinite(p50)) {
      return p50;
    }
  }

  throw new Error("Sentinel Hub: NDVI mean not available in response");
}

function authorizeRequest(req) {
  const expected = process.env.NIRS_API_KEY || "";
  if (!expected) {
    throw new Error("NIRS_API_KEY is not configured on the server.");
  }
  const header = req.headers.authorization || "";
  const token = header.replace(/^Bearer\s+/i, "").trim();
  if (token !== expected) {
    const err = new Error("Unauthorized");
    err.status = 401;
    throw err;
  }
}

async function fetchNirsForParcelBody(body) {
  const points = body?.points;
  if (!Array.isArray(points) || points.length < 3) {
    const err = new Error("Invalid points array.");
    err.status = 400;
    throw err;
  }

  const bbox = bboxFromPoints(points);
  const scene = await findLatestClearScene(bbox);

  const clientId = process.env.SENTINEL_HUB_CLIENT_ID || "";
  const clientSecret = process.env.SENTINEL_HUB_CLIENT_SECRET || "";
  if (!clientId || !clientSecret) {
    const err = new Error(
      "Sentinel Hub is not configured. Set SENTINEL_HUB_CLIENT_ID and SENTINEL_HUB_CLIENT_SECRET.",
    );
    err.status = 503;
    err.captureDate = scene.captureDate;
    err.cloudCover = scene.cloudCover;
    throw err;
  }

  const hubToken = await getSentinelHubToken(clientId, clientSecret);
  const ndviMean = await fetchNdviMeanFromSentinelHub({
    accessToken: hubToken,
    points,
    captureDateIso: scene.captureDate,
  });

  const ndviRounded = Math.round(ndviMean * 1000) / 1000;
  const moistureIndex =
    Math.round(estimateMoistureFromNdvi(ndviRounded) * 10) / 10;

  return {
    ndviMean: ndviRounded,
    moistureIndex,
    captureDate: scene.captureDate,
    cloudCoverPercent: scene.cloudCover,
    source: "Sentinel-2",
  };
}

module.exports = {
  fetchNirsForParcelBody,
  authorizeRequest,
};
