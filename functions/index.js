const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { runPremiumWeatherAlerts } = require("./weather_alerts");
const {
  authorizeRequest: authorizeNirsRequest,
  fetchNirsForParcelBody,
} = require("./nirs_sentinel");
const {
  createPayPalOrderBody,
  capturePayPalOrderBody,
} = require("./paypal_checkout");
const { identifyPlantBody } = require("./plant_id_proxy");
const {
  requestAccountDeletion,
  purgeScheduledAccountDeletions,
} = require("./account_deletion");

const PAYPAL_SECRETS = ["PAYPAL_CLIENT_ID", "PAYPAL_CLIENT_SECRET", "PAYPAL_ENV"];
const PLANT_ID_SECRETS = ["PLANT_ID_API_KEY"];

initializeApp();

function getStripeSecretKey() {
  return process.env.STRIPE_SECRET_KEY || "";
}

/** Kanonske mjesečne cijene pretplate u centima (EUR). */
const SUBSCRIPTION_MONTHLY_CENTS_EUR = {
  premium_buyer_monthly: 199,
  premium_hobby_monthly: 399,
  premium_pro_monthly: 999,
  license_vet_monthly: 999,
  license_pharmacy_monthly: 1999,
};

exports.createPaymentIntent = onCall(
  { secrets: ["STRIPE_SECRET_KEY"] },
  async (request) => {
  const amount = Number(request.data?.amount);
  const currency = (request.data?.currency || "eur").toLowerCase();

  if (!Number.isFinite(amount) || amount <= 0) {
    throw new HttpsError("invalid-argument", "Invalid payment amount.");
  }

  const stripeSecret = getStripeSecretKey();
  if (!stripeSecret) {
    throw new HttpsError(
      "failed-precondition",
      "Stripe secret key is not configured on the server.",
    );
  }

  const stripe = require("stripe")(stripeSecret);
  const productId = request.data?.productId || "";
  const subscriptionCents = SUBSCRIPTION_MONTHLY_CENTS_EUR[productId];
  const resolvedAmount =
    subscriptionCents != null ? subscriptionCents : Math.round(amount);

  const intent = await stripe.paymentIntents.create({
    amount: resolvedAmount,
    currency,
    automatic_payment_methods: { enabled: true },
    metadata: {
      sellerId: request.data?.sellerId || "",
      buyerId: request.auth?.uid || "",
      productId,
      subscriptionMonthlyCents:
        subscriptionCents != null ? String(subscriptionCents) : "",
    },
  });

  return {
    clientSecret: intent.client_secret,
    paymentIntentId: intent.id,
  };
  },
);

exports.createPayPalOrder = onCall(
  { secrets: PAYPAL_SECRETS },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication required.");
    }

    const amount = Number(request.data?.amount);
    const currency = (request.data?.currency || "EUR").toUpperCase();

    if (!Number.isFinite(amount) || amount <= 0) {
      throw new HttpsError("invalid-argument", "Invalid payment amount.");
    }

    try {
      return await createPayPalOrderBody({
        amount,
        currency,
        sellerId: request.data?.sellerId || "",
        buyerId: request.auth.uid,
      });
    } catch (error) {
      if (error.code === "invalid-argument") {
        throw new HttpsError("invalid-argument", error.message);
      }
      if (error.code === "failed-precondition") {
        throw new HttpsError("failed-precondition", error.message);
      }
      console.error("createPayPalOrder failed:", error);
      throw new HttpsError("internal", "PayPal order creation failed.");
    }
  },
);

exports.capturePayPalOrder = onCall(
  { secrets: PAYPAL_SECRETS },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication required.");
    }

    const orderId = request.data?.orderId;
    if (!orderId) {
      throw new HttpsError("invalid-argument", "Missing PayPal order id.");
    }

    try {
      return await capturePayPalOrderBody(orderId);
    } catch (error) {
      if (error.code === "invalid-argument") {
        throw new HttpsError("invalid-argument", error.message);
      }
      console.error("capturePayPalOrder failed:", error);
      throw new HttpsError("internal", error.message || "PayPal capture failed.");
    }
  },
);

