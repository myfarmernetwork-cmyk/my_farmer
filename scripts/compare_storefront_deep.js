/**
 * Deep compare two seller UIDs — all user fields + product details.
 */
const path = require("path");
const admin = require(path.join(__dirname, "..", "functions", "node_modules", "firebase-admin"));

admin.initializeApp({ projectId: "my-farmer-552a3" });
const db = admin.firestore();

const MARTINA = "ZXkWVzSb49gVIj2AyTVUMkS6PB92";
const DRAGANA = "J3oLuZ50UfSZWCJcEkwWCRmBF1u2";

function summarizeUser(data) {
  const keys = Object.keys(data).sort();
  const summary = {};
  for (const k of keys) {
    const v = data[k];
    if (v === null || v === undefined) {
      summary[k] = null;
    } else if (typeof v === "string" || typeof v === "boolean" || typeof v === "number") {
      summary[k] = v;
    } else if (v instanceof admin.firestore.Timestamp) {
      summary[k] = v.toDate().toISOString();
    } else if (v instanceof admin.firestore.GeoPoint) {
      summary[k] = { lat: v.latitude, lng: v.longitude };
    } else if (Array.isArray(v)) {
      summary[k] = v;
    } else if (typeof v === "object") {
      summary[k] = JSON.stringify(v).slice(0, 200);
    } else {
      summary[k] = String(v);
    }
  }
  return summary;
}

function productIssues(data, id) {
  const issues = [];
  if (!data.name) issues.push("missing name");
  if (data.price == null) issues.push("missing price");
  if (data.requiresFinalPhoto === true) issues.push("requiresFinalPhoto");
  if (data.isService === true) issues.push("isService");
  if (data.isUpcoming === true) issues.push("isUpcoming");
  const loc = data.location;
  if (loc && loc.constructor?.name === "GeoPoint") {
    issues.push("GeoPoint location");
  }
  if (data.imageUrl == null || data.imageUrl === "") issues.push("empty imageUrl");
  return { id, name: data.name || "(no name)", issues };
}

async function load(uid, label) {
  const userDoc = await db.collection("users").doc(uid).get();
  const productsSnap = await db.collection("products").where("sellerId", "==", uid).get();

  const byNameSnap = await db
    .collection("products")
    .where("sellerName", ">=", label.split(" ")[0])
    .where("sellerName", "<=", label.split(" ")[0] + "\uf8ff")
    .limit(5)
    .get();

  return {
    uid,
    userFields: summarizeUser(userDoc.data() || {}),
    productCount: productsSnap.size,
    products: productsSnap.docs.map((d) => productIssues(d.data(), d.id)),
    productsByNameHint: byNameSnap.docs.map((d) => ({
      id: d.id,
      sellerId: d.data().sellerId,
      sellerName: d.data().sellerName,
      name: d.data().name,
    })),
  };
}

async function main() {
  const martina = await load(MARTINA, "Martina");
  const dragana = await load(DRAGANA, "Dragana");

  console.log("\n=== MARTINA ALL FIELDS ===");
  console.log(JSON.stringify(martina, null, 2));
  console.log("\n=== DRAGANA ALL FIELDS ===");
  console.log(JSON.stringify(dragana, null, 2));

  const mKeys = new Set(Object.keys(martina.userFields));
  const dKeys = new Set(Object.keys(dragana.userFields));
  const allKeys = [...new Set([...mKeys, ...dKeys])].sort();

  console.log("\n=== USER FIELD DIFF (keys only in one / different values) ===");
  for (const k of allKeys) {
    const a = martina.userFields[k];
    const b = dragana.userFields[k];
    if (JSON.stringify(a) !== JSON.stringify(b)) {
      console.log(`- ${k}:`);
      console.log(`    Martina: ${JSON.stringify(a)}`);
      console.log(`    Dragana: ${JSON.stringify(b)}`);
    }
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
