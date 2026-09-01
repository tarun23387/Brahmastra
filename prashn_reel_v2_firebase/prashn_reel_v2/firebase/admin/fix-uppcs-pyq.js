/**
 * uppcs-pyq-itihas.json को सुधारकर चढ़ाने लायक़ बनाता है.
 *
 *   node fix-uppcs-pyq.js                    # repo की मूल फ़ाइल पर
 *   node fix-uppcs-pyq.js <कोई-और.json>      # किसी और फ़ाइल पर
 *
 * पढ़ता है repo की जड़ वाली कच्ची scrape फ़ाइल, लिखता है यहीं admin/ में:
 *
 *   admin/uppcs-pyq-itihas.json          चढ़ाने लायक़ प्रश्न ← import.js इसी को लेता है
 *   admin/uppcs-pyq-itihas-review.json   हाथ से देखने वाले टूटे प्रश्न
 *
 * जड़ वाली uppcs-pyq-itihas.json को छूता नहीं — वह कच्चा scrape है,
 * तुलना के लिए रहने दी गई है.
 *
 * ── यह script क्यों है ─────────────────────────────────────
 *
 * scrape की हुई फ़ाइल में answer 1 से गिना गया था (1–4), जबकि
 * lib/models.dart और import.js दोनों 0 से गिनते हैं (0–3).
 * इससे दो तरह का नुक़सान होता:
 *
 *   answer=4 वाले 15 प्रश्न  → import की जाँच में अटकते, और import
 *                              एक भी ख़राब पंक्ति पर पूरी फ़ाइल रोक
 *                              देता है, इसलिए कुछ भी न चढ़ता.
 *   answer=1,2,3 वाले 64     → जाँच चुपचाप पास कर जाते, पर हर उत्तर
 *                              एक खाना खिसका हुआ. यही ज़्यादा ख़तरनाक
 *                              था — कोई चेतावनी नहीं, बस ग़लत उत्तर.
 *
 * इसका नतीजा पहले ही चढ़ चुका है (uppcs-pyq-itihas-fixed.json commit
 * में है). यह script उसी का हिसाब-किताब है — दोबारा चलाने पर वही
 * फ़ाइल बननी चाहिए. आगे कोई और scrape की फ़ाइल आए तो यहीं से शुरू कीजिए.
 */

const fs = require('fs');
const path = require('path');

const EXPLANATIONS = require('./uppcs-pyq-explanations');

// admin/ से चार ऊपर repo की जड़ है
const REPO_ROOT = path.resolve(__dirname, '..', '..', '..', '..');
const SRC = process.argv[2] || path.join(REPO_ROOT, 'uppcs-pyq-itihas.json');

/* ── 1. टूटे प्रश्न अलग निकालो ─────────────────────────────
 * इन्हें अपने आप ठीक नहीं कर सकते — विकल्प या कथन ही ग़ायब हैं.
 * अंदाज़े से भरना यानी PYQ बदल देना, इसलिए अलग रख देते हैं.  */
const QUARANTINE = {
  'pyq-2024-002':
    'प्रश्न अधूरा — "कौन-सा/से कथन सही है" पूछता है पर कथन (1) और (2) पाठ में हैं ही नहीं.',
};

/* ── 1क. टूटा सूची-मिलान, पूरा दोबारा लिखा ─────────────────
 * scrape में options की जगह दोनों सूचियों की प्रविष्टियाँ भर गई थीं और
 * असली कूट-विकल्प ग़ायब थे. चारों विकल्प असली प्रश्नपत्र से लिए हैं
 * (UPPSC PCS प्रा. 14 मई 2023, प्रश्न 71) — अंदाज़े से नहीं गढ़े.
 *
 * रूप uppcs-bank-571.json वाले मिलान प्रश्नों जैसा ही है: `question` में
 * दोनों सूचियाँ सादे पाठ में (पुरानी APK के लिए), `match` में वही सारणी
 * के रूप में, और `options` में सूची-II के अंक A,B,C,D के क्रम में.       */
