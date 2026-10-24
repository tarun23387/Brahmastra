/**
 * चुने हुए प्रश्नों को बदलना या हटाना — पूरा collection पढ़े बिना.
 *
 *   node patch-questions.js fixes.json [more.json …]            # सिर्फ़ दिखाता है
 *   node patch-questions.js fixes.json [more.json …] --commit   # बैकअप बनाकर लिखता है
 *
 * फ़ाइल का रूप:
 *
 *   {
 *     "delete": { "imp-0025": "दोहराव — seed-016" },
 *     "update": {
 *       "imp-0267": { "answer": 2, "explanation": "…", "_why": "ग़लत उत्तर" },
 *       "seed-087": { "exams": ["uppcs"] }
 *     }
 *   }
 *
 * कई फ़ाइलें दें तो एक ही id के बदलाव आपस में जुड़ जाते हैं (बाद वाली
 * फ़ाइल की फ़ील्ड आगे). '_' से शुरू होने वाली कुंजियाँ सिर्फ़ टिप्पणी हैं.
 *
 * ── यह क्यों ──
 *
 * import.js हर बार पूरा `questions` collection पढ़ता है (~3.8k reads), और
 * Spark plan पर रोज़ के 50,000 reads छात्रों के साथ साझा हैं. यह लिपि
 * सिर्फ़ उन्हीं documents को पढ़ती है जिनकी id फ़ाइल में है.
 *
 * `subject` या `exams` बदले तो `papers` taxonomy.js से दोबारा बनते हैं —
 * import.js की तरह. जाँच भी वही है जो import.js करता है.
 *
 * ⚠️ प्रश्न का पाठ बदलने पर यह नहीं देखा जाता कि वैसा प्रश्न कहीं और पहले
 *    से है या नहीं (उसके लिए पूरा collection पढ़ना पड़ता).
 *
 * लिखने के बाद packs दोबारा बनाइए: node build-packs.js --commit
 */

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');
const { tagsFor } = require('./taxonomy');

const COLLECTION = 'questions';

const shared = JSON.parse(
  fs.readFileSync(path.join(__dirname, '..', 'shared', 'exams.json'), 'utf8')
);

const keyPath = path.join(__dirname, '..', 'seed', 'serviceAccountKey.json');
if (!fs.existsSync(keyPath)) {
  console.error('❌ serviceAccountKey.json nahi mili.');
  process.exit(1);
}
admin.initializeApp({ credential: admin.credential.cert(require(keyPath)) });
const db = admin.app().firestore('(default)');

/** फ़ील्ड जो बदली जा सकती हैं — बाक़ी कुछ आया तो टाइपो मानकर रोक देते हैं. */
const FIELDS = new Set([
  'subject', 'exams', 'question', 'options', 'answer', 'explanation',
  'difficulty', 'match', 'year', 'free',
]);

/** ऐप LaTeX नहीं बनाता — '$82^\circ$' जैसा पाठ ज्यों का त्यों छपता है. */
const LATEX = /\$|\\[a-zA-Z]+/;

/* ───────────────────────── फ़ाइलें पढ़ना ───────────────────────── */

function loadFixes(files) {
  const del = new Map();
  const upd = new Map();
  for (const f of files) {
    const j = JSON.parse(fs.readFileSync(f, 'utf8'));
    for (const [id, why] of Object.entries(j.delete || {})) del.set(id, why);
    for (const [id, fields] of Object.entries(j.update || {})) {
      const clean = Object.fromEntries(
        Object.entries(fields).filter(([k]) => !k.startsWith('_'))
      );
      upd.set(id, { ...(upd.get(id) || {}), ...clean });
    }
  }
  return { del, upd };
}

/* ───────────────────────── जाँच ───────────────────────── */

