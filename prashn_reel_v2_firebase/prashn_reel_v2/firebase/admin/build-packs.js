/**
 * `packs` — वही प्रश्न, पर थोड़े-से बड़े दस्तावेज़ों में बँधे हुए.
 *
 *   node build-packs.js              # क्या बनेगा, सिर्फ़ दिखाता है
 *   node build-packs.js --commit     # असल में बनाता है (+ manifest भी बढ़ा देता है)
 *
 * ── यह चाहिए क्यों ──
 *
 * Firestore हर दस्तावेज़ को अलग गिनता है. `pet-main` में 1333 प्रश्न हैं,
 * यानी एक छात्र के एक बार पूरा पेपर उतारने पर 1333 reads. Spark plan की
 * रोज़ की हद 50,000 है — यानी सिर्फ़ ~37 छात्र, और उसके बाद Firestore
 * सबके लिए बंद, आधी रात तक.
 *
 * यहाँ वही प्रश्न कुछ बड़े दस्तावेज़ों में बाँध दिए जाते हैं. पूरा पेपर
 * उतारना अब 1333 reads नहीं, 3 reads का काम है — यानी उसी मुफ़्त हद में
 * हज़ारों छात्र समा जाते हैं.
 *
 * ── `questions` ही असली जगह है ──
 *
 * packs सिर्फ़ पढ़ने की सुविधा हैं, सच्चाई का ठिकाना नहीं. प्रश्न हमेशा
 * `questions` में ही जोड़ने/बदलने हैं (import.js से), और उसके बाद यह लिपि
 * चलाकर packs दोबारा बना देने हैं. उलटा कभी मत कीजिए.
 *
 * ── रोज़ का क्रम ──
 *
 *   node import.js nayi-file.json --commit
 *   node subscriptions.js free-pet --commit     (नए PET प्रश्न मुफ़्त करने हों तो)
 *   node build-packs.js --commit                ← यही manifest भी बढ़ा देता है
 *
 * आख़िरी वाला भूल गए तो नए प्रश्न छात्रों तक नहीं पहुँचेंगे.
 */

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

const COLLECTION = 'questions';
const PACKS = 'packs';

/**
 * एक pack में ज़्यादा से ज़्यादा कितने बाइट.
 *
 * Firestore की सख़्त हद 1 MiB (10,48,576 बाइट) प्रति दस्तावेज़ है. 700 KB
 * पर रुकते हैं ताकि गुंजाइश बची रहे — हिंदी UTF-8 में एक अक्षर तीन बाइट
 * का होता है, और गिनती में हमारा अंदाज़ा थोड़ा नीचे रह सकता है.
 */
const MAX_PACK_BYTES = 700 * 1024;

/** मुफ़्त प्रश्नों का अपना pack — ऐप बिना सदस्यता वाले के लिए यही माँगता है. */
const FREE_KEY = '_free';

const shared = JSON.parse(
  fs.readFileSync(path.join(__dirname, '..', 'shared', 'exams.json'), 'utf8')
);

const keyPath = path.join(__dirname, '..', 'seed', 'serviceAccountKey.json');
if (!fs.existsSync(keyPath)) {
  console.error(`serviceAccountKey.json नहीं मिली: ${keyPath}`);
  process.exit(1);
}

admin.initializeApp({ credential: admin.credential.cert(require(keyPath)) });
const db = admin.app().firestore('(default)');

/**
 * ऐप जिस रूप में प्रश्न पढ़ता है, वही रूप pack में रखते हैं.
 *
 * यह `Question.toMap()` (lib/models.dart) से हूबहू मेल खाना चाहिए — ऐप
 * pack के प्रश्नों को उसी `fromMap` से पढ़ता है जिससे अपना कैश पढ़ता है.
 * यहाँ कोई फ़ील्ड जोड़ें तो वहाँ भी देख लीजिए.
 */
function slim(id, d) {
  return {
    id,
    subject: d.subject ?? 'ca',
    question: String(d.question ?? '').trim(),
    options: (d.options ?? []).map((o) => String(o)),
    answer: typeof d.answer === 'number' ? d.answer : parseInt(d.answer, 10),
    explanation: String(d.explanation ?? '').trim(),
    // सूची-मिलान वाले प्रश्नों में ही — बाक़ी में यह फ़ील्ड होती ही नहीं
    ...(d.match ? { match: d.match } : {}),
    // वैसे ही सिर्फ़ PYQ में — कार्ड पर "2023" का ठप्पा इसी से लगता है
    ...(typeof d.year === 'number' ? { year: d.year } : {}),
  };
}

