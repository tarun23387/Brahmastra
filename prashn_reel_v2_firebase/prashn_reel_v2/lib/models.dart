import 'package:flutter/material.dart';

/// सूची-मिलान प्रश्न की दो सूचियाँ.
///
/// पहले ऐसे प्रश्न पूरे-के-पूरे `question` में एक लंबी पट्टी बनकर आते थे —
/// "A. किलिमंजारो 1. यूरोप B. एलब्रुस 2. उत्तरी अमेरिका …" — और कार्ड में
/// पढ़ना नामुमकिन था. इसीलिए ये प्रश्न अगस्त में बैंक से हटा दिए गए थे.
/// अब दोनों सूचियाँ अलग रखी जाती हैं ताकि कार्ड में आमने-सामने, वैसे ही
/// दिखें जैसे असली प्रश्नपत्र में छपती हैं.
class MatchTable {
  /// प्रश्न की सिर्फ़ पहली पंक्ति — "सूची-I को सूची-II से सुमेलित कीजिए:".
  ///
  /// `question` में दोनों सूचियाँ सादे पाठ में भी पड़ी रहती हैं, ताकि जिन
  /// फ़ोनों में पुरानी APK है (जो `match` समझती ही नहीं) उनमें प्रश्न अधूरा
  /// न दिखे. नई APK सूचियाँ सारणी में दिखाती है, इसलिए ऊपर सिर्फ़ यही
  /// पंक्ति छापती है — वरना वही सूचियाँ दो बार दिखतीं.
  final String intro;

  final String leftTitle;
  final String rightTitle;
  final List<String> left;
  final List<String> right;

  const MatchTable({
    required this.intro,
    required this.leftTitle,
    required this.rightTitle,
    required this.left,
    required this.right,
  });

  /// कितनी कतारें बनेंगी — दोनों सूचियाँ बराबर न हों तो भी कुछ न छूटे.
  int get rows => left.length > right.length ? left.length : right.length;

  static MatchTable? fromMap(dynamic m) {
    if (m is! Map) return null;
    List<String> pick(String k) {
      final v = m[k];
      return v is List ? v.map((e) => '$e'.trim()).toList() : const <String>[];
    }

    final left = pick('left');
    final right = pick('right');
    if (left.isEmpty || right.isEmpty) return null;

    return MatchTable(
      intro: '${m['intro'] ?? ''}'.trim(),
      leftTitle: '${m['leftTitle'] ?? 'सूची-I'}'.trim(),
      rightTitle: '${m['rightTitle'] ?? 'सूची-II'}'.trim(),
      left: left,
      right: right,
    );
  }

  Map<String, dynamic> toMap() => {
        'intro': intro,
        'leftTitle': leftTitle,
        'rightTitle': rightTitle,
        'left': left,
        'right': right,
      };
}

class Question {
  final String id;
  final String subject;
  final String question;
  final List<String> options;
  final int answer;
  final String explanation;

  /// सिर्फ़ सूची-मिलान वाले प्रश्नों में — बाक़ी में null.
  final MatchTable? match;

  /// किस वर्ष की परीक्षा में यह प्रश्न आया था — सिर्फ़ PYQ में, बाक़ी में null.
  /// कार्ड पर "2023" का ठप्पा इसी से लगता है.
  final int? year;

  const Question({
    required this.id,
    required this.subject,
    required this.question,
    required this.options,
    required this.answer,
    required this.explanation,
    this.match,
    this.year,
  });

  static Question? fromMap(String id, Map<String, dynamic> m) {
    final rawOptions = m['options'];
    if (rawOptions is! List || rawOptions.length < 2) return null;
    final options = rawOptions.map((e) => '$e').toList();

    final rawAnswer = m['answer'];
    final answer =
        rawAnswer is int ? rawAnswer : int.tryParse('${rawAnswer ?? ''}') ?? -1;
    if (answer < 0 || answer >= options.length) return null;

    final question = '${m['question'] ?? ''}'.trim();
    if (question.isEmpty) return null;

    final subject = '${m['subject'] ?? 'ca'}';

    return Question(
      id: id,
      subject: kSubjects.containsKey(subject) ? subject : 'ca',
      question: question,
      options: options,
      answer: answer,
      explanation: '${m['explanation'] ?? ''}'.trim(),
      match: MatchTable.fromMap(m['match']),
      year: _year(m['year']),
    );
  }

  /// बेतुका वर्ष चुपचाप गिरा देते हैं — ठप्पा न दिखना, ग़लत ठप्पा दिखने से
  /// बेहतर है. पुराने कैश में यह फ़ील्ड होती ही नहीं, वहाँ null आता है.
  static int? _year(dynamic raw) {
    final y = raw is int ? raw : int.tryParse('${raw ?? ''}');
    if (y == null || y < 1900 || y > 2100) return null;
    return y;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'subject': subject,
        'question': question,
        'options': options,
        'answer': answer,
        'explanation': explanation,
        // सिर्फ़ मिलान वाले प्रश्नों में — बाक़ी का कैश हल्का रहे
        if (match != null) 'match': match!.toMap(),
        // वैसे ही सिर्फ़ PYQ में
        if (year != null) 'year': year,
      };
}