exports.identifyPlant = onCall(
  { secrets: PLANT_ID_SECRETS, memory: "512MiB", timeoutSeconds: 60 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication required.");
    }

    try {
      return await identifyPlantBody(request.data);
    } catch (error) {
      if (error.code === "invalid-argument") {
        throw new HttpsError("invalid-argument", error.message);
      }
      if (error.code === "failed-precondition") {
        throw new HttpsError("failed-precondition", error.message);
      }
      console.error("identifyPlant failed:", error);
      throw new HttpsError("internal", "Plant identification failed.");
    }
  },
);

function buildOrderSummary(order) {
  const items = Array.isArray(order.items) ? order.items : [];

  if (items.length === 0) {
    return "nova narudžba";
  }

  if (items.length === 1) {
    return items[0].name || "proizvod";
  }

  return `${items.length} proizvoda`;
}

exports.notifyFarmerOnNewOrder = onDocumentCreated(
  "orders/{orderId}",
  async (event) => {
    const order = event.data?.data();
    if (!order) return;

    const sellerId = order.sellerId;
    if (!sellerId) {
      console.log("Order without sellerId, skipping notification.");
      return;
    }

    const sellerDoc = await getFirestore().collection("users").doc(sellerId).get();
    const fcmToken = sellerDoc.data()?.fcmToken;

    if (!fcmToken) {
      console.log(`No FCM token for seller ${sellerId}.`);
      return;
    }

    const buyerName = order.buyerName || "Kupac";
    const summary = buildOrderSummary(order);
    const total = order.total ?? order.totalPrice ?? 0;

    await getMessaging().send({
      token: fcmToken,
      notification: {
        title: "Nova narudžba!",
        body: `${buyerName} je naručio: ${summary} (${total} KM)`,
      },
      data: {
        type: "new_order",
        orderId: event.params.orderId,
      },
      android: {
        priority: "high",
        notification: {
          channelId: "high_importance_channel",
        },
      },
    });

    console.log(`Notification sent to seller ${sellerId}.`);
  },
);

exports.notifyFollowersOnNewProduct = onDocumentCreated(
  "products/{productId}",
  async (event) => {
    const product = event.data?.data();
    if (!product?.sellerId) {
      console.log("Product without sellerId, skipping follower notifications.");
      return;
    }

    const farmerId = product.sellerId;
    const farmerName = product.sellerName || "Farmer";
    const productName = product.name || "novi proizvod";
    const price = product.price ?? "";

    const followersSnap = await getFirestore()
      .collection("followers")
      .where("farmerId", "==", farmerId)
      .get();

    if (followersSnap.empty) {
      console.log(`No followers for farmer ${farmerId}.`);
      return;
    }

    const tokens = [];

    for (const followerDoc of followersSnap.docs) {
      const buyerId = followerDoc.data().buyerId;
      if (!buyerId || buyerId === farmerId) continue;

      const buyerDoc = await getFirestore().collection("users").doc(buyerId).get();
      const token = buyerDoc.data()?.fcmToken;
      if (token) tokens.push(token);
    }

    if (tokens.length === 0) {
      console.log(`Followers found but no FCM tokens for farmer ${farmerId}.`);
      return;
    }

    const body = price
      ? `${productName} — ${price} KM. Pogledaj u prodavnici!`
      : `${productName} — pogledaj u prodavnici!`;

    await getMessaging().sendEachForMulticast({
      tokens,
      notification: {
        title: `${farmerName} ima novi proizvod!`,
        body,
      },
      data: {
        type: "new_product",
        farmerId,
        productId: event.params.productId,
        farmerName,
      },
      android: {
        priority: "high",
        notification: {
          channelId: "high_importance_channel",
        },
      },
    });

    console.log(
      `New product notification sent to ${tokens.length} follower(s) for farmer ${farmerId}.`,
    );
  },
);

exports.notifyOwnerOnVetResponse = onDocumentUpdated(
  "veterinary_requests/{requestId}",
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!after) return;

    const beforeMessages = Array.isArray(before?.conversationMessages)
      ? before.conversationMessages.length
      : 0;
    const afterMessages = Array.isArray(after.conversationMessages)
      ? after.conversationMessages.length
      : 0;
    const responseText = (after.vetResponse || "").trim();
    const hasNewResponse =
      responseText.length > 0 &&
      (before?.vetResponse !== after.vetResponse ||
        afterMessages > beforeMessages);

    if (!hasNewResponse) return;

    const clientId = after.clientId;
    if (!clientId) {
      console.log("Vet response without clientId, skipping notification.");
      return;
    }

    const clientDoc = await getFirestore().collection("users").doc(clientId).get();
    const fcmToken = clientDoc.data()?.fcmToken;
    if (!fcmToken) {
      console.log(`No FCM token for client ${clientId}.`);
      return;
    }

    const vetName = after.vetName || "Veterinar";
    const animalName = after.animalName || "životinja";
    const preview =
      responseText.length > 120
        ? `${responseText.slice(0, 117)}...`
        : responseText;

    await getMessaging().send({
      token: fcmToken,
      notification: {
        title: "Nalaz veterinara",
        body: `${vetName} je odgovorio za ${animalName}: ${preview}`,
      },
      data: {
        type: "vet_response",
        requestId: event.params.requestId,
        animalId: after.animalId || "",
        vetName,
      },
      android: {
        priority: "high",
        notification: {
          channelId: "high_importance_channel",
        },
      },
    });

    console.log(`Vet response notification sent to client ${clientId}.`);
  },
);

exports.notifyVetOnNewIntake = onDocumentCreated(
  "veterinary_requests/{requestId}",
  async (event) => {
    const request = event.data?.data();
    if (!request) return;

    const vetId = request.vetId;
    if (!vetId) {
      console.log("Intake without vetId, skipping notification.");
      return;
    }

    const vetDoc = await getFirestore().collection("users").doc(vetId).get();
    const fcmToken = vetDoc.data()?.fcmToken;
    if (!fcmToken) {
      console.log(`No FCM token for vet ${vetId}.`);
      return;
    }

    const clientName = request.clientName || "Vlasnik";
    const animalName = request.animalName || "životinja";
    const memo = (request.clientMemo || "").trim();
    const memoPreview =
      memo.length > 80 ? `${memo.slice(0, 77)}...` : memo;
    const body = memoPreview
      ? `${clientName} — ${animalName}: ${memoPreview}`
      : `${clientName} je poslao karton za ${animalName}`;

    await getMessaging().send({
      token: fcmToken,
      notification: {
        title: "Novi digitalni karton",
        body,
      },
      data: {
        type: "vet_intake",
        requestId: event.params.requestId,
        animalName,
        clientName,
      },
      android: {
        priority: "high",
        notification: {
          channelId: "high_importance_channel",
        },
      },
    });

    console.log(`Vet intake notification sent to vet ${vetId}.`);
  },
);

