/**
 * सदस्यता का काम — नया उपयोगकर्ता बनाना, बढ़ाना, बंद करना.
 *
 * यह फ़ाइल दो जगह काम आती है: सीधे टर्मिनल से, और admin panel के API से.
 *
 * टर्मिनल से:
 *
 *   node subscriptions.js list
 *   node subscriptions.js create --name "राम कुमार" --phone 9876543210 \
 *        --exams roaro,uppcs --months 1
 *   node subscriptions.js extend ro2401 --months 1
 *   node subscriptions.js disable ro2401
 *   node subscriptions.js test-user          # जाँच के लिए पूरा एक्सेस
 *   node subscriptions.js free-pet           # पूरा UP PET मुफ़्त कर देता है
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const admin = require('firebase-admin');

const EMAIL_DOMAIN = 'prashnreel.app';

const shared = JSON.parse(
  fs.readFileSync(path.join(__dirname, '..', 'shared', 'exams.json'), 'utf8')
);

/* ───────────────────────── firebase ───────────────────────── */

let _db = null;
let _auth = null;

function init() {
  if (_db) return;
  const keyPath = path.join(__dirname, '..', 'seed', 'serviceAccountKey.json');
  if (!fs.existsSync(keyPath)) {
    throw new Error('serviceAccountKey.json nahi mili: ' + keyPath);
  }
  if (!admin.apps.length) {
    admin.initializeApp({ credential: admin.credential.cert(require(keyPath)) });
  }
  _db = admin.app().firestore('(default)');
  _auth = admin.auth();
}

const db = () => { init(); return _db; };
const auth = () => { init(); return _auth; };

/* ───────────────────────── helpers ───────────────────────── */

/**
 * पढ़ने में आसान पासवर्ड — फ़ोन पर टाइप करना पड़ता है, इसलिए
 * जो अक्षर आपस में उलझते हैं (0/O, 1/l/I) वे छोड़ दिए हैं.
 */
function makePassword() {
  // 4 अक्षर + 4 अंक, बिना डैश — जैसे "kmpv7284".
  //
  // छात्र इसे WhatsApp पर देखकर फ़ोन के कीबोर्ड से टाइप करता है, इसलिए
  // छोटा और सीधा होना ज़रूरी है. पहले 14 अक्षर और दो डैश थे, जिनमें
  // गलती होना तय था.
  //
  // जो अक्षर-अंक आपस में उलझते हैं वे छोड़े हैं: l/1/I, o/0/O, s/5, z/2.
  // अक्षर पहले और अंक बाद में रखे हैं ताकि कीबोर्ड एक ही बार बदलना पड़े.
  const letters = 'abcdefghjkmnpqrtuvwxy';
  const digits = '34678';

  let out = '';
  for (let i = 0; i < 4; i++) out += letters[crypto.randomInt(letters.length)];
  for (let i = 0; i < 4; i++) out += digits[crypto.randomInt(digits.length)];
  return out;
}

/** परीक्षाओं से उनके सारे प्रश्नपत्र निकालता है. */
function papersForExams(exams) {
  const out = [];
  for (const [pid, p] of Object.entries(shared.papers)) {
    if (exams.includes(p.exam)) out.push(pid);
  }
  return out.sort();
}

function emailFor(userId) {
  return userId.includes('@') ? userId : `${userId}@${EMAIL_DOMAIN}`;
}

/** अगली आईडी — ro2401, ro2402 … (परीक्षा + साल + क्रम) */
async function nextUserId(exams) {
  const prefix = exams.includes('roaro') ? 'ro'
    : exams.includes('uppcs') ? 'pc'
    : 'pt';
  const yy = String(new Date().getFullYear()).slice(2);
  const stem = `${prefix}${yy}`;

  const snap = await db().collection('users').get();
  let max = 0;
  for (const d of snap.docs) {
    const uid = d.data().userId || '';
    const m = new RegExp(`^${stem}(\\d+)$`).exec(uid);
    if (m) max = Math.max(max, parseInt(m[1], 10));
  }
  return `${stem}${String(max + 1).padStart(2, '0')}`;
}

/* ───────────────────────── actions ───────────────────────── */

