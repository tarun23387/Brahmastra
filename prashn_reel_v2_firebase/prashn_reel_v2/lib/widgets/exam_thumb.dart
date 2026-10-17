import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../exam_dates.dart';
import '../exams.dart';
import '../models.dart';

/// हर परीक्षा का अपना "thumbnail" — रंग, चिह्न और एक पंक्ति, जिससे पहली
/// नज़र में समझ आए कि यह किस परीक्षा का course है.
///
/// सब कोड से बनता है (कोई इमेज फ़ाइल नहीं) — बिना इंटरनेट भी वैसा ही दिखता
/// है और APK हल्का रहता है. "जीवंत" दिखने के लिए पीछे का बड़ा चिह्न धीरे
/// तैरता है और कुछ-कुछ देर में एक चमक गुज़रती है.
///
/// ⚠️ यहाँ कोई सरकारी चिह्न (अशोक चक्र, राजचिह्न, मुहर) नहीं आना चाहिए —
/// Play की Misleading Claims नीति पर ऐप दो बार रुक चुका है.
class ExamLook {
  final List<Color> colors;
  final FaIconData icon;

  /// परीक्षा का अंग्रेज़ी छोटा नाम — thumbnail पर सबसे बड़ा.
  final String code;

  /// उसके नीचे एक पंक्ति — परीक्षा में क्या है.
  final String tagline;

  const ExamLook(this.colors, this.icon, this.code, this.tagline);
}

const Map<String, ExamLook> kExamLooks = {
  'pet': ExamLook([Color(0xFFC0581E), Color(0xFF7A2E12)],
      FontAwesomeIcons.listCheck, 'UP PET', '15 खंड · पूरा पेपर'),
  'uppcs': ExamLook([Color(0xFF2A4494), Color(0xFF14204F)],
      FontAwesomeIcons.landmark, 'UPPCS', 'प्रारंभिक · GS + CSAT'),
  'roaro': ExamLook([Color(0xFF0B6357), Color(0xFF053A32)],
      FontAwesomeIcons.fileSignature, 'RO / ARO', 'सा. अध्ययन + सा. हिंदी'),
  'prog-sr': ExamLook([Color(0xFF4338CA), Color(0xFF1E1A5E)],
      FontAwesomeIcons.code, 'Sr. Programmer', 'कंप्यूटर · प्रोग्रामिंग'),
  'mgr-system': ExamLook([Color(0xFF0E7490), Color(0xFF07364A)],
      FontAwesomeIcons.server, 'Manager (System)', 'सिस्टम · नेटवर्क · DB'),
  'prog-fin': ExamLook([Color(0xFF7C3AED), Color(0xFF34116E)],
      FontAwesomeIcons.chartLine, 'Programmer (Finance)', 'कंप्यूटर · वित्त'),
};

/// thumbnail की चौड़ाई÷ऊँचाई — grid भी यही लेते हैं (landing, dashboard).
/// तारीख़ वाली पट्टी के लिए थोड़ा लंबा रखा है.
const double kThumbAspect = 0.86;

ExamLook lookOf(String examId) =>
    kExamLooks[examId] ??
    const ExamLook([P.brand, P.brandDeep], FontAwesomeIcons.graduationCap,
        'Course', '');

class ExamThumb extends StatelessWidget {
  final Exam exam;

  /// ताला लगा है — आईडी-पासवर्ड से ही खुलेगा.
  final bool locked;

  /// मुफ़्त है (UP PET).
  final bool free;

  /// नीचे की छोटी पंक्ति की जगह — जैसे "312 दिन बचे".
  final String? footnote;

  final VoidCallback onTap;

  /// सूची में कौन-सा नंबर — आने की animation थोड़ी-थोड़ी देर से हो.
  final int index;

  const ExamThumb({
    super.key,
    required this.exam,
    required this.onTap,
    this.locked = false,
    this.free = false,
    this.footnote,
    this.index = 0,
  });

