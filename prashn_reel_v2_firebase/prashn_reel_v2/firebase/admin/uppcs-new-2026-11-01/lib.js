/**
 * UPPCS के नए प्रश्न लिखने के छोटे सहायक (1 नव॰ 2026).
 *
 * हर ढाँचे का एक फ़ंक्शन है, ताकि प्रश्न-फ़ाइलों में केवल विषय-वस्तु रहे:
 *   direct  — सीधा प्रश्न; सही विकल्प की जगह बराबर बाँटी जाती है (place())
 *   stmts   — कथन वाले; विकल्प जिस क्रम में लिखे, उसी क्रम में रहते हैं
 *   ar      — कथन (A) / कारण (R); विकल्पों का मानक क्रम, उत्तर code (0–3)
 *   match   — सूची-मिलान; सूची-II का क्रम बीज वाले rng से फेंटा जाता है और
 *             चारों कूट match-options.js बनाता है (UPPSC का "2, 1, 4, 3" रूप)
 *
 * rng बीज वाला है, इसलिए लिपि दोबारा चलाने पर वही फ़ाइल बनती है।
 */
const { matchOptions } = require('../match-options');

let s = 20261101;
function rnd() {
  s |= 0; s = (s + 0x6d2b79f5) | 0;
  let t = Math.imul(s ^ (s >>> 15), 1 | s);
  t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
}

// सीधे प्रश्नों में सही विकल्प की जगह: 0,1,2,3 का फेंटा हुआ चक्र
let bag = [];
function place() {
  if (!bag.length) {
    bag = [0, 1, 2, 3];
    for (let i = 3; i > 0; i--) { const j = Math.floor(rnd() * (i + 1)); [bag[i], bag[j]] = [bag[j], bag[i]]; }
  }
  return bag.pop();
}

function direct(id, subject, question, correct, wrongs, explanation, difficulty = 'moderate') {
  if (wrongs.length !== 3) throw new Error(id + ': तीन ग़लत विकल्प चाहिए');
  const at = place();
  const options = [...wrongs];
  options.splice(at, 0, correct);
  return { id, subject, question, options, answer: at, explanation, difficulty };
}

// जिन विकल्पों का क्रम ही अर्थ है (वाक्य के भाग, "No error", तय कूट): जैसे लिखे वैसे रहें
function fixed(id, subject, question, options, answer, explanation, difficulty = 'moderate') {
  if (options.length !== 4 || answer < 0 || answer > 3) throw new Error(id + ': चार विकल्प और 0–3 उत्तर चाहिए');
  return { id, subject, question, options, answer, explanation, difficulty };
}

function stmts(id, subject, intro, list, options, answerText, explanation, ask, difficulty = 'moderate') {
  const answer = options.indexOf(answerText);
  if (answer < 0) throw new Error(id + ': उत्तर विकल्पों में नहीं: ' + answerText);
  const tail = ask || (list.length === 2 ? 'उपर्युक्त में से कौन सा/से कथन सही है/हैं?' : 'उपर्युक्त कथनों में से कौन सा/से सही है/हैं?');
  const question = `${intro}\n${list.map((t, i) => `${i + 1}. ${t}`).join('\n')}\n${tail}`;
  return { id, subject, question, options, answer, explanation, difficulty };
}

const AR = [
  '(A) और (R) दोनों सही हैं, तथा (R), (A) की सही व्याख्या है।',
  '(A) और (R) दोनों सही हैं, परन्तु (R), (A) की सही व्याख्या नहीं है।',
  '(A) सही है, परन्तु (R) गलत है।',
  '(A) गलत है, परन्तु (R) सही है।',
];
function ar(id, subject, A, R, code, explanation, difficulty = 'moderate') {
  const question = `नीचे दो कथन दिए गए हैं, एक को कथन (A) और दूसरे को कारण (R) कहा गया है:\nकथन (A): ${A}\nकारण (R): ${R}\nनीचे दिए गए कूट से सही उत्तर चुनिए:`;
  return { id, subject, question, options: [...AR], answer: code, explanation, difficulty };
}

const MATCH_INTRO = 'सूची-I को सूची-II से सुमेलित कीजिए और सूचियों के नीचे दिए गए कूट (A, B, C, D के क्रम में) से सही उत्तर चुनिए:';
function match(id, subject, leftTitle, rightTitle, pairs, explanation, difficulty = 'moderate') {
  if (pairs.length !== 4) throw new Error(id + ': चार जोड़ियाँ चाहिए');
  // सूची-II का क्रम फेंटिए, पर पहचान (1,2,3,4) और पूरा उलटा (4,3,2,1) नहीं
  let order;
  do {
    order = [0, 1, 2, 3];
    for (let i = 3; i > 0; i--) { const j = Math.floor(rnd() * (i + 1)); [order[i], order[j]] = [order[j], order[i]]; }
  } while (order.join() === '0,1,2,3' || order.join() === '3,2,1,0');
  // order[k] = सूची-II की k-वीं प्रविष्टि किस जोड़ी से आई
  const right = order.map((p) => pairs[p][1]);
  const correct = pairs.map((_, i) => order.indexOf(i) + 1);
  const r = matchOptions(correct, rnd);
  const left = pairs.map((p, i) => `${'ABCD'[i]}. ${p[0]}`);
  const rightL = right.map((t, i) => `${i + 1}. ${t}`);
  const question = `${MATCH_INTRO}\n${leftTitle}\n${left.join('\n')}\n${rightTitle}\n${rightL.join('\n')}`;
  return {
    id, subject, question,
    options: r.options.map((o) => o.replace(/[A-D]-/g, '')),
    answer: r.answer,
    explanation,
    difficulty,
    match: { intro: MATCH_INTRO, leftTitle, rightTitle, left, right: rightL },
  };
}

// कालक्रम/क्रम वाले: items सही क्रम में दीजिए; प्रश्न में वे फेंटे क्रम में दिखते हैं
function order(id, subject, intro, items, explanation, difficulty = 'moderate') {
  let shown;
  do {
    shown = items.map((_, i) => i);
    for (let i = shown.length - 1; i > 0; i--) { const j = Math.floor(rnd() * (i + 1)); [shown[i], shown[j]] = [shown[j], shown[i]]; }
  } while (shown.every((v, i) => v === i));
  // सही उत्तर: सही क्रम की हर घटना प्रश्न में किस संख्या पर है
  const correct = items.map((_, k) => shown.indexOf(k) + 1);
  const key = (p) => p.join(', ');
  const wrong = new Set();
  while (wrong.size < 3) {
    const p = [...correct];
    const a = Math.floor(rnd() * p.length); let b = Math.floor(rnd() * p.length);
    if (a === b) continue;
    [p[a], p[b]] = [p[b], p[a]];
    if (rnd() < 0.5) { const c = Math.floor(rnd() * p.length), d = Math.floor(rnd() * p.length); [p[c], p[d]] = [p[d], p[c]]; }
    if (key(p) !== key(correct)) wrong.add(key(p));
  }
  const q = direct(id, subject, `${intro}\n${shown.map((k, i) => `${i + 1}. ${items[k]}`).join('\n')}\nनीचे दिए गए कूट से सही उत्तर चुनिए:`, key(correct), [...wrong], explanation, difficulty);
  return q;
}

module.exports = { direct, fixed, stmts, ar, match, order, rnd, AR };
