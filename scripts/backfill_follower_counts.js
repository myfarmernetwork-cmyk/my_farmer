/**
 * One-time backfill: users/{farmerId}.followerCount from followers collection.
 *
 * Windows (bez gcloud SDK-a):
 *   1. Firebase Console -> Project Settings -> Service accounts -> Generate new private key
 *   2. Spremi JSON kao scripts/firebase-admin-key.json (ne commitaj!)
 *   3. node scripts/backfill_follower_counts.js
 *
 * Ili:
 *   node scripts/backfill_follower_counts.js --key=C:\path\to\key.json
 */

const fs = require('fs');
const path = require('path');

const admin = require('../functions/node_modules/firebase-admin');

const projectId = process.env.FIREBASE_PROJECT_ID || 'my-farmer-552a3';
const repoRoot = path.join(__dirname, '..');

function resolveKeyPath() {
  const arg = process.argv.find((a) => a.startsWith('--key='));
  if (arg) return path.resolve(arg.slice('--key='.length));

  const envKey = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (envKey && fs.existsSync(envKey)) return path.resolve(envKey);

  const defaultKey = path.join(__dirname, 'firebase-admin-key.json');
  if (fs.existsSync(defaultKey)) return defaultKey;

  return null;
}

const keyPath = resolveKeyPath();

if (!admin.apps.length) {
  if (keyPath) {
    const serviceAccount = JSON.parse(fs.readFileSync(keyPath, 'utf8'));
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId: serviceAccount.project_id || projectId,
    });
    console.log(`Using service account: ${path.basename(keyPath)}`);
  } else {
    admin.initializeApp({ projectId });
    console.log('Using Application Default Credentials (gcloud ADC)...');
  }
}

const db = admin.firestore();

async function main() {
  console.log(`Backfilling followerCount for project ${projectId}...`);

  const snapshot = await db.collection('followers').get();
  const counts = new Map();

  snapshot.forEach((doc) => {
    const farmerId = doc.data()?.farmerId?.toString?.() ?? '';
    if (!farmerId) return;
    counts.set(farmerId, (counts.get(farmerId) ?? 0) + 1);
  });

  console.log(`Found ${snapshot.size} follower docs for ${counts.size} farmers.`);

  if (counts.size === 0) {
    console.log('Nothing to update.');
    return;
  }

  let batch = db.batch();
  let ops = 0;
  let updated = 0;

  for (const [farmerId, count] of counts.entries()) {
    batch.set(
      db.collection('users').doc(farmerId),
      { followerCount: count },
      { merge: true },
    );
    ops += 1;
    updated += 1;

    if (ops >= 400) {
      await batch.commit();
      batch = db.batch();
      ops = 0;
    }
  }

  if (ops > 0) {
    await batch.commit();
  }

  console.log(`Done. Updated followerCount on ${updated} user documents.`);
}

main().catch((err) => {
  if (
    err.message?.includes('Could not load the default credentials') ||
    err.message?.includes('default credentials')
  ) {
    console.error('');
    console.error('Nema pristupnih podataka. Bez gcloud SDK-a uradi ovako:');
    console.error('  1. Otvori https://console.firebase.google.com/project/my-farmer-552a3/settings/serviceaccounts/adminsdk');
    console.error('  2. "Generate new private key" -> spremi JSON');
    console.error(`  3. Kopiraj u: ${path.join(__dirname, 'firebase-admin-key.json')}`);
    console.error('  4. Ponovo pokreni: node scripts/backfill_follower_counts.js');
    console.error('');
  }
  console.error(err);
  process.exit(1);
});
