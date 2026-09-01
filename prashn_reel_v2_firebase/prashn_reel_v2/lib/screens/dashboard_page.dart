import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../auth.dart';
import '../exams.dart';
import '../models.dart';
import '../widgets/study_art.dart';
import 'exam_picker_page.dart';
import 'paper_picker_page.dart';

/// सदस्य का घर — कौन-सी परीक्षाएँ ली हैं, और आगे क्या.
///
/// पहले यहाँ सिर्फ़ "सदस्यता चालू है" वाला कार्ड दिखता था और रास्ता वहीं
/// ख़त्म हो जाता था — न दूसरी परीक्षा ली जा सकती थी, न प्रश्नपत्र बदला
/// जा सकता था. अब यह पन्ना वही दोनों काम करता है.
class DashboardPage extends StatelessWidget {
  /// किसी परीक्षा का कोई प्रश्नपत्र चुनने पर.
  final void Function(String paperId, String? subject) onPractise;

  /// सब कुछ (बिना छाँट) हल करने पर.
  final VoidCallback onPractiseAll;

  final VoidCallback onFreeSample;
  final Future<void> Function() onSignOut;

  const DashboardPage({
    super.key,
    required this.onPractise,
    required this.onPractiseAll,
    required this.onFreeSample,
    required this.onSignOut,
  });

  static const _examColors = {
    'uppcs': Color(0xFF2A4494),
    'roaro': Color(0xFF0B6357),
    'pet': Color(0xFF97203E),
  };

  static const _examIcons = {
    'uppcs': FontAwesomeIcons.landmarkDome,
    'roaro': FontAwesomeIcons.penFancy,
    'pet': FontAwesomeIcons.listCheck,
  };

  Color _colorOf(String id) => _examColors[id] ?? P.brand;

  @override
  Widget build(BuildContext context) {
    final e = Session.entitlement;
    final mine = e.activeCourses;
    final expired = e.expiredCourses;

    // जो अभी ली नहीं हैं
    final others = kExams.values
        .where((x) => !mine.any((c) => c.examId == x.id))
        .where((x) => !expired.any((c) => c.examId == x.id))
        .toList();

    return Scaffold(
      backgroundColor: P.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 30),
          children: [
            // ── ऊपर: कौन हैं ──
            Row(
              children: [
                Container(
                  width: 4,
                  height: 36,
                  decoration: BoxDecoration(
                      color: P.brand, borderRadius: BorderRadius.circular(3)),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(e.name.isEmpty ? 'ब्रह्मास्त्र' : e.name,
                          style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              height: 1.15)),
                      const SizedBox(height: 1),
                      Text(
                        mine.isEmpty
                            ? 'कोई परीक्षा चालू नहीं'
                            : '${mine.length} परीक्षा चालू',
                        style: TextStyle(fontSize: 12.5, color: P.muted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'लॉगआउट',
                  onPressed: onSignOut,
                  icon: FaIcon(FontAwesomeIcons.rightFromBracket,
                      size: 16, color: P.muted),
                ),
              ],
            ),

            // ── पढ़ाई का बैनर ──
            const SizedBox(height: 18),
            StudyHero(
              title: mine.isEmpty ? 'तैयारी शुरू कीजिए' : 'आज की तैयारी',
              subtitle: mine.isEmpty
                  ? 'परीक्षा चुनिए और रोज़ थोड़ा-थोड़ा हल कीजिए।'
                  : 'रोज़ का अभ्यास ही मेरिट लाता है।',
              tint: Tint.sky,
              tintInk: Tint.skyInk,
              motif: StudyMotif.target,
            ),

            // ── मेरी परीक्षाएँ ──
            if (mine.isNotEmpty) ...[
              const SizedBox(height: 22),
              _heading('मेरी परीक्षाएँ'),
              const SizedBox(height: 10),
              ...mine.map((c) => _myCourse(context, c)),

              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: onPractiseAll,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  side: const BorderSide(color: P.line),
                  foregroundColor: P.muted,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13)),
                ),
                icon: const FaIcon(FontAwesomeIcons.shuffle, size: 14),
                label: const Text('सब मिलाकर हल करें',
                    style:
                        TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
              ),
            ],

