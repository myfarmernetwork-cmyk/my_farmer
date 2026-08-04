/**
 * Compare two seller profiles in Firestore for storefront debugging.
 * Usage: node scripts/compare_storefront_profiles.js "martina" "dragana"
 */
const path = require("path");
const admin = require(path.join(__dirname, "..", "functions", "node_modules", "firebase-admin"));

admin.initializeApp({
  projectId: "my-farmer-552a3",
});

const db = admin.firestore();

const KEYS = [
  "name",
  "role",
  "isPublicProfile",
  "isVerified",
  "profileImageUrl",
  "address",
  "phone",
  "workingDays",
  "workingHours",
  "isAvailable",
  "offersPickup",
  "offersDelivery",
  "pickupDays",
  "pickupHoursFrom",
  "pickupHoursTo",
  "deliveryDays",
  "farmLat",
  "farmLng",
  "subscriptionTier",
  "premiumApprovalStatus",
  "currencyRegion",
  "companyRegistrationNumber",
];

function normalizeRole(data) {
  const role = (data.role || "").toString().toLowerCase();
  if (["pro_farmer", "professional_farmer", "farmer", "services"].includes(role)) {
    return "professional_farmer";
  }
  if (["hobby_farmer", "hobbyist_farmer", "hobi_farmer"].includes(role)) {
    return "hobby_farmer";
  }
  return role;
}

function summarizeProducts(docs) {
  let visible = 0;
  let hidden = 0;
  let parseErrors = 0;
  const flags = [];

  for (const doc of docs) {
    const data = doc.data();
    try {
      const requiresFinalPhoto = data.requiresFinalPhoto === true;
      const isService = data.isService === true;
      if (requiresFinalPhoto) hidden += 1;
      else visible += 1;
      if (data.location && typeof data.location === "object" && data.location.constructor?.name === "GeoPoint") {
        flags.push(`${doc.id}: GeoPoint location`);
      }
      if (data.price == null) flags.push(`${doc.id}: missing price`);
      if (!data.name) flags.push(`${doc.id}: missing name`);
      if (isService) flags.push(`${doc.id}: isService=true`);
    } catch (e) {
      parseErrors += 1;
      flags.push(`${doc.id}: inspect error ${e.message}`);
    }
  }

  return { total: docs.length, visible, hidden, parseErrors, flags: flags.slice(0, 15) };
}

async function findUserByNameFragment(fragment) {
  const snap = await db.collection("users").get();
  const needle = fragment.toLowerCase();
  return snap.docs.filter((d) => {
    const name = (d.data().name || "").toString().toLowerCase();
    return name.includes(needle);
  });
}

async function loadProfile(doc) {
  const data = doc.data();
  const productsSnap = await db
    .collection("products")
    .where("sellerId", "==", doc.id)
    .get();
  const products = summarizeProducts(productsSnap.docs);
  return {
    uid: doc.id,
    name: data.name || "",
    canonicalRole: normalizeRole(data),
    fields: Object.fromEntries(
      KEYS.map((k) => [k, data[k] ?? null]),
    ),
    products,
  };
}

function diffProfiles(a, b) {
  const diffs = [];
  for (const key of KEYS) {
    const av = JSON.stringify(a.fields[key]);
    const bv = JSON.stringify(b.fields[key]);
    if (av !== bv) {
      diffs.push({ key, a: a.fields[key], b: b.fields[key] });
    }
  }
  if (a.canonicalRole !== b.canonicalRole) {
    diffs.push({ key: "canonicalRole", a: a.canonicalRole, b: b.canonicalRole });
  }
  return diffs;
}

async function main() {
  const args = process.argv.slice(2);
  const q1 = args[0] || "depcinski";
  const q2 = args[1] || "duvnjak";

  const matches1 = await findUserByNameFragment(q1);
  const matches2 = await findUserByNameFragment(q2);

  console.log(`\nMatches for "${q1}":`, matches1.map((d) => d.data().name + " (" + d.id + ")"));
  console.log(`Matches for "${q2}":`, matches2.map((d) => d.data().name + " (" + d.id + ")"));

  if (matches1.length === 0 || matches2.length === 0) {
    console.error("Could not find both profiles.");
    process.exit(1);
  }

  const profileA = await loadProfile(matches1[0]);
  const profileB = await loadProfile(matches2[0]);

  console.log("\n=== PROFILE A ===");
  console.log(JSON.stringify(profileA, null, 2));
  console.log("\n=== PROFILE B ===");
  console.log(JSON.stringify(profileB, null, 2));

  console.log("\n=== FIELD DIFFERENCES ===");
  const diffs = diffProfiles(profileA, profileB);
  if (diffs.length === 0) {
    console.log("(no differences in compared fields)");
  } else {
    for (const d of diffs) {
      console.log(`- ${d.key}:`);
      console.log(`    A: ${JSON.stringify(d.a)}`);
      console.log(`    B: ${JSON.stringify(d.b)}`);
    }
  }

  console.log("\n=== PRODUCT SUMMARY ===");
  console.log("A:", profileA.products);
  console.log("B:", profileB.products);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
