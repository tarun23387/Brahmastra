/**
 * 150 seed questions ko Firestore me upload karta hai.
 *
 * Chalane se pehle:
 *   1. Firebase Console -> Project settings -> Service accounts
 *      -> "Generate new private key" -> file ko yahin `serviceAccountKey.json` naam se rakhein
 *   2. npm install
 *   3. npm run upload
 *
 * Dobara chalane par purane docs overwrite ho jayenge (same id), duplicate nahi banenge.
 */

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

const keyPath = path.join(__dirname, 'serviceAccountKey.json');
if (!fs.existsSync(keyPath)) {
  console.error('❌ serviceAccountKey.json nahi mili. README ka Step 3 dekhein.');
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(require(keyPath)),
});

const db = admin.app().firestore('(default)');
const COLLECTION = 'questions';

async function main() {
  const questions = JSON.parse(
    fs.readFileSync(path.join(__dirname, 'questions.json'), 'utf8')
  );

  console.log(`📦 ${questions.length} prashn upload ho rahe hain…`);

  let batch = db.batch();
  let pending = 0;
  let done = 0;

  for (const q of questions) {
    const ref = db.collection(COLLECTION).doc(q.id);
    batch.set(
      ref,
      {
        subject: q.subject,
        question: q.question,
        options: q.options,
        answer: q.answer,
        explanation: q.explanation,
        difficulty: q.difficulty || 'moderate',
        source: 'seed',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        // NOTE: seed prashno par `expiresAt` field jaan-boojh kar nahi lagayi ja rahi.
        // Cleanup function sirf un docs ko dekhta hai jinme yeh field hoti hai,
        // isliye ye 150 core questions kabhi delete nahi honge.
      },
      { merge: true }
    );

    pending++;
    done++;

    if (pending === 400) {
      await batch.commit();
      batch = db.batch();
      pending = 0;
      console.log(`   … ${done}/${questions.length}`);
    }
  }

  if (pending > 0) await batch.commit();

  const counts = {};
  for (const q of questions) counts[q.subject] = (counts[q.subject] || 0) + 1;

  console.log(`✅ Ho gaya — ${questions.length} prashn '${COLLECTION}' collection me.`);
  console.log('   Vishay-wise:', counts);
  process.exit(0);
}

main().catch((e) => {
  console.error('❌ Upload fail hua:', e);
  process.exit(1);
});
