const fs = require('fs');
const { P, unitOf } = require('./classify.js');
const papers = ['dec2023', 'aug2024', 'jun2025', 'dec2025', 'jun2026'];
const recency = { dec2023: 0.6, aug2024: 0.7, jun2025: 0.85, dec2025: 1.0, jun2026: 1.0 };
function fmtOf(name, n) {
  if (name === 'jun2026') return P.jun2026[n][1];
  if (n >= 141) return 'comp';
  const q = require(`./${name}-p2.json`).find(x => x.n === n);
  const t = q ? q.text : '';
  if (/Assertion/i.test(t)) return 'ar';
  if (/Statement\s*\(?I\)?\s*:/i.test(t) && /Statement\s*\(?II\)?\s*:/i.test(t)) return 'two';
  if (/Match\s+(the\s+)?List/i.test(t)) return 'match';
  if (/\b(Arrange|sequence|correct order|in the order|ascending order|increasing order|hierarchy)\b/i.test(t) && /(\bA\.|\(A\))/.test(t)) return 'seq';
  if (/(\bA\.|\(A\))/.test(t) && /Choose the correct answer/i.test(t)) return 'multi';
  if (/#include|printf|cout|int main|void main/.test(t)) return 'code';
  return 'direct';
}
const rows = [];
for (const p of papers) for (const [n, v] of Object.entries(P[p])) {
  const c = Array.isArray(v) ? v[0] : v; if (c === '?') continue;
  rows.push({ p, n: +n, c, u: unitOf[c], f: fmtOf(p, +n) });
}
fs.writeFileSync('rows.json', JSON.stringify(rows));
// 1. format share per paper
const F = ['direct', 'code', 'multi', 'match', 'seq', 'ar', 'two', 'comp'];
console.log('FORMAT per paper (%):'); console.log('paper    ' + F.map(f => f.padStart(7)).join(''));
for (const p of papers) { const r = rows.filter(x => x.p === p); console.log(p.padEnd(9) + F.map(f => (100 * r.filter(x => x.f === f).length / r.length).toFixed(0).padStart(7)).join('') + '   n=' + r.length); }
// 2. unit share
console.log('\nUNIT share (% of classified items):');
for (let u = 1; u <= 10; u++) { const per = papers.map(p => { const r = rows.filter(x => x.p === p); return (100 * r.filter(x => x.u === u).length / r.length).toFixed(0).padStart(4); }); const all = (100 * rows.filter(x => x.u === u).length / rows.length).toFixed(1); console.log(`U${String(u).padEnd(3)} ${per.join('')}   avg ${all}%`); }
// 3. concept table
const cs = {};
for (const r of rows) { const o = cs[r.c] ??= { c: r.c, u: r.u, items: 0, w: 0, sess: new Set(), fmts: new Set() }; o.items++; o.w += recency[r.p]; o.sess.add(r.p); o.fmts.add(r.f); }
const list = Object.values(cs).map(o => ({ ...o, sess: o.sess.size, fmts: o.fmts.size, score: 3 * o.sess.size + 1.5 * o.w + o.fmts.size }));
list.sort((a, b) => b.score - a.score);
console.log('\nCONCEPTS (sessions/5, items, recency-weighted, formats, score):');
for (const o of list) console.log(`${o.c.padEnd(11)} U${String(o.u).padEnd(3)} ${o.sess}/5 ${String(o.items).padStart(3)} ${o.w.toFixed(1).padStart(5)} ${o.fmts} ${o.score.toFixed(1).padStart(6)}`);
fs.writeFileSync('concepts.json', JSON.stringify(list, null, 1));
