/**
 * `config/manifest` — ऐप को बताता है कि प्रश्न कब बदले.
 *
 *   node manifest.js                          # अभी क्या लिखा है, दिखाता है
 *   node manifest.js bump --all --commit      # हर पेपर का संस्करण एक बढ़ाओ
 *   node manifest.js bump pet-main --commit   # सिर्फ़ इसी पेपर का
 *
 * बिना --commit के कुछ लिखता नहीं — पहले रिपोर्ट देख लीजिए.
 *
 * ── यह चाहिए क्यों ──
 *
 * पहले ऐप का कैश 24 घंटे में अपने आप बासी हो जाता था, इसलिए हर छात्र रोज़
 * पूरा पेपर दोबारा उतारता था — प्रश्न बदले हों या नहीं. हज़ार छात्र यानी
 * रोज़ दस लाख Firestore reads, और वह भी ज़्यादातर बेकार.
 *
 * अब ऐप हर बार सिर्फ़ यह एक छोटा doc पढ़ता है (1 read). संस्करण वही निकला
 * तो अपने कैश से चल पड़ता है, चाहे वह दस दिन पुराना हो. संस्करण बढ़ा हुआ
 * मिले तभी पूरा पेपर दोबारा उतरता है.
 *
 * ── इसका मतलब एक ज़िम्मेदारी भी है ──
 *
 * प्रश्न चढ़ाने या बदलने के बाद संस्करण बढ़ाना ज़रूरी है. नहीं बढ़ाया तो नए
 * प्रश्न छात्रों तक नहीं पहुँचेंगे — 30 दिन तक नहीं (ऐप का सुरक्षा-जाल
 * `cacheMaxLife` तब जाकर ख़ुद ताज़ा करता है).
 *
 * इसलिए आदत बना लीजिए:
 *
 *   node import.js nayi-file.json --commit
 *   node manifest.js bump --all --commit      ← यह मत भूलिए
 *
 * ऐप का सिंक बटन इस सबको दरकिनार करके सीधे सर्वर से लाता है, इसलिए जाँचने
 * के लिए वह हमेशा मौजूद है.
 */

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

const shared = JSON.parse(
  fs.readFileSync(path.join(__dirname, '..', 'shared', 'exams.json'), 'utf8')
);

/** हर प्रश्नपत्र, और दो ख़ास कुंजियाँ. */
const PAPERS = Object.keys(shared.papers);

/** बिना सदस्यता वाला मुफ़्त सेट — ऐप इसे `freeOnly` से माँगता है. */
const FREE_KEY = '_free';

/** बिना किसी छाँट के पूरी collection — ऐप में यह रास्ता अभी इस्तेमाल नहीं होता. */
const ALL_KEY = 'all';

const KEYS = [...PAPERS, FREE_KEY, ALL_KEY];

const keyPath = path.join(__dirname, '..', 'seed', 'serviceAccountKey.json');
if (!fs.existsSync(keyPath)) {
  console.error(`serviceAccountKey.json नहीं मिली: ${keyPath}`);
  process.exit(1);
}

admin.initializeApp({ credential: admin.credential.cert(require(keyPath)) });
const db = admin.app().firestore('(default)');

const ref = db.collection('config').doc('manifest');

async function readManifest() {
  const snap = await ref.get();
  const papers = snap.exists ? snap.data().papers : null;
  return papers && typeof papers === 'object' ? papers : {};
}

async function show() {
  const papers = await readManifest();

  if (Object.keys(papers).length === 0) {
    console.log('config/manifest अभी बना ही नहीं है.');
    console.log('पहली बार बनाने के लिए:  node manifest.js bump --all --commit');
    return;
  }

  console.log('config/manifest:\n');
  for (const k of KEYS) {
    const v = papers[k];
    console.log(`  ${k.padEnd(16)} ${v === undefined ? '—' : v}`);
  }

  // manifest में ऐसी कुंजियाँ जो exams.json में नहीं हैं — पुराने पेपर या टाइपो
  const extra = Object.keys(papers).filter((k) => !KEYS.includes(k));
  if (extra.length) {
    console.log(`\n  (अनजानी कुंजियाँ: ${extra.join(', ')})`);
  }
}

async function bump({ which, commit }) {
  const papers = await readManifest();
  const targets = which === 'all' ? KEYS : which;

  const unknown = targets.filter((k) => !KEYS.includes(k));
  if (unknown.length) {
    console.error(`ये पेपर पहचाने नहीं गए: ${unknown.join(', ')}`);
    console.error(`चल सकते हैं: ${KEYS.join(', ')}`);
    process.exit(1);
  }

  const next = { ...papers };
  for (const k of targets) {
    next[k] = (typeof papers[k] === 'number' ? papers[k] : 0) + 1;
    console.log(`  ${k.padEnd(16)} ${papers[k] ?? '—'} → ${next[k]}`);
  }

  if (!commit) {
    console.log('\n(जाँच भर थी — कुछ लिखा नहीं. लिखने के लिए --commit लगाइए.)');
    return;
  }

  await ref.set(
    { papers: next, updatedAt: admin.firestore.FieldValue.serverTimestamp() },
    { merge: true }
  );
  console.log('\nलिख दिया. छात्रों के ऐप अगली बार खुलते ही नए प्रश्न उतार लेंगे.');
}

async function main() {
  const args = process.argv.slice(2);
  const commit = args.includes('--commit');
  const flags = args.filter((a) => a.startsWith('--'));
  const rest = args.filter((a) => !a.startsWith('--'));

  if (rest[0] !== 'bump') {
    await show();
    return;
  }

  const names = rest.slice(1);
  if (flags.includes('--all')) {
    await bump({ which: 'all', commit });
  } else if (names.length) {
    await bump({ which: names, commit });
  } else {
    console.error('किस पेपर का? नाम दीजिए या --all लगाइए.');
    console.error('  node manifest.js bump pet-main --commit');
    console.error('  node manifest.js bump --all --commit');
    process.exit(1);
  }
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });
