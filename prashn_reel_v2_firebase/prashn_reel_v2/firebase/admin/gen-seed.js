/**
 * ऐप में बंडल होने वाली फ़ाइल बनाता है — सिर्फ़ मुफ़्त नमूने वाले प्रश्नों से.
 *
 *   node gen-seed.js            # दिखाता है
 *   node gen-seed.js --write    # lib/data/seed_questions.dart लिख देता है
 *
 * क्यों सिर्फ़ नमूना:
 *   APK के अंदर जो कुछ है, उसे कोई भी निकाल सकता है — इंटरनेट बंद करके भी
 *   देख सकता है. पहले पूरे 271 प्रश्न बंडल थे, यानी सदस्यता का कोई मतलब ही
 *   नहीं था. अब बंडल में वही 25 रहते हैं जो वैसे भी मुफ़्त हैं; बाक़ी सब
 *   Firestore से आते हैं और पहली बार सिंक होने के बाद कैश से offline भी चलते हैं.
 *
 * मुफ़्त सेट बदलें (free-pet दोबारा चलाएँ) तो यह भी दोबारा चलाइए, वरना बंडल
 * और Firestore अलग-अलग बातें कहेंगे.
 */

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

const WRITE = process.argv.includes('--write');

const OUT = path.join(__dirname, '..', '..', 'lib', 'data', 'seed_questions.dart');

admin.initializeApp({
  credential: admin.credential.cert(
    require(path.join(__dirname, '..', 'seed', 'serviceAccountKey.json'))
  ),
});
const db = admin.app().firestore('(default)');

/** Dart की एकल-उद्धरण वाली स्ट्रिंग के लिए. */
function q(s) {
  return "'" + String(s ?? '').replace(/\\/g, '\\\\').replace(/'/g, "\\'").replace(/\$/g, '\\$').replace(/\r?\n/g, '\\n') + "'";
}

async function main() {
  const snap = await db.collection('questions').where('free', '==', true).get();

  const rows = snap.docs
    .map((d) => ({ id: d.id, ...d.data() }))
    .filter((r) => Array.isArray(r.options) && r.options.length === 4)
    .sort((a, b) => a.id.localeCompare(b.id));

  const by = {};
  for (const r of rows) by[r.subject] = (by[r.subject] || 0) + 1;

  console.log(`\n${rows.length} मुफ़्त प्रश्न मिले.`);
  console.log('विषय-वार:', JSON.stringify(by));

  const lines = [];
  lines.push('// GENERATED FILE — firebase/admin/gen-seed.js से बनी है, हाथ से न बदलें.');
  lines.push('//');
  lines.push('// इसमें सिर्फ़ मुफ़्त नमूने वाले प्रश्न हैं. APK के अंदर जो कुछ हो,');
  lines.push('// उसे निकाला जा सकता है — इसलिए पैसे वाले प्रश्न यहाँ नहीं रखते.');
  lines.push('// वे Firestore से आते हैं और पहली बार सिंक के बाद कैश से offline भी चलते हैं.');
  lines.push('//');
  lines.push('// दोबारा बनाने के लिए:  node firebase/admin/gen-seed.js --write');
  lines.push('');
  lines.push('const List<Map<String, dynamic>> kSeedQuestions = [');

  for (const r of rows) {
    lines.push('  {');
    lines.push(`    'id': ${q(r.id)},`);
    lines.push(`    'subject': ${q(r.subject)},`);
    lines.push(`    'question': ${q(r.question)},`);
    lines.push(`    'options': [${r.options.map(q).join(', ')}],`);
    lines.push(`    'answer': ${Number(r.answer)},`);
    lines.push(`    'explanation': ${q(r.explanation || '')},`);
    lines.push('  },');
  }

  lines.push('];');
  lines.push('');

  const out = lines.join('\n');

  if (!WRITE) {
    const old = fs.existsSync(OUT) ? fs.readFileSync(OUT, 'utf8') : '';
    const oldCount = (old.match(/'id':/g) || []).length;
    console.log(`\nअभी बंडल में: ${oldCount} प्रश्न, ${Math.round(old.length / 1024)} KB`);
    console.log(`नए बंडल में  : ${rows.length} प्रश्न, ${Math.round(out.length / 1024)} KB`);
    console.log('\n👀 कुछ नहीं लिखा. लिखने के लिए:  node gen-seed.js --write\n');
    process.exit(0);
  }

  fs.writeFileSync(OUT, out, 'utf8');
  console.log(`\n✅ लिख दिया: lib/data/seed_questions.dart (${Math.round(out.length / 1024)} KB)\n`);
  process.exit(0);
}

main().catch((e) => {
  console.error('❌ fail:', e.message);
  process.exit(1);
});
