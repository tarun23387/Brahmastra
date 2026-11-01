/**
 * पाठ के अध्यायों को प्रश्नों से जोड़ना — "पढ़िए" के बाद "अभ्यास करें".
 *
 *   node map-practice.js roaro-gs roaro-hindi      → lessons/practice-map.json
 *
 * हर प्रश्न उसी विषय के पाठ के उस अध्याय से जुड़ता है जिसके शब्द उससे सबसे
 * ज़्यादा मिलते हैं (दुर्लभ शब्दों को अधिक वज़न, यानी IDF). build-lessons.js
 * यह फ़ाइल पढ़कर हर अध्याय में `practice` (प्रश्नों की ids) जोड़ता है, और ऐप
 * अध्याय के अंत में उन्हीं प्रश्नों का "अभ्यास करें" बटन दिखाता है.
 *
 * साथ में यह भी देखता है कि प्रश्न का उत्तर अध्याय के पाठ में है या नहीं.
 * जिनका नहीं है, उनकी व्याख्या का पहला वाक्य (परीक्षा-वर्ष वाले हिस्से हटाकर)
 * उस अध्याय की "और ज़रूरी तथ्य" सारणी में जाता है, ताकि पाठ पढ़कर उस अध्याय
 * के प्रश्न हल हो सकें. यही सारणी build-lessons जोड़ता है; हाथ से लिखी पाठ-
 * फ़ाइलें नहीं बदलतीं.
 *
 * लागत: हर paper के packs = 1–2 reads. पूरा `questions` collection नहीं पढ़ता.
 */

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

const papers = process.argv.slice(2).filter((a) => !a.startsWith('--'));
if (!papers.length) {
  console.error('कौन-से paper? जैसे: node map-practice.js roaro-gs roaro-hindi');
  process.exit(1);
}

admin.initializeApp({ credential: admin.credential.cert(require('../seed/serviceAccountKey.json')) });
const db = admin.app().firestore('(default)');

const OUT = path.join(__dirname, 'lessons', 'practice-map.json');
const dir = path.join(__dirname, 'lessons');

const norm = (s) =>
  String(s ?? '')
    .replace(/[़ँ]/g, '')
    .replace(/ं/g, '')
    // \p{M} ज़रूरी है: हिंदी की मात्राएँ और हलंत (ा ि ्) Unicode में "चिह्न" हैं,
    // अक्षर नहीं. इनके बिना "उच्चारण" टूटकर "उच च रण" बन जाता था और लगभग
    // हर हिंदी शब्द तीन अक्षर से छोटा होकर गिनती से बाहर हो जाता था (1 नव॰ 2026 तक).
    .replace(/[^\p{L}\p{M}\p{N}]+/gu, ' ')
    .toLowerCase();
const STOP = new Set(
  ('निम्नलिखित में से कौन किस किसे किसके किसकी किसने कहाँ कब क्या है हैं था थी थे की का के को और या एक पर ' +
    'से भी नहीं सही युग्म सुमेलित कीजिए कथनों विचार उपर्युक्त कौन-सा कौन-सी कौन-से संदर्भ नीचे दिए गए कूट उत्तर ' +
    'चुनिए सूची किया गया जाता जाती होता होती द्वारा लिए इस उस वह यह गई गए रूप प्रश्न अधिक सबसे होते जिस जो').split(' ')
);
const toks = (s) => norm(s).split(' ').filter((w) => w.length > 2 && !STOP.has(w));

const STRUCTURED = /^(A-\d|[IV]+,|केवल|1, 2|1 और 2|न तो|\(A\)|I और II|उपर्युक्त)/;
const METHOD = new Set(['reasoning', 'ganit', 'comprehension']);
const ORD = '(पहला|दूसरा|तीसरा|चौथा|पहले|दूसरे|तीसरे)';

