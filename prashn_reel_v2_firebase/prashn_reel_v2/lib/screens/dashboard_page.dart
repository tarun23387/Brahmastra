import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../auth.dart';
import '../build_flags.dart';
import '../exams.dart';
import '../models.dart';
import '../widgets/exam_thumb.dart';
import '../widgets/locked_sheet.dart';
import '../widgets/streak_hero.dart';
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
                // नाम का पहला अक्षर — इंडिगो गोले में केसरिया किनारा
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: P.brand,
                    shape: BoxShape.circle,
                    border: Border.all(color: P.goldBright, width: 2),
                  ),
                  child: Text(
                    e.name.isEmpty ? 'ब्र' : e.name.characters.first,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.1),
                  ),
                ),
                const SizedBox(width: 12),
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
                // सब मुफ़्त हो तो बिना लॉगिन भी यही पन्ना दिखता है —
                // तब लॉगआउट का बटन बेमानी है
                if (Session.isLoggedIn)
                  IconButton(
                    tooltip: 'लॉगआउट',
                    onPressed: onSignOut,
                    icon: FaIcon(FontAwesomeIcons.rightFromBracket,
                        size: 16, color: P.muted),
                  ),
              ],
            ),

            // ── 🔥 लय, आज का लक्ष्य, हफ़्ता ──
            // पहले यहाँ एक स्थिर बैनर था ("आज की तैयारी"), जो हर दिन वैसा ही
            // दिखता था. अब यह रोज़ बदलता है — यही छात्र को लौटाता है.
            const SizedBox(height: 18),
            const StreakHero(),

            // ── आज का प्रश्न ──
            const SizedBox(height: 14),
            const DailyQuestionCard(),

            // ── मेरी परीक्षाएँ ──
            if (mine.isNotEmpty) ...[
              const SizedBox(height: 22),
              _heading('मेरी परीक्षाएँ'),
              const SizedBox(height: 10),
              _grid([
                for (final (i, c) in mine.indexed)
                  if (kExams[c.examId] != null)
                    ExamThumb(
                      exam: kExams[c.examId]!,
                      index: i,
                      // "दिन बचे" नहीं — thumbnail पर अब परीक्षा के बचे दिन
                      // भी दिखते हैं, दोनों उलझते
                      footnote: '${kExams[c.examId]!.papers.length} पेपर · '
                          '${kAllFree ? 'मुफ़्त' : 'सदस्यता ${c.daysLeft} दिन'}',
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => PaperPickerPage(
                          exam: kExams[c.examId]!,
                          accent: lookOf(c.examId).colors.first,
                          onPractise: onPractise,
                        ),
                      )),
                    ),
              ]),
              const SizedBox(height: 4),

              const SizedBox(height: 8),
              // पन्ने का मुख्य बटन — केसरिया (ElevatedButton का theme)
              ElevatedButton.icon(
                onPressed: onPractiseAll,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                icon: const FaIcon(FontAwesomeIcons.shuffle, size: 14),
                label: const Text('सब मिलाकर हल करें'),
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
              _heading(mine.isEmpty ? 'परीक्षाएँ' : 'और courses'),
              const SizedBox(height: 10),
              // ली नहीं हैं — ताला; छूने पर "आईडी-पासवर्ड से खुलेगा"
              _grid([
                for (final (i, x) in others.indexed)
                  ExamThumb(
                    exam: x,
                    index: i,
                    locked: x.id != 'pet',
                    free: x.id == 'pet',
                    onTap: () => x.id == 'pet'
                        ? onFreeSample()
                        : showLockedCourse(context, x),
                  ),
              ]),
            ],

            // ── मुफ़्त नमूना ── (सब मुफ़्त हो तो PET ऊपर ही है)
            if (!kAllFree) ...[
              const SizedBox(height: 22),
              TextButton.icon(
                onPressed: onFreeSample,
                icon:
                    FaIcon(FontAwesomeIcons.bookOpen, size: 14, color: P.muted),
                label: Text('मुफ़्त पीईटी देखें',
                    style: TextStyle(fontSize: 13.5, color: P.muted)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _grid(List<Widget> children) => GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: kThumbAspect,
        children: children,
      );

  Widget _heading(String t) => Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
                color: P.goldBright, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 8),
          Text(t,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: P.ink,
                  letterSpacing: 0.2)),
        ],
      );

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
            colors: [P.card, P.cardLow],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: P.line),
          boxShadow: [
            BoxShadow(
              color: P.shadow.withOpacity(0.06),
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
}