/** import.js के check() जैसे ही नियम, पर पूरे बने हुए document पर. */
function check(d) {
  const errors = [];
  const warnings = [];

  if (!String(d.question ?? '').trim()) errors.push('प्रश्न खाली है');

  const opts = Array.isArray(d.options) ? d.options.map((o) => String(o).trim()) : null;
  if (!opts || opts.length !== 4) errors.push('ठीक 4 विकल्प चाहिए');
  else if (opts.some((o) => !o)) errors.push('कोई विकल्प खाली है');
  else if (new Set(opts).size !== 4) errors.push('दो विकल्प एक जैसे हैं');

  if (!Number.isInteger(d.answer) || d.answer < 0 || d.answer > 3) {
    errors.push(`answer 0 से 3 के बीच होना चाहिए, मिला "${d.answer}"`);
  }
  if (!shared.subjects[d.subject]) errors.push(`विषय "${d.subject}" पहचाना नहीं गया`);

  const badExams = (d.exams || []).filter((e) => !shared.exams[e]);
  if (badExams.length) errors.push(`अनजान परीक्षा: ${badExams.join(', ')}`);
  // paper न लगे तो प्रश्न ऐप में कहीं नहीं दिखता — जैसे net-cs पर 'itihas'.
  if (!d.papers || !d.papers.length) errors.push('कोई प्रश्नपत्र नहीं लगा — प्रश्न कहीं नहीं दिखेगा');

  const texts = [d.question, ...(d.options || []), d.explanation || ''];
  if (texts.some((t) => LATEX.test(String(t)))) warnings.push('LaTeX जैसा पाठ ($ या \\) — ऐप में ज्यों का त्यों छपेगा');
  if (!String(d.explanation ?? '').trim()) warnings.push('व्याख्या नहीं है');

  return { errors, warnings };
}

/* ───────────────────────── main ───────────────────────── */

