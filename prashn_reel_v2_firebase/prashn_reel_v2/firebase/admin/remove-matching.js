/**
 * सुमेलित (सूची-I ↔ सूची-II मिलान) वाले प्रश्न ढूँढ़कर हटाता है.
 *
 * ये प्रश्न रील के कार्ड में ठीक नहीं बैठते — दो सूचियाँ और कूट मिलाकर
 * इतने लंबे हो जाते हैं कि स्क्रीन पर पढ़ना मुश्किल हो जाता है.
 *
 *   node remove-matching.js             # सिर्फ़ दिखाता है
 *   node remove-matching.js --commit    # बैकअप बनाकर हटाता है
 *
 * हटाने से पहले हर प्रश्न `backup-matching-<तारीख़>.json` में सेव हो जाता है,
 * इसलिए ग़लती लगे तो `import.js` से वापस डाला जा सकता है.
 */

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

const COMMIT = process.argv.includes('--commit');
const COLLECTION = 'questions';

admin.initializeApp({
  credential: admin.credential.cert(
    require(path.join(__dirname, '..', 'seed', 'serviceAccountKey.json'))
  ),
});
const db = admin.app().firestore('(default)');

/** सुमेलित वाले प्रश्न पहचानने के निशान. */
const MARKS = [
  /सुमेलित/,
  /सूची\s*[-–—]?\s*(I|II|1|2|एक|दो)\b/,
  /मिलान\s*कीजिए/,
  /निम्नलिखित\s*का\s*मिलान/,
  /कूट\s*[:：]/,
];

/** विकल्प "A-1, B-2, C-3, D-4" जैसे हों तो भी मिलान वाला प्रश्न है. */
const CODE_OPTION = /^[A-Dअ-द]\s*[-–—]\s*\d[\s,;]+[A-Dअ-द]\s*[-–—]\s*\d/;

function isMatching(d) {
  const q = String(d.question ?? '');
  if (MARKS.some((re) => re.test(q))) return true;

  const opts = Array.isArray(d.options) ? d.options : [];
  const coded = opts.filter((o) => CODE_OPTION.test(String(o).trim()));
  // चारों विकल्प कूट जैसे हों तभी — एक-दो हों तो शायद कुछ और है
  return coded.length >= 3;
}

async function main() {
  console.log(COMMIT
    ? '\n⚠️  COMMIT — प्रश्न सचमुच हटेंगे (पहले बैकअप बनेगा).\n'
    : '\n👀 सिर्फ़ दिखा रहा हूँ. हटाने के लिए --commit लगाइए.\n');

  const snap = await db.collection(COLLECTION).get();
  const hit = [];

  for (const doc of snap.docs) {
    const d = doc.data();
    if (isMatching(d)) hit.push({ id: doc.id, ref: doc.ref, data: d });
  }

  if (!hit.length) {
    console.log('कोई सुमेलित प्रश्न नहीं मिला।');
    process.exit(0);
  }

  // पुराने (seed/brahm) और नए (imp) अलग-अलग गिन लेते हैं
  const older = hit.filter((h) => !h.id.startsWith('imp-'));
  const newer = hit.filter((h) => h.id.startsWith('imp-'));

  console.log(`कुल ${snap.size} में से ${hit.length} सुमेलित वाले मिले:`);
  console.log(`   पुराने संग्रह से : ${older.length}`);
  console.log(`   नए आयात से      : ${newer.length}\n`);

  const bySubject = {};
  for (const h of hit) {
    const s = h.data.subject || '—';
    bySubject[s] = (bySubject[s] || 0) + 1;
  }
  console.log('विषय-वार:', JSON.stringify(bySubject), '\n');

  console.log('नमूने:');
  for (const h of hit.slice(0, 5)) {
    console.log(`   ${h.id}: ${String(h.data.question).slice(0, 72)}…`);
  }
  if (hit.length > 5) console.log(`   … और ${hit.length - 5}\n`);

  if (!COMMIT) {
    console.log('👀 कुछ नहीं हटा. हटाने के लिए:  node remove-matching.js --commit\n');
    process.exit(0);
  }

  // ── बैकअप ──
  const stamp = new Date().toISOString().slice(0, 10);
  const backupPath = path.join(__dirname, `backup-matching-${stamp}.json`);
  fs.writeFileSync(
    backupPath,
    JSON.stringify(
      hit.map((h) => ({
        id: h.id,
        subject: h.data.subject,
        question: h.data.question,
        options: h.data.options,
        answer: h.data.answer,
        explanation: h.data.explanation || '',
        exams: h.data.exams || [],
      })),
      null,
      1
    )
  );
  console.log(`💾 बैकअप बना: ${path.basename(backupPath)}`);
  console.log('   ग़लती लगे तो वापस लाने के लिए:');
  console.log(`   node import.js ${path.basename(backupPath)} --commit\n`);

  // ── हटाना ──
  let batch = db.batch();
  let pending = 0;
  let done = 0;
  for (const h of hit) {
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

  const after = await db.collection(COLLECTION).get();
  console.log(`🧹 ${done} प्रश्न हटा दिए. अब कुल ${after.size} बचे.\n`);
  process.exit(0);
}

main().catch((e) => {
  console.error('❌ fail:', e.message);
  process.exit(1);
});