/**
 * "और ज़रूरी तथ्य" की एक पंक्ति: [सवाल, उत्तर और तथ्य].
 *
 * पुरानी व्याख्याएँ अक्सर मानकर चलती हैं कि प्रश्न सामने है ("28 अगस्त 2014;
 * वित्तीय समावेशन हेतु।"), इसलिए अकेला वाक्य अधूरा लगता है. सवाल साथ रखने से
 * हर पंक्ति अपने-आप में पूरी है. परीक्षा-वर्ष, विकल्पों का ज़िक्र और "कथन ग़लत
 * है" जैसे हिस्से हटाए जाते हैं, ताकि पाठ के नियम (§6A) बने रहें.
 */
function factOf(q) {
  const lines = String(q.question).split('\n').map((s) => s.trim()).filter(Boolean);
  // अंग्रेज़ी के प्रश्नों की पहली पंक्ति केवल निर्देश होती है ("Choose the word…:"),
  // असली शब्द या वाक्य उसके बाद की पंक्ति में.
  const generic = /^(नीचे दो कथन|सूची-I को|निम्नलिखित कथनों|उपर्युक्त|कूट|नीचे दिए गए|Choose the|Fill in the|Read the|Find the)/;
  let ask =
    lines.find((s) => /^कथन \(A\)/.test(s)) ??
    lines.find((s) => !generic.test(s) && !/^(\d|[A-D]\.|[IV]+\.)/.test(s)) ??
    lines[0];
  ask = ask.replace(/^सूची-I \((.+)\)$/, '$1 (सूची-मिलान)').replace(/निम्नलिखित (कथनों पर विचार कीजिए|में से)[:]?/g, '').replace(/\s+/g, ' ').trim();

  const sentences = String(q.explanation || '')
    .replace(/\((RO\/ARO|UPPCS|PET)[^)]*\)/g, '')
    .split(/(?<=[।?])\s+/)
    .map((s) => s.trim())
    .filter((s) => s && !/RO\/ARO|PET 20|पूछ|पेपर|जाल|विकल्प|प्रश्न/.test(s));
  let exp = '';
  for (let s of sentences) {
    s = s
      .replace(new RegExp(`^(केवल )?${ORD}( (और|व) ${ORD})? (कथन|युग्म)[^:।]*[:।]\\s*`), '')
      .replace(/^कथन \d+ (गलत|ग़लत|सही) है,? (क्योंकि )?/, '')
      .replace(/^(दोनों|तीनों|चारों) (कथन )?सही हैं[^:।]*[:।]?\s*/, '')
      .replace(/^दोनों (कथन )?(ग़लत|गलत) हैं[:।]\s*/, '')
      .replace(/^\(A\)[^:।]*[:।]\s*/, '')
      .replace(/^सही (सुमेल|क्रम):\s*/, '')
      .trim();
    if (!s) continue;
    exp = exp ? `${exp} ${s}` : s;
    if (exp.length >= 70) break;
  }
  const ans = String(q.options[q.answer]);
  const answer = STRUCTURED.test(ans) ? exp : exp && !norm(exp).includes(norm(ans)) ? `${ans} — ${exp}` : exp || ans;
  if (!ask || answer.length < 4) return null;
  return [ask, answer];
}

(async () => {
  // ── पाठ ──
  const lessons = new Map();
  for (const f of fs.readdirSync(dir).filter((x) => x.endsWith('.js'))) {
    const l = require(path.join(dir, f));
    if (!papers.includes(l.paper)) continue;
    const have = lessons.get(l.key) ?? { ...l, chapters: [] };
    have.chapters.push(...l.chapters.map((c) => ({ ...c, order: l.order ?? 1 })));
    lessons.set(l.key, have);
  }

  // ── प्रश्न (packs से) ──
  const qs = [];
  for (const p of papers) {
    for (let i = 1; ; i++) {
      const snap = await db.collection('packs').doc(`${p}-${i}`).get();
      if (!snap.exists) break;
      for (const q of snap.data().questions) qs.push({ ...q, paper: p });
    }
  }

  const map = { _note: 'map-practice.js बनाता है; हाथ से मत बदलिए', practice: {}, facts: {} };
  const report = {};

  for (const [key, l] of lessons) {
    // फ़ाइलें नाम के क्रम में पढ़ी जाती हैं ("arthvyavastha" order 2 पहले, "krishi"
    // order 1 बाद में), इसलिए अध्याय `order` से लगाइए, जैसे build-lessons.js लगाता है.
    // 1 नव॰ 2026 तक यह छूटा था और "पहला अध्याय छोड़ो" वाला नियम असल में बैंक-
    // रिज़र्व बैंक वाले अध्याय को अभ्यास से बाहर कर रहा था.
    l.chapters.sort((a, b) => a.order - b.order);
    const chapters = l.chapters.map((c) => {
      const text = norm([c.title, c.summary, c.body, ...(c.tables ?? []).map((t) => t.rows.flat().join(' '))].join(' '));
      return { id: c.id, text, set: new Set(text.split(' ')), intro: /को कैसे पढ़ें/.test(c.title) };
    });
    // "…को कैसे पढ़ें" वाला अध्याय अभ्यास के लिए नहीं; जिस पाठ में ऐसा अध्याय नहीं
    // (UPPCS इतिहास), उसके सारे अध्याय उम्मीदवार हैं
    const pool = chapters.some((c) => !c.intro) ? chapters.filter((c) => !c.intro) : chapters;
    // IDF: जो शब्द कम अध्यायों में है, उसका वज़न अधिक
    const df = new Map();
    for (const c of chapters) for (const w of c.set) df.set(w, (df.get(w) ?? 0) + 1);
    const idf = (w) => Math.log((chapters.length + 1) / ((df.get(w) ?? 0) + 0.5));

    const subject = l.subject;
    const mine = qs.filter((q) => q.paper === l.paper && (l.paper.endsWith('hindi') || q.subject === subject));
    const r = (report[key] = { total: mine.length, covered: 0, facts: 0 });

    for (const q of mine) {
      // भाषा के पाठ में गद्यांश वाले प्रश्न किसी अध्याय के नहीं (वे गद्यांश के पाठ के हैं)
      if (subject !== 'comprehension' && /गद्यांश|passage/i.test(q.question)) { r.total--; continue; }
      const ans = String(q.options[q.answer]);
      const T = [...new Set(toks(`${q.question} ${ans} ${String(q.explanation).split('।')[0]}`))];
      let best = pool[0];
      let bs = -1;
      for (const c of pool) {
        let s = 0;
        for (const w of T) if (c.set.has(w)) s += idf(w);
        if (s > bs) { bs = s; best = c; }
      }
      (map.practice[best.id] ??= []).push(q.id);

      // उत्तर अध्याय में है?
      const structured = STRUCTURED.test(ans);
      const A = structured ? toks(String(q.explanation).split('।')[0]) : toks(ans);
      const hit = A.filter((w) => best.text.includes(w)).length;
      const ok = A.length === 0 || hit / A.length >= (structured ? 0.7 : 0.6);
      // तर्कशक्ति, गणित और गद्यांश तरीक़े के विषय हैं: उनके प्रश्न का "तथ्य" नहीं
      // होता, और गद्यांश का प्रश्न गद्यांश के बिना सारणी में अर्थहीन है. इनके लिए
      // केवल "अभ्यास करें" वाला जोड़ बनता है.
      if (ok || METHOD.has(subject) || /गद्यांश|passage/i.test(q.question)) { r.covered++; continue; }
      const fact = factOf(q);
      if (!fact) continue;
      const list = (map.facts[best.id] ??= []);
      if (!list.some((x) => x[0] === fact[0])) { list.push(fact); r.facts++; }
    }
  }

  fs.writeFileSync(OUT, JSON.stringify(map, null, 1) + '\n');
  for (const [k, r] of Object.entries(report)) {
    console.log(`${k.padEnd(28)} प्रश्न ${String(r.total).padStart(4)} · उत्तर पाठ में ${String(r.covered).padStart(4)} · जोड़े गए तथ्य ${r.facts}`);
  }
  console.log(`→ ${path.relative(__dirname, OUT)}`);
})().catch((e) => {
  console.error('❌', e.message);
  process.exit(1);
});
