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
 * अंग्रेज़ी में वही बात. NET के Assertion-Reason और Statement I/II वाले
 * प्रश्नों के चारों विकल्प NTA हमेशा एक ही क्रम में छापता है, और छात्र उसी
 * क्रम का अभ्यस्त होता है. पहले ऊपर की सूची ही थी, इसलिए ऐसे अंग्रेज़ी
 * प्रश्न चुपचाप फेंटे जा रहे थे.
 *
 * अकेला 'neither' इसमें नहीं है — 'neither lossless nor dependency-preserving'
 * जैसा विकल्प अपने आप में पूरा है, दूसरे विकल्पों की ओर इशारा नहीं करता.
 */
const ORDER_SENSITIVE_EN = [
  /\bA and R\b|\b[AR] is (not )?(correct|true|false)/, // Assertion-Reason
  /\bStatements? ?(I|II|1|2)\b/, // Statement I/II
  /\b(all|none|any|both) of (the )?(above|these|them)\b/i,
  /\b(both|neither) \(?[a-d1-4]\)? (and|nor) \(?[a-d1-4]\)?/i,
];

/**
 * जिन प्रश्नों की व्याख्या विकल्प का नाम लेती है — "विकल्प (D) असत्य है",
 * "विकल्प 2 C-SCAN का क्रम है", "option (b)" — उन्हें भी नहीं फेंटा जाता.
 * फेंटने पर उत्तर तो सही रहता है पर व्याख्या झूठी हो जाती है, और छात्र को
 * वही सबसे ज़्यादा भ्रमित करता है.
 *
 * "कथन (A)" इसमें नहीं आता — वह प्रश्न के भीतर का कथन है, विकल्प नहीं.
 * अक्षर/अंक के बाद कोई और अक्षर हो ("विकल्प सही", "option buttons") तो वह
 * विकल्प का नाम नहीं, साधारण शब्द है.
 */
const NAMES_OPTION =
  /(विकल्प|\boptions?)\s*\(?([A-Da-d1-4]|[अबसद])\)?(?![\p{L}\p{M}\d])/iu;

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
    q.options.some(
      (o) => ORDER_SENSITIVE.test(o) || ORDER_SENSITIVE_EN.some((re) => re.test(o))
    ) ||
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
