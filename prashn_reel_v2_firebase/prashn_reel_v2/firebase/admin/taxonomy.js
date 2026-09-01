/**
 * परीक्षा और प्रश्नपत्र का नियम — एक ही जगह.
 *
 * पहले हर प्रश्न विषय के आधार पर तीनों परीक्षाओं में अपने आप चला जाता था.
 * अब हर परीक्षा के प्रश्न अलग रखे जाते हैं: JSON में `exams` बताइए, और
 * उसी परीक्षा के भीतर विषय देखकर सही प्रश्नपत्र तय हो जाता है.
 */

const DEFAULT_EXAMS = ['roaro'];

/** हिंदी/भाषा/गणित वाले विषय — इन्हें अलग प्रश्नपत्र मिलता है. */
const LANGUAGE_ISH = new Set([
  'hindi',
  'english',
  'ganit',
  'reasoning',
  'comprehension',
]);

/**
 * एक परीक्षा के भीतर विषय से प्रश्नपत्र.
 *
 * RO/ARO — सामान्य हिंदी अलग पेपर है (60 प्रश्न); बाक़ी सब सामान्य अध्ययन में,
 *          जिसमें सामान्य बौद्धिक क्षमता भी आती है.
 * UPPCS  — भाषा/गणित/तर्क सी-सैट में; बाक़ी सामान्य अध्ययन प्रथम में.
 * PET    — एक ही पेपर, सब उसी में.
 */
function paperFor(exam, subject) {
  switch (exam) {
    case 'roaro':
      return subject === 'hindi' ? 'roaro-hindi' : 'roaro-gs';
    case 'uppcs':
      return LANGUAGE_ISH.has(subject) ? 'uppcs-csat' : 'uppcs-gs1';
    case 'pet':
      return 'pet-main';
    default:
      return null;
  }
}

/**
 * प्रश्न पर लगने वाले exams और papers.
 * `exams` न बताया हो तो RO/ARO मान लेते हैं — अभी वही बन रहा है.
 */
function tagsFor(subject, exams) {
  const list =
    Array.isArray(exams) && exams.length ? [...new Set(exams)] : [...DEFAULT_EXAMS];

  const papers = [];
  for (const e of list) {
    const p = paperFor(e, subject);
    if (p && !papers.includes(p)) papers.push(p);
  }

  return { exams: list.sort(), papers: papers.sort() };
}

module.exports = { tagsFor, paperFor, DEFAULT_EXAMS, LANGUAGE_ISH };
