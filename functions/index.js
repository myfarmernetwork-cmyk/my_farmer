const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
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
const {
  createPaymentIntentBody,
  mapStripeError,
} = require("./stripe_checkout");
const { identifyPlantBody } = require("./plant_id_proxy");
const {
  requestAccountDeletion,
  purgeScheduledAccountDeletions,
} = require("./account_deletion");
const {
  resolveLang,
  normalizeOrderStatus,
  newOrderNotification,
  buyerStatusNotification,
} = require("./order_notification_copy");

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
    try {
      return await createPaymentIntentBody({
        stripeSecret: getStripeSecretKey(),
        amountCents: Number(request.data?.amount),
        currency: request.data?.currency || "eur",
        sellerId: request.data?.sellerId || "",
        buyerId: request.auth?.uid || "",
        productId: request.data?.productId || "",
        subscriptionCentsMap: SUBSCRIPTION_MONTHLY_CENTS_EUR,
      });
    } catch (error) {
      const mapped = mapStripeError(error);
      console.error("createPaymentIntent failed:", {
        code: mapped.code,
        message: mapped.message,
        stripeType: error?.type,
        amount: request.data?.amount,
        currency: request.data?.currency,
        productId: request.data?.productId,
      });
      throw new HttpsError(mapped.code, mapped.message);
    }
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
      if (error.httpStatus === 401 || error.httpStatus === 403) {
        throw new HttpsError(
          "failed-precondition",
          "Plant.id API key is invalid or expired.",
        );
      }
      if (error.httpStatus === 429) {
        throw new HttpsError(
          "resource-exhausted",
          "Plant.id API credits exhausted for this key.",
        );
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
    const sellerData = sellerDoc.data() || {};
    const fcmToken = sellerData.fcmToken;

    if (!fcmToken) {
      console.log(`No FCM token for seller ${sellerId}.`);
      return;
    }

    const buyerName = order.buyerName || "Kupac";
    const summary = buildOrderSummary(order);
    const total = order.total ?? order.totalPrice ?? 0;
    const currency = sellerData.orderCurrency || "KM";
    const lang = resolveLang(sellerData.preferredLanguage);
    const notification = newOrderNotification({
      lang,
      buyer: buyerName,
      summary,
      total,
      currency,
    });

    await getMessaging().send({
      token: fcmToken,
      notification,
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

exports.notifyBuyerOnOrderStatusUpdate = onDocumentUpdated(
  "orders/{orderId}",
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!before || !after) return;

    const prevStatus = normalizeOrderStatus(before.status);
    const nextStatus = normalizeOrderStatus(after.status);
    if (prevStatus === nextStatus) return;
    if (nextStatus !== "preparing" && nextStatus !== "completed") return;

    const buyerId = after.buyerId;
    if (!buyerId) {
      console.log("Order without buyerId, skipping buyer notification.");
      return;
    }

    const buyerDoc = await getFirestore().collection("users").doc(buyerId).get();
    const buyerData = buyerDoc.data() || {};
    const fcmToken = buyerData.fcmToken;
    if (!fcmToken) {
      console.log(`No FCM token for buyer ${buyerId}.`);
      return;
    }

    const sellerId = after.sellerId || after.farmerId;
    let sellerData = {};
    if (sellerId) {
      const sellerDoc = await getFirestore().collection("users").doc(sellerId).get();
      sellerData = sellerDoc.data() || {};
    }

    const lang = resolveLang(buyerData.preferredLanguage);
    const sellerName =
      after.sellerName || after.farmerName || sellerData.name || "Farmer";
    const deliveryType = after.deliveryType || "pickup";
    const notification = buyerStatusNotification({
      lang,
      status: nextStatus,
      sellerName,
      deliveryType,
      sellerData,
    });
    if (!notification) return;

    await getMessaging().send({
      token: fcmToken,
      notification,
      data: {
        type: "order_status",
        orderId: event.params.orderId,
        status: nextStatus,
        deliveryType,
      },
      android: {
        priority: "high",
        notification: {
          channelId: "high_importance_channel",
        },
      },
    });

    console.log(
      `Order status notification (${nextStatus}) sent to buyer ${buyerId}.`,
    );
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
        productName,
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

    try {
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
        message: preview,
      },
      android: {
        priority: "high",
        notification: {
          channelId: "high_importance_channel",
          sound: "default",
          notificationPriority: "PRIORITY_HIGH",
        },
      },
    });

    console.log(`Chat notification sent to ${receiverId}.`);
  } catch (error) {
    console.error(`Chat notification failed for ${receiverId}:`, error);
    const code = error?.code || "";
    if (
      code === "messaging/registration-token-not-registered" ||
      code === "messaging/invalid-registration-token"
    ) {
      await getFirestore().collection("users").doc(receiverId).update({
        fcmToken: FieldValue.delete(),
      });
    }
  }
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