/**
 * नया सदस्य बनाता है और उसका पासवर्ड लौटाता है.
 *
 * पासवर्ड सिर्फ़ यहीं एक बार दिखता है — Firebase उसे hash करके रखता है,
 * बाद में पढ़ा नहीं जा सकता. भूल जाएँ तो reset-password चलाना होगा.
 */
async function create({ name, phone, exams, months = 1, userId, note, password }) {
  if (!name) throw new Error('name zaroori hai');
  if (!Array.isArray(exams) || !exams.length) throw new Error('kam se kam ek exam chunein');

  for (const e of exams) {
    if (!shared.exams[e]) throw new Error(`exam "${e}" pehchana nahi gaya`);
  }

  const id = userId || await nextUserId(exams);
  const pass = password || makePassword();
  const email = emailFor(id);

  const expiresAt = new Date();
  expiresAt.setMonth(expiresAt.getMonth() + Number(months));

  const user = await auth().createUser({
    email,
    password: pass,
    displayName: name,
  });

  await db().collection('users').doc(user.uid).set({
    userId: id,
    name,
    phone: phone || '',
    active: true,
    note: note || '',
    // हर परीक्षा की अपनी तारीख़ — बाद में दूसरी परीक्षा लें तो उसे
    // पूरा महीना मिले, पहली वाली की तारीख़ से न बँधे.
    courses: Object.fromEntries(exams.sort().map((e) => [e, {
      expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
      months: Number(months),
      since: admin.firestore.Timestamp.now(),
    }])),
    // नियमों के लिए — नीचे maxExpiry() की टिप्पणी देखें
    maxExpiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { uid: user.uid, userId: id, password: pass, expiresAt, exams };
}

async function findByUserId(userId) {
  const snap = await db().collection('users')
    .where('userId', '==', userId).limit(1).get();
  if (snap.empty) throw new Error(`"${userId}" nahi mila`);
  return snap.docs[0];
}

/**
 * सबसे आगे की तारीख़ — सारे courses में से.
 *
 * यह सिर्फ़ Firestore के नियमों के लिए ऊपर रखी जाती है. नियम map के अंदर
 * घूम नहीं सकते, इसलिए बिना इसके अवधि की जाँच सर्वर पर हो ही नहीं पाती
 * और बदला हुआ APK एक्सपायर होने के बाद भी प्रश्न पढ़ लेता.
 */
function maxExpiry(courses) {
  let max = null;
  for (const c of Object.values(courses || {})) {
    const d = c?.expiresAt?.toDate?.() ?? null;
    if (d && (!max || d > max)) max = d;
  }
  return max ? admin.firestore.Timestamp.fromDate(max) : null;
}

/** पुराने रूप वाले doc को नए रूप में पढ़ लेता है. */
function coursesOf(data) {
  if (data.courses && typeof data.courses === 'object') return { ...data.courses };

  // पुराना रूप — exams सूची + एक साझा expiresAt
  const out = {};
  const at = data.expiresAt;
  for (const e of data.exams || []) {
    out[e] = { expiresAt: at, months: data.months || 1 };
  }
  return out;
}

/**
 * किसी एक परीक्षा की अवधि बढ़ाता है.
 * परीक्षा न बताएँ तो सब चालू परीक्षाओं की.
 */
async function extend(userId, months = 1, examId) {
  const doc = await findByUserId(userId);
  const courses = coursesOf(doc.data());

  const targets = examId ? [examId] : Object.keys(courses);
  if (!targets.length) throw new Error('koi course hai hi nahi — pehle add-course chalayein');
  for (const e of targets) {
    if (!shared.exams[e]) throw new Error(`exam "${e}" pehchana nahi gaya`);
  }

  const now = new Date();
  const done = {};

  for (const e of targets) {
    const cur = courses[e]?.expiresAt?.toDate?.() ?? null;
    // पहले ही ख़त्म हो चुका हो तो आज से गिनते हैं, वरना आगे से
    const base = cur && cur > now ? cur : now;
    const next = new Date(base);
    next.setMonth(next.getMonth() + Number(months));

    courses[e] = {
      ...(courses[e] || {}),
      expiresAt: admin.firestore.Timestamp.fromDate(next),
      months: Number(months),
    };
    done[e] = next;
  }

  await doc.ref.update({
    courses,
    maxExpiresAt: maxExpiry(courses),
    active: true,
    // पुराने फ़ील्ड हटा देते हैं ताकि दो जगह अलग-अलग बात न रहे
    exams: admin.firestore.FieldValue.delete(),
    papers: admin.firestore.FieldValue.delete(),
    expiresAt: admin.firestore.FieldValue.delete(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  return { userId, done };
}

/**
 * पहले से बने सदस्य को एक और परीक्षा देता है — अपनी पूरी अवधि के साथ.
 *
 * यही वह काम है जो पहले हो ही नहीं सकता था: कोई जनवरी में RO/ARO ले और
 * मार्च में UPPCS, तो दूसरी वाली की गिनती मार्च से शुरू होती है.
 */
async function addCourse(userId, examId, months = 1) {
  if (!shared.exams[examId]) throw new Error(`exam "${examId}" pehchana nahi gaya`);

  const doc = await findByUserId(userId);
  const courses = coursesOf(doc.data());

  const now = new Date();
  const cur = courses[examId]?.expiresAt?.toDate?.() ?? null;
  const base = cur && cur > now ? cur : now;
  const next = new Date(base);
  next.setMonth(next.getMonth() + Number(months));

  courses[examId] = {
    expiresAt: admin.firestore.Timestamp.fromDate(next),
    months: Number(months),
    since: courses[examId]?.since ?? admin.firestore.Timestamp.now(),
  };

  await doc.ref.update({
    courses,
    maxExpiresAt: maxExpiry(courses),
    active: true,
    exams: admin.firestore.FieldValue.delete(),
    papers: admin.firestore.FieldValue.delete(),
    expiresAt: admin.firestore.FieldValue.delete(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { userId, examId, expiresAt: next, renewed: !!cur };
}

async function setActive(userId, active) {
  const doc = await findByUserId(userId);
  await doc.ref.update({
    active,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  // Firebase Auth में भी बंद कर देते हैं — दोहरी सुरक्षा
  await auth().updateUser(doc.id, { disabled: !active });
  return { userId, active };
}

/**
 * फ़ोन बदलने की इजाज़त — दर्ज किया हुआ device छुड़ा देता है.
 *
 * एक आईडी एक ही फ़ोन में चलती है, वरना एक छात्र ₹100 देकर दस दोस्तों को
 * आईडी बाँट देता. फ़ोन सचमुच बदला हो (टूट गया, नया ले लिया) तो यह चलाइए —
 * अगली बार जिस फ़ोन से लॉगिन होगा, वही दर्ज हो जाएगा.
 */
async function releaseDevice(userId) {
  const doc = await findByUserId(userId);
  await doc.ref.update({
    deviceId: admin.firestore.FieldValue.delete(),
    deviceName: admin.firestore.FieldValue.delete(),
    deviceBoundAt: admin.firestore.FieldValue.delete(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  return { userId };
}

async function resetPassword(userId) {
  const doc = await findByUserId(userId);
  const pass = makePassword();
  await auth().updateUser(doc.id, { password: pass });
  return { userId, password: pass };
}

async function list() {
  const snap = await db().collection('users').get();
  const now = new Date();
  return snap.docs.map((d) => {
    const x = d.data();
    const courses = coursesOf(x);

    // हर परीक्षा अलग — "roaro 28द, uppcs ख़त्म" जैसा
    const parts = [];
    let soonest = null;
    for (const [e, c] of Object.entries(courses)) {
      const exp = c.expiresAt?.toDate?.() ?? null;
      const live = exp && exp > now;
      const days = exp ? Math.ceil((exp - now) / 86400000) : 0;
      parts.push(`${e} ${live ? days + 'द' : 'ख़त्म'}`);
      if (live && (!soonest || exp < soonest)) soonest = exp;
    }

    return {
      uid: d.id,
      userId: x.userId,
      name: x.name,
      phone: x.phone,
      courses: parts,
      active: x.active === true,
      soonest,
      anyLive: !!soonest,
      deviceName: x.deviceName || '',
      hasDevice: !!x.deviceId,
    };
  }).sort((a, b) => (b.soonest ?? 0) - (a.soonest ?? 0));
}

/**
 * पूरा पीईटी पेपर मुफ़्त कर देता है — बिना लॉगिन वाला उपयोगकर्ता यही पढ़ता है.
 *
 * पहले 40 चुने हुए "नमूना" प्रश्न मुफ़्त होते थे. अब नमूना नहीं, पूरा UP PET
 * ही मुफ़्त है — छात्र पहले असली परीक्षा पूरी हल कर के देखे, फिर UPPCS/RO-ARO
 * के लिए पैसे दे. इसलिए `pet-main` में जो भी प्रश्न हैं, सब पर `free: true`
 * लग जाता है; बाक़ी सबका free हट जाता है.
 *
 * ध्यान: कई प्रश्न (इतिहास, राजव्यवस्था आदि) PET के साथ-साथ UPPCS/RO-ARO में भी
 * गिने जाते हैं — वे साझा प्रश्न भी मुफ़्त हो जाएँगे. यह जान-बूझकर है: PET को
 * lead बनाना ही मक़सद है. जो प्रश्न सिर्फ़ paid पेपरों में हैं (जैसे uppcs-csat
 * के गणित/तर्क) वे paid ही रहते हैं.
 *
 * Firestore नियम (`resource.data.free == true`) इसी झंडे को देखते हैं, इसलिए
 * यहाँ लगाते ही बिना सदस्यता वाला उपयोगकर्ता पूरा PET पढ़ पाएगा.
 */
const FREE_PAPER = 'pet-main';

async function freePet({ commit = false, paper = FREE_PAPER } = {}) {
  const snap = await db().collection('questions').get();

  const chosen = snap.docs.filter((d) => (d.data().papers || []).includes(paper));
  const alreadyFree = snap.docs.filter((d) => d.data().free === true);
  const chosenIds = new Set(chosen.map((d) => d.id));

  // जो पहले free थे पर अब PET में नहीं — उनका free हटाना है
  const toClear = alreadyFree.filter((d) => !chosenIds.has(d.id));

  if (!commit) {
    return { chosen: chosen.map((d) => d.id), alreadyFree: alreadyFree.map((d) => d.id), committed: false };
  }

  // सिर्फ़ उन्हीं पर लिखते हैं जिन पर झंडा है ही नहीं.
  //
  // पहले यह हर बार सारे PET प्रश्नों पर दोबारा लिख देता था. एक बैच जोड़ने
  // के बाद चलाने पर 900 में से 899 writes बेकार जाते थे — और Firestore का
  // मुफ़्त दैनिक कोटा एक ही दिन में ख़त्म हो गया. अब नया जुड़ा प्रश्न ही
  // लिखा जाता है.
  const needFlag = chosen.filter((d) => d.data().free !== true);

  // Firestore एक batch में 500 write लेता है — बड़े पेपर के लिए बाँट लेते हैं
  const writes = [
    ...toClear.map((d) => ({ ref: d.ref, data: { free: admin.firestore.FieldValue.delete() } })),
    ...needFlag.map((d) => ({
      ref: d.ref,
      data: { free: true, updatedAt: admin.firestore.FieldValue.serverTimestamp() },
    })),
  ];

  if (!writes.length) {
    return { chosen: chosen.map((d) => d.id), alreadyFree: alreadyFree.map((d) => d.id), committed: true, skipped: true };
  }
  for (let i = 0; i < writes.length; i += 450) {
    const batch = db().batch();
    for (const w of writes.slice(i, i + 450)) batch.set(w.ref, w.data, { merge: true });
    await batch.commit();
  }

  return { chosen: chosen.map((d) => d.id), alreadyFree: alreadyFree.map((d) => d.id), committed: true };
}

/**
 * भुगतान की जानकारी सेट करता है — UPI, फ़ोन, ईमेल, दाम.
 *
 * यह ऐप में हार्डकोड नहीं होती, इसलिए बदलनी हो तो नया APK बाँटने की
 * ज़रूरत नहीं — यहाँ बदलिए, सबके फ़ोन में अगली बार दिख जाएगा.
 */
async function setContact({ upiId, phone, email, priceMonthly, note }) {
  const ref = db().collection('config').doc('contact');
  const cur = (await ref.get()).data() || {};

  const next = {
    upiId: upiId ?? cur.upiId ?? '',
    phone: phone ?? cur.phone ?? '',
    email: email ?? cur.email ?? '',
    priceMonthly: Number(priceMonthly ?? cur.priceMonthly ?? 100),
    note: note ?? cur.note ?? '',
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  await ref.set(next, { merge: true });
  return next;
}

async function getContact() {
  const snap = await db().collection('config').doc('contact').get();
  return snap.exists ? snap.data() : null;
}

module.exports = {
  create, extend, addCourse, setActive, resetPassword, list, freePet, releaseDevice,
  setContact, getContact,
  papersForExams, makePassword, EMAIL_DOMAIN,
};

/* ───────────────────────── CLI ───────────────────────── */

function arg(name, fallback) {
  const i = process.argv.indexOf('--' + name);
  return i >= 0 && process.argv[i + 1] ? process.argv[i + 1] : fallback;
}

async function cli() {
  const cmd = process.argv[2];

  if (cmd === 'list') {
    const rows = await list();
    if (!rows.length) return console.log('अभी कोई सदस्य नहीं।');
    console.log(`\n${rows.length} सदस्य:\n`);
    for (const r of rows) {
      const status = !r.active ? '⛔ बंद' : r.anyLive ? '✅' : '⌛ सब ख़त्म';
      const phone = r.hasDevice ? `📱 ${r.deviceName || 'दर्ज'}` : '— फ़ोन नहीं';
      console.log(`  ${String(r.userId).padEnd(9)} ${String(r.name).padEnd(18)} ` +
        `${status.padEnd(10)} ${r.courses.join(' · ').padEnd(26)} ${phone}`);
    }
    console.log('');
    return;
  }

  if (cmd === 'create') {
    const exams = arg('exams', '').split(',').map((s) => s.trim()).filter(Boolean);
    const r = await create({
      name: arg('name'),
      phone: arg('phone', ''),
      exams,
      months: arg('months', 1),
      note: arg('note', ''),
      userId: arg('id'),
    });
    console.log('\n✅ सदस्य बन गया — यह जानकारी उपयोगकर्ता को भेजें:\n');
    console.log(`   आईडी      : ${r.userId}`);
    console.log(`   पासवर्ड   : ${r.password}`);
    console.log(`   परीक्षा   : ${r.exams.join(', ')}`);
    console.log(`   वैध तक    : ${r.expiresAt.toLocaleDateString('hi-IN')}`);
    console.log('\n⚠️  पासवर्ड सिर्फ़ अभी दिख रहा है — बाद में पढ़ा नहीं जा सकता।\n');
    return;
  }

  if (cmd === 'extend') {
    const r = await extend(process.argv[3], arg('months', 1), arg('exam'));
    console.log('');
    for (const [e, d] of Object.entries(r.done)) {
      console.log(`✅ ${r.userId} · ${e} — अब ${d.toLocaleDateString('hi-IN')} तक।`);
    }
    console.log('');
    return;
  }

  if (cmd === 'add-course') {
    const r = await addCourse(
      process.argv[3],
      arg('exam'),
      arg('months', 1),
    );
    console.log(`\n✅ ${r.userId} — ${r.examId} ${r.renewed ? 'बढ़ा दी' : 'जुड़ गई'}।`);
    console.log(`   वैध तक: ${r.expiresAt.toLocaleDateString('hi-IN')}\n`);
    return;
  }

  if (cmd === 'disable') {
    await setActive(process.argv[3], false);
    console.log(`⛔ ${process.argv[3]} बंद कर दिया गया।`);
    return;
  }

  if (cmd === 'enable') {
    await setActive(process.argv[3], true);
    console.log(`✅ ${process.argv[3]} फिर से चालू।`);
    return;
  }

  if (cmd === 'release-device') {
    await releaseDevice(process.argv[3]);
    console.log();
    return;
  }

  if (cmd === 'reset-password') {
    const r = await resetPassword(process.argv[3]);
    console.log(`\n✅ नया पासवर्ड: ${r.password}\n`);
    return;
  }

  if (cmd === 'test-user') {
    // जाँच के लिए — तीनों परीक्षाएँ, एक साल की वैधता
    const r = await create({
      name: 'टेस्ट उपयोगकर्ता',
      phone: '',
      exams: ['uppcs', 'roaro', 'pet'],
      months: 12,
      userId: arg('id', 'test01'),
      note: 'testing ke liye — release se pehle hata dein',
    });
    console.log('\n✅ टेस्ट आईडी बन गई:\n');
    console.log(`   आईडी     : ${r.userId}`);
    console.log(`   पासवर्ड  : ${r.password}`);
    console.log(`   पहुँच    : तीनों परीक्षाएँ, पूरे प्रश्न`);
    console.log(`   वैध तक   : ${r.expiresAt.toLocaleDateString('hi-IN')}`);
    console.log('\n⚠️  यह सिर्फ़ जाँच के लिए है — असली launch से पहले हटा दें:');
    console.log(`      node subscriptions.js disable ${r.userId}\n`);
    return;
  }

  if (cmd === 'contact') {
    const has = process.argv.some((a) => a.startsWith('--'));
    if (!has) {
      const c = await getContact();
      if (!c) {
        console.log('\n⚠️  भुगतान की जानकारी अभी सेट नहीं है।');
        console.log('   ऐप के payment पेज पर "सेट नहीं हुई" दिखेगा।\n');
        console.log('   सेट करने के लिए:');
        console.log('   node subscriptions.js contact --upi "aapka@upi" \\');
        console.log('        --phone 9876543210 --email aap@gmail.com --price 100\n');
        return;
      }
      console.log('\nअभी की जानकारी:\n');
      console.log(`   UPI    : ${c.upiId || '—'}`);
      console.log(`   फ़ोन    : ${c.phone || '—'}`);
      console.log(`   ईमेल   : ${c.email || '—'}`);
      console.log(`   दाम    : ₹${c.priceMonthly ?? 100} / महीना`);
      if (c.note) console.log(`   नोट    : ${c.note}`);
      console.log('');
      return;
    }

    const r = await setContact({
      upiId: arg('upi'),
      phone: arg('phone'),
      email: arg('email'),
      priceMonthly: arg('price'),
      note: arg('note'),
    });
    console.log('\n✅ सेट हो गया:\n');
    console.log(`   UPI    : ${r.upiId || '—'}`);
    console.log(`   फ़ोन    : ${r.phone || '—'}`);
    console.log(`   ईमेल   : ${r.email || '—'}`);
    console.log(`   दाम    : ₹${r.priceMonthly} / महीना\n`);
    return;
  }

  // free-sample पुराना नाम है — अब पूरा PET मुफ़्त होता है, इसलिए दोनों एक ही काम करते हैं
  if (cmd === 'free-pet' || cmd === 'free-sample') {
    const commit = process.argv.includes('--commit');
    const r = await freePet({ commit });
    console.log(`\n${r.chosen.length} PET प्रश्न मुफ़्त हैं (पूरा UP PET पेपर)।`);
    if (r.alreadyFree.length) console.log(`(पहले से ${r.alreadyFree.length} पर free लगा था)`);
    console.log(r.skipped
      ? '\n✅ सब पर झंडा पहले से लगा है — एक भी write नहीं लगा।\n'
      : r.committed
          ? '\n✅ Firestore में लग गया।\n'
          : '\n👀 DRY RUN — कुछ नहीं बदला. असली में: node subscriptions.js free-pet --commit\n');
    return;
  }

  console.log(`
उपयोग:
  node subscriptions.js list
  node subscriptions.js create --name "नाम" --phone 9876543210 --exams roaro,uppcs --months 1
  node subscriptions.js extend <userId> --months 1 [--exam roaro]
  node subscriptions.js add-course <userId> --exam uppcs --months 1
  node subscriptions.js disable <userId>
  node subscriptions.js enable <userId>
  node subscriptions.js reset-password <userId>
  node subscriptions.js release-device <userId>   फ़ोन बदलने पर
  node subscriptions.js test-user
  node subscriptions.js free-pet [--commit]      # पूरा UP PET मुफ़्त
`);
}

if (require.main === module) {
  cli().then(() => process.exit(0)).catch((e) => {
    console.error('❌', e.message);
    process.exit(1);
  });
}
