import 'package:flutter/material.dart';

/// परीक्षा और प्रश्नपत्र की सूची.
///
/// यह फ़ाइल `firebase/shared/exams.json` की जोड़ीदार है — एक बदलें तो
/// दूसरी भी बदलनी होगी. वहाँ admin panel पढ़ता है, यहाँ से ऐप चलता है.
class Paper {
  final String id;
  final String examId;
  final String label;
  final int questions;
  final int marks;
  final String? note;

  /// इस पेपर में कौन-कौन से विषय आते हैं.
  final List<String> subjects;

  const Paper({
    required this.id,
    required this.examId,
    required this.label,
    required this.questions,
    required this.marks,
    required this.subjects,
    this.note,
  });
}

class Exam {
  final String id;
  final String label;
  final String shortLabel;
  final String authority;
  final String negative;
  final List<String> paperIds;

  /// यह परीक्षा कराने वाले आयोग का पूरा नाम — जैसा उसकी अपनी साइट पर लिखा है.
  final String authorityFullName;

  /// उसी आयोग की आधिकारिक वेबसाइट.
  ///
  /// Play की Misleading Claims नीति के लिए ज़रूरी है: सरकारी जानकारी देने
  /// वाले ऐप को हर जानकारी का असली सरकारी स्रोत साफ़-साफ़ दिखाना होता है.
  /// इसे बदलें तो पहले खोलकर देख लीजिए — टूटा लिंक होने पर ऐप फिर अटकेगा.
  final String sourceUrl;

  /// इस परीक्षा के प्रश्न तैयार हैं या नहीं.
  ///
  /// ख़ाली परीक्षा बेचना धोखा होगा — कोई ₹100 देकर देखे कि एक भी प्रश्न
  /// नहीं है, तो पैसे वापस माँगेगा और भरोसा टूटेगा. इसलिए जब तक प्रश्न
  /// न आ जाएँ, परीक्षा दिखती तो है पर "जल्द आ रहा है" के साथ.
  final bool ready;

  const Exam({
    required this.id,
    required this.label,
    required this.shortLabel,
    required this.authority,
    required this.authorityFullName,
    required this.sourceUrl,
    required this.negative,
    required this.paperIds,
    this.ready = false,
  });

  List<Paper> get papers =>
      paperIds.map((p) => kPapers[p]!).toList(growable: false);
}

