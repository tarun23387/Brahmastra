/**
 * जोखिम वाले तथ्य छाँटने की लिपि.
 *
 *   node risky-facts.js pet-*.json
 *
 * हर प्रश्न सच नहीं जाँचा जा सकता — पर हर प्रश्न में ग़लती की गुंजाइश
 * बराबर भी नहीं होती. 'धौलावीरा किस राज्य में है' जैसा प्रश्न पत्थर की
 * लकीर है; 'नाबार्ड की स्थापना किस वर्ष हुई' में एक अंक इधर-उधर हो सकता
 * है और कोई जाँच उसे नहीं पकड़ेगी.
 *
 * यह लिपि वही प्रश्न छाँटती है जहाँ ग़लती की सबसे ज़्यादा सम्भावना है:
 *
 *   • साल      — 1757, 1935, 2016 जैसे चार अंक
 *   • गिनती    — 'कितने', अनुच्छेद संख्या, अनुसूची संख्या, संशोधन संख्या
 *   • सर्वोच्च  — सबसे बड़ा, सबसे लंबा, प्रथम, एकमात्र
 *
 * इन्हीं को स्रोत से मिलाना है. बाक़ी को छोड़ देना बेईमानी नहीं —
 * सीमित समय जहाँ सबसे ज़्यादा काम आए, वहाँ लगाना है.
 */
const fs = require('fs');

const files = process.argv.slice(2).filter((a) => !a.startsWith('--'));
if (!files.length) {
  console.error('usage: node risky-facts.js <file.json> [file2.json ...]');
  process.exit(1);
}

const YEAR = /\b(1[5-9]\d\d|20[0-2]\d)\b/;
const COUNT = /कितन|अनुच्छेद \d|अनुसूची|संशोधन|\bधारा \d/;
const SUPERLATIVE = /सबसे |प्रथम|पहल[ाी]|एकमात्र|सर्वाधिक|न्यूनतम|अधिकतम/;

const buckets = { साल: [], गिनती: [], सर्वोच्च: [] };
let total = 0;

for (const file of files) {
  const rows = JSON.parse(fs.readFileSync(file, 'utf8'));
  total += rows.length;

  rows.forEach((q, i) => {
    const hay = q.question + ' ' + q.options[q.answer] + ' ' + (q.explanation || '');
    const where = `${file}#${i + 1}`;

    // एक प्रश्न एक ही टोकरी में — सबसे जोखिम वाली श्रेणी पहले
    if (YEAR.test(hay)) buckets['साल'].push({ where, q });
    else if (COUNT.test(hay)) buckets['गिनती'].push({ where, q });
    else if (SUPERLATIVE.test(hay)) buckets['सर्वोच्च'].push({ where, q });
  });
}

let risky = 0;
for (const [name, list] of Object.entries(buckets)) {
  risky += list.length;
  console.log(`\n═══ ${name} — ${list.length} प्रश्न ═══`);
  if (process.argv.includes('--list')) {
    for (const { where, q } of list) {
      console.log(`  ${where}  ${q.question.replace(/\n/g, ' ').slice(0, 58)}`);
      console.log(`        → ${q.options[q.answer]}`);
    }
  }
}

console.log(`\nकुल ${total} में से ${risky} प्रश्न जाँचने लायक़ (${Math.round((risky / total) * 100)}%).`);
console.log('पूरी सूची देखने के लिए --list लगाइए.');
