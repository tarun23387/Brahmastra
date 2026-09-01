import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../auth.dart';
import '../models.dart';
import '../repository.dart';

/// एक विषय की पढ़ने वाली सामग्री — अध्यायों की सूची.
///
/// क्रम ही यहाँ सब कुछ है. अध्याय काल के हिसाब से समूह में दिखते हैं और
/// उसी क्रम में जिस क्रम में इतिहास घटा — इसीलिए इन्हें छाँटा नहीं जाता.
class LearnPage extends StatefulWidget {
  final String paperId;
  final String subject;
  final Color accent;

  const LearnPage({
    super.key,
    required this.paperId,
    required this.subject,
    required this.accent,
  });

  @override
  State<LearnPage> createState() => _LearnPageState();
}

class _LearnPageState extends State<LearnPage> {
  Lesson? _lesson;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final l = await LessonRepo.load(
      paperId: widget.paperId,
      subject: widget.subject,
    );
    if (!mounted) return;
    setState(() {
      _lesson = l;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sub = subjectOf(widget.subject);

    return Scaffold(
      backgroundColor: P.bg,
      appBar: AppBar(
        backgroundColor: P.card,
        surfaceTintColor: P.card,
        elevation: 0,
        title: Text(sub.label,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        leading: IconButton(
          icon: const FaIcon(FontAwesomeIcons.arrowLeft, size: 17),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(child: _body(sub)),
    );
  }

  Widget _body(Subject sub) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
    }

    final lesson = _lesson;
    if (lesson == null) return _empty();

    final groups = lesson.byEra;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
      children: [
        if (lesson.subtitle != null) ...[
          Text(lesson.subtitle!,
              style: TextStyle(fontSize: 13.5, color: P.muted, height: 1.5)),
          const SizedBox(height: 4),
        ],
        Text('${lesson.chapters.length} अध्याय · लगभग ${lesson.minutes} मिनट',
            style: TextStyle(fontSize: 12, color: P.muted.withOpacity(0.85))),
        const SizedBox(height: 18),
        for (final entry in groups.entries) ...[
          Row(
            children: [
              Container(width: 3, height: 15, color: sub.color),
              const SizedBox(width: 8),
              Text(entry.key,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: sub.color,
                      letterSpacing: 0.2)),
            ],
          ),
          const SizedBox(height: 10),
          ...entry.value.map((c) => _ChapterTile(
                chapter: c,
                index: lesson.chapters.indexOf(c) + 1,
                accent: sub.color,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ChapterPage(
                    chapter: c,
                    accent: sub.color,
                    subjectLabel: sub.label,
                  ),
                )),
              )),
          const SizedBox(height: 18),
        ],
      ],
    );
  }

  /// पाठ न मिलने की दो अलग वजहें हैं, और छात्र को सही वजह बतानी चाहिए.
  Widget _empty() {
    final locked = !Session.isSubscribed;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(locked ? FontAwesomeIcons.lock : FontAwesomeIcons.bookOpen,
                size: 26, color: P.muted.withOpacity(0.5)),
            const SizedBox(height: 14),
            Text(
              locked
                  ? 'यह हिस्सा सदस्यता वालों के लिए है।'
                  : 'इस विषय का पाठ अभी तैयार हो रहा है।',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: P.muted, height: 1.6),
            ),
            if (!locked) ...[
              const SizedBox(height: 6),
              Text('इंटरनेट बंद हो तो भी यही दिखता है — एक बार जाँच लीजिए।',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12,
                      color: P.muted.withOpacity(0.8),
                      height: 1.5)),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChapterTile extends StatelessWidget {
  final LessonChapter chapter;
  final int index;
  final Color accent;
  final VoidCallback onTap;

  const _ChapterTile({
    required this.chapter,
    required this.index,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: P.card,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: P.line),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('$index',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: accent)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(chapter.title,
                          style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              height: 1.35)),
                      if (chapter.summary.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(chapter.summary,
                            style: TextStyle(
                                fontSize: 12.5, color: P.muted, height: 1.45)),
                      ],
                      const SizedBox(height: 6),
                      Text('${chapter.minutes} मिनट',
                          style: TextStyle(
                              fontSize: 11.5, color: P.muted.withOpacity(0.8))),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 6),
                  child: FaIcon(FontAwesomeIcons.chevronRight,
                      size: 12, color: P.muted.withOpacity(0.55)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// एक अध्याय पढ़ने का परदा.
///
/// यहाँ जानबूझकर कुछ नहीं है — न बटन, न चित्र, न रंगीन डिब्बे. लंबा पढ़ना
/// तभी टिकता है जब परदा शांत हो. फ़ॉन्ट का आकार बड़ा और पंक्तियों के बीच
/// खुली जगह इसी वजह से है.
class ChapterPage extends StatelessWidget {
  final LessonChapter chapter;
  final Color accent;
  final String subjectLabel;

  const ChapterPage({
    super.key,
    required this.chapter,
    required this.accent,
    required this.subjectLabel,
  });

  @override
  Widget build(BuildContext context) {
    final paras = chapter.paragraphs;

    return Scaffold(
      backgroundColor: P.bg,
      appBar: AppBar(
        backgroundColor: P.card,
        surfaceTintColor: P.card,
        elevation: 0,
        title: Text(subjectLabel,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        leading: IconButton(
          icon: const FaIcon(FontAwesomeIcons.arrowLeft, size: 17),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 44),
          children: [
            if (chapter.era.isNotEmpty)
              Text(chapter.era.toUpperCase(),
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: accent,
                      letterSpacing: 0.8)),
            const SizedBox(height: 8),
            Text(chapter.title,
                style: const TextStyle(
                    fontSize: 21, fontWeight: FontWeight.w800, height: 1.35)),
            const SizedBox(height: 10),
            Container(width: 42, height: 3, color: accent.withOpacity(0.55)),
            const SizedBox(height: 22),
            for (final p in paras) ...[
              Text(p,
                  style: const TextStyle(
                      fontSize: 16.5, height: 1.85, color: P.ink)),
              const SizedBox(height: 18),
            ],
            // सारणियाँ कहानी के बाद आती हैं, बीच में नहीं — पढ़ने का बहाव
            // टूटे नहीं. रटने वाली चीज़ें यहीं एक जगह मिल जाती हैं.
            for (final tb in chapter.tables) ...[
              const SizedBox(height: 6),
              _TableBlock(table: tb, accent: accent),
              const SizedBox(height: 22),
            ],

            const SizedBox(height: 8),
            Center(
              child: Text('॥ अध्याय समाप्त ॥',
                  style: TextStyle(
                      fontSize: 12.5, color: P.muted.withOpacity(0.7))),
            ),
          ],
        ),
      ),
    );
  }
}