exports.notifyUsersOnNewForumTopic = onDocumentCreated(
  "forum_topics/{topicId}",
  async (event) => {
    const topic = event.data?.data();
    if (!topic) return;

    const authorId = topic.authorId;
    if (!authorId) return;

    let authorName = (topic.authorName || "").trim();
    if (!authorName) {
      const authorDoc = await getFirestore().collection("users").doc(authorId).get();
      authorName =
        authorDoc.data()?.name ||
        authorDoc.data()?.displayName ||
        "Korisnik";
    }

    const topicTitle = (topic.title || "Nova tema").trim();
    const topicId = event.params.topicId;

    const usersSnap = await getFirestore().collection("users").get();
    const tokens = [];

    for (const userDoc of usersSnap.docs) {
      if (userDoc.id === authorId) continue;
      const token = userDoc.data()?.fcmToken;
      if (token) tokens.push(token);
    }

    if (tokens.length === 0) {
      console.log("No FCM tokens for forum new topic notification.");
      return;
    }

    const body = `${authorName} — ${topicTitle}`;
    const preview = body.length > 120 ? `${body.slice(0, 117)}...` : body;

    await getMessaging().sendEachForMulticast({
      tokens,
      notification: {
        title: "Nova tema na forumu",
        body: preview,
      },
      data: {
        type: "forum_new_topic",
        topicId,
        topicTitle,
        authorName,
      },
      android: {
        priority: "high",
        notification: {
          channelId: "high_importance_channel",
        },
      },
    });

    console.log(`Forum new topic notification sent to ${tokens.length} user(s).`);
  },
);

exports.notifyTopicAuthorOnForumComment = onDocumentCreated(
  "forum_comments/{commentId}",
  async (event) => {
    const comment = event.data?.data();
    if (!comment) return;

    const topicId = comment.topicId;
    const commentAuthorId = comment.authorId;
    if (!topicId || !commentAuthorId) return;

    const topicDoc = await getFirestore().collection("forum_topics").doc(topicId).get();
    if (!topicDoc.exists) return;

    const topic = topicDoc.data();
    const topicAuthorId = topic?.authorId;
    if (!topicAuthorId || topicAuthorId === commentAuthorId) return;

    const authorDoc = await getFirestore()
      .collection("users")
      .doc(topicAuthorId)
      .get();
    const fcmToken = authorDoc.data()?.fcmToken;
    if (!fcmToken) {
      console.log(`No FCM token for forum topic author ${topicAuthorId}.`);
      return;
    }

    let authorName = (comment.authorName || "").trim();
    if (!authorName) {
      const commentAuthorDoc = await getFirestore()
        .collection("users")
        .doc(commentAuthorId)
        .get();
      authorName =
        commentAuthorDoc.data()?.name ||
        commentAuthorDoc.data()?.displayName ||
        "Korisnik";
    }

    const topicTitle = (topic?.title || "Vaša tema").trim();
    let preview = (comment.text || "").trim();
    if (!preview && comment.imageUrl) preview = "📷 Slika u komentaru";
    if (!preview) preview = "Novi odgovor";
    if (preview.length > 120) preview = `${preview.slice(0, 117)}...`;

    try {
      await getMessaging().send({
        token: fcmToken,
        notification: {
          title: topicTitle,
          body: preview,
        },
        data: {
          type: "forum_reply",
          topicId,
          topicTitle,
          authorName,
          preview,
        },
        android: {
          priority: "high",
          notification: {
            channelId: "high_importance_channel",
            sound: "default",
            notificationPriority: "PRIORITY_HIGH",
          },
        },
      });

      console.log(`Forum reply notification sent to ${topicAuthorId}.`);
    } catch (error) {
      console.error(`Forum reply notification failed for ${topicAuthorId}:`, error);
      const code = error?.code || "";
      if (
        code === "messaging/registration-token-not-registered" ||
        code === "messaging/invalid-registration-token"
      ) {
        await getFirestore().collection("users").doc(topicAuthorId).update({
          fcmToken: FieldValue.delete(),
        });
      }
    }
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
