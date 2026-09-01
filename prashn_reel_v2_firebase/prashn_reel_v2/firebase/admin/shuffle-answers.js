/**
 * विकल्पों को फेंटकर सही उत्तर चारों जगह बराबर बाँटना.
 *
 * एक ही जगह सही उत्तर जमा हो जाए तो छात्र पैटर्न पकड़ लेता है और
 * अभ्यास बेमानी हो जाता है. यह लिपि हर प्रश्न के विकल्प फेंटती है और
 * answer का नया सूचकांक लिखती है.
 */
const fs = require('fs');

const file = process.argv[2];
if (!file) { console.error('usage: node shuffle.js <file.json>'); process.exit(1); }

const rows = JSON.parse(fs.readFileSync(file, 'utf8'));

// जिन विकल्पों का क्रम मायने रखता है उन्हें छुआ नहीं जाता
const ORDER_SENSITIVE = /(तीनों|चारों|दोनों|सभी|उपरोक्त|इनमें से कोई|कोई नहीं|उपर्युक्त)/;

/**
 * जिन प्रश्नों की व्याख्या विकल्प के अक्षर का नाम लेती है — "विकल्प (D)
 * असत्य है" — उन्हें भी नहीं फेंटा जाता. फेंटने पर उत्तर तो सही रहता है
 * पर व्याख्या झूठी हो जाती है, और छात्र को वही सबसे ज़्यादा भ्रमित करता है.
 *
 * "कथन (A)" इसमें नहीं आता — वह प्रश्न के भीतर का कथन है, विकल्प नहीं.
 */
const NAMES_OPTION = /विकल्प\s*\(?[A-D]\)?/;

// तय बीज — दोबारा चलाने पर वही नतीजा
let seed = 20260824;
const rnd = () => {
  seed = (seed * 1103515245 + 12345) & 0x7fffffff;
  return seed / 0x7fffffff;
};

// किस जगह कितने सही उत्तर गए, यह गिनकर सबसे ख़ाली जगह चुनते हैं
const placed = [0, 0, 0, 0];
let skipped = 0;

for (const q of rows) {
  if (
    q.options.some((o) => ORDER_SENSITIVE.test(o)) ||
    NAMES_OPTION.test(String(q.explanation ?? ''))
  ) {
    placed[q.answer]++;
    skipped++;
    continue;
  }

  const correct = q.options[q.answer];
  const others = q.options.filter((_, i) => i !== q.answer);

  // बाक़ी तीन विकल्पों को फेंटो
  for (let i = others.length - 1; i > 0; i--) {
    const j = Math.floor(rnd() * (i + 1));
    [others[i], others[j]] = [others[j], others[i]];
  }

  // सही उत्तर उस जगह जहाँ अब तक सबसे कम गए हैं (बराबरी पर बेतरतीब)
  const min = Math.min(...placed);
  const candidates = [0, 1, 2, 3].filter((i) => placed[i] === min);
  const target = candidates[Math.floor(rnd() * candidates.length)];

  const out = [];
  let k = 0;
  for (let i = 0; i < 4; i++) out.push(i === target ? correct : others[k++]);

  q.options = out;
  q.answer = target;
  placed[target]++;
}

fs.writeFileSync(file, JSON.stringify(rows, null, 1) + '\n');
console.log('कुल:', rows.length, '| क्रम-संवेदी छोड़े:', skipped);
console.log('सही उत्तर की जगह (अ/ब/स/द):', placed.join(' / '));
