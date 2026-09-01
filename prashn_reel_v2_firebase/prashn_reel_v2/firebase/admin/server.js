/**
 * प्रश्न रील — Admin Panel (sirf aapke computer par chalta hai)
 *
 * Chalane ke liye:
 *   cd firebase/admin
 *   npm install
 *   npm start
 *   browser me kholein:  http://localhost:4000
 *
 * ⚠️  SURAKSHA: yeh server serviceAccountKey.json use karta hai, jiske paas
 *     poore database ka access hai. Isliye yeh sirf 127.0.0.1 par sunta hai —
 *     internet par ya public server par kabhi mat chalayein.
 */

const fs = require('fs');
const path = require('path');
const express = require('express');
const admin = require('firebase-admin');

const PORT = 4000;
const COLLECTION = 'questions';

// Yeh list lib/models.dart ke kSubjects se milti-julti honi chahiye.
const SUBJECTS = {
  itihas: 'इतिहास',
  polity: 'राजव्यवस्था',
  bhugol: 'भूगोल',
  arth: 'अर्थव्यवस्था',
  vigyan: 'विज्ञान व पर्यावरण',
  up: 'यूपी विशेष',
  ca: 'करेंट अफेयर्स',
  hindi: 'सामान्य हिंदी',
};

/* ───────────────────────── Firebase ───────────────────────── */

const keyPath = path.join(__dirname, '..', 'seed', 'serviceAccountKey.json');
if (!fs.existsSync(keyPath)) {
  console.error('❌ serviceAccountKey.json nahi mili:', keyPath);
  console.error('   Firebase Console → Project settings → Service accounts →');
  console.error('   "Generate new private key" → file ko wahan rakhein.');
  process.exit(1);
}

admin.initializeApp({ credential: admin.credential.cert(require(keyPath)) });
const db = admin.app().firestore('(default)');

/* ───────────────────────── validation ───────────────────────── */

/**
 * Yeh jaanch lib/models.dart ke Question.fromMap se mel khati hai.
 * Agar yahan se nikla doc app ke niyam tod de, to app use chup-chaap
 * chhod degi — isliye save karne se pehle hi rok dete hain.
 */
function validate(body) {
  const errors = [];

  const question = String(body.question ?? '').trim();
  if (!question) errors.push('प्रश्न खाली नहीं हो सकता।');

  const options = Array.isArray(body.options)
    ? body.options.map((o) => String(o ?? '').trim())
    : [];
  if (options.length !== 4) {
    errors.push('ठीक 4 विकल्प चाहिए।');
  } else if (options.some((o) => !o)) {
    errors.push('कोई भी विकल्प खाली नहीं हो सकता।');
  } else {
    const seen = new Set(options);
    if (seen.size !== options.length) errors.push('दो विकल्प एक जैसे हैं।');
  }

  const answer = Number.isInteger(body.answer)
    ? body.answer
    : parseInt(body.answer, 10);
  if (!Number.isInteger(answer) || answer < 0 || answer >= 4) {
    errors.push('सही उत्तर चुनना ज़रूरी है।');
  }

  const subject = String(body.subject ?? '');
  if (!SUBJECTS[subject]) errors.push('विषय गलत है।');

  const explanation = String(body.explanation ?? '').trim();
  if (!explanation) errors.push('व्याख्या लिखना ज़रूरी है।');

  return {
    errors,
    value: { question, options, answer, subject, explanation },
  };
}

/* ───────────────────────── app ───────────────────────── */

const app = express();
app.use(express.json({ limit: '1mb' }));
app.use(express.static(path.join(__dirname, 'public')));

app.get('/api/subjects', (_req, res) => res.json(SUBJECTS));

// Sabhi prashn — nayi entry sabse upar.
app.get('/api/questions', async (req, res) => {
  try {
    const snap = await db.collection(COLLECTION).get();
    const list = snap.docs.map((d) => ({ id: d.id, ...d.data() }));

    const subject = req.query.subject;
    const search = String(req.query.search ?? '').trim();

    let out = list;
    if (subject && SUBJECTS[subject]) {
      out = out.filter((q) => q.subject === subject);
    }
    if (search) {
      out = out.filter(
        (q) =>
          String(q.question ?? '').includes(search) ||
          (Array.isArray(q.options) && q.options.some((o) => String(o).includes(search)))
      );
    }

    // sabse nayi pehle
    out.sort((a, b) => {
      const ta = a.updatedAt?._seconds ?? a.createdAt?._seconds ?? 0;
      const tb = b.updatedAt?._seconds ?? b.createdAt?._seconds ?? 0;
      return tb - ta;
    });

    const counts = {};
    for (const q of list) counts[q.subject] = (counts[q.subject] || 0) + 1;

    res.json({ questions: out, total: list.length, counts });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Naya prashn
app.post('/api/questions', async (req, res) => {
  const { errors, value } = validate(req.body);
  if (errors.length) return res.status(400).json({ errors });

  try {
    // Wahi prashn pehle se to nahi hai?
    const dupe = await db
      .collection(COLLECTION)
      .where('question', '==', value.question)
      .limit(1)
      .get();
    if (!dupe.empty && !req.body.allowDuplicate) {
      return res.status(409).json({
        errors: [`यही प्रश्न पहले से मौजूद है (${dupe.docs[0].id})।`],
        duplicateId: dupe.docs[0].id,
      });
    }

    const id = await nextId();
    await db.collection(COLLECTION).doc(id).set({
      ...value,
      difficulty: req.body.difficulty || 'moderate',
      source: 'admin',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      // NOTE: `expiresAt` jaan-boojh kar nahi lag rahi. Cleanup function
      // sirf usi field wale docs hatata hai, isliye haath se jode gaye
      // prashn kabhi apne aap delete nahi honge.
    });

    res.json({ ok: true, id });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Prashn badalna
app.put('/api/questions/:id', async (req, res) => {
  const { errors, value } = validate(req.body);
  if (errors.length) return res.status(400).json({ errors });

  try {
    const ref = db.collection(COLLECTION).doc(req.params.id);
    const doc = await ref.get();
    if (!doc.exists) return res.status(404).json({ errors: ['प्रश्न नहीं मिला।'] });

    await ref.update({
      ...value,
      difficulty: req.body.difficulty || 'moderate',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Prashn hatana
app.delete('/api/questions/:id', async (req, res) => {
  try {
    await db.collection(COLLECTION).doc(req.params.id).delete();
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

/** Agli id: man-0001, man-0002 … */
async function nextId() {
  const snap = await db
    .collection(COLLECTION)
    .where('source', '==', 'admin')
    .get();
  let max = 0;
  for (const d of snap.docs) {
    const m = /^man-(\d+)$/.exec(d.id);
    if (m) max = Math.max(max, parseInt(m[1], 10));
  }
  return `man-${String(max + 1).padStart(4, '0')}`;
}

// Sirf localhost — internet par expose mat kijiye.
app.listen(PORT, '127.0.0.1', () => {
  console.log(`\n  ✅ Admin panel chalu hai:  http://localhost:${PORT}\n`);
  console.log('     Band karne ke liye Ctrl+C dabayein.\n');
});