const REPAIR = {
  'pyq-2023-071': {
    question:
      'सूची-I को सूची-II से सुमेलित कीजिए तथा सूचियों के नीचे दिए गए कूट से सही उत्तर चुनिए:\n' +
      'कूट (A, B, C, D):\n' +
      'सूची-I (पुस्तक)\n' +
      'A. मिरात-ए-सिकन्दरी\n' +
      'B. बुरहान-ए-माशिर\n' +
      'C. रियाज़-उस-सलातिन\n' +
      'D. रियाज़-उल-इंशा\n' +
      'सूची-II (विषय)\n' +
      '1. बंगाल का इतिहास\n' +
      '2. बहमनी के अहमदनगर का इतिहास\n' +
      '3. महमूद गवां के पत्रों का संग्रह\n' +
      '4. गुजरात विजय',
    options: ['4, 2, 1, 3', '2, 4, 1, 3', '1, 2, 4, 3', '4, 2, 3, 1'],
    answer: 1, // 1 से गिना हुआ — नीचे बाक़ी सबके साथ यह भी 1 घटेगा
    explanation:
      'मिरात-ए-सिकन्दरी गुजरात के सुल्तानों का इतिहास है, बुरहान-ए-माशिर बहमनी तथा ' +
      'अहमदनगर (निज़ामशाही) का, रियाज़-उस-सलातिन ग़ुलाम हुसैन सलीम की लिखी बंगाल का ' +
      'इतिहास है, और रियाज़-उल-इंशा बहमनी के प्रधानमंत्री महमूद गवां के पत्रों का संग्रह है।',
    match: {
      intro:
        'सूची-I को सूची-II से सुमेलित कीजिए तथा सूचियों के नीचे दिए गए कूट से सही उत्तर चुनिए:\n' +
        'कूट (A, B, C, D):',
      leftTitle: 'सूची-I (पुस्तक)',
      rightTitle: 'सूची-II (विषय)',
      left: [
        'A. मिरात-ए-सिकन्दरी',
        'B. बुरहान-ए-माशिर',
        'C. रियाज़-उस-सलातिन',
        'D. रियाज़-उल-इंशा',
      ],
      right: [
        '1. बंगाल का इतिहास',
        '2. बहमनी के अहमदनगर का इतिहास',
        '3. महमूद गवां के पत्रों का संग्रह',
        '4. गुजरात विजय',
      ],
    },
  },
};

/* ── 2. उत्तर-कुंजी की अलग ग़लती ───────────────────────────
 * 1 घटाने से पहले लगती है. व्याख्या ख़ुद "नागसेन" कहती थी
 * पर answer "कुमारिल भट्ट" पर जाता था.  */
const ANSWER_FIX = { 'pyq-2023-005': 3 };

/* ── 3. scrape का कचरा ─────────────────────────────────────
 * व्याख्या की जगह वेबपेज का navigation/comment आ गया था.  */
const CLEAR_EXPLANATION = [
  'pyq-2014-100',   // Pages: 1 2 3… + user comments
  'pyq-2017-080',   // navigation + social links
  'pyq-2018-013',   // पूरी तरह दूसरा ही प्रश्न घुसा है
  'pyq-2021-150',   // Read Also… + Related Posts
  'pyq-2022-080',   // navigation + user comment
];

// इसमें काम की बात पहले है, कचरा बाद में — काटकर रख लेते हैं.
const TRIM_EXPLANATION = {
  'pyq-2023-150':
    'झांसी में विद्रोह 5 जून, 1857 को आरंभ हुआ था, 11 मई को नहीं. ' +
    'मेरठ — 10 मई 1857, बैरकपुर — 29 मार्च 1857, लखनऊ — 4 जून 1857.',
};