/** प्रश्नों को बाइट के हिसाब से टुकड़ों में बाँटता है. */
function chunk(list) {
  const parts = [];
  let cur = [];
  let size = 0;

  for (const q of list) {
    const n = Buffer.byteLength(JSON.stringify(q), 'utf8');
    if (cur.length && size + n > MAX_PACK_BYTES) {
      parts.push(cur);
      cur = [];
      size = 0;
    }
    cur.push(q);
    size += n;
  }
  if (cur.length) parts.push(cur);
  return parts;
}

async function main() {
  const commit = process.argv.includes('--commit');

  console.log(
    commit
      ? '\n⚠️  COMMIT — packs असल में बनेंगे.\n'
      : '\n👀 सिर्फ़ जाँच — कुछ नहीं बदलेगा. बनाने के लिए --commit लगाइए.\n'
  );

  // ── सब प्रश्न एक ही बार पढ़ते हैं ──
  const snap = await db.collection(COLLECTION).get();
  console.log(`${snap.size} प्रश्न पढ़े.\n`);

  const now = new Date();

  /** कुंजी → प्रश्नों की सूची */
  const groups = new Map();
  const add = (key, q) => {
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key).push(q);
  };

  for (const doc of snap.docs) {
    const d = doc.data();

    // साप्ताहिक प्रश्न जिनकी अवधि बीत चुकी — pack में नहीं जाने चाहिए
    const exp = d.expiresAt;
    if (exp && typeof exp.toDate === 'function' && exp.toDate() < now) continue;

    const q = slim(doc.id, d);
    if (!q.question || q.options.length < 2) continue;

    for (const p of d.papers ?? []) add(p, q);
    if (d.free === true) add(FREE_KEY, q);
  }

  // ── manifest पढ़कर संस्करण एक बढ़ाते हैं ──
  const manRef = db.collection('config').doc('manifest');
  const manSnap = await manRef.get();
  const oldVer = (manSnap.exists && manSnap.data().papers) || {};

  const keys = [...groups.keys()].sort();
  const newVer = { ...oldVer };
  const writes = [];
  const deletes = [];

  for (const key of keys) {
    const list = groups.get(key);
    const parts = chunk(list);
    const version = (typeof oldVer[key] === 'number' ? oldVer[key] : 0) + 1;
    newVer[key] = version;

    // pack मुफ़्त तभी, जब उसका हर प्रश्न मुफ़्त हो. आधा-अधूरा मुफ़्त pack
    // बनाना ख़तरनाक होगा — नियम पूरे दस्तावेज़ पर लगते हैं, प्रश्न पर नहीं,
    // इसलिए एक भी बिना-सदस्यता वाला प्रश्न अंदर हुआ तो वह मुफ़्त में बँट जाएगा.
    const free = key === FREE_KEY;

    const label = shared.papers[key]?.label ?? (key === FREE_KEY ? 'मुफ़्त सेट' : key);
    const kb = Math.round(
      parts.reduce((a, p) => a + Buffer.byteLength(JSON.stringify(p), 'utf8'), 0) / 1024
    );
    console.log(
      `  ${key.padEnd(14)} ${String(list.length).padStart(5)} प्रश्न → ` +
        `${parts.length} pack, ~${kb} KB, संस्करण ${oldVer[key] ?? '—'} → ${version}` +
        `${free ? '  (मुफ़्त)' : ''}   ${label}`
    );

    parts.forEach((questions, i) => {
      writes.push({
        id: `${key}-${i + 1}`,
        data: {
          key,
          part: i + 1,
          parts: parts.length,
          version,
          free,
          count: questions.length,
          questions,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
      });
    });
  }

  // ── पुराने pack जो अब नहीं चाहिए ──
  //
  // प्रश्न घटने पर टुकड़े भी घट सकते हैं. पुराना `pet-main-4` पड़ा रह गया
  // तो ऐप उसे भी पढ़ लेगा और हटाए हुए प्रश्न वापस दिखने लगेंगे.
  const existing = await db.collection(PACKS).get();
  const keep = new Set(writes.map((w) => w.id));
  for (const d of existing.docs) {
    if (!keep.has(d.id)) deletes.push(d.id);
  }

  console.log(`\n${writes.length} pack लिखे जाएँगे, ${deletes.length} पुराने हटेंगे.`);

  if (!commit) {
    console.log('\n(जाँच भर थी — कुछ लिखा नहीं.)');
    return;
  }

  const batch = db.batch();
  for (const w of writes) batch.set(db.collection(PACKS).doc(w.id), w.data);
  for (const id of deletes) batch.delete(db.collection(PACKS).doc(id));
  batch.set(
    manRef,
    { papers: newVer, updatedAt: admin.firestore.FieldValue.serverTimestamp() },
    { merge: true }
  );
  await batch.commit();

  console.log('\n✅ packs बन गए और manifest भी बढ़ गया.');
  console.log('   छात्रों के ऐप अगली बार खुलते ही नए प्रश्न उतार लेंगे.');
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });
