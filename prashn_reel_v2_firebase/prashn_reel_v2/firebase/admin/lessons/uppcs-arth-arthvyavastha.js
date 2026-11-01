/**
 * UPPCS सामान्य अध्ययन-I: अर्थव्यवस्था और कृषि, भाग 2 — बैंक, योजनाएँ, कर (1 नव॰ 2026).
 *
 * अध्याय RO/ARO वाले पाठ (roaro-arth-arthvyavastha.js) से. "वाणिज्य और लेखाशास्त्र"
 * (roaro-arth-09) RO/ARO के पाठ्यक्रम का अलग अंश है, UPPCS का नहीं, इसलिए छोड़ा.
 */
const { derive } = require('../lesson-derive');

module.exports = derive(require('./roaro-arth-arthvyavastha'), {
  paper: 'uppcs-gs1',
  omit: ['roaro-arth-09'],
});
