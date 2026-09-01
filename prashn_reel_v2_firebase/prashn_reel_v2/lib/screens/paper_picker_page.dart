import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../exams.dart';
import '../models.dart';
import 'learn_page.dart';

/// एक परीक्षा के भीतर — कौन-सा प्रश्नपत्र, और चाहें तो कौन-सा विषय.
///
/// छात्र जब चाहे यहाँ आकर बदल सकता है. पूरा पेपर चाहिए तो ऊपर वाला
/// बटन, किसी एक विषय पर काम करना हो तो नीचे की सूची.
class PaperPickerPage extends StatefulWidget {
  final Exam exam;
  final Color accent;

  /// (प्रश्नपत्र, विषय) — विषय null हो तो पूरा पेपर.
  final void Function(String paperId, String? subject) onPractise;

  const PaperPickerPage({
    super.key,
    required this.exam,
    required this.accent,
    required this.onPractise,
  });

  @override
  State<PaperPickerPage> createState() => _PaperPickerPageState();
}

class _PaperPickerPageState extends State<PaperPickerPage> {
  String? _openPaper;

  /// 0 = पेपर हल करना, 1 = पढ़ना.
  int _tab = 0;

  void _go(String paperId, String? subject) {
    widget.onPractise(paperId, subject);
    // डैशबोर्ड तक के सारे पन्ने बंद — छात्र सीधे प्रश्नों पर पहुँचे
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.accent;

    return Scaffold(
      backgroundColor: P.bg,
      appBar: AppBar(
        backgroundColor: P.card,
        surfaceTintColor: P.card,
        elevation: 0,
        title: Text(widget.exam.shortLabel,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        leading: IconButton(
          icon: const FaIcon(FontAwesomeIcons.arrowLeft, size: 17),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
          children: [
            // दो हिस्से — अभ्यास और पढ़ाई.
            //
            // पहला tab वही रहा जो पहले से था, क्योंकि छात्र इसी पन्ने से
            // पेपर खोलने के आदी हैं. पढ़ने वाला हिस्सा बग़ल में जुड़ा है.
            _tabs(c),
            const SizedBox(height: 18),

            if (_tab == 0) ...[
              Text('कौन-सा पेपर हल करना है?',
                  style:
                      TextStyle(fontSize: 13.5, color: P.muted, height: 1.5)),
              const SizedBox(height: 14),
              ...widget.exam.papers.map((p) => _paper(p, c)),
            ] else
              LearnSubjectList(
                paperId: widget.exam.papers.first.id,
                accent: c,
              ),
          ],
        ),
      ),
    );
  }

  Widget _tabs(Color c) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: P.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: P.line),
      ),
      child: Row(
        children: [
          _tabButton(0, 'हल करें', FontAwesomeIcons.listCheck, c),
          _tabButton(1, 'पढ़िए', FontAwesomeIcons.bookOpen, c),
        ],
      ),
    );
  }

  Widget _tabButton(int index, String label, FaIconData icon, Color c) {
    final on = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: on ? c : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FaIcon(icon, size: 12, color: on ? Colors.white : P.muted),
              const SizedBox(width: 7),
              Text(label,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: on ? Colors.white : P.muted)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _paper(Paper p, Color c) {
    final open = _openPaper == p.id;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: P.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: open ? c.withOpacity(0.4) : P.line),
        ),
        child: Column(
          children: [
            // ── पेपर का शीर्ष ──
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _go(p.id, null),
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(p.label,
                                style: const TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w700,
                                    height: 1.35)),
                            const SizedBox(height: 3),
                            Text('${p.questions} प्रश्न · ${p.marks} अंक',
                                style: TextStyle(fontSize: 12, color: P.muted)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 13, vertical: 8),
                        decoration: BoxDecoration(
                          color: c,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: const Text('हल करें',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: P.card)),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const Divider(height: 1, color: P.line),

            // ── विषय से छाँटें ──
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _openPaper = open ? null : p.id),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
                  child: Row(
                    children: [
                      FaIcon(FontAwesomeIcons.filter, size: 12, color: P.muted),
                      const SizedBox(width: 9),
                      Text('किसी एक विषय पर काम करें',
                          style: TextStyle(fontSize: 13, color: P.muted)),
                      const Spacer(),
                      FaIcon(
                          open
                              ? FontAwesomeIcons.chevronUp
                              : FontAwesomeIcons.chevronDown,
                          size: 11,
                          color: P.muted),
                    ],
                  ),
                ),
              ),
            ),

            if (open)
              Padding(
                padding: const EdgeInsets.fromLTRB(13, 0, 13, 13),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: p.subjects.map((s) {
                    final sub = subjectOf(s);
                    final empty = kEmptySubjects.contains(s);
                    return InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: empty ? null : () => _go(p.id, s),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: empty ? P.bg : sub.color.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color:
                                  empty ? P.line : sub.color.withOpacity(0.28)),
                        ),
                        child: Text(
                          sub.label,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: empty ? P.muted.withOpacity(0.5) : sub.color,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
