/**
 * सूची-मिलान के चार कूट (A-x, B-y, C-z, D-w) ऐसे बनाता है कि अंदाज़े से उत्तर न निकले।
 *
 *   const { matchOptions } = require('./match-options');
 *   matchOptions([3, 1, 4, 2])  // → ['A-…', …] चार कूट, जिनमें एक [3,1,4,2] है
 *
 * ── यह क्यों ──
 *
 * 31 अक्टू॰ 2026 तक ग़लत कूट सही कूट में दो अंक अदल-बदलकर बनते थे। तब हर
 * अक्षर पर सही अंक चार में से तीन विकल्पों में होता था, और "हर अक्षर पर जो अंक
 * सबसे ज़्यादा बार आए, वही चुनो" वाली चाल 81 में से लगभग सभी नए प्रश्नों का
 * उत्तर बिना पढ़े दे देती थी।
 *
 * यहाँ चारों कूट इन शर्तों पर चुने जाते हैं:
 *  1. हर अक्षर का सही अंक ठीक दो विकल्पों में हो। एक जोड़ी जानने पर दो विकल्प
 *     कटते हैं, उत्तर तक पहुँचने के लिए दूसरी जोड़ी भी चाहिए (UPPSC का ढंग)।
 *  2. बाक़ी दो विकल्पों में उस अक्षर पर एक ही (ग़लत) अंक हो, ताकि गिनती बराबर
 *     रहे और "सबसे ज़्यादा बार" वाली चाल कुछ न बताए।
 * दोनों शर्तें एक साथ न बनें तो सिर्फ़ ये माँगते हैं: किसी अक्षर का सही अंक
 * अकेले एक विकल्प में न हो, और गिनती वाली चाल पूरा उत्तर न दे।
 */

const ALL = [];
(function perm(a, p = []) {
  if (!a.length) return ALL.push(p);
  a.forEach((x, i) => perm([...a.slice(0, i), ...a.slice(i + 1)], [...p, x]));
})([1, 2, 3, 4]);

const code = (p) => p.map((n, i) => `${'ABCD'[i]}-${n}`).join(', ');

/** हर अक्षर पर सबसे ज़्यादा आने वाला अंक; बराबरी हो तो null */
function vote(set) {
  return [0, 1, 2, 3].map((i) => {
    const t = {};
    for (const p of set) t[p[i]] = (t[p[i]] || 0) + 1;
    const mx = Math.max(...Object.values(t));
    const w = Object.keys(t).filter((k) => t[k] === mx);
    return w.length === 1 ? Number(w[0]) : null;
  });
}

function score(c, set) {
  let strict = true;
  for (let i = 0; i < 4; i++) {
    const have = set.filter((p) => p[i] === c[i]);
    if (have.length === 1) return -1; // एक जोड़ी से ही उत्तर
    if (have.length !== 2) { strict = false; continue; }
    const rest = set.filter((p) => p[i] !== c[i]);
    if (rest[0][i] !== rest[1][i]) strict = false;
  }
  if (vote(set).every((v, i) => v === c[i])) return -1; // गिनती वाली चाल
  return strict ? 2 : 1;
}

/**
 * @param {number[]} correct  जैसे [3, 1, 4, 2] = A-3, B-1, C-4, D-2
 * @param {() => number} rnd  0–1 (बीज वाला दें तो नतीजा हर बार वही)
 * @returns {{ options: string[], answer: number }}
 */
function matchOptions(correct, rnd = Math.random) {
  const others = ALL.filter((p) => code(p) !== code(correct));
  let best = [];
  let bestScore = -1;
  for (let a = 0; a < others.length; a++)
    for (let b = a + 1; b < others.length; b++)
      for (let c = b + 1; c < others.length; c++) {
        const set = [correct, others[a], others[b], others[c]];
        const s = score(correct, set);
        if (s > bestScore) { bestScore = s; best = []; }
        if (s === bestScore) best.push(set);
      }
  if (bestScore < 0) throw new Error(`कूट नहीं बने: ${code(correct)}`);
  const set = best[Math.floor(rnd() * best.length)].slice(1);
  for (let i = set.length - 1; i > 0; i--) {
    const j = Math.floor(rnd() * (i + 1));
    [set[i], set[j]] = [set[j], set[i]];
  }
  const answer = Math.floor(rnd() * 4);
  set.splice(answer, 0, correct);
  return { options: set.map(code), answer, strict: bestScore === 2 };
}

module.exports = { matchOptions, code, vote };
