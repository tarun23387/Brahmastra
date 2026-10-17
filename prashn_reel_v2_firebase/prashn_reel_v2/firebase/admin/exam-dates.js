/**
 * परीक्षा की तारीख़ें — course के thumbnail पर दिखती हैं (lib/exam_dates.dart).
 *
 * Firestore का `config/exam_dates` doc. नई build की ज़रूरत नहीं — यहाँ
 * बदलिए, अगली बार ऐप खुलते ही सबके फ़ोन पर.
 *
 *   node exam-dates.js list
 *   node exam-dates.js set pet --notif 2026-08-01 --last 2026-09-07 --exam 2026-10-25
 *   node exam-dates.js set roaro --notif 2026-11-15          # आगे की = "संभावित"
 *   node exam-dates.js set uppcs --exam 2026-12-06           # सिर्फ़ एक बदले, बाक़ी वैसे
 *   node exam-dates.js set uppcs --last none                 # कोई तारीख़ हटानी हो
 *   node exam-dates.js clear roaro                           # thumbnail से सब हटे
 *
 * ऐप में क्या दिखेगा (आज के हिसाब से, अपने आप):
 *   अधिसूचना आगे की        → "अधिसूचना (संभावित) · 15 नव॰ 2026"
 *   अधिसूचना जारी, आवेदन चालू → "अधिसूचना 1 अग॰ जारी · अंतिम तिथि 7 सित॰"
 *   आवेदन बंद, परीक्षा तय     → "परीक्षा 25 अक्टू॰ · 8 दिन बाक़ी"
 *   आवेदन बंद, तारीख़ नहीं    → "आवेदन बंद · परीक्षा तिथि जल्द"
 *   परीक्षा हो चुकी          → कुछ नहीं
 *
 * ⚠️ सरकारी जानकारी है — भरने से पहले आयोग की अपनी सूचना से मिलाइए.
 *    गलत तारीख़ छात्र का नुक़सान करती है, और Play की Misleading Claims नीति भी.
 */

const path = require('path');
const fs = require('fs');
const admin = require('firebase-admin');

const shared = JSON.parse(
  fs.readFileSync(path.join(__dirname, '..', 'shared', 'exams.json'), 'utf8'),
);

function db() {
  if (!admin.apps.length) {
    admin.initializeApp({
      credential: admin.credential.cert(
        require(path.join(__dirname, '..', 'seed', 'serviceAccountKey.json')),
      ),
    });
  }
  return admin.app().firestore('(default)');
}

const ref = () => db().collection('config').doc('exam_dates');

function arg(name) {
  const i = process.argv.indexOf('--' + name);
  return i === -1 ? undefined : process.argv[i + 1];
}

function checkDate(v, name) {
  if (v === undefined || v === 'none') return;
  if (!/^\d{4}-\d{2}-\d{2}$/.test(v) || isNaN(new Date(v))) {
    throw new Error(`--${name} "${v}" सही नहीं — YYYY-MM-DD लिखिए, जैसे 2026-10-25`);
  }
}

async function list() {
  const snap = await ref().get();
  const exams = (snap.data() || {}).exams || {};
  console.log('\nपरीक्षा        अधिसूचना     अंतिम तिथि   परीक्षा');
  for (const id of Object.keys(shared.exams)) {
    const e = exams[id] || {};
    console.log(
      `${id.padEnd(14)} ${(e.notif || '—').padEnd(12)} ${(e.lastDate || '—').padEnd(12)} ${e.exam || '—'}`,
    );
  }
  console.log('');
}

async function set(id) {
  if (!shared.exams[id]) throw new Error(`परीक्षा "${id}" नहीं मिली — ${Object.keys(shared.exams).join(', ')}`);
  const patch = {};
  for (const [flag, field] of [['notif', 'notif'], ['last', 'lastDate'], ['exam', 'exam']]) {
    const v = arg(flag);
    checkDate(v, flag);
    if (v === undefined) continue;
    patch[`exams.${id}.${field}`] =
      v === 'none' ? admin.firestore.FieldValue.delete() : v;
  }
  if (!Object.keys(patch).length) throw new Error('--notif / --last / --exam में से कुछ दीजिए');
  patch.updatedAt = admin.firestore.FieldValue.serverTimestamp();
  // update() बिंदु वाले रास्ते (exams.pet.exam) समझता है; doc न हो तो पहले बनाओ
  const snap = await ref().get();
  if (!snap.exists) await ref().set({ exams: {} });
  await ref().update(patch);
  console.log(`✅ ${id} बदल गया`);
  await list();
}

async function clear(id) {
  await ref().update({
    [`exams.${id}`]: admin.firestore.FieldValue.delete(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  console.log(`✅ ${id} की तारीख़ें हटीं`);
  await list();
}

(async () => {
  const [cmd, id] = process.argv.slice(2);
  try {
    if (cmd === 'list') await list();
    else if (cmd === 'set' && id) await set(id);
    else if (cmd === 'clear' && id) await clear(id);
    else {
      console.log(fs.readFileSync(__filename, 'utf8').split('*/')[0]);
      process.exit(1);
    }
    process.exit(0);
  } catch (e) {
    console.error('❌', e.message);
    process.exit(1);
  }
})();