  @override
  Widget build(BuildContext context) {
    final look = lookOf(exam.id);

    // gradient और छाया बाहर के Container पर, ripple भीतर के Material पर.
    // पहले Ink पर छाया थी — Material उसे चौकोर काटता था और नीचे के कोनों पर
    // हल्के धब्बे दिखते थे (फ़ोन पर पकड़ा).
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: look.colors,
        ),
        boxShadow: [
          BoxShadow(
            color: look.colors.first.withOpacity(0.28),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            // चमक clip के भीतर — बाहर लगाने पर कोनों पर चौकोर धब्बे दिखते थे
            child: AspectRatio(
              aspectRatio: kThumbAspect,
              child: Stack(
                children: [
                  // सजावट: दो हल्के घेरे
                  Positioned(
                    right: -30,
                    top: -30,
                    child: _ring(110, Colors.white.withOpacity(0.07)),
                  ),
                  Positioned(
                    left: -24,
                    bottom: -40,
                    child: _ring(90, Colors.white.withOpacity(0.05)),
                  ),
                  // पीछे का बड़ा चिह्न — धीरे तैरता है. ऊपर-दाएँ, ताकि
                  // नीचे लिखे नाम के ऊपर न चढ़े.
                  Positioned(
                    right: 10,
                    top: 46,
                    child: FaIcon(look.icon,
                            size: 64, color: Colors.white.withOpacity(0.16))
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .moveY(
                          begin: 0,
                          end: -6,
                          duration: 2200.ms,
                          curve: Curves.easeInOut,
                        ),
                  ),
                  // पाठ
                  Padding(
                    padding: const EdgeInsets.fromLTRB(13, 12, 13, 11),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.16),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Center(
                                child: FaIcon(look.icon,
                                    size: 14, color: Colors.white),
                              ),
                            ),
                            const Spacer(),
                            if (free) _badge('मुफ़्त', P.goldBright, P.ink),
                            if (locked) _lock(),
                          ],
                        ),
                        const SizedBox(height: 9),
                        // अधिसूचना / अंतिम तिथि / परीक्षा — exam_dates.dart
                        ValueListenableBuilder<int>(
                          valueListenable: ExamDates.changes,
                          builder: (_, __, ___) {
                            final st = ExamDates.stageOf(exam.id);
                            return st == null
                                ? const SizedBox.shrink()
                                : _stage(st, look.colors.last);
                          },
                        ),
                        const Spacer(),
                        Text(
                          look.code,
                          maxLines: 2,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            height: 1.1,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          footnote ?? look.tagline,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.82),
                            fontSize: 11.5,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
                  // आने के थोड़ी देर बाद एक चमक गुज़रती है — कार्ड "ज़िंदा" लगें
                  .animate(delay: (900 + 250 * index).ms)
                  .shimmer(
                      duration: 1400.ms, color: Colors.white.withOpacity(0.22)),
            ),
          ),
        ),
      ),
    )
        .animate(delay: (70 * index).ms)
        .fadeIn(duration: 320.ms)
        .slideY(begin: 0.12, end: 0, curve: Curves.easeOutCubic);
  }

  // पट्टी ठोस रंग की — पारदर्शी रखने पर पीछे तैरता बड़ा चिह्न आर-पार
  // दिखता था और तारीख़ धुँधली पढ़ी जाती थी (फ़ोन पर पकड़ा).
  Widget _stage(ExamStage st, Color deep) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(8, 5, 8, 6),
        decoration: BoxDecoration(
          color: st.urgent ? P.goldBright : Color.lerp(deep, Colors.black, 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                FaIcon(FontAwesomeIcons.calendarDays,
                    size: 9.5,
                    color: st.urgent ? P.ink : Colors.white.withOpacity(0.85)),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(st.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 10.5,
                          height: 1.2,
                          color: st.urgent
                              ? P.ink
                              : Colors.white.withOpacity(0.85))),
                ),
              ],
            ),
            Text(st.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12.5,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                    color: st.urgent ? P.ink : Colors.white)),
          ],
        ),
      );

  Widget _ring(double size, Color c) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: c, width: 14),
        ),
      );

  Widget _badge(String t, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(t,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w800, color: fg)),
      );

  Widget _lock() => Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.28),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.35)),
        ),
        child: const Center(
          child: FaIcon(FontAwesomeIcons.lock, size: 11, color: Colors.white),
        ),
      );
}
