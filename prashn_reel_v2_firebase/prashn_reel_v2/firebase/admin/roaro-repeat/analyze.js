// RO/ARO के असली PYQ में दोहराव: (1) तथ्य-स्तर (वही प्रश्न/वही उत्तर-तथ्य दूसरे वर्ष में)
// (2) विषय-स्तर (वही topic दूसरे वर्ष में). node roaro-repeat/analyze.js
const fs = require('fs');
const qs = [];
for (const f of fs.readdirSync('.').filter((f) => /^roaro-.*pyq.*\.json$/.test(f))) qs.push(...require('../' + f));
const norm = (s) => String(s || '').replace(/[़ँं]/g, '').replace(/[^\p{L}\p{M}\p{N}]+/gu, ' ').toLowerCase().trim();
const BOIL = /नीचे दो कथन दिए गए हैं|एक को कथन|कूट|निम्नलिखित|सुमेलित|सूची-I+|उपर्युक्त|विचार कीजिए|सही उत्तर चुनिए|कथन \(A\)|कारण \(R\)/g;
const tri = (s) => { const t = new Set(); s = ' ' + s + ' '; for (let i = 0; i < s.length - 2; i++) t.add(s.slice(i, i + 3)); return t; };
const T = qs.map((q) => ({ q, t: tri(norm(q.question.replace(BOIL, ' ')) + ' ' + norm(q.options[q.answer])) }));
const years = [...new Set(qs.map((q) => q.year))].sort();
const byYear = {}; for (const q of qs) byYear[q.year] = (byYear[q.year] || 0) + 1;
console.log('वर्ष-वार PYQ:', JSON.stringify(byYear), 'कुल', qs.length);
// तथ्य-स्तर: अलग वर्ष के जोड़े, समानता ≥ 0.55
const rep = new Map();
for (let i = 0; i < T.length; i++) for (let j = i + 1; j < T.length; j++) {
  const a = T[i], b = T[j]; if (a.q.year === b.q.year) continue;
  let n = 0; for (const x of a.t) if (b.t.has(x)) n++;
  const s = n / Math.min(a.t.size, b.t.size);
  if (s >= 0.55 && n / (a.t.size + b.t.size - n) >= 0.33) { (rep.get(a.q.id) || rep.set(a.q.id, []).get(a.q.id)).push([b.q.year, s]); (rep.get(b.q.id) || rep.set(b.q.id, []).get(b.q.id)).push([a.q.year, s]); }
}
const later = years.slice(1);
for (const y of later) {
  const mine = qs.filter((q) => q.year === y); const hit = mine.filter((q) => (rep.get(q.id) || []).some(([yy]) => yy < y));
  console.log(`${y}: ${hit.length}/${mine.length} प्रश्नों का तथ्य पिछले किसी वर्ष में आ चुका था (${(100 * hit.length / mine.length).toFixed(0)}%)`);
}
const pairs = [...rep.entries()].map(([id, r]) => [qs.find((q) => q.id === id), r]);
fs.writeFileSync('roaro-repeat/fact-repeats.txt', pairs.sort((a, b) => a[0].year - b[0].year).map(([q, r]) => `${q.year} ${q.subject} | ${q.question.split('\n').slice(0, 2).join(' / ').slice(0, 110)} => ${q.options[q.answer].slice(0, 40)} | अन्य वर्ष: ${[...new Set(r.map((x) => x[0]))].join(',')}`).join('\n'));
// विषय-स्तर: हाथ से बने topic-नियम
const TOP = {
  'विटामिन/रोग': /विटामिन|कमी से/, 'UP के मेले/नृत्य/संगीत': /मेला|लोकनृत्य|नृत्य|घराना|लोकगीत/, 'UP ज़िले-उत्पाद/ODOP/GI': /ODOP|एक ज़िला|GI|जीआई|शिल्प|उत्पाद/,
  'UP संस्थान/अकादमी': /संस्थान|अकादमी/, 'UP कृषि-जलवायु क्षेत्र': /कृषि-जलवायु|कृषि जलवायु/, 'जनजाति': /जनजाति|थारू|बुक्सा|खरवार/,
  'जनगणना 2011': /जनगणना|लिंगानुपात|साक्षरता|जनसंख्या घनत्व/, 'फ़सल/किस्म/रोग': /फ़सल|फसल|किस्म|रबी|खरीफ|ख़रीफ़|गेहूँ|धान|गन्ना/,
  'खनिज/खनन': /खनिज|खान|अयस्क|कोयला|बॉक्साइट/, 'देश-राजधानी/विश्व': /राजधानी|जलसंधि|महाद्वीप|महासागर/,
  'स्वतंत्रता आंदोलन 1919–47': /आंदोलन|सत्याग्रह|गांधी|कांग्रेस|मिशन|गोलमेज/, '1857 और विद्रोह': /1857|विद्रोह/,
  'सल्तनत/मुग़ल': /सल्तनत|सुल्तान|मुग़ल|मुगल|अकबर|बाबर|ख़िलजी|तुग़लक/, 'प्राचीन/अभिलेख': /अभिलेख|प्रशस्ति|उपाधि|वेद|बौद्ध|जैन|गुप्त|मौर्य/,
  'संविधान अनुच्छेद/अनुसूची/भाग': /अनुच्छेद|अनुसूची|भाग I|संशोधन/, 'संस्थाएँ/आयोग': /आयोग|परिषद|प्राधिकरण|बोर्ड/,
  'बैंक/RBI/योजना': /बैंक|रिज़र्व|रिजर्व|योजना|MSME|मुद्रा/, 'पर्यावरण/उद्यान': /राष्ट्रीय उद्यान|अभयारण्य|रामसर|जैव|बाघ|प्रदूषण|ओज़ोन/,
  'अंतरिक्ष/विज्ञान CA': /इसरो|ISRO|उपग्रह|मिशन|चंद्रयान/, 'पुरस्कार/खेल': /पुरस्कार|सम्मान|ओलंपिक|विजेता|कप/,
};
const out = [];
for (const [k, r] of Object.entries(TOP)) {
  const m = qs.filter((q) => q.subject !== 'hindi' && r.test(q.question.split('\n').slice(0, 3).join(' ') + ' ' + q.options[q.answer]));
  const ys = {}; for (const q of m) ys[q.year] = (ys[q.year] || 0) + 1;
  out.push([k, m.length, Object.keys(ys).length, JSON.stringify(ys)]);
}
out.sort((a, b) => b[2] - a[2] || b[1] - a[1]);
console.log('\nविषय | कुल | कितने वर्षों में | वर्ष-वार');
for (const o of out) console.log(o.join(' | '));
// हिंदी: शब्द-स्तर
const hi = qs.filter((q) => q.subject === 'hindi');
const words = new Map();
for (const q of hi) { const m = q.question.match(/'([^']+)'/g) || []; for (const w of m) { const k = w.replace(/'/g, ''); (words.get(k) || words.set(k, new Set()).get(k)).add(q.year); } }
console.log('\nहिंदी में एक से अधिक वर्षों में आए शब्द:', [...words.entries()].filter(([, s]) => s.size > 1).map(([w, s]) => w + '(' + [...s].join(',') + ')').join(' · '));
