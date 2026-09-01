/**
 * पढ़ने वाली सामग्री Firestore पर चढ़ाता है.
 *
 *   node build-lessons.js              # सिर्फ़ जाँच — कुछ नहीं लिखता
 *   node build-lessons.js --commit     # असल में चढ़ाता है (+ manifest बढ़ाता है)
 *
 * सामग्री `lessons/` फ़ोल्डर की .js फ़ाइलों में है. वहाँ बदलिए, फिर यह चलाइए.
 *
 * यह `lessons` collection में लिखता है, `packs` में नहीं — जानबूझकर.
 * build-packs.js `packs` में अपने लिखे के अलावा हर doc मिटा देता है, इसलिए
 * पाठ वहाँ रखते ही अगली बार प्रश्न बनाने पर उड़ जाता.
 *
 * manifest वही साझा है जो प्रश्नों का है (`config/manifest` → `papers`),
 * क्योंकि key अलग है (`lesson:` से शुरू) तो टकराव नहीं होता. ऐप उसी अंक से
 * तय करता है कि कैश पुराना हुआ या नहीं.
 */

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

const COLLECTION = 'lessons';
const commit = process.argv.includes('--commit');

/* ───────────────────────── firebase ───────────────────────── */

const keyPath = path.join(__dirname, '..', 'seed', 'serviceAccountKey.json');
if (!fs.existsSync(keyPath)) {
  console.error('❌ serviceAccountKey.json nahi mili.');
  process.exit(1);
}
admin.initializeApp({ credential: admin.credential.cert(require(keyPath)) });
const db = admin.app().firestore('(default)');

/* ───────────────────────── सामग्री पढ़ना ───────────────────────── */

const dir = path.join(__dirname, 'lessons');
const files = fs.existsSync(dir) ? fs.readdirSync(dir).filter((f) => f.endsWith('.js')) : [];

if (files.length === 0) {
  console.error('❌ lessons/ में कोई फ़ाइल नहीं मिली.');
  process.exit(1);
}

/**
 * एक पाठ की जाँच.
 *
 * यहाँ अटका हुआ ऐप में चुपचाप ग़ायब हो जाता, इसलिए यहीं रोक देना बेहतर है.
 */
function check(lesson, file) {
  const e = [];
  if (!lesson.key || !lesson.key.startsWith('lesson:')) {
    e.push('key नहीं है या `lesson:` से शुरू नहीं होती');
  }
  if (!lesson.paper) e.push('paper नहीं है');
  if (!lesson.subject) e.push('subject नहीं है');
  if (!lesson.title) e.push('title नहीं है');
  if (typeof lesson.free !== 'boolean') e.push('free true/false नहीं है');
  if (!Array.isArray(lesson.chapters) || lesson.chapters.length === 0) {
    e.push('chapters ख़ाली है');
    return e;
  }

  const ids = new Set();
  lesson.chapters.forEach((c, i) => {
    const at = `अध्याय ${i + 1}`;
    if (!c.id) e.push(`${at}: id नहीं है`);
    else if (ids.has(c.id)) e.push(`${at}: id दोहरी है — ${c.id}`);
    else ids.add(c.id);
    if (!c.title) e.push(`${at}: title नहीं है`);
    if (!c.era) e.push(`${at}: era नहीं है`);
    if (!c.body || c.body.trim().length < 200) e.push(`${at}: body बहुत छोटी है`);
    if (typeof c.minutes !== 'number') e.push(`${at}: minutes संख्या नहीं है`);
  });
  return e;
}

