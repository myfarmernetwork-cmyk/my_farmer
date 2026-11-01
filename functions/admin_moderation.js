const { getAuth } = require("firebase-admin/auth");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getStorage } = require("firebase-admin/storage");
const { onCall, HttpsError } = require("firebase-functions/v2/https");

const { finalizeAccountDeletion } = require("./account_deletion");

async function isAdminUid(uid) {
  if (!uid) return false;
  const doc = await getFirestore().collection("users").doc(uid).get();
  if (!doc.exists) return false;
  const data = doc.data() || {};
  return data.role === "admin" || data.isAdmin === true;
}

async function assertCallerIsAdmin(request) {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Login required.");
  }
  if (!(await isAdminUid(request.auth.uid))) {
    throw new HttpsError("permission-denied", "Admin access required.");
  }
  return request.auth.uid;
}

async function deleteStorageUrl(url) {
  const trimmed = (url || "").trim();
  if (!trimmed) return;

  try {
    const bucket = getStorage().bucket();
    const match = trimmed.match(/\/o\/(.+?)(\?|$)/);
    if (match?.[1]) {
      const objectPath = decodeURIComponent(match[1]);
      await bucket.file(objectPath).delete({ ignoreNotFound: true });
    }
  } catch (_) {
    // Best effort — profile URL may already be gone.
  }
}

async function deleteProfileImageForUser(uid, profileImageUrl) {
  try {
    const bucket = getStorage().bucket();
    await bucket.file(`user_profiles/${uid}.jpg`).delete({ ignoreNotFound: true });
  } catch (_) {}

  await deleteStorageUrl(profileImageUrl);
}

async function deleteUserCommunityPosts(uid) {
  const db = getFirestore();
  const seen = new Set();

  async function purgeSnapshot(snapshot) {
    for (const doc of snapshot.docs) {
      if (seen.has(doc.id)) continue;
      seen.add(doc.id);
      const imageUrl = doc.data()?.imageUrl;
      await deleteStorageUrl(imageUrl);
      await doc.ref.delete();
    }
  }

  const byAuthor = await db
    .collection("community_posts")
    .where("authorId", "==", uid)
    .get();
  await purgeSnapshot(byAuthor);

  const byUser = await db
    .collection("community_posts")
    .where("userId", "==", uid)
    .get();
  await purgeSnapshot(byUser);
}

const adminClearUserProfileImage = onCall(async (request) => {
  await assertCallerIsAdmin(request);

  const targetUid = (request.data?.targetUid || "").trim();
  if (!targetUid) {
    throw new HttpsError("invalid-argument", "Missing targetUid.");
  }

  const db = getFirestore();
  const userRef = db.collection("users").doc(targetUid);
  const userDoc = await userRef.get();
  if (!userDoc.exists) {
    throw new HttpsError("not-found", "User not found.");
  }

  const profileImageUrl = userDoc.data()?.profileImageUrl;
  await deleteProfileImageForUser(targetUid, profileImageUrl);

  await userRef.update({
    profileImageUrl: FieldValue.delete(),
    updatedAt: FieldValue.serverTimestamp(),
  });

  return { success: true };
});

const adminDeleteUserAccount = onCall(async (request) => {
  const callerUid = await assertCallerIsAdmin(request);

  const targetUid = (request.data?.targetUid || "").trim();
  if (!targetUid) {
    throw new HttpsError("invalid-argument", "Missing targetUid.");
  }
  if (targetUid === callerUid) {
    throw new HttpsError(
      "permission-denied",
      "You cannot delete your own admin account here.",
    );
  }

  const db = getFirestore();
  const userRef = db.collection("users").doc(targetUid);
  const userDoc = await userRef.get();
  if (!userDoc.exists) {
    throw new HttpsError("not-found", "User not found.");
  }

  const data = userDoc.data() || {};
  if (data.role === "admin" || data.isAdmin === true) {
    throw new HttpsError(
      "permission-denied",
      "Other admin accounts cannot be deleted here.",
    );
  }

  await deleteProfileImageForUser(targetUid, data.profileImageUrl);
  await deleteUserCommunityPosts(targetUid);
  await finalizeAccountDeletion(targetUid);

  return { success: true };
});

module.exports = {
  adminClearUserProfileImage,
  adminDeleteUserAccount,
  isAdminUid,
};
