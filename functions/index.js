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
const { identifyPlantBody: identifyPlantViaPlantId } = require("./plant_id_proxy");
const { identifyPlantBody: identifyPlantViaPlantNet } = require("./plantnet_proxy");
const {
  requestAccountDeletion,
  purgeScheduledAccountDeletions,
} = require("./account_deletion");
const {
  adminClearUserProfileImage,
  adminDeleteUserAccount,
} = require("./admin_moderation");
const {
  resolveLang,
  normalizeOrderStatus,
  newOrderNotification,
  buyerStatusNotification,
  lowStockNotification,
} = require("./order_notification_copy");
const { writeInboxNotification } = require("./inbox_notifications");

const PAYPAL_SECRETS = ["PAYPAL_CLIENT_ID", "PAYPAL_CLIENT_SECRET", "PAYPAL_ENV"];
const PLANT_ID_SECRETS = ["PLANT_ID_API_KEY"];
const PLANTNET_SECRETS = ["PLANTNET_API_KEY"];

function resolveIdentifyPlantBody() {
  if (process.env.PLANTNET_API_KEY) {
    return identifyPlantViaPlantNet;
  }
  return identifyPlantViaPlantId;
}

async function identifyPlantWithFallback(data) {
  const hasPlantNet = Boolean(process.env.PLANTNET_API_KEY);
  const hasPlantId = Boolean(process.env.PLANT_ID_API_KEY);

  if (hasPlantNet) {
    try {
      return await identifyPlantViaPlantNet(data);
    } catch (error) {
      const retriable =
        error.code === "failed-precondition" ||
        error.code === "resource-exhausted" ||
        error.httpStatus === 401 ||
        error.httpStatus === 403 ||
        error.httpStatus === 429;

      if (hasPlantId && retriable) {
        console.warn(
          "Pl@ntNet unavailable, falling back to Plant.id:",
          error.message,
        );
        return identifyPlantViaPlantId(data);
      }
      throw error;
    }
  }

  if (hasPlantId) {
    return identifyPlantViaPlantId(data);
  }

  const err = new Error(
    "No plant scanner API key configured (PLANTNET_API_KEY or PLANT_ID_API_KEY).",
  );
  err.code = "failed-precondition";
  throw err;
}

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
  {
    secrets: [...PLANTNET_SECRETS, ...PLANT_ID_SECRETS],
    memory: "512MiB",
    timeoutSeconds: 60,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication required.");
    }

    if (!process.env.PLANTNET_API_KEY && !process.env.PLANT_ID_API_KEY) {
      throw new HttpsError(
        "failed-precondition",
        "No plant scanner API key configured (PLANTNET_API_KEY or PLANT_ID_API_KEY).",
      );
    }

    try {
      return await identifyPlantWithFallback(request.data);
    } catch (error) {
      if (error.code === "invalid-argument") {
        throw new HttpsError("invalid-argument", error.message);
      }
      if (error.code === "failed-precondition") {
        throw new HttpsError("failed-precondition", error.message);
      }
      if (error.code === "resource-exhausted") {
        throw new HttpsError("resource-exhausted", error.message);
      }
      if (error.httpStatus === 401 || error.httpStatus === 403) {
        throw new HttpsError(
          "failed-precondition",
          error.message ||
            "Plant scanner API key is invalid, expired, or blocked for this server IP.",
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

    await writeInboxNotification(sellerId, {
      type: "new_order",
      title: notification.title,
      body: notification.body,
      orderId: event.params.orderId,
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
    if (nextStatus !== "preparing" &&
        nextStatus !== "completed" &&
        nextStatus !== "rejected") return;

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
      sellerMessage: after.sellerMessage,
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

    await writeInboxNotification(buyerId, {
      type: "order_status",
      title: notification.title,
      body: notification.body,
      orderId: event.params.orderId,
      orderStatus: nextStatus,
      status: nextStatus,
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
    const followerIds = [];

    for (const followerDoc of followersSnap.docs) {
      const buyerId = followerDoc.data().buyerId;
      if (!buyerId || buyerId === farmerId) continue;

      const buyerDoc = await getFirestore().collection("users").doc(buyerId).get();
      const token = buyerDoc.data()?.fcmToken;
      if (token) {
        tokens.push(token);
        followerIds.push(buyerId);
      }
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

    await Promise.all(
      followerIds.map((buyerId) =>
        writeInboxNotification(buyerId, {
          type: "new_product",
          title: `${farmerName} ima novi proizvod!`,
          body,
          farmerId,
          productId: event.params.productId,
          farmerName,
          productName,
        }),
      ),
    );

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
    }

    const vetName = after.vetName || "Veterinar";
    const animalName = after.animalName || "životinja";
    const preview =
      responseText.length > 120
        ? `${responseText.slice(0, 117)}...`
        : responseText;

    const pushTitle = "Nalaz veterinara";
    const pushBody = `${vetName} je odgovorio za ${animalName}: ${preview}`;

    if (fcmToken) {
      await getMessaging().send({
        token: fcmToken,
        notification: {
          title: pushTitle,
          body: pushBody,
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
    }

    await writeInboxNotification(clientId, {
      type: "vet_response",
      title: pushTitle,
      body: pushBody,
      requestId: event.params.requestId,
      animalId: after.animalId || "",
      animalName,
      vetName,
    });

    console.log(`Vet response notification sent to client ${clientId}.`);
  },
);

exports.notifyOnVetAppointmentUpdate = onDocumentUpdated(
  "veterinary_requests/{requestId}",
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!after) return;

    const beforeStatus = before?.appointmentStatus || "none";
    const afterStatus = after.appointmentStatus || "none";
    if (beforeStatus === afterStatus) return;

    const vetId = after.vetId;
    const clientId = after.clientId;
    const animalName = after.animalName || "životinja";
    const animalId = after.animalId || "";
    const requestId = event.params.requestId;
    const clientName = after.clientName || "Vlasnik";
    const vetName = after.vetName || "Veterinar";

    const formatTs = (ts) => {
      if (!ts || typeof ts.toDate !== "function") return "";
      try {
        return ts.toDate().toLocaleString("hr-HR");
      } catch (_) {
        return "";
      }
    };

    const appointmentWhen =
      formatTs(after.confirmedAt) ||
      formatTs(after.proposedAt) ||
      formatTs(after.ownerCounterAt);

    if (afterStatus === "counter" && vetId) {
      const title = "Novi prijedlog termina";
      const body = `${clientName} predlaže termin za ${animalName}: ${formatTs(after.ownerCounterAt)}`;
      const vetDoc = await getFirestore().collection("users").doc(vetId).get();
      const token = vetDoc.data()?.fcmToken;
      if (token) {
        await getMessaging().send({
          token,
          notification: { title, body },
          data: {
            type: "vet_intake",
            requestId,
            animalId,
            animalName,
          },
          android: {
            priority: "high",
            notification: { channelId: "high_importance_channel" },
          },
        });
      }
      await writeInboxNotification(vetId, {
        type: "vet_intake",
        title,
        body,
        requestId,
        animalId,
        animalName,
        clientName,
      });
    }

    if (afterStatus === "confirmed") {
      if (beforeStatus === "counter" && clientId) {
        const title = "Termin potvrđen";
        const body = `${vetName} potvrđuje termin za ${animalName}: ${appointmentWhen}`;
        const clientDoc = await getFirestore()
          .collection("users")
          .doc(clientId)
          .get();
        const token = clientDoc.data()?.fcmToken;
        if (token) {
          await getMessaging().send({
            token,
            notification: { title, body },
            data: {
              type: "vet_response",
              requestId,
              animalId,
              vetName,
            },
            android: {
              priority: "high",
              notification: { channelId: "high_importance_channel" },
            },
          });
        }
        await writeInboxNotification(clientId, {
          type: "vet_response",
          title,
          body,
          requestId,
          animalId,
          animalName,
          vetName,
        });
      } else if (vetId) {
        const title = "Termin potvrđen";
        const body = `${clientName} potvrđuje termin za ${animalName}: ${appointmentWhen}`;
        const vetDoc = await getFirestore().collection("users").doc(vetId).get();
        const token = vetDoc.data()?.fcmToken;
        if (token) {
          await getMessaging().send({
            token,
            notification: { title, body },
            data: {
              type: "vet_intake",
              requestId,
              animalId,
              animalName,
            },
            android: {
              priority: "high",
              notification: { channelId: "high_importance_channel" },
            },
          });
        }
        await writeInboxNotification(vetId, {
          type: "vet_intake",
          title,
          body,
          requestId,
          animalId,
          animalName,
          clientName,
        });
      }
    }

    if (afterStatus === "proposed" && beforeStatus === "counter" && clientId) {
      const title = "Novi termin veterinara";
      const body = `${vetName} predlaže novi termin za ${animalName}: ${formatTs(after.proposedAt)}`;
      const clientDoc = await getFirestore().collection("users").doc(clientId).get();
      const token = clientDoc.data()?.fcmToken;
      if (token) {
        await getMessaging().send({
          token,
          notification: { title, body },
          data: {
            type: "vet_response",
            requestId,
            animalId,
            vetName,
          },
          android: {
            priority: "high",
            notification: { channelId: "high_importance_channel" },
          },
        });
      }
      await writeInboxNotification(clientId, {
        type: "vet_response",
        title,
        body,
        requestId,
        animalId,
        animalName,
        vetName,
      });
    }

    if (afterStatus === "declined" && vetId) {
      const title = "Termin odbijen";
      const body = `${clientName} ne može doći na predloženi termin za ${animalName}.`;
      const vetDoc = await getFirestore().collection("users").doc(vetId).get();
      const token = vetDoc.data()?.fcmToken;
      if (token) {
        await getMessaging().send({
          token,
          notification: { title, body },
          data: {
            type: "vet_intake",
            requestId,
            animalId,
            animalName,
          },
          android: {
            priority: "high",
            notification: { channelId: "high_importance_channel" },
          },
        });
      }
      await writeInboxNotification(vetId, {
        type: "vet_intake",
        title,
        body,
        requestId,
        animalId,
        animalName,
        clientName,
      });
    }
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

    await writeInboxNotification(vetId, {
      type: "vet_intake",
      title: "Novi digitalni karton",
      body,
      requestId: event.params.requestId,
      animalName,
      clientName,
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

    await writeInboxNotification(receiverId, {
      type: "chat_message",
      title: senderName,
      body: preview,
      roomId: event.params.roomId,
      senderId,
      senderName,
      messageId: event.params.messageId,
    });

    if (!fcmToken) {
      console.log(`No FCM token for chat receiver ${receiverId}; inbox only.`);
      return;
    }

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
    const stockBefore = Number(before?.stock);
    if (!Number.isFinite(stockAfter) || !Number.isFinite(stockBefore)) {
      return;
    }
    if (stockAfter > 10 || stockBefore <= 10 || stockBefore <= stockAfter) {
      return;
    }

    const sellerDoc = await getFirestore().collection("users").doc(sellerId).get();
    const sellerData = sellerDoc.data() || {};
    const fcmToken = sellerData.fcmToken;

    const productName = after.name || "Proizvod";
    const stockCount = Math.floor(stockAfter);
    const lang = resolveLang(sellerData.preferredLanguage);
    const notification = lowStockNotification({
      lang,
      productName,
      stock: stockCount,
    });

    await writeInboxNotification(sellerId, {
      type: "low_stock",
      title: notification.title,
      body: notification.body,
      productId: event.params.productId,
      productName,
      stockCount,
    });

    if (!fcmToken) {
      console.log(`No FCM token for seller ${sellerId}; inbox only.`);
      return;
    }

    await getMessaging().send({
      token: fcmToken,
      notification: {
        title: notification.title,
        body: notification.body,
      },
      data: {
        type: "low_stock",
        productId: event.params.productId,
        productName,
        stockCount: String(stockCount),
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
  async () => {
    // Forum push is disabled — in-app category indicators only (100k+ scale).
    console.log("Forum new topic: push skipped (in-app only).");
  },
);

exports.notifyTopicAuthorOnForumComment = onDocumentCreated(
  "forum_comments/{commentId}",
  async () => {
    // Forum push is disabled — in-app category indicators only (100k+ scale).
    console.log("Forum reply: push skipped (in-app only).");
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

/** Admin — ukloni profilnu sliku korisnika. */
exports.adminClearUserProfileImage = adminClearUserProfileImage;

/** Admin — trajno obriši korisnički račun. */
exports.adminDeleteUserAccount = adminDeleteUserAccount;
