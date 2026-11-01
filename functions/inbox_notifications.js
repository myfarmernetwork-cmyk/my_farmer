const { getFirestore, FieldValue } = require("firebase-admin/firestore");

function inboxDocId(data) {
  const type = (data.type || "unknown").trim();
  switch (type) {
    case "new_order":
      return `new_order_${data.orderId || "x"}`;
    case "order_status":
      return `order_status_${data.orderId || "x"}_${data.status || data.orderStatus || "x"}`;
    case "new_product":
      return `new_product_${data.productId || data.farmerId || "x"}`;
    case "vet_response":
      return `vet_response_${data.requestId || data.animalId || "x"}`;
    case "vet_intake":
      return `vet_intake_${data.requestId || "x"}`;
    case "chat_message":
      return `chat_${data.roomId || data.senderId || "x"}_${data.messageId || Date.now()}`;
    case "forum_new_topic":
      return `forum_topic_${data.topicId || "x"}`;
    case "forum_reply":
      return `forum_reply_${data.topicId || "x"}_${data.commentId || "x"}`;
    case "weather_alert":
      return `weather_${data.alertKey || Date.now()}`;
    case "low_stock":
      return `low_stock_${data.productId || "x"}`;
    default:
      return `${type}_${Date.now()}`;
  }
}

async function writeInboxNotification(userId, payload) {
  if (!userId) return;

  const title = (payload.title || "").trim();
  const body = (payload.body || "").trim();
  const type = (payload.type || "").trim();
  if (!type || (!title && !body)) return;

  const docId = inboxDocId(payload);
  const data = {
    type,
    title,
    body,
    createdAt: FieldValue.serverTimestamp(),
    readAt: null,
  };

  const optionalFields = [
    "orderId",
    "orderStatus",
    "status",
    "productId",
    "farmerId",
    "farmerName",
    "productName",
    "requestId",
    "animalId",
    "animalName",
    "vetName",
    "senderId",
    "senderName",
    "topicId",
    "commentId",
    "roomId",
    "messageId",
    "alertKey",
    "weatherAlertKey",
    "clientName",
    "stockCount",
  ];

  for (const key of optionalFields) {
    const value = payload[key];
    if (value != null && `${value}`.trim().length > 0) {
      data[key] = `${value}`.trim();
    }
  }

  if (payload.status && !data.orderStatus) {
    data.orderStatus = `${payload.status}`.trim();
  }
  if (payload.alertKey && !data.weatherAlertKey) {
    data.weatherAlertKey = `${payload.alertKey}`.trim();
  }

  await getFirestore()
    .collection("users")
    .doc(userId)
    .collection("inbox_notifications")
    .doc(docId)
    .set(data, { merge: true });
}

module.exports = {
  inboxDocId,
  writeInboxNotification,
};
