// पाँच असली NTA papers (Paper-2, कोड 87) के हर प्रश्न का micro-concept — पढ़कर हाथ से तय किया
const UNIT = {
  1: 'prob comb logic rel grp graph bool lpp numth',
  2: 'digi datarep rtl instcyc mem io pipe',
  3: 'c oop java cg',
  4: 'sql ra norm txn idx er dw bigdata',
  5: 'sched proc sync dead pagemem disk sysw linux osbasic vm',
  6: 'sdlc req design testing metrics quality',
  7: 'ds tree hash sortsearch asym design7 graphalg npc string',
  8: 'fa cfl tm parse comp icg opt',
  9: 'phys dll mac ip routing transport app netsec mobile switching osi',
  10: 'search kr plan nlp mas fuzzy ga ann ml aibasic',
};
const unitOf = {}; for (const [u, s] of Object.entries(UNIT)) for (const c of s.split(' ')) unitOf[c] = +u;
const seq = (from, s) => Object.fromEntries(s.trim().split(/\s+/).map((c, i) => [from + i, c]));
const P = {
  dec2023: { ...seq(51, `prob string tree ds digi datarep rtl rtl cg oop c cg er mem io c disk pagemem linux netsec
      fa fa icg parse hash hash asym tree mem comp fa testing phys transport dll req mas fuzzy ga ann
      logic logic rel io mem logic cg oop txn idx pipe disk sync icg fa logic logic graph mac sdlc transport routing phys nlp search
      ? rtl cg norm pagemem comp logic search netsec search
      numth instcyc c design linux comp sdlc ga ip ml
      grp oop proc sdlc switching
      lpp lpp lpp lpp lpp ra ra ra ra ra`) },
  aug2024: { ...seq(51, `parse parse cfl tree c c oop c quality metrics metrics metrics transport ip ip mac mac c c c c oop oop norm er sql er norm norm norm norm txn graph comb logic logic logic pipe pipe pipe
      er digi io c mem sdlc sdlc design7 asym tm comp tm app ann ga
      cfl prob datarep instcyc proc osbasic sync fa ip ip fa comp sortsearch sdlc sdlc c oop digi rel logic
      prob graph asym ip digi digi ann ml pagemem graphalg design testing pagemem java sched
      ann ann ann ann ann dead dead dead dead dead`) },
  jun2025: { ...seq(51, `comb comb prob bool grp datarep io mem datarep c cg c c norm norm norm ra sched proc sched pagemem req metrics quality sdlc ds asym string graphalg c fa fa dll transport transport switching fuzzy ga ann ann
      instcyc pipe io c linux disk design testing design7 design7 parse app vm kr ga
      logic numth mem digi java c proc sync design quality design7 tree mac phys mas plan cfl netsec dw txn
      logic tm mem oop cg pagemem disk quality testing ds hash mobile netsec fuzzy ga
      opt opt opt opt opt disk disk disk disk disk`) },
  dec2025: { ...seq(51, `grp grp grp rel logic logic graph ds bool lpp cg oop cg oop c java oop cg cg oop
      er txn dw bigdata txn bigdata idx sql design linux sched pagemem disk osbasic sched osbasic
      tree asym tree sortsearch asym graphalg graphalg graphalg graphalg design7 design7 design7
      fa comp fa tm fa comp fa cfl comp cfl osi phys routing phys netsec mac ip osi mac phys
      plan kr nlp aibasic ml ml mas nlp nlp ann ml aibasic kr io instcyc ip pipe design metrics testing design sdlc
      metrics metrics metrics metrics metrics io io io io io`) },
};
// June 2026: response sheet; कुछ लेबल OCR में छूटे — जो पढ़े जा सके वही गिने
P.jun2026 = {
  51: ['sortsearch', 'match'], 52: ['tree', 'direct'], 53: ['digi', 'direct'], 54: ['dll', 'direct'], 55: ['logic', 'multi'], 56: ['io', 'match'],
  58: ['quality', 'direct'], 59: ['ip', 'multi'], 60: ['req', 'direct'], 61: ['osi', 'seq'], 62: ['c', 'match'], 63: ['ann', 'direct'], 64: ['prob', 'direct'],
  65: ['sortsearch', 'direct'], 66: ['mem', 'direct'], 67: ['icg', 'direct'], 68: ['tm', 'match'], 69: ['oop', 'multi'], 70: ['asym', 'direct'], 71: ['digi', 'direct'],
  72: ['c', 'seq'], 73: ['asym', 'direct'], 74: ['norm', 'direct'], 75: ['sdlc', 'match'], 76: ['c', 'direct'], 77: ['app', 'match'], 78: ['mem', 'direct'],
  79: ['sched', 'direct'], 81: ['rel', 'match'], 82: ['npc', 'direct'], 83: ['sched', 'match'], 84: ['graph', 'direct'], 85: ['numth', 'seq'], 86: ['vm', 'direct'],
  87: ['osi', 'direct'], 88: ['cfl', 'direct'], 90: ['rel', 'seq'], 91: ['ra', 'direct'], 92: ['tm', 'direct'], 93: ['ra', 'direct'], 94: ['osi', 'match'],
  95: ['mem', 'seq'], 96: ['nlp', 'direct'], 97: ['tree', 'direct'], 98: ['logic', 'match'], 99: ['tm', 'seq'], 100: ['phys', 'direct'], 101: ['hash', 'direct'],
  102: ['bool', 'match'], 103: ['grp', 'direct'], 104: ['digi', 'direct'], 105: ['graph', 'multi'], 107: ['phys', 'direct'], 108: ['pagemem', 'direct'],
  109: ['sync', 'direct'], 110: ['phys', 'match'], 111: ['dll', 'multi'], 112: ['graph', 'direct'], 113: ['digi', 'direct'], 114: ['tree', 'direct'],
  115: ['sdlc', 'match'], 116: ['rel', 'direct'], 117: ['mac', 'seq'], 118: ['transport', 'multi'], 119: ['tm', 'direct'], 120: ['comb', 'direct'],
  121: ['ra', 'direct'], 122: ['lpp', 'direct'], 123: ['osi', 'match'], 126: ['ds', 'match'], 127: ['io', 'direct'], 128: ['disk', 'direct'],
  129: ['sysw', 'match'], 132: ['ml', 'direct'], 133: ['c', 'direct'], 136: ['cg', 'direct'], 137: ['pipe', 'direct'], 138: ['er', 'seq'], 139: ['cg', 'multi'],
  140: ['txn', 'match'], 141: ['metrics', 'comp'], 142: ['metrics', 'comp'], 143: ['metrics', 'comp'], 144: ['metrics', 'comp'], 145: ['metrics', 'comp'],
  146: ['parse', 'comp'], 147: ['parse', 'comp'], 148: ['parse', 'comp'], 149: ['parse', 'comp'], 150: ['parse', 'comp'],
};
module.exports = { P, unitOf, UNIT };