class Subject {
  final String label;
  final Color color;
  final IconData icon;
  const Subject(this.label, this.color, this.icon);
}

const Map<String, Subject> kSubjects = {
  'itihas':
      Subject('इतिहास', Color(0xFF8C3A1E), Icons.account_balance_outlined),
  'polity': Subject('राजव्यवस्था', Color(0xFF2A4494), Icons.gavel_outlined),
  'bhugol': Subject('भूगोल', Color(0xFF0B6357), Icons.public_outlined),
  'arth':
      Subject('अर्थव्यवस्था', Color(0xFF7D5606), Icons.trending_up_outlined),
  'vigyan': Subject('विज्ञान', Color(0xFF56308A), Icons.science_outlined),
  // पर्यावरण अब अपना विषय है — पहले यह नाम भर से विज्ञान में जुड़ा था,
  // जबकि UPPSC की अधिसूचना में यह अलग से नामज़द हिस्सा है.
  'paryavaran': Subject('पर्यावरण', Color(0xFF2F6B34), Icons.eco_outlined),
  'up': Subject('यूपी विशेष', Color(0xFF97203E), Icons.location_on_outlined),
  'ca': Subject('करेंट अफेयर्स', Color(0xFFA1540A), Icons.newspaper_outlined),
  'hindi':
      Subject('सामान्य हिंदी', Color(0xFF0A5670), Icons.translate_outlined),

  // NOTE: ये विषय `lib/exams.dart` में तो थे पर यहाँ नहीं — और `fromMap`
  // अनजान विषय को चुपचाप 'ca' बना देता है. इसलिए इनके प्रश्न करेंट अफेयर्स
  // में जा गिरते. अब दोनों सूचियाँ मेल खाती हैं.
  'reasoning':
      Subject('तर्कशक्ति', Color(0xFF5B4B8A), Icons.psychology_outlined),
  'ganit':
      Subject('प्रारंभिक गणित', Color(0xFF8A5A2B), Icons.calculate_outlined),
  'english': Subject('General English', Color(0xFF1F6F8B), Icons.abc_outlined),
  'comprehension':
      Subject('गद्यांश', Color(0xFF2E6B4F), Icons.menu_book_outlined),
  'graph':
      Subject('ग्राफ़ व सारणी', Color(0xFFA03E5E), Icons.bar_chart_outlined),
};

Subject subjectOf(String id) => kSubjects[id] ?? kSubjects['ca']!;

/// काग़ज़ जैसा गर्म पैलेट.
///
/// पहले यह ठंडा नीला-धूसर था और सब कुछ सफ़ेद पर सफ़ेद लगता था. क्रीम
/// पृष्ठभूमि पर हाथीदाँती कार्ड रखने से गहराई अपने आप बनती है, और लंबी
/// पढ़ाई में आँखें कम थकती हैं — छपी किताब की तरह.
///
/// पूरे ऐप के रंग यहीं से आते हैं. यहाँ बदलिए, हर स्क्रीन बदल जाएगी.
class P {
  /// पृष्ठभूमि — हल्की क्रीम
  static const bg = Color(0xFFF7F3EC);

  /// कार्ड और हेडर — हाथीदाँती, पृष्ठभूमि से थोड़ा हल्का
  static const card = Color(0xFFFFFCF6);

  /// मुख्य पाठ — गर्म काला (शुद्ध काला कठोर लगता है)
  static const ink = Color(0xFF231B14);

  /// गौण पाठ
  static const muted = Color(0xFF7A6A58);

  /// किनारे और बँटवारे की रेखाएँ
  static const line = Color(0xFFE3D9C8);

  static const right = Color(0xFF1B7A50);
  static const wrong = Color(0xFFA83228);

  /// सदस्यता और ख़ास चीज़ों के लिए — सोना
  static const gold = Color(0xFF9C7A16);

  /// ऐप का अपना रंग — गहरा मैरून. जहाँ किसी विषय का रंग न हो वहाँ यही.
  static const brand = Color(0xFF8C3A1E);
}

const List<String> kLetters = ['अ', 'ब', 'स', 'द'];

/// पढ़ने वाली सामग्री का एक अध्याय.
///
/// प्रश्न नहीं — कहानी. `firebase/admin/lessons/` में लिखी जाती है और
/// `build-lessons.js` से Firestore पर चढ़ती है, इसलिए इसे बदलने के लिए
/// नई build की ज़रूरत नहीं पड़ती.
class LessonChapter {
  final String id;
  final String era;
  final String title;
  final String summary;
  final String body;
  final int minutes;
  final List<LessonTable> tables;

  const LessonChapter({
    required this.id,
    required this.era,
    required this.title,
    required this.summary,
    required this.body,
    required this.minutes,
    required this.tables,
  });

  /// अधूरा अध्याय चुपचाप छोड़ दिया जाता है — आधा पाठ दिखाने से बेहतर है
  /// कि वह दिखे ही नहीं.
  static LessonChapter? fromMap(dynamic raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final id = '${m['id'] ?? ''}'.trim();
    final title = '${m['title'] ?? ''}'.trim();
    final body = '${m['body'] ?? ''}'.trim();
    if (id.isEmpty || title.isEmpty || body.isEmpty) return null;
    final mins = m['minutes'];
    return LessonChapter(
      id: id,
      era: '${m['era'] ?? ''}'.trim(),
      title: title,
      summary: '${m['summary'] ?? ''}'.trim(),
      body: body,
      minutes: mins is num ? mins.toInt() : 0,
      tables: _tablesOf(m['tables']),
    );
  }

  static List<LessonTable> _tablesOf(dynamic raw) {
    if (raw is! List) return const [];
    final out = <LessonTable>[];
    for (final e in raw) {
      final t = LessonTable.fromMap(e);
      if (t != null) out.add(t);
    }
    return out;
  }

  /// पैराग्राफ़ — पढ़ने के परदे को यही चाहिए.
  List<String> get paragraphs =>
      body.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
}

/// अध्याय के आख़िर में लगने वाली सारणी.
///
/// कहानी सिलसिला समझाती है, पर परीक्षा में आधे प्रश्न सुमेलन वाले होते हैं —
/// वैदिक नदियों के आधुनिक नाम, महाजनपद और राजधानियाँ, हड़प्पाई स्थल और नदियाँ.
/// वे तथ्य कहानी में ठूँसने से पढ़ना भारी हो जाता, इसलिए अलग सारणी में हैं.
class LessonTable {
  final String title;
  final List<String> columns;
  final List<List<String>> rows;

  const LessonTable({
    required this.title,
    required this.columns,
    required this.rows,
  });

  static LessonTable? fromMap(dynamic raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final cols = m['columns'];
    final rows = m['rows'];
    if (cols is! List || rows is! List || cols.isEmpty) return null;

    final columns = cols.map((c) => '$c').toList();
    final out = <List<String>>[];
    for (final r in rows) {
      // Firestore array के भीतर array नहीं रखता, इसलिए हर पंक्ति
      // { cells: [...] } बनकर आती है. सादा array भी चला लेते हैं, ताकि
      // पुराना ढाँचा कहीं बचा हो तो टूटे नहीं.
      final List? cellList =
          r is List ? r : (r is Map ? r['cells'] as List? : null);
      if (cellList == null) continue;
      // छोटी पंक्ति को भर देते हैं — आधी सारणी दिखाने से बेहतर है कि
      // ख़ाली ख़ाना दिखे, वरना पूरी सारणी गिर जाती.
      final cells = cellList.map((c) => '$c').toList();
      while (cells.length < columns.length) {
        cells.add('');
      }
      out.add(cells.take(columns.length).toList());
    }
    if (out.isEmpty) return null;

    return LessonTable(
      title: '${m['title'] ?? ''}'.trim(),
      columns: columns,
      rows: out,
    );
  }
}

/// एक विषय की पूरी पढ़ने वाली सामग्री.
class Lesson {
  final String key;
  final String paper;
  final String subject;
  final String title;
  final String? subtitle;
  final List<LessonChapter> chapters;

  const Lesson({
    required this.key,
    required this.paper,
    required this.subject,
    required this.title,
    required this.subtitle,
    required this.chapters,
  });

  int get minutes => chapters.fold(0, (a, c) => a + c.minutes);

  /// अध्याय काल के हिसाब से, क्रम बिगाड़े बिना.
  ///
  /// क्रम ही इस सामग्री की जान है — प्राचीन के बाद मध्यकाल, फिर आधुनिक.
  /// इसलिए यहाँ छाँटा नहीं जाता, बस वैसे ही समूह बना दिए जाते हैं जैसे
  /// फ़ाइल में लिखे हैं.
  Map<String, List<LessonChapter>> get byEra {
    final out = <String, List<LessonChapter>>{};
    for (final c in chapters) {
      (out[c.era.isEmpty ? 'अन्य' : c.era] ??= []).add(c);
    }
    return out;
  }

  static Lesson? fromMap(Map<String, dynamic> m) {
    final raw = m['chapters'];
    if (raw is! List) return null;
    final chapters = <LessonChapter>[];
    for (final e in raw) {
      final c = LessonChapter.fromMap(e);
      if (c != null) chapters.add(c);
    }
    if (chapters.isEmpty) return null;
    return Lesson(
      key: '${m['key'] ?? ''}',
      paper: '${m['paper'] ?? ''}',
      subject: '${m['subject'] ?? ''}',
      title: '${m['title'] ?? 'पाठ'}',
      subtitle: m['subtitle'] == null ? null : '${m['subtitle']}',
      chapters: chapters,
    );
  }
}
