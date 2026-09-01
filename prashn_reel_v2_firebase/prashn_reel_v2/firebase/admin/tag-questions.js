/**
 * Purane 271 prashno par exam/paper tags lagata hai.
 *
 * Ek hi prashn kai exam me chalta hai — UP ke itihas wala prashn UPPCS,
 * RO/ARO aur PET teeno me kaam aata hai. Isliye `exams` aur `papers`
 * dono arrays hain, single value nahi.
 *
 * Chalane ka tarika:
 *
 *   node tag-questions.js            # sirf dikhata hai, kuch badalta nahi
 *   node tag-questions.js --commit   # asli me Firestore me likhta hai
 *
 * Bina --commit ke yeh database ko chhoota tak nahi.
 */

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

const COMMIT = process.argv.includes('--commit');
const COLLECTION = 'questions';

/* ── taxonomy ── */

const shared = JSON.parse(
  fs.readFileSync(path.join(__dirname, '..', 'shared', 'exams.json'), 'utf8')
);

// vishay se paper — lib/exams.dart ke kSubjectToPapers jaisa hi
const SUBJECT_TO_PAPERS = {
  itihas: ['uppcs-gs1', 'roaro-gs', 'pet-main'],
  polity: ['uppcs-gs1', 'roaro-gs', 'pet-main'],
  bhugol: ['uppcs-gs1', 'roaro-gs', 'pet-main'],
  arth: ['uppcs-gs1', 'roaro-gs', 'pet-main'],
  vigyan: ['uppcs-gs1', 'roaro-gs', 'pet-main'],
  up: ['uppcs-gs1', 'roaro-gs', 'pet-main'],
  ca: ['uppcs-gs1', 'roaro-gs', 'pet-main'],
  hindi: ['roaro-hindi', 'pet-main', 'uppcs-csat'],
  english: ['pet-main', 'uppcs-csat'],
  ganit: ['pet-main', 'uppcs-csat'],
  reasoning: ['pet-main', 'uppcs-csat'],
  comprehension: ['pet-main', 'uppcs-csat'],
  graph: ['pet-main'],
};

function examsForPapers(papers) {
  const set = new Set();
  for (const p of papers) {
    const paper = shared.papers[p];
    if (paper) set.add(paper.exam);
  }
  return [...set].sort();
}

/* ── firebase ── */

const keyPath = path.join(__dirname, '..', 'seed', 'serviceAccountKey.json');
if (!fs.existsSync(keyPath)) {
  console.error('❌ serviceAccountKey.json nahi mili.');
  process.exit(1);
}
admin.initializeApp({ credential: admin.credential.cert(require(keyPath)) });
const db = admin.app().firestore('(default)');

/* ── main ── */

async function main() {
  console.log(COMMIT
    ? '⚠️  COMMIT MODE — Firestore me asli badlav honge.\n'
    : '👀 DRY RUN — sirf dikha raha hoon, kuch nahi badlega.\n     Asli me chalane ke liye:  node tag-questions.js --commit\n');

  const snap = await db.collection(COLLECTION).get();
  console.log(`📦 ${snap.size} prashn mile.\n`);

  const perPaper = {};
  const perExam = {};
  const unknown = [];
  const alreadyTagged = [];
  const toWrite = [];

  for (const doc of snap.docs) {
    const d = doc.data();
    const subject = d.subject;
    const papers = SUBJECT_TO_PAPERS[subject];

    if (!papers) {
      unknown.push({ id: doc.id, subject });
      continue;
    }

    const exams = examsForPapers(papers);
    for (const p of papers) perPaper[p] = (perPaper[p] || 0) + 1;
    for (const e of exams) perExam[e] = (perExam[e] || 0) + 1;

    // pehle se sahi tag lage hain to chhod dete hain
    const same =
      Array.isArray(d.papers) &&
      d.papers.length === papers.length &&
      papers.every((p) => d.papers.includes(p));
    if (same) {
      alreadyTagged.push(doc.id);
      continue;
    }

    toWrite.push({ ref: doc.ref, exams, papers });
  }

  /* ── report ── */

  console.log('परीक्षा के हिसाब से:');
  for (const [e, n] of Object.entries(perExam).sort((a, b) => b[1] - a[1])) {
    const label = shared.exams[e]?.shortLabel || e;
    console.log(`   ${label.padEnd(10)} ${n} प्रश्न`);
  }

  console.log('\nप्रश्नपत्र के हिसाब से:');
  for (const [p, n] of Object.entries(perPaper).sort((a, b) => b[1] - a[1])) {
    const paper = shared.papers[p];
    const need = paper ? paper.questions : 0;
    const bar = need ? `  (एक पेपर में ${need} आते हैं)` : '';
    console.log(`   ${p.padEnd(13)} ${String(n).padStart(4)} प्रश्न${bar}`);
  }

  if (unknown.length) {
    console.log(`\n⚠️  ${unknown.length} प्रश्न ऐसे जिनका विषय पहचाना नहीं गया:`);
    for (const u of unknown.slice(0, 10)) console.log(`   ${u.id} → "${u.subject}"`);
    if (unknown.length > 10) console.log(`   … और ${unknown.length - 10}`);
  }

  if (alreadyTagged.length) {
    console.log(`\n✔️  ${alreadyTagged.length} प्रश्न पहले से सही टैग हैं — छोड़ दिए.`);
  }

  console.log(`\n📝 ${toWrite.length} प्रश्नों पर टैग लगेंगे.`);

  if (!COMMIT) {
    if (toWrite.length) {
      const s = toWrite[0];
      console.log('\n   नमूना — पहले प्रश्न पर यह लगेगा:');
      console.log(`   exams:  [${s.exams.join(', ')}]`);
      console.log(`   papers: [${s.papers.join(', ')}]`);
    }
    console.log('\n👀 DRY RUN था — Firestore में कुछ नहीं बदला.');
    process.exit(0);
  }

  /* ── commit ── */

  let batch = db.batch();
  let pending = 0;
  let done = 0;

  for (const { ref, exams, papers } of toWrite) {
    batch.set(ref, {
      exams,
      papers,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    pending++;
    done++;
    if (pending === 400) {
      await batch.commit();
      batch = db.batch();
      pending = 0;
      console.log(`   … ${done}/${toWrite.length}`);
    }
  }
  if (pending > 0) await batch.commit();

  console.log(`\n✅ ${done} प्रश्नों पर टैग लग गए.`);
  process.exit(0);
}

main().catch((e) => {
  console.error('❌ fail:', e);
  process.exit(1);
});