            // ── खत्म हो चुकी ──
            if (expired.isNotEmpty) ...[
              const SizedBox(height: 22),
              _heading('खत्म हो चुकी'),
              const SizedBox(height: 10),
              ...expired.map((c) => _expiredCourse(context, c)),
            ],

            // ── और परीक्षाएँ ──
            if (others.isNotEmpty) ...[
              const SizedBox(height: 22),
              _heading(mine.isEmpty ? 'परीक्षाएँ' : 'और परीक्षाएँ जोड़ें'),
              const SizedBox(height: 10),
              ...others.map((x) => _otherExam(context, x)),
            ],

            // ── मुफ़्त नमूना ──
            const SizedBox(height: 22),
            TextButton.icon(
              onPressed: onFreeSample,
              icon: FaIcon(FontAwesomeIcons.bookOpen, size: 14, color: P.muted),
              label: Text('मुफ़्त पीईटी देखें',
                  style: TextStyle(fontSize: 13.5, color: P.muted)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heading(String t) => Text(t,
      style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          color: P.muted,
          letterSpacing: 0.3));

  // ───────────── ली हुई परीक्षा ─────────────

  Widget _myCourse(BuildContext context, Course c) {
    final exam = kExams[c.examId];
    if (exam == null) return const SizedBox.shrink();
    final col = _colorOf(c.examId);

    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => PaperPickerPage(
              exam: exam,
              accent: col,
              onPractise: onPractise,
            ),
          )),
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFFEFB), Color(0xFFFBF6EC)],
              ),
              border: Border.all(color: col.withOpacity(0.24)),
              boxShadow: [
                BoxShadow(
                  color: col.withOpacity(0.12),
                  blurRadius: 18,
                  offset: const Offset(0, 9),
                ),
                BoxShadow(
                  color: const Color(0xFF3B2A17).withOpacity(0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: col.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: FaIcon(
                        _examIcons[c.examId] ?? FontAwesomeIcons.graduationCap,
                        size: 17,
                        color: col),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(exam.shortLabel,
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: col)),
                      const SizedBox(height: 2),
                      Text('${exam.papers.length} पेपर',
                          style: const TextStyle(fontSize: 12.5)),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          FaIcon(FontAwesomeIcons.clock,
                              size: 10,
                              color: c.isExpiringSoon ? P.wrong : P.muted),
                          const SizedBox(width: 5),
                          Text(
                            '${c.daysLeft} दिन बचे',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: c.isExpiringSoon ? P.wrong : P.muted,
                              fontWeight: c.isExpiringSoon
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                FaIcon(FontAwesomeIcons.chevronRight,
                    size: 13, color: P.muted.withOpacity(0.7)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ───────────── अवधि पूरी ─────────────

  Widget _expiredCourse(BuildContext context, Course c) {
    final exam = kExams[c.examId];
    if (exam == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFEFB), Color(0xFFFBF6EC)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: P.line),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3B2A17).withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(exam.shortLabel,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: P.muted)),
                  const SizedBox(height: 2),
                  Text('खत्म हो गई है',
                      style: TextStyle(fontSize: 12, color: P.wrong)),
                ],
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ExamPickerPage(startExamId: exam.id),
              )),
              style: FilledButton.styleFrom(
                backgroundColor: P.gold,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11)),
              ),
              child: const Text('दोबारा लें',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────── जो ली नहीं ─────────────

  Widget _otherExam(BuildContext context, Exam x) {
    final col = _colorOf(x.id);

    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Opacity(
        opacity: x.ready ? 1.0 : 0.5,
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: P.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: P.line),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: col.withOpacity(0.09),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Center(
                  child: FaIcon(
                      _examIcons[x.id] ?? FontAwesomeIcons.graduationCap,
                      size: 15,
                      color: col),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(x.shortLabel,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(x.ready ? x.label : 'प्रश्न तैयार हो रहे हैं',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.5, color: P.muted)),
                  ],
                ),
              ),
              if (x.ready)
                FilledButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ExamPickerPage(startExamId: x.id),
                  )),
                  style: FilledButton.styleFrom(
                    backgroundColor: P.gold,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11)),
                  ),
                  child: const Text('लें',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                )
              else
                FaIcon(FontAwesomeIcons.clock,
                    size: 13, color: P.muted.withOpacity(0.7)),
            ],
          ),
        ),
      ),
    );
  }
}