const Map<String, Exam> kExams = {
  'uppcs': Exam(
    id: 'uppcs',
    label: 'यूपीपीसीएस (प्रारंभिक)',
    shortLabel: 'UPPCS',
    authority: 'UPPSC',
    authorityFullName: 'उत्तर प्रदेश लोक सेवा आयोग (UPPSC)',
    sourceUrl: 'https://uppsc.up.nic.in',
    negative: '1/3',
    paperIds: ['uppcs-gs1', 'uppcs-csat'],
    ready: true, // 642 सामान्य अध्ययन + 100 सी-सैट
  ),
  'roaro': Exam(
    id: 'roaro',
    label: 'समीक्षा अधिकारी / सहायक समीक्षा अधिकारी',
    shortLabel: 'RO/ARO',
    authority: 'UPPSC',
    authorityFullName: 'उत्तर प्रदेश लोक सेवा आयोग (UPPSC)',
    sourceUrl: 'https://uppsc.up.nic.in',
    negative: '1/3',
    paperIds: ['roaro-gs', 'roaro-hindi'],
    ready: true, // 243 सामान्य अध्ययन + 61 सामान्य हिंदी
  ),
  'pet': Exam(
    id: 'pet',
    label: 'UPPET',
    shortLabel: 'UPPET',
    authority: 'UPSSSC',
    authorityFullName: 'उत्तर प्रदेश अधीनस्थ सेवा चयन आयोग (UPSSSC)',
    sourceUrl: 'https://upsssc.gov.in',
    negative: '1/4',
    paperIds: ['pet-main'],
    ready: true, // सभी 15 खंडों पर प्रश्न तैयार — 1300 से ऊपर
  ),

  // ── UPPSC की तकनीकी भर्तियाँ, विज्ञापन A-2/E-1/2026 ──
  //
  // ये तीनों अलग-अलग पद हैं, एक परीक्षा के तीन पेपर नहीं. प्रोग्रामर की
  // तैयारी करने वाले को प्रबंधक (सिस्टम) के प्रश्न परोसना बेमतलब होगा —
  // प्रश्न-संख्या, समय और पाठ्यक्रम तीनों अलग हैं (परिशिष्ट-3).
  //
  // ऊपर वाली तीन परीक्षाओं से इनका मिज़ाज भी अलग है: वहाँ सामान्य अध्ययन
  // है, यहाँ आधे से ज़्यादा अंक कंप्यूटर के हैं.
  'prog-sr': Exam(
    id: 'prog-sr',
    label: 'वरिष्ठ प्रोग्रामर / प्रोग्रामर ग्रेड-2',
    shortLabel: 'वरि. प्रोग्रामर',
    authority: 'UPPSC',
    authorityFullName: 'उत्तर प्रदेश लोक सेवा आयोग (UPPSC)',
    sourceUrl: 'https://uppsc.up.nic.in',
    negative: '1/3',
    paperIds: ['prog-sr-main'],
    ready: true, // 85 प्रश्न — मॉक टेस्ट-1
  ),
  'mgr-system': Exam(
    id: 'mgr-system',
    label: 'प्रबंधक (सिस्टम) — औद्योगिक विकास विभाग',
    shortLabel: 'प्रबंधक (सिस्टम)',
    authority: 'UPPSC',
    authorityFullName: 'उत्तर प्रदेश लोक सेवा आयोग (UPPSC)',
    sourceUrl: 'https://uppsc.up.nic.in',
    negative: '1/3',
    paperIds: ['mgr-system-main'],
    ready: true, // 110 प्रश्न — मॉक टेस्ट-2
  ),
  'prog-fin': Exam(
    id: 'prog-fin',
    label: 'प्रोग्रामर ग्रेड-2 — वित्तीय योजना एवं संसाधन निदेशालय',
    shortLabel: 'प्रोग्रामर (वित्त)',
    authority: 'UPPSC',
    authorityFullName: 'उत्तर प्रदेश लोक सेवा आयोग (UPPSC)',
    sourceUrl: 'https://uppsc.up.nic.in',
    negative: '1/3',
    paperIds: ['prog-fin-main'],
    ready: true, // 85 प्रश्न — मॉक टेस्ट-3
  ),
};

const Map<String, Paper> kPapers = {
  'uppcs-gs1': Paper(
    id: 'uppcs-gs1',
    examId: 'uppcs',
    label: 'सामान्य अध्ययन — प्रथम प्रश्नपत्र',
    questions: 150,
    marks: 200,
    note: 'इसी पेपर के नंबर मेरिट में जुड़ते हैं',
    subjects: ['itihas', 'polity', 'bhugol', 'arth', 'vigyan', 'paryavaran', 'up', 'ca'],
  ),
  'uppcs-csat': Paper(
    id: 'uppcs-csat',
    examId: 'uppcs',
    label: 'सी-सैट — द्वितीय प्रश्नपत्र',
    questions: 100,
    marks: 200,
    note: 'सिर्फ़ पास होना है — 33% नंबर चाहिए',
    subjects: ['comprehension', 'reasoning', 'ganit', 'hindi', 'english'],
  ),
  'roaro-gs': Paper(
    id: 'roaro-gs',
    examId: 'roaro',
    label: 'सामान्य अध्ययन',
    questions: 140,
    marks: 140,
    subjects: ['itihas', 'polity', 'bhugol', 'arth', 'vigyan', 'paryavaran', 'up', 'ca'],
  ),
  'roaro-hindi': Paper(
    id: 'roaro-hindi',
    examId: 'roaro',
    label: 'सामान्य हिंदी',
    questions: 60,
    marks: 60,
    subjects: ['hindi'],
  ),
  'pet-main': Paper(
    id: 'pet-main',
    examId: 'pet',
    label: 'पूरा पेपर',
    questions: 100,
    marks: 100,
    note: '15 खंड, कुल 2 घंटे',
    subjects: [
      'itihas', 'polity', 'bhugol', 'arth', 'vigyan', 'paryavaran', 'ca', 'up',
      'hindi', 'english', 'ganit', 'reasoning', 'comprehension', 'graph',
    ],
  ),

  // तीनों तकनीकी पदों में एक ही पेपर है और चारों खंड उसी में आते हैं.
  // अंकों का बँटवारा नीचे टिप्पणी में है — UI में सिर्फ़ कुल दिखता है.
  'prog-sr-main': Paper(
    id: 'prog-sr-main',
    examId: 'prog-sr',
    label: 'पूरा पेपर',
    questions: 85,
    marks: 170,
    note: '4 खंड, कुल 2 घंटे',
    // कंप्यूटर 100 · तार्किक 30 · गणित 20 · अंग्रेज़ी 20
    subjects: ['computer', 'reasoning', 'ganit', 'english'],
  ),
  'mgr-system-main': Paper(
    id: 'mgr-system-main',
    examId: 'mgr-system',
    label: 'पूरा पेपर',
    questions: 110,
    marks: 220,
    note: '4 खंड, कुल 2 घंटे 30 मिनट',
    // कंप्यूटर 150 · तार्किक 30 · गणित 20 · अंग्रेज़ी 20
    subjects: ['computer', 'reasoning', 'ganit', 'english'],
  ),
  'prog-fin-main': Paper(
    id: 'prog-fin-main',
    examId: 'prog-fin',
    label: 'पूरा पेपर',
    questions: 85,
    marks: 170,
    note: '4 खंड, कुल 2 घंटे',
    // कंप्यूटर 100 · तार्किक 30 · गणित 20 · अंग्रेज़ी 20
    subjects: ['computer', 'reasoning', 'ganit', 'english'],
  ),
};