async function main() {
  const COMMIT = process.argv.includes('--commit');
  const files = process.argv.slice(2).filter((a) => !a.startsWith('--'));
  if (!files.length) {
    console.log('\nउपयोग:  node patch-questions.js <fixes.json> [more.json …] [--commit]\n');
    process.exit(1);
  }

  const { del, upd } = loadFixes(files);
  const both = [...del.keys()].filter((id) => upd.has(id));
  if (both.length) {
    console.error(`❌ ये id हटाने और बदलने, दोनों में हैं: ${both.join(', ')}`);
    process.exit(1);
  }
  for (const [id, f] of upd) {
    const unknown = Object.keys(f).filter((k) => !FIELDS.has(k));
    if (unknown.length) {
      console.error(`❌ ${id}: अनजान फ़ील्ड ${unknown.join(', ')}`);
      process.exit(1);
    }
  }

  console.log(COMMIT
    ? '\n⚠️  COMMIT — Firestore में असल बदलाव होंगे.\n'
    : '\n👀 सिर्फ़ जाँच — कुछ नहीं बदलेगा. लिखने के लिए --commit लगाइए.\n');

  // ── सिर्फ़ ज़रूरी documents पढ़ना (हर id = 1 read) ──
  const ids = [...del.keys(), ...upd.keys()];
  const old = new Map();
  for (let i = 0; i < ids.length; i += 100) {
    const refs = ids.slice(i, i + 100).map((id) => db.collection(COLLECTION).doc(id));
    for (const s of await db.getAll(...refs)) if (s.exists) old.set(s.id, s.data());
  }
  console.log(`📖 ${ids.length} documents पढ़े (${ids.length} reads).\n`);

  const missing = ids.filter((id) => !old.has(id));
  if (missing.length) {
    console.error(`❌ Firestore में नहीं मिले: ${missing.join(', ')}`);
    process.exit(1);
  }

  // ── नया रूप बनाना और जाँचना ──
  const writes = [];
  const bad = [];
  const warn = [];
  const kinds = { subject: 0, exams: 0, answer: 0, text: 0, explanation: 0 };
  const paperMoves = {};

  for (const [id, fields] of upd) {
    const before = old.get(id);
    const after = { ...before, ...fields };
    if ('subject' in fields || 'exams' in fields) {
      const t = tagsFor(after.subject, after.exams);
      after.exams = t.exams;
      after.papers = t.papers;
    }

    const { errors, warnings } = check(after);
    if (errors.length) bad.push(`${id}: ${errors.join(' · ')}`);
    if (warnings.length) warn.push(`${id}: ${warnings.join(' · ')}`);

    if (fields.subject && fields.subject !== before.subject) kinds.subject++;
    if ('exams' in fields) kinds.exams++;
    if ('answer' in fields && fields.answer !== before.answer) kinds.answer++;
    if ('question' in fields || 'options' in fields) kinds.text++;
    if ('explanation' in fields) kinds.explanation++;

    const from = (before.papers || []).join('+');
    const to = (after.papers || []).join('+');
    if (from !== to) paperMoves[`${from} → ${to}`] = (paperMoves[`${from} → ${to}`] || 0) + 1;

    const patch = { ...fields };
    if (after.papers !== before.papers) {
      patch.exams = after.exams;
      patch.papers = after.papers;
    }
    writes.push({ id, patch });
  }

  /* ── रिपोर्ट ── */

  const delByPaper = {};
  for (const id of del.keys()) {
    const k = (old.get(id).papers || []).join('+') || '(कोई नहीं)';
    delByPaper[k] = (delByPaper[k] || 0) + 1;
  }
  console.log(`🗑️  ${del.size} हटेंगे:`, JSON.stringify(delByPaper));
  console.log(`✏️  ${writes.length} बदलेंगे — विषय ${kinds.subject}, परीक्षा ${kinds.exams}, ` +
    `उत्तर ${kinds.answer}, प्रश्न/विकल्प ${kinds.text}, व्याख्या ${kinds.explanation}`);
  for (const [m, n] of Object.entries(paperMoves)) console.log(`   प्रश्नपत्र ${m}: ${n}`);

  if (warn.length) {
    console.log(`\nℹ️  ${warn.length} चेतावनी:`);
    warn.slice(0, 15).forEach((w) => console.log('   ' + w));
    if (warn.length > 15) console.log(`   … और ${warn.length - 15}`);
  }
  if (bad.length) {
    console.log(`\n❌ ${bad.length} में गड़बड़ी — कुछ नहीं लिखा जाएगा:`);
    bad.forEach((b) => console.log('   ' + b));
    process.exit(1);
  }

  if (!COMMIT) {
    console.log('\n👀 जाँच ही थी. लिखने के लिए वही आदेश --commit के साथ चलाइए.\n');
    process.exit(0);
  }

  /* ── बैकअप, फिर लिखना ── */

  const stamp = new Date().toISOString().slice(0, 16).replace(/[:T]/g, '-');
  const backupFile = path.join(__dirname, `backup-patch-${stamp}.json`);
  const backup = ids.map((id) => {
    const d = { id, ...old.get(id) };
    for (const k of ['createdAt', 'updatedAt']) if (d[k]?.toDate) d[k] = d[k].toDate().toISOString();
    return d;
  });
  fs.writeFileSync(backupFile, JSON.stringify(backup, null, 1) + '\n');
  console.log(`\n💾 बैकअप: ${path.basename(backupFile)}`);
  console.log(`   वापस लाना हो: node import.js ${path.basename(backupFile)} --commit\n`);

  let batch = db.batch();
  let pending = 0;
  const flush = async () => {
    if (pending) await batch.commit();
    batch = db.batch();
    pending = 0;
  };

  for (const id of del.keys()) {
    batch.delete(db.collection(COLLECTION).doc(id));
    if (++pending === 400) await flush();
  }
  for (const { id, patch } of writes) {
    batch.update(db.collection(COLLECTION).doc(id), {
      ...patch,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    if (++pending === 400) await flush();
  }
  await flush();

  console.log(`✅ हो गया — ${del.size} हटे, ${writes.length} बदले.`);
  console.log('   अब packs बनाइए:  node build-packs.js --commit\n');
  process.exit(0);
}

main().catch((e) => {
  console.error('❌ fail:', e);
  process.exit(1);
});
