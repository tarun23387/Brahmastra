/**
 * मौजूदा प्रश्नों की परीक्षा बदलता है.
 *
 *   node retag.js roaro              # दिखाता है — सब RO/ARO के हो जाएँगे
 *   node retag.js roaro --commit     # असल में बदलता है
 *   node retag.js roaro --only imp   # सिर्फ़ imp- से शुरू होने वाले
 *
 * ज़रूरत क्यों: पहले हर प्रश्न अपने आप तीनों परीक्षाओं में चला जाता था.
 * अब हर परीक्षा के प्रश्न अलग रखने हैं, इसलिए पुराने सब RO/ARO के कर देते हैं
 * और UPPCS/PET तब तक ख़ाली रहेंगी जब तक उनके अपने प्रश्न न आ जाएँ.
 */

const path = require('path');
const admin = require('firebase-admin');
const { tagsFor } = require('./taxonomy');

const COMMIT = process.argv.includes('--commit');
const COLLECTION = 'questions';

const exams = (process.argv[2] || '')
  .split(',')
  .map((s) => s.trim())
  .filter(Boolean);

if (!exams.length) {
  console.log('\nउपयोग:  node retag.js roaro [--commit] [--only <prefix>]\n');
  process.exit(1);
}

const onlyIdx = process.argv.indexOf('--only');
const onlyPrefix = onlyIdx >= 0 ? process.argv[onlyIdx + 1] : null;

admin.initializeApp({
  credential: admin.credential.cert(
    require(path.join(__dirname, '..', 'seed', 'serviceAccountKey.json'))
  ),
});
const db = admin.app().firestore('(default)');

async function main() {
  console.log(COMMIT
    ? `\n⚠️  COMMIT — प्रश्न ${exams.join(', ')} के कर दिए जाएँगे.\n`
    : `\n👀 सिर्फ़ दिखा रहा हूँ. बदलने के लिए --commit लगाइए.\n`);

  const snap = await db.collection(COLLECTION).get();

  const targets = snap.docs.filter(
    (d) => !onlyPrefix || d.id.startsWith(onlyPrefix)
  );

  const changes = [];
  const perPaper = {};

  for (const doc of targets) {
    const d = doc.data();
    const t = tagsFor(d.subject, exams);

    for (const p of t.papers) perPaper[p] = (perPaper[p] || 0) + 1;

    const same =
      Array.isArray(d.papers) &&
      d.papers.length === t.papers.length &&
      t.papers.every((p) => d.papers.includes(p));

    if (!same) changes.push({ ref: doc.ref, ...t });
  }

  console.log(`${snap.size} में से ${targets.length} देखे गए.`);
  console.log(`${changes.length} पर टैग बदलेंगे.\n`);

  console.log('बदलने के बाद प्रश्नपत्र-वार:');
  for (const [p, n] of Object.entries(perPaper).sort((a, b) => b[1] - a[1])) {
    console.log(`   ${p.padEnd(13)} ${n}`);
  }

  const untouched = snap.size - targets.length;
  if (untouched) console.log(`\n(${untouched} प्रश्न छुए ही नहीं गए)`);

  if (!COMMIT) {
    console.log('\n👀 कुछ नहीं बदला. बदलने के लिए --commit\n');
    process.exit(0);
  }

  let batch = db.batch();
  let pending = 0;
  let done = 0;

  for (const c of changes) {
    batch.set(
      c.ref,
      {
        exams: c.exams,
        papers: c.papers,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    pending++;
    done++;
    if (pending === 400) {
      await batch.commit();
      batch = db.batch();
      pending = 0;
    }
  }
  if (pending > 0) await batch.commit();

  console.log(`\n✅ ${done} प्रश्नों पर टैग बदल गए.\n`);
  process.exit(0);
}

main().catch((e) => {
  console.error('❌ fail:', e.message);
  process.exit(1);
});
