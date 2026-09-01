import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../build_flags.dart';
import '../exams.dart';
import '../models.dart';
import 'payment_page.dart';

/// परीक्षा चुनने का पन्ना — फिर उसी परीक्षा के प्रश्नपत्र दिखते हैं.
class ExamPickerPage extends StatefulWidget {
  /// सीधे इसी परीक्षा पर खुले — डैशबोर्ड से "लें" दबाने पर.
  final String? startExamId;

  const ExamPickerPage({super.key, this.startExamId});

  @override
  State<ExamPickerPage> createState() => _ExamPickerPageState();
}

class _ExamPickerPageState extends State<ExamPickerPage> {
  String? _examId;

  @override
  void initState() {
    super.initState();
    _examId = widget.startExamId;
  }

  static const _colors = {
    'uppcs': P.brand,
    'roaro': Color(0xFF10786B),
    'pet': Color(0xFFB62B4E),
  };

  static const _icons = {
    'uppcs': FontAwesomeIcons.landmarkDome,
    'roaro': FontAwesomeIcons.penFancy,
    'pet': FontAwesomeIcons.listCheck,
  };

  Color _colorOf(String id) => _colors[id] ?? P.brand;

  @override
  Widget build(BuildContext context) {
    final exam = _examId == null ? null : kExams[_examId];

    return Scaffold(
      backgroundColor: P.bg,
      appBar: AppBar(
        backgroundColor: P.card,
        surfaceTintColor: P.card,
        elevation: 0,
        title: Text(exam == null ? 'परीक्षा चुनिए' : 'पेपर चुनिए',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        leading: IconButton(
          icon: const FaIcon(FontAwesomeIcons.arrowLeft, size: 17),
          onPressed: () {
            if (exam != null) {
              setState(() => _examId = null);
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
          child: exam == null ? _examList() : _paperList(exam),
        ),
      ),
    );
  }

  // ───────────── परीक्षाएँ ─────────────

  Widget _examList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('आप कौन-सी परीक्षा दे रहे हैं?',
            style: TextStyle(fontSize: 13.5, color: P.muted, height: 1.5)),
        const SizedBox(height: 16),
        ...kExams.values.map((e) {
          final c = _colorOf(e.id);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _Tile(
              accent: c,
              icon: _icons[e.id] ?? FontAwesomeIcons.graduationCap,
              title: e.shortLabel,
              subtitle: e.label,
              trailing: e.ready
                  ? '${e.papers.length} पेपर · ${e.authority}'
                  : 'प्रश्न तैयार हो रहे हैं',
              ready: e.ready,
              onTap: e.ready ? () => setState(() => _examId = e.id) : null,
            ),
          );
        }),
      ],
    );
  }

  // ───────────── प्रश्नपत्र ─────────────

  Widget _paperList(Exam exam) {
    final c = _colorOf(exam.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.withOpacity(0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.withOpacity(0.18)),
          ),
          child: Row(
            children: [
              FaIcon(_icons[exam.id] ?? FontAwesomeIcons.graduationCap,
                  size: 15, color: c),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(exam.label,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: c,
                            height: 1.3)),
                    const SizedBox(height: 2),
                    Text('गलत जवाब पर ${exam.negative} अंक कटता है',
                        style: TextStyle(fontSize: 11.5, color: P.muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Text('इस परीक्षा के दोनों पेपर मिलेंगे —',
            style: TextStyle(fontSize: 13, color: P.muted, height: 1.5)),
        const SizedBox(height: 12),
        ...exam.papers.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: P.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: P.line),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: FaIcon(FontAwesomeIcons.solidCircleCheck,
                          size: 14, color: c),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(p.label,
                              style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  height: 1.35)),
                          const SizedBox(height: 3),
                          Text('${p.questions} प्रश्न · ${p.marks} अंक',
                              style: TextStyle(fontSize: 12, color: P.muted)),
                          if (p.note != null) ...[
                            const SizedBox(height: 3),
                            Text(p.note!,
                                style: TextStyle(
                                    fontSize: 11.5,
                                    color: P.muted.withOpacity(0.85),
                                    fontStyle: FontStyle.italic)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )),
        const SizedBox(height: 16),

        // Play Store वाली build में भुगतान का रास्ता नहीं दिखता — वजह
        // build_flags.dart में लिखी है. सीधे बाँटी जाने वाली APK में सब
        // पहले जैसा ही रहता है.
        if (kIsPlayBuild)
          const _SubscriptionNote()
        else
          FilledButton(
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => PaymentPage(exam: exam),
              ));
            },
            style: FilledButton.styleFrom(
              backgroundColor: c,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13)),
            ),
            child: const Text('आगे बढ़ें',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  final Color accent;
  final FaIconData icon;
  final String title;
  final String subtitle;
  final String trailing;

  /// null हो तो परीक्षा अभी चुनी नहीं जा सकती.
  final VoidCallback? onTap;
  final bool ready;

  const _Tile({
    required this.accent,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
    this.ready = true,
  });

  @override
  Widget build(BuildContext context) {
    // तैयार न हो तो कार्ड फीका, और दबता भी नहीं
    final shade = ready ? 1.0 : 0.45;

    return Opacity(
      opacity: shade,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFFEFB), Color(0xFFFBF6EC)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accent.withOpacity(0.22)),
              boxShadow: [
                BoxShadow(
                  color: accent.withOpacity(0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
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
                    color: accent.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(child: FaIcon(icon, size: 17, color: accent)),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title,
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: accent)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: const TextStyle(fontSize: 12.5, height: 1.35)),
                      const SizedBox(height: 3),
                      Text(trailing,
                          style: TextStyle(fontSize: 11.5, color: P.muted)),
                    ],
                  ),
                ),
                FaIcon(
                    ready
                        ? FontAwesomeIcons.chevronRight
                        : FontAwesomeIcons.clock,
                    size: 13,
                    color: P.muted.withOpacity(0.7)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Play Store वाली build में भुगतान के बटन की जगह यही दिखता है.
///
/// जानबूझकर सादा रखा है — न क़ीमत, न UPI, न फ़ोन नंबर, न "संपर्क कीजिए".
/// Google की समीक्षा सिर्फ़ बटन नहीं, ऐप के बाहर ख़रीदने की तरफ़ इशारा करने
/// वाला वाक्य भी पकड़ती है. इसलिए यहाँ बस इतना बताते हैं कि यह प्रश्नपत्र
/// सदस्यता वाला है, और जिसके पास सदस्यता है वह लॉगिन कर ले.
class _SubscriptionNote extends StatelessWidget {
  const _SubscriptionNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: P.card,
        border: Border.all(color: P.line),
        borderRadius: BorderRadius.circular(13),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FaIcon(FontAwesomeIcons.lock, size: 12, color: P.muted),
              SizedBox(width: 8),
              Text(
                'यह प्रश्नपत्र सदस्यता वाला है',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            'सदस्यता पहले से हो तो अपनी आईडी से लॉगिन कीजिए। '
            'यूपी पीईटी का पूरा प्रश्नपत्र बिना सदस्यता के भी खुला है।',
            style: TextStyle(fontSize: 12.5, color: P.muted, height: 1.45),
          ),
        ],
      ),
    );
  }
}
