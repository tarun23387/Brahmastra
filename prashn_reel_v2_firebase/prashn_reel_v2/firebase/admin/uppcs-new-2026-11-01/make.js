/**
 * UPPCS के नए अभ्यास-प्रश्न (1 नव॰ 2026) एक फ़ाइल में:
 *
 *   node uppcs-new-2026-11-01/make.js   → uppcs-new-2026-11-01.json
 *   node check-questions.js uppcs-new-2026-11-01.json
 *   node import.js uppcs-new-2026-11-01.json [--commit]
 *
 * यह JSON ही चढ़ने वाला सच है; प्रश्न बदलने हों तो यहाँ की स्रोत-फ़ाइलें
 * (gs.js, csat-ganit.js, csat-bhasha.js) बदलकर लिपि दोबारा चलाइए। सब पर
 * exams: ['uppcs'] है; paper विषय से taxonomy.js तय करता है (GS विषय → uppcs-gs1,
 * भाषा/गणित/तर्क → uppcs-csat)।
 */
const fs = require('fs');
const path = require('path');

const all = [
  ...require('./gs'),
  ...require('./csat-ganit'),
  ...require('./csat-bhasha'),
].map((q) => ({ ...q, exams: ['uppcs'] }));

const ids = new Set();
for (const q of all) {
  if (ids.has(q.id)) throw new Error('दोहरी id: ' + q.id);
  ids.add(q.id);
  if (new Set(q.options).size !== 4) throw new Error(q.id + ': विकल्प दोहराए गए');
  if (!(q.answer >= 0 && q.answer <= 3)) throw new Error(q.id + ': उत्तर का सूचकांक');
  if (/विकल्प \(?[A-Da-d1-4]\)|option \([a-d]\)/i.test(q.explanation)) throw new Error(q.id + ': व्याख्या विकल्प को अक्षर से बुला रही है');
}

const out = path.join(__dirname, '..', 'uppcs-new-2026-11-01.json');
fs.writeFileSync(out, JSON.stringify(all, null, 2) + '\n');

const by = {}, pos = [0, 0, 0, 0];
for (const q of all) { by[q.subject] = (by[q.subject] || 0) + 1; pos[q.answer]++; }
console.log(`${all.length} प्रश्न → ${path.basename(out)}`);
console.log('विषय-वार:', JSON.stringify(by));
console.log('सही उत्तर की जगह (A, B, C, D):', pos.join(', '));
