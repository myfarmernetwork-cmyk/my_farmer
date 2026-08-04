const path = require("path");
const admin = require(path.join(__dirname, "..", "functions", "node_modules", "firebase-admin"));
admin.initializeApp({ projectId: "my-farmer-552a3" });
const db = admin.firestore();

async function main() {
  const snap = await db.collection("products").get();
  const draganaUid = "J3oLuZ50UfSZWCJcEkwWCRmBF1u2";
  const matches = [];
  for (const doc of snap.docs) {
    const d = doc.data();
    const sellerId = (d.sellerId || "").toString();
    const sellerName = (d.sellerName || "").toString().toLowerCase();
    if (
      sellerId === draganaUid ||
      sellerName.includes("dragana") ||
      sellerName.includes("duvnjak") ||
      sellerName.includes("krndija")
    ) {
      matches.push({
        id: doc.id,
        sellerId,
        sellerName: d.sellerName,
        name: d.name,
        requiresFinalPhoto: d.requiresFinalPhoto,
        isService: d.isService,
      });
    }
  }
  console.log("Products linked to Dragana:", matches.length);
  console.log(JSON.stringify(matches, null, 2));
}

main().catch(console.error);