exports.notifyUserOnChatMessage = onDocumentCreated(
  "chat_rooms/{roomId}/messages/{messageId}",
  async (event) => {
    const message = event.data?.data();
    if (!message) return;

    const receiverId = message.receiverId;
    const senderId = message.senderId;
    if (!receiverId || !senderId || receiverId === senderId) return;

    const receiverDoc = await getFirestore().collection("users").doc(receiverId).get();
    const fcmToken = receiverDoc.data()?.fcmToken;
    if (!fcmToken) {
      console.log(`No FCM token for chat receiver ${receiverId}.`);
      return;
    }

    const senderDoc = await getFirestore().collection("users").doc(senderId).get();
    const senderName =
      senderDoc.data()?.name ||
      senderDoc.data()?.displayName ||
      "Korisnik";

    const messageType = message.messageType || "text";
    let body = (message.message || "").trim();
    if (messageType === "medical_card") {
      const animalName = message.animalName || "životinja";
      body = `Poslao medicinski karton: ${animalName}`;
    }
    if (!body) body = "Nova poruka";

    const preview = body.length > 120 ? `${body.slice(0, 117)}...` : body;

    await getMessaging().send({
      token: fcmToken,
      notification: {
        title: senderName,
        body: preview,
      },
      data: {
        type: "chat_message",
        roomId: event.params.roomId,
        senderId,
        senderName,
        messageId: event.params.messageId,
      },
      android: {
        priority: "high",
        notification: {
          channelId: "high_importance_channel",
        },
      },
    });

    console.log(`Chat notification sent to ${receiverId}.`);
  },
);

exports.notifyFarmerOnLowStock = onDocumentUpdated(
  "products/{productId}",
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!after) return;

    const sellerId = after.sellerId;
    if (!sellerId) return;

    const stockAfter = Number(after.stock);
    const stockBefore = Number(before?.stock ?? stockAfter + 1);
    if (!Number.isFinite(stockAfter) || stockAfter > 10 || stockBefore <= 10) {
      return;
    }

    const sellerDoc = await getFirestore().collection("users").doc(sellerId).get();
    const fcmToken = sellerDoc.data()?.fcmToken;
    if (!fcmToken) {
      console.log(`No FCM token for seller ${sellerId}.`);
      return;
    }

    const productName = after.name || "Proizvod";

    await getMessaging().send({
      token: fcmToken,
      notification: {
        title: "Niska zaliha",
        body: `${productName} — ostalo ${Math.floor(stockAfter)} kom`,
      },
      data: {
        type: "low_stock",
        productId: event.params.productId,
        productName,
      },
      android: {
        priority: "high",
        notification: {
          channelId: "high_importance_channel",
        },
      },
    });

    console.log(`Low stock notification sent to seller ${sellerId}.`);
  },
);

/**
 * Sentinel-2 NIRS/NDVI — Copernicus STAC + Sentinel Hub.
 * POST JSON: { points: [{ lat, lng }, ...] }
 * Authorization: Bearer <NIRS_API_KEY>
 */
exports.fetchNirsNdvi = onRequest(
  {
    cors: true,
    memory: "512MiB",
    timeoutSeconds: 120,
    secrets: [
      "NIRS_API_KEY",
      "SENTINEL_HUB_CLIENT_ID",
      "SENTINEL_HUB_CLIENT_SECRET",
    ],
  },
  async (req, res) => {
    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }
    if (req.method !== "POST") {
      res.status(405).json({ error: "Method not allowed" });
      return;
    }

    try {
      authorizeNirsRequest(req);
      const result = await fetchNirsForParcelBody(req.body);
      res.json(result);
    } catch (error) {
      const status = error.status || 500;
      res.status(status).json({
        error: error.message,
        captureDate: error.captureDate,
        cloudCoverPercent: error.cloudCover,
      });
    }
  },
);

/** Premium farmeri — hitni vremenski alarmi svakih 30 min (radi i kad je app zatvoren). */
exports.checkPremiumWeatherAlerts = onSchedule(
  {
    schedule: "every 30 minutes",
    timeZone: "Europe/Sarajevo",
    memory: "256MiB",
  },
  async () => {
    await runPremiumWeatherAlerts();
  },
);

/** Korisnik zatraži brisanje računa — odgodi do isteka pretplate ako je aktivna. */
exports.requestAccountDeletion = requestAccountDeletion;

/** Dnevno briše račune s isteklim rokom brisanja. */
exports.purgeScheduledAccountDeletions = purgeScheduledAccountDeletions;