/* ── 4. वर्तनी — सिर्फ़ वे जिनमें अर्थ नहीं बदलता ─────────── */
const SPELLING = [
  [/द्धारा/g, 'द्वारा'],
  [/ब्रह्राण/g, 'ब्राह्मण'],
  [/गयारह/g, 'ग्यारह'],
  [/ल्तान इब्राहीम/g, 'सुल्तान इब्राहीम'],
  [/संयुक्त प्रात /g, 'संयुक्त प्रांत '],
  [/नही है/g, 'नहीं है'],
  [/जीर्णोंद्धार/g, 'जीर्णोद्धार'],
  [/भारत छोड़ों/g, 'भारत छोड़ो'],
  [/अधिवेशन \(1931\) लो/g, 'अधिवेशन (1931) को'],
  [/&#8230;/g, '…'],
  [/&#916;/g, ''],
];

// एक-एक प्रश्न पर लगने वाले सुधार (जहाँ global regex ख़तरनाक हो)
const TARGETED = {
  'pyq-2014-099': [[/कलकत्ता अधिवेशन, 1996/, 'कलकत्ता अधिवेशन, 1896']],
  'pyq-2023-121': [[/^केवल$/, 'केवल 2']],          // कटा हुआ विकल्प
  'pyq-2023-017': [[/^शाहजहा$/, 'शाहजहाँ']],
  // ये व्याख्या लिखते समय सामने आए
  'pyq-2014-100': [[/बाँझ आये वेश्या/, 'बाँझ और वेश्या']],
  'pyq-2018-013': [[/की संहिता$/, 'की संहिता है ?'], [/^वाजसनेमि$/, 'वाजसनेयि']],
  'pyq-2017-083': [[/युुद्व/g, 'युद्ध'], [/युद्व/g, 'युद्ध']],
  'pyq-2017-085': [
    [/ग़ुफाये है।/, 'गुफाएँ हैं।'],
    [/गुफाओ की दिवार/, 'गुफाओं की दीवार'],
    [/उत्कीर्ण है।/, 'उत्कीर्ण हैं।'],
    [/इन गुफाओ को आजीविकाओं को/, 'इन गुफाओं को आजीवकों को'],
    [/उल्लेख करते है।/, 'उल्लेख करते हैं।'],
    [/के है।/, 'के हैं।'],
  ],
};

/* ───────────────────── चलाना ───────────────────── */

function fixText(text, id) {
  let out = String(text);
  for (const [pat, rep] of SPELLING) out = out.replace(pat, rep);
  for (const [pat, rep] of TARGETED[id] || []) out = out.replace(pat, rep);
  return out;
}

function main() {
  if (!fs.existsSync(SRC)) {
    console.error(`❌ फ़ाइल नहीं मिली: ${SRC}`);
    process.exit(1);
  }

  const rows = JSON.parse(fs.readFileSync(SRC, 'utf8'));
  const log = [];
  const fixed = [];
  const review = [];

  for (const row of rows) {
    const id = row.id;

    if (QUARANTINE[id]) {
      review.push({ ...row, _reason: QUARANTINE[id] });
      log.push(`⚠️  ${id}  अलग रखा — ${QUARANTINE[id].slice(0, 55)}…`);
      continue;
    }

    // टूटा प्रश्न पूरा दोबारा लिखा हुआ — बाक़ी सफ़ाई इसी पर आगे चलती है,
    // इसलिए answer यहाँ भी 1 से गिना रखा है.
    const r = { ...row, ...(REPAIR[id] || {}) };
    if (REPAIR[id]) log.push(`🔧 ${id}  सूची-मिलान दोबारा लिखा (असली प्रश्नपत्र से)`);

    // उत्तर-कुंजी की अलग ग़लती पहले
    if (ANSWER_FIX[id] != null) {
      log.push(`🔑 ${id}  answer ${r.answer} → ${ANSWER_FIX[id]} (व्याख्या से मिलान)`);
      r.answer = ANSWER_FIX[id];
    }

    // 1-indexed → 0-indexed
    const before = r.answer;
    r.answer = r.answer - 1;
    if (!Number.isInteger(r.answer) || r.answer < 0 || r.answer > 3) {
      console.error(`❌ ${id}: answer ${before} सीमा से बाहर — हाथ से देखिए`);
      process.exit(1);
    }

    // पाठ की सफ़ाई
    r.question = fixText(r.question, id);
    r.options = r.options.map((o) => fixText(o, id));

    // व्याख्या
    if (CLEAR_EXPLANATION.includes(id)) {
      r.explanation = '';
      log.push(`🧹 ${id}  scrape का कचरा हटाया`);
    } else if (TRIM_EXPLANATION[id]) {
      r.explanation = TRIM_EXPLANATION[id];
      log.push(`✂️  ${id}  व्याख्या काटकर साफ़ की`);
    } else {
      r.explanation = fixText(r.explanation ?? '', id);
    }

    // जो अब भी ख़ाली हैं उनमें लिखी हुई व्याख्या भरो
    if (!String(r.explanation).trim() && EXPLANATIONS[id]) {
      r.explanation = EXPLANATIONS[id];
    }

    // NFC — कुछ प्रश्नों में ड़ दो अलग Unicode रूपों में था. दिखने में
    // एक जैसा, पर import.js का dupeKey और ऐप का search इन्हें अलग
    // मान लेते, जिससे वही प्रश्न दोबारा चढ़ सकता था.
    r.question = r.question.normalize('NFC');
    r.options = r.options.map((o) => o.normalize('NFC'));
    r.explanation = r.explanation.normalize('NFC');
    if (r.match) {
      r.match = {
        ...r.match,
        intro: r.match.intro.normalize('NFC'),
        leftTitle: r.match.leftTitle.normalize('NFC'),
        rightTitle: r.match.rightTitle.normalize('NFC'),
        left: r.match.left.map((x) => x.normalize('NFC')),
        right: r.match.right.map((x) => x.normalize('NFC')),
      };
    }

    fixed.push(r);
  }

  for (const r of review) {
    r.question = r.question.normalize('NFC');
    r.options = r.options.map((o) => o.normalize('NFC'));
  }

  const outFixed = path.join(__dirname, 'uppcs-pyq-itihas.json');
  const outReview = path.join(__dirname, 'uppcs-pyq-itihas-review.json');
  fs.writeFileSync(outFixed, JSON.stringify(fixed, null, 2) + '\n', 'utf8');
  fs.writeFileSync(outReview, JSON.stringify(review, null, 2) + '\n', 'utf8');

  console.log(log.join('\n'));

  const noExp = fixed.filter((r) => !String(r.explanation).trim());
  console.log(`\n✅ ${fixed.length} प्रश्न → ${path.basename(outFixed)}`);
  console.log(`   व्याख्या सहित: ${fixed.length - noExp.length}/${fixed.length}`);
  if (noExp.length) {
    console.log(`   ⚠️  बिना व्याख्या: ${noExp.map((r) => r.id).join(', ')}`);
  }
  console.log(`⚠️  ${review.length} प्रश्न → ${path.basename(outReview)}`);
  console.log('\n   अब जाँच लीजिए:  node import.js ' + outFixed);
}

main();
