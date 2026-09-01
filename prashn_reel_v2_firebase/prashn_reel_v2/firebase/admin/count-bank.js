/**
 * Firestore में कितने प्रश्न हैं — विषयवार और परीक्षावार गिनती.
 *
 *   node count-bank.js
 *
 * एक बार पूरी collection पढ़ता है, इसलिए बार-बार मत चलाइए — मुफ़्त
 * कोटे में रोज़ 50,000 reads हैं और यह उसमें से उतने ही खाता है जितने
 * प्रश्न हैं.
 */
const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

const keyPath = path.join(__dirname, '..', 'seed', 'serviceAccountKey.json');
if (!fs.existsSync(keyPath)) {
  console.error('❌ serviceAccountKey.json nahi mili.');
  process.exit(1);
}
admin.initializeApp({ credential: admin.credential.cert(require(keyPath)) });
const db = admin.app().firestore('(default)');

const LABEL = {
  itihas: 'इतिहास', polity: 'राजव्यवस्था', bhugol: 'भूगोल', arth: 'अर्थव्यवस्था',
  vigyan: 'विज्ञान', paryavaran: 'पर्यावरण', up: 'यूपी विशेष', ca: 'सामयिकी', hindi: 'हिंदी',
  english: 'अंग्रेज़ी', ganit: 'गणित', reasoning: 'तर्कशक्ति',
  comprehension: 'गद्यांश', graph: 'ग्राफ़ व सारणी',
};

(async () => {
  const snap = await db.collection('questions').get();

  const bySubject = {};
  const byPaper = {};
  let free = 0;

  for (const doc of snap.docs) {
    const d = doc.data();
    bySubject[d.subject] = (bySubject[d.subject] || 0) + 1;
    for (const p of d.papers || []) byPaper[p] = (byPaper[p] || 0) + 1;
    if (d.free === true) free++;
  }

  console.log(`\nकुल प्रश्न: ${snap.size}\n`);

  console.log('विषयवार:');
  for (const [k, v] of Object.entries(bySubject).sort((a, b) => b[1] - a[1])) {
    console.log(`   ${(LABEL[k] || k).padEnd(16)} ${String(v).padStart(4)}`);
  }

  console.log('\nप्रश्नपत्र-वार:');
  for (const [k, v] of Object.entries(byPaper).sort((a, b) => b[1] - a[1])) {
    console.log(`   ${k.padEnd(16)} ${String(v).padStart(4)}`);
  }

  console.log(`\nमुफ़्त झंडा लगा: ${free}`);
  process.exit(0);
})();
