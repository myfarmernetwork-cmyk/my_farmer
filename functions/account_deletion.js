const { getAuth } = require("firebase-admin/auth");
const { getFirestore, FieldValue, Timestamp } = require("firebase-admin/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");

function parseDate(value) {
  if (!value) return null;
  if (value instanceof Date) return value;
  if (typeof value.toDate === "function") return value.toDate();
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

async function deleteSubcollection(docRef, subcollectionName) {
  const db = getFirestore();
  const snap = await docRef.collection(subcollectionName).get();
  if (snap.empty) return;

  let batch = db.batch();
  let count = 0;
  for (const doc of snap.docs) {
    batch.delete(doc.ref);
    count += 1;
    if (count >= 400) {
      await batch.commit();
      batch = db.batch();
      count = 0;
    }
  }
  if (count > 0) {
    await batch.commit();
  }
}

async function hideSellerProducts(uid) {
  const db = getFirestore();
  const products = await db.collection("products").where("sellerId", "==", uid).get();
  if (products.empty) return;

  let batch = db.batch();
  let count = 0;
  for (const doc of products.docs) {
    batch.update(doc.ref, {
      isSoldOut: true,
      accountDeletedAt: FieldValue.serverTimestamp(),
    });
    count += 1;
    if (count >= 400) {
      await batch.commit();
      batch = db.batch();
      count = 0;
    }
  }
  if (count > 0) {
    await batch.commit();
  }
}

async function purgeUserData(uid) {
  const db = getFirestore();
  const userRef = db.collection("users").doc(uid);

  await deleteSubcollection(userRef, "payment_methods");
  await deleteSubcollection(userRef, "weather_alert_state");
  await hideSellerProducts(uid);
  await userRef.delete();
}

function resolveDeletionSchedule(data, clientExpiresAt) {
  const now = new Date();
  const expiresAt =
    parseDate(data.subscriptionExpiresAt) || parseDate(clientExpiresAt);

  const hasPremiumFlag = data.premiumActive === true;
  const hasTier =
    typeof data.subscriptionTier === "string" &&
    data.subscriptionTier.trim().length > 0;

  if (expiresAt && expiresAt > now && (hasPremiumFlag || hasTier)) {
    return { scheduledAt: expiresAt, keepAccessUntilExpiry: true };
  }

  if (hasPremiumFlag && !expiresAt) {
    const fallback = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000);
    return { scheduledAt: fallback, keepAccessUntilExpiry: true };
  }

  return { scheduledAt: now, keepAccessUntilExpiry: false };
}

async function finalizeAccountDeletion(uid) {
  const auth = getAuth();
  try {
    await auth.updateUser(uid, { disabled: true });
  } catch (_) {
    // User may already be disabled or missing.
  }

  await purgeUserData(uid);

  try {
    await auth.deleteUser(uid);
  } catch (_) {
    // Auth user may already be deleted.
  }
}

const requestAccountDeletion = onCall(async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Login required.");
  }

  const uid = request.auth.uid;
  const db = getFirestore();
  const userRef = db.collection("users").doc(uid);
  const userDoc = await userRef.get();

  if (!userDoc.exists) {
    throw new HttpsError("not-found", "User not found.");
  }

  const data = userDoc.data() || {};
  if (data.status === "PENDING_DELETION") {
    throw new HttpsError("already-exists", "Account deletion already requested.");
  }
  if (data.isAdmin === true) {
    throw new HttpsError("permission-denied", "Admin accounts cannot be deleted here.");
  }

  const { scheduledAt, keepAccessUntilExpiry } = resolveDeletionSchedule(
    data,
    request.data?.subscriptionExpiresAt,
  );

  await userRef.update({
    accountDeletionRequestedAt: FieldValue.serverTimestamp(),
    accountDeletionScheduledAt: Timestamp.fromDate(scheduledAt),
    status: "PENDING_DELETION",
    isPublicProfile: false,
    isActive: keepAccessUntilExpiry,
    ...(keepAccessUntilExpiry ? {} : { fcmToken: FieldValue.delete() }),
  });

  if (!keepAccessUntilExpiry) {
    await finalizeAccountDeletion(uid);
  }

  return {
    scheduledAt: scheduledAt.toISOString(),
    keepAccessUntilExpiry,
    deletedImmediately: !keepAccessUntilExpiry,
  };
});

const purgeScheduledAccountDeletions = onSchedule(
  {
    schedule: "every 24 hours",
    timeZone: "Europe/Sarajevo",
    memory: "256MiB",
  },
  async () => {
    const db = getFirestore();
    const now = Timestamp.now();
    const snap = await db
      .collection("users")
      .where("status", "==", "PENDING_DELETION")
      .where("accountDeletionScheduledAt", "<=", now)
      .limit(50)
      .get();

    for (const doc of snap.docs) {
      await finalizeAccountDeletion(doc.id);
    }
  },
);

module.exports = {
  requestAccountDeletion,
  purgeScheduledAccountDeletions,
  finalizeAccountDeletion,
  resolveDeletionSchedule,
};