/// किस-किस विषय का पाठ तैयार है — यह Firestore से पूछकर दिखाता है.
///
/// सूची कोड में तय नहीं है: जिस विषय का पाठ चढ़ा दिया जाएगा वह अपने आप
/// यहाँ आ जाएगा, बिना नई build के. यही पूरी व्यवस्था का मक़सद था.
class LearnSubjectList extends StatefulWidget {
  final String paperId;
  final Color accent;

  const LearnSubjectList({
    super.key,
    required this.paperId,
    required this.accent,
  });

  @override
  State<LearnSubjectList> createState() => _LearnSubjectListState();
}

class _LearnSubjectListState extends State<LearnSubjectList> {
  List<String>? _subjects;

  @override
  void initState() {
    super.initState();
    LessonRepo.subjectsFor(widget.paperId).then((s) {
      if (mounted) setState(() => _subjects = s);
    });
  }

  @override
  Widget build(BuildContext context) {
    final subs = _subjects;

    if (subs == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
      );
    }

    // ख़ाली सूची की दो अलग वजहें हैं, और छात्र को सही वजह बतानी चाहिए.
    if (subs.isEmpty) {
      final locked = !Session.isSubscribed;
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: P.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: P.line),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FaIcon(locked ? FontAwesomeIcons.lock : FontAwesomeIcons.bookOpen,
                size: 14, color: P.muted),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                locked
                    ? 'पढ़ने वाला हिस्सा सदस्यता वालों के लिए है।'
                    : 'पाठ अभी तैयार हो रहे हैं। जल्दी ही यहाँ मिलेंगे।',
                style: TextStyle(fontSize: 13, color: P.muted, height: 1.6),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('विषय चुनिए — हर विषय शुरू से आख़िर तक, क्रम से।',
            style: TextStyle(fontSize: 13, color: P.muted, height: 1.5)),
        const SizedBox(height: 12),
        ...subs.map((id) {
          final s = subjectOf(id);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: P.card,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => LearnPage(
                    paperId: widget.paperId,
                    subject: id,
                    accent: widget.accent,
                  ),
                )),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: P.line),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: s.color.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(s.icon, size: 17, color: s.color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(s.label,
                            style: const TextStyle(
                                fontSize: 14.5, fontWeight: FontWeight.w700)),
                      ),
                      FaIcon(FontAwesomeIcons.chevronRight,
                          size: 12, color: P.muted.withOpacity(0.55)),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

/// एक सारणी.
///
/// चौड़ी सारणी फ़ोन पर टूटती है, इसलिए यह अपने अंदर बग़ल में सरकती है —
/// पूरा पन्ना नहीं सरकता. दो से ज़्यादा खाने वाली सारणियों में यही बचाता है.
class _TableBlock extends StatelessWidget {
  final LessonTable table;
  final Color accent;

  const _TableBlock({required this.table, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (table.title.isNotEmpty) ...[
          Row(
            children: [
              Container(width: 3, height: 14, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(table.title,
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: accent,
                        height: 1.35)),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        Container(
          decoration: BoxDecoration(
            color: P.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: P.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              defaultColumnWidth: const IntrinsicColumnWidth(),
              border: TableBorder.symmetric(
                inside: BorderSide(color: P.line, width: 1),
              ),
              children: [
                TableRow(
                  decoration: BoxDecoration(color: accent.withOpacity(0.08)),
                  children: [
                    for (final c in table.columns)
                      _cell(c, bold: true, color: accent),
                  ],
                ),
                for (final r in table.rows)
                  TableRow(children: [for (final c in r) _cell(c)]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _cell(String text, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13.5,
          height: 1.5,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w400,
          color: color ?? P.ink,
        ),
      ),
    );
  }
}
