/**
 * एक पूरे प्रश्नपत्र के प्रश्न हटाता है.
 *
 *   node remove-paper.js uppcs-gs1             # सिर्फ़ दिखाता है
 *   node remove-paper.js uppcs-gs1 --commit    # बैकअप बनाकर हटाता है
 *
 * हटाने से पहले हर प्रश्न `backup-<पेपर>-<तारीख़>.json` में सेव हो जाता है,
 * इसलिए ग़लती लगे तो वापस लाया जा सकता है:
 *
 *   node import.js backup-uppcs-gs1-2026-08-28.json --commit
 *
 * ── सावधानी ──
 *
 * जो प्रश्न एक से ज़्यादा पेपरों में लगे हैं वे छुए नहीं जाते. उन्हें हटाने
 * का मतलब होता किसी दूसरी परीक्षा का प्रश्न चुपचाप ग़ायब कर देना. ऐसे प्रश्न
 * गिनकर बता दिए जाते हैं — फिर आप तय कीजिए.
 */

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

const PAPER = process.argv[2];
const COMMIT = process.argv.includes('--commit');
const COLLECTION = 'questions';

const shared = JSON.parse(
  fs.readFileSync(path.join(__dirname, '..', 'shared', 'exams.json'), 'utf8')
);

if (!PAPER || !shared.papers[PAPER]) {
  console.error(`\nउपयोग: node remove-paper.js <पेपर> [--commit]`);
  console.error(`चलेंगे: ${Object.keys(shared.papers).join(', ')}\n`);
  process.exit(1);
}

const keyPath = path.join(__dirname, '..', 'seed', 'serviceAccountKey.json');
if (!fs.existsSync(keyPath)) {
  console.error('serviceAccountKey.json nahi mili.');
  process.exit(1);
}
admin.initializeApp({ credential: admin.credential.cert(require(keyPath)) });
const db = admin.app().firestore('(default)');

async function main() {
  console.log(COMMIT
    ? `\n⚠️  COMMIT — "${PAPER}" के प्रश्न सचमुच हटेंगे (पहले बैकअप बनेगा).\n`
    : `\n👀 सिर्फ़ दिखा रहा हूँ. हटाने के लिए --commit लगाइए.\n`);

  const snap = await db.collection(COLLECTION).where('papers', 'array-contains', PAPER).get();

  const mine = [];
  const shared_ = [];
  for (const doc of snap.docs) {
    const d = doc.data();
    const papers = Array.isArray(d.papers) ? d.papers : [];
    (papers.length > 1 ? shared_ : mine).push({ id: doc.id, ref: doc.ref, data: d, papers });
  }

  console.log(`"${shared.papers[PAPER].label}" (${PAPER}) में कुल ${snap.size} प्रश्न.`);
  console.log(`   सिर्फ़ इसी पेपर के : ${mine.length}   ← ये हटेंगे`);
  console.log(`   दूसरे पेपरों में भी: ${shared_.length}   ← ये नहीं छुए जाएँगे`);

  if (shared_.length) {
    const other = {};
    for (const h of shared_) {
      for (const p of h.papers) if (p !== PAPER) other[p] = (other[p] || 0) + 1;
    }
    console.log('   (साझा प्रश्न इनमें भी हैं:', JSON.stringify(other) + ')');
  }

  if (!mine.length) {
    console.log('\nहटाने को कुछ नहीं.\n');
    process.exit(0);
  }

  const bySubject = {};
  for (const h of mine) {
    const s = h.data.subject || '—';
    bySubject[s] = (bySubject[s] || 0) + 1;
  }
  console.log('\nविषय-वार:', JSON.stringify(bySubject));

  console.log('\nनमूने:');
  for (const h of mine.slice(0, 5)) {
    console.log(`   ${h.id}: ${String(h.data.question).replace(/\s+/g, ' ').slice(0, 70)}…`);
  }

  if (!COMMIT) {
    console.log(`\n👀 कुछ नहीं हटा. हटाने के लिए:  node remove-paper.js ${PAPER} --commit\n`);
    process.exit(0);
  }

  const stamp = new Date().toISOString().slice(0, 10);
  const backupPath = path.join(__dirname, `backup-${PAPER}-${stamp}.json`);
  fs.writeFileSync(
    backupPath,
    JSON.stringify(
      mine.map((h) => ({
        id: h.id,
        subject: h.data.subject,
        question: h.data.question,
        options: h.data.options,
        answer: h.data.answer,
        explanation: h.data.explanation || '',
        exams: h.data.exams || [],
        ...(h.data.match ? { match: h.data.match } : {}),
      })),
      null,
      1
    )
  );
  console.log(`\n💾 बैकअप बना: ${path.basename(backupPath)}`);
  console.log('   वापस लाने के लिए:');
  console.log(`   node import.js ${path.basename(backupPath)} --commit`);

  let batch = db.batch();
  let pending = 0;
  let done = 0;
  for (const h of mine) {
    batch.delete(h.ref);
    pending++;
    done++;
    if (pending === 400) {
      await batch.commit();
      batch = db.batch();
      pending = 0;
    }
  }
  if (pending > 0) await batch.commit();

  console.log(`\n🧹 ${done} प्रश्न हटा दिए.\n`);
  process.exit(0);
}

main().catch((e) => {
  console.error('❌ fail:', e.message);
  process.exit(1);
});
