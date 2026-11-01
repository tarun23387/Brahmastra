/**
 * RO/ARO के "पढ़िए" पाठ से UPPCS का पाठ बनाना — विषय-वस्तु वही, paper अलग.
 *
 *   // lessons/uppcs-polity.js
 *   const { derive } = require('../lesson-derive');
 *   module.exports = derive(require('./roaro-polity'), { paper: 'uppcs-gs1', intro: {…} });
 *
 * ── यह क्यों ──
 *
 * RO/ARO और UPPCS दोनों UPPSC की परीक्षाएँ हैं और सामान्य अध्ययन का पाठ्यक्रम
 * लगभग एक है. पाठ दो जगह हाथ से रखने पर एक सुधार दूसरी जगह छूट जाता, इसलिए
 * UPPCS वाली फ़ाइल RO/ARO की फ़ाइल को ही पढ़कर बदलती है:
 *  - key/paper UPPCS के; अध्यायों की id में 'roaro-' की जगह 'uppcs-', ताकि
 *    practice-map.json में दोनों परीक्षाओं के अध्याय अलग रहें;
 *  - पहला अध्याय ("…को कैसे पढ़ें") RO/ARO के पेपर के बारे में है, इसलिए
 *    order 1 वाली फ़ाइल में उसकी जगह `intro` (UPPCS का) आता है;
 *  - "परीक्षा में यह ऐसे आया" की पंक्तियाँ RO/ARO के असली प्रश्न हैं; उनके
 *    वर्ष के आगे "RO/ARO" लिखा जाता है, ताकि कोई इन्हें UPPCS का प्रश्न न समझे;
 *  - `omit` में दिए अध्याय छोड़ दिए जाते हैं (जो UPPCS के पाठ्यक्रम में नहीं).
 *
 * मूल वस्तु की गहरी नक़ल पर काम होता है: build-lessons.js एक ही प्रक्रिया में
 * RO/ARO की फ़ाइल भी require करता है, उसे बदलना उस पाठ को बिगाड़ देता.
 */
const PYQ = 'परीक्षा में यह ऐसे आया';

function derive(src, { paper, subtitle, intro, omit = [] }) {
  const l = JSON.parse(JSON.stringify(src));
  l.key = `lesson:${paper}:${l.subject}`;
  l.paper = paper;
  if (subtitle) l.subtitle = subtitle;
  l.chapters = l.chapters
    .filter((c) => !omit.includes(c.id))
    .map((c) => ({ ...c, id: c.id.replace(/^roaro-/, 'uppcs-') }));
  if (intro) l.chapters[0] = intro;
  for (const c of l.chapters) {
    for (const t of c.tables ?? []) {
      if (t.title !== PYQ) continue;
      t.rows = t.rows.map((r) => (/^\d{4}/.test(String(r[0])) ? [`RO/ARO ${r[0]}`, ...r.slice(1)] : r));
    }
  }
  return l;
}

module.exports = { derive };