(async () => {
  console.log(
    commit ? '⚠️  COMMIT — सामग्री असल में चढ़ेगी.\n' : '👀 सिर्फ़ जाँच — कुछ नहीं बदलेगा.\n'
  );

  const lessons = [];
  let bad = 0;

  for (const f of files) {
    const lesson = require(path.join(dir, f));
    const errs = check(lesson, f);
    if (errs.length) {
      bad++;
      console.log(`❌ ${f}`);
      for (const x of errs) console.log(`     ${x}`);
      continue;
    }
    lessons.push(lesson);
  }

  // एक ही key वाली फ़ाइलें जोड़ दी जाती हैं — इतिहास प्राचीन और मध्यकाल
  // अलग फ़ाइलों में लिखे जाते हैं (लिखने वाले के लिए आसान), पर ऐप में वे
  // एक ही पाठ हैं जिसके अध्याय काल के हिसाब से समूह बनते हैं.
  // क्रम `order` से तय होता है, फ़ाइल के नाम से नहीं — वरना "madhyakal"
  // वर्णक्रम में "prachin" से पहले आ जाता.
  const merged = new Map();
  for (const l of lessons.sort((x, y) => (x.order ?? 99) - (y.order ?? 99))) {
    const have = merged.get(l.key);
    if (have) have.chapters.push(...l.chapters);
    else merged.set(l.key, { ...l, chapters: [...l.chapters] });
  }
  lessons.length = 0;
  lessons.push(...merged.values());

  if (bad) {
    console.log('\nपहले ये ठीक कीजिए — कुछ नहीं चढ़ा.');
    process.exit(1);
  }

  // ── manifest पढ़कर संस्करण एक बढ़ाते हैं ──
  const manRef = db.collection('config').doc('manifest');
  const manSnap = await manRef.get();
  const oldVer = (manSnap.exists && manSnap.data().papers) || {};
  const newVer = { ...oldVer };

  const writes = [];

  for (const l of lessons) {
    const version = (typeof oldVer[l.key] === 'number' ? oldVer[l.key] : 0) + 1;
    newVer[l.key] = version;

    const kb = Math.round(Buffer.byteLength(JSON.stringify(l.chapters), 'utf8') / 1024);
    const mins = l.chapters.reduce((a, c) => a + (c.minutes || 0), 0);

    console.log(
      `  ${l.key.padEnd(28)} ${String(l.chapters.length).padStart(3)} अध्याय · ` +
        `~${kb} KB · ~${mins} मिनट · संस्करण ${oldVer[l.key] ?? '—'} → ${version}` +
        `${l.free ? '  (मुफ़्त)' : '  (सदस्यता)'}`
    );
    for (const c of l.chapters) {
      console.log(`       ${c.era.padEnd(14)} ${c.title}`);
    }

    // Firestore array के भीतर array नहीं लेता, और सारणी की पंक्तियाँ ठीक
    // वही हैं. इसलिए हर पंक्ति को { cells: [...] } में लपेट देते हैं.
    // स्रोत फ़ाइल में वे सादे array ही रहती हैं — लिखने वाले के लिए वही आसान है.
    const chapters = l.chapters.map((c) => ({
      ...c,
      tables: (c.tables ?? []).map((tb) => ({
        ...tb,
        rows: tb.rows.map((r) => ({ cells: r })),
      })),
    }));

    writes.push({
      id: l.key.replace(/[:/]/g, '_'),
      data: {
        key: l.key,
        paper: l.paper,
        subject: l.subject,
        title: l.title,
        subtitle: l.subtitle ?? null,
        free: l.free,
        version,
        count: l.chapters.length,
        chapters,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
    });
  }

  console.log(`\n${writes.length} पाठ लिखे जाएँगे.`);

  if (!commit) {
    console.log('\n(जाँच भर थी — कुछ लिखा नहीं.)');
    console.log('   चढ़ाने के लिए:  node build-lessons.js --commit');
    return;
  }

  const batch = db.batch();
  for (const w of writes) batch.set(db.collection(COLLECTION).doc(w.id), w.data);
  batch.set(
    manRef,
    { papers: newVer, updatedAt: admin.firestore.FieldValue.serverTimestamp() },
    { merge: true }
  );
  await batch.commit();

  console.log('\n✅ हो गया — सामग्री चढ़ गई और manifest भी बढ़ गया.');
  console.log('   छात्रों के ऐप अगली बार खुलते ही नए अध्याय उतार लेंगे.');
})().catch((e) => {
  console.error('\n❌', e.message);
  process.exit(1);
});