Exam? examOf(String id) => kExams[id];
Paper? paperOf(String id) => kPapers[id];

/// जिन विषयों पर अभी एक भी प्रश्न नहीं है — UI में "जल्द आ रहा है" दिखाने के लिए.
///
/// अब यह ख़ाली है. पहले इसमें अंग्रेज़ी, गणित, तर्कशक्ति, गद्यांश और
/// ग्राफ़ पड़े थे — तब उन पर सचमुच कुछ नहीं था. अब हर विषय पर सौ से ऊपर
/// प्रश्न हैं, इसलिए किसी पर "जल्द आ रहा है" दिखाना झूठ होता.
///
/// नया विषय जोड़ें और उस पर प्रश्न न हों, तो उसे यहाँ डाल दीजिए —
/// छात्र को ख़ाली चिप दबाकर सूना पन्ना देखने से बचा लेगा.
const Set<String> kEmptySubjects = {};

/// पुराने प्रश्नों को टैग करने का नियम: विषय से परीक्षा-पेपर निकालना.
///
/// एक ही प्रश्न कई परीक्षाओं में चल जाता है — यूपी का इतिहास वाला प्रश्न
/// UPPCS, RO/ARO और PET तीनों के काम आता है. इसीलिए `exams` और `papers`
/// दोनों सूचियाँ हैं, एक मान नहीं.
const Map<String, List<String>> kSubjectToPapers = {
  'itihas': ['uppcs-gs1', 'roaro-gs', 'pet-main'],
  'polity': ['uppcs-gs1', 'roaro-gs', 'pet-main'],
  'bhugol': ['uppcs-gs1', 'roaro-gs', 'pet-main'],
  'arth': ['uppcs-gs1', 'roaro-gs', 'pet-main'],
  'vigyan': ['uppcs-gs1', 'roaro-gs', 'pet-main'],
  'up': ['uppcs-gs1', 'roaro-gs', 'pet-main'],
  'ca': ['uppcs-gs1', 'roaro-gs', 'pet-main'],
  'hindi': ['roaro-hindi', 'pet-main', 'uppcs-csat'],
  'english': ['pet-main', 'uppcs-csat'],
  'ganit': ['pet-main', 'uppcs-csat'],
  'reasoning': ['pet-main', 'uppcs-csat'],
  'comprehension': ['pet-main', 'uppcs-csat'],
  'graph': ['pet-main'],

  // तकनीकी पदों का अपना विषय — इन्हीं तीन पेपरों में जाता है, ऊपर वाली
  // सामान्य अध्ययन की परीक्षाओं में कहीं नहीं.
  'computer': ['prog-sr-main', 'mgr-system-main', 'prog-fin-main'],
};

/// नए रंग — `models.dart` के kSubjects में जो विषय नहीं हैं उनके लिए.
const Map<String, Color> kNewSubjectColors = {
  'english': Color(0xFF1F6F8B),
  'ganit': Color(0xFF8A5A2B),
  'reasoning': Color(0xFF5B4B8A),
  'comprehension': Color(0xFF2E6B4F),
  'graph': Color(0xFFA03E5E),
};
