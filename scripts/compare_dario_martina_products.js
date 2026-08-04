const path = require("path");
const admin = require(path.join(__dirname, "..", "functions", "node_modules", "firebase-admin"));
admin.initializeApp({ projectId: "my-farmer-552a3" });
const db = admin.firestore();

const DARIO = "TQjMRA9S13b86Cmg7BRHp6D3sf72";
const MARTINA = "ZXkWVzSb49gVIj2AyTVUMkS6PB92";

function analyzeProduct(data, id) {
  const loc = data.location;
  let locationType = "none";
  if (loc instanceof admin.firestore.GeoPoint) locationType = "GeoPoint";
  else if (loc && typeof loc === "object") locationType = "map";

  return {
    id,
    name: data.name,
    price: data.price,
    priceType: typeof data.price,
    category: data.category,
    productionType: data.productionType,
    isService: data.isService ?? false,
    isUpcoming: data.isUpcoming ?? false,
    requiresFinalPhoto: data.requiresFinalPhoto ?? false,
    imageUrl: data.imageUrl ? (data.imageUrl.length > 60 ? data.imageUrl.slice(0, 60) + "..." : data.imageUrl) : null,
    hasImage: !!(data.imageUrl && data.imageUrl.trim()),
    locationType,
    unit: data.unit,
    originalCurrency: data.originalCurrency,
    stock: data.stock,
    createdAt: data.createdAt?.toDate?.()?.toISOString?.() ?? null,
  };
}

function fieldStats(products) {
  const stats = {
    count: products.length,
    isService: 0,
    isUpcoming: 0,
    requiresFinalPhoto: 0,
    geoPointLocation: 0,
    mapLocation: 0,
    noLocation: 0,
    noImage: 0,
    categories: new Set(),
    productionTypes: new Set(),
  };
  for (const p of products) {
    if (p.isService) stats.isService++;
    if (p.isUpcoming) stats.isUpcoming++;
    if (p.requiresFinalPhoto) stats.requiresFinalPhoto++;
    if (p.locationType === "GeoPoint") stats.geoPointLocation++;
    else if (p.locationType === "map") stats.mapLocation++;
    else stats.noLocation++;
    if (!p.hasImage) stats.noImage++;
    stats.categories.add(p.category);
    stats.productionTypes.add(p.productionType);
  }
  stats.categories = [...stats.categories];
  stats.productionTypes = [...stats.productionTypes];
  return stats;
}

async function loadProducts(uid) {
  const snap = await db.collection("products").where("sellerId", "==", uid).get();
  return snap.docs.map((d) => analyzeProduct(d.data(), d.id));
}

async function main() {
  const darioProducts = await loadProducts(DARIO);
  const martinaProducts = await loadProducts(MARTINA);

  console.log("\n=== DARIO PRODUCTS ===");
  console.log(JSON.stringify(darioProducts, null, 2));
  console.log("\n=== MARTINA PRODUCTS (first 5) ===");
  console.log(JSON.stringify(martinaProducts.slice(0, 5), null, 2));

  console.log("\n=== PRODUCT STATS ===");
  console.log("Dario:", JSON.stringify(fieldStats(darioProducts), null, 2));
  console.log("Martina:", JSON.stringify(fieldStats(martinaProducts), null, 2));

  const userA = (await db.collection("users").doc(DARIO).get()).data();
  const userB = (await db.collection("users").doc(MARTINA).get()).data();

  console.log("\n=== TAB CONFIG IMPLICATION ===");
  console.log("Dario role:", userA.role, "-> showServicesTab:", userA.role === "professional_farmer");
  console.log("Martina role:", userB.role, "-> showServicesTab:", userB.role === "professional_farmer");
  console.log("Dario tabCount:", (userA.role === "professional_farmer" ? 2 : 1) + 1);
  console.log("Martina tabCount:", (userB.role === "professional_farmer" ? 2 : 1) + 1);
}

main().catch(console.error);
