import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../auth.dart';
import '../models.dart';
import '../exams.dart';
import '../widgets/exam_thumb.dart';
import '../widgets/locked_sheet.dart';
import '../widgets/study_art.dart';
import 'login_page.dart';
import 'sources_page.dart';

/// पहला पन्ना — दो कार्ड: मुफ़्त नमूना और पूरा एक्सेस.
class LandingPage extends StatelessWidget {
  /// मुफ़्त नमूना खोलने पर.
  final VoidCallback onFreeSample;

  /// लॉगिन सफल होने पर.
  final VoidCallback onLoggedIn;

  /// सदस्य के लिए — प्रश्नों पर वापस जाने का रास्ता.
  /// सदस्यता न हो तो null.
  final VoidCallback? onContinue;

  const LandingPage({
    super.key,
    required this.onFreeSample,
    required this.onLoggedIn,
    this.onContinue,
  });

  static const _gold = P.gold;

  /// UP PET सबसे पहले — वही मुफ़्त है, नए छात्र को वहीं से शुरू करना है.
  static List<Exam> get _ordered => [
        kExams['pet']!,
        ...kExams.values.where((x) => x.id != 'pet'),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: P.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 26, 18, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── शीर्षक ──
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset('assets/images/logo.png',
                        width: 46, height: 46),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('ब्रह्मास्त्र',
                            style: TextStyle(
                                fontSize: 23,
                                fontWeight: FontWeight.w800,
                                color: P.brand,
                                height: 1.1)),
                        SizedBox(height: 2),
                        Text('UPPCS · RO/ARO · PET · Programmer',
                            style: TextStyle(fontSize: 12.5, color: P.muted)),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ── अस्वीकरण की पट्टी ──
              //
              // ऊपर, कार्डों से पहले — क्योंकि Play की Misleading Claims नीति
              // माँगती है कि "यह सरकारी ऐप नहीं है" पहली नज़र में दिखे, किसी
              // भीतरी पन्ने में छिपा न हो. छूने पर पूरा ब्योरा खुलता है.
              const _NotGovernmentStrip(),

              const SizedBox(height: 18),

              // ── पढ़ाई का बैनर ──
              // const StudyHero(
              //   title: 'UPPET — पूरा मुफ़्त',
              //   subtitle: 'रील की तरह स्क्रॉल कीजिए — कोई फ़िल्टर, कोई झंझट नहीं।',
              //   tint: Tint.mint,
              //   tintInk: Tint.mintInk,
              //   motif: StudyMotif.book,
              // ),

              // नए छात्र के लिए — एक नज़र में क्या मिलेगा, और सीधा मुफ़्त PET
              if (onContinue == null) ...[
                _Hero(onStart: onFreeSample),
                const SizedBox(height: 18),
              ],

              // सदस्य के लिए पहला कार्ड — "ख़रीदिए" वाला उसे दिखाना बेमतलब है
              if (onContinue != null) ...[
                _Card(
                  accent: _gold,
                  icon: FontAwesomeIcons.solidCircleCheck,
                  title: 'सदस्यता चालू है',
                  subtitle: Session.entitlement.name,
                  bullets: [
                    '${Session.entitlement.daysLeft} दिन बचे हैं',
                    'सारे प्रश्न और मानचित्र खुले हैं',
                  ],
                  cta: 'प्रश्नों पर वापस जाएँ',
                  filled: true,
                  onTap: onContinue!,
                ),
                const SizedBox(height: 14),
              ],

              // ── सारे courses ──
              //
              // पहले यहाँ दो कार्ड थे (PET मुफ़्त / UPPCS·RO/ARO) और बाक़ी
              // परीक्षाएँ भीतर छिपी थीं. अब सब सामने हैं: UP PET खुला, बाक़ी
              // पर ताला — छूने पर बताया जाता है कि आईडी-पासवर्ड से खुलेगा.
              const Text('सभी courses',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800, color: P.ink)),
              const SizedBox(height: 2),
              const Text('UP PET मुफ़्त है · बाक़ी आईडी-पासवर्ड से खुलते हैं',
                  style: TextStyle(fontSize: 12.5, color: P.muted)),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: kThumbAspect,
                children: [
                  for (final (i, x) in _ordered.indexed)
                    ExamThumb(
                      exam: x,
                      index: i,
                      free: x.id == 'pet',
                      locked: x.id != 'pet' && onContinue == null,
                      onTap: () async {
                        if (x.id == 'pet') {
                          onFreeSample();
                          return;
                        }
                        if (onContinue != null) {
                          onContinue!();
                          return;
                        }
                        if (await showLockedCourse(context, x)) onLoggedIn();
                      },
                    ),
                ],
              ),

              // तारीख़ें सरकारी जानकारी हैं — स्रोत और "बदल सकती हैं" साफ़
              // दिखे (Misleading Claims नीति). छूने पर स्रोत वाला पन्ना.
              const SizedBox(height: 12),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SourcesPage()),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                  child: Text(
                    '📅 तिथियाँ आयोगों की सूचना पर आधारित हैं और बदल सकती हैं — '
                    'पक्की जानकारी आयोग की आधिकारिक साइट पर देखें। स्रोत ›',
                    style: TextStyle(fontSize: 11.5, color: P.muted, height: 1.45),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── पहले से आईडी है — जो लॉगिन कर चुका है उसे नहीं दिखाना ──
              if (onContinue == null) Container(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('पहले से आईडी है?',
                        style: TextStyle(fontSize: 13.5, color: P.muted)),
                    TextButton(
                      onPressed: () async {
                        final ok = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                        );
                        if (ok == true) onLoggedIn();
                      },
                      child: const Text('लॉगिन करें',
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: P.brand)),
                    ),
                  ],
                ),
              ),

              if (!Session.available) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: P.gold.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Row(
                    children: [
                      const FaIcon(FontAwesomeIcons.wifi,
                          size: 13, color: P.gold),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'अभी सर्वर से जुड़ नहीं पाए — लॉगिन के लिए इंटरनेट चाहिए।',
                          style: TextStyle(
                              fontSize: 12.5,
                              color: P.gold,
                              height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// "यह सरकारी ऐप नहीं है" — पहले पन्ने की पट्टी.
///
/// छूने पर `SourcesPage` खुलता है, जहाँ पूरा अस्वीकरण और हर आयोग की
/// आधिकारिक वेबसाइट है. दोनों एक ही नीति-रोक के जवाब में बने हैं —
/// वजह `sources_page.dart` की टिप्पणी में लिखी है.
/// पहले पन्ने का इंडिगो बैनर — केसरिया बटन से सीधा मुफ़्त UP PET.
class _Hero extends StatelessWidget {
  final VoidCallback onStart;
  const _Hero({required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [P.brand, P.brandDeep],
        ),
        boxShadow: [
          BoxShadow(
            color: P.brand.withOpacity(0.30),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: P.goldBright.withOpacity(0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('UP PET · पूरा मुफ़्त',
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFFCD34D))),
          ),
          const SizedBox(height: 10),
          const Text('रील की तरह स्क्रॉल कीजिए,\nहर प्रश्न से कुछ सीखिए',
              style: TextStyle(
                  fontSize: 20,
                  height: 1.3,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
          const SizedBox(height: 6),
          Text('व्याख्या, तरकीब और "पढ़िए" के पाठ — सब हिंदी में',
              style: TextStyle(
                  fontSize: 13, color: Colors.white.withOpacity(0.8))),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: onStart,
            icon: const FaIcon(FontAwesomeIcons.play, size: 13),
            label: const Text('अभ्यास शुरू करें'),
          ),
        ],
      ),
    );
  }
}

class _NotGovernmentStrip extends StatelessWidget {
  const _NotGovernmentStrip();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Tint.peach,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SourcesPage()),
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: Tint.peachInk.withOpacity(0.22)),
          ),
          child: Row(
            children: [
              const FaIcon(FontAwesomeIcons.circleInfo,
                  size: 13, color: Tint.peachInk),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  'यह सरकारी ऐप नहीं है। प्रश्न आयोगों के पिछले प्रश्नपत्रों पर '
                  'आधारित निजी अभ्यास सामग्री हैं।',
                  style: TextStyle(fontSize: 12, height: 1.4, color: P.ink),
                ),
              ),
              const SizedBox(width: 8),
              Text('स्रोत',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Tint.peachInk)),
              const SizedBox(width: 3),
              const FaIcon(FontAwesomeIcons.chevronRight,
                  size: 10, color: Tint.peachInk),
            ],
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Color accent;
  final FaIconData icon;
  final String title;
  final String subtitle;
  final List<String> bullets;
  final String cta;
  final bool filled;
  final VoidCallback onTap;

  const _Card({
    required this.accent,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.bullets,
    required this.cta,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        // उभरा हुआ काग़ज़ — ऊपर हल्का, नीचे ज़रा गरम
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [P.card, P.cardLow],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withOpacity(filled ? 0.34 : 0.16)),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(filled ? 0.18 : 0.10),
            blurRadius: filled ? 26 : 18,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: P.shadow.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(17, 17, 17, 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.11),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Center(
                          child: FaIcon(icon, size: 16, color: accent)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(title,
                              style: const TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w800,
                                  height: 1.2)),
                          const SizedBox(height: 1),
                          Text(subtitle,
                              style:
                                  TextStyle(fontSize: 12.5, color: P.muted)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                ...bullets.map((b) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: FaIcon(FontAwesomeIcons.check,
                                size: 11, color: accent),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(b,
                                style: const TextStyle(
                                    fontSize: 13.5, height: 1.4)),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 11),
                SizedBox(
                  width: double.infinity,
                  child: filled
                      ? FilledButton(
                          onPressed: onTap,
                          style: FilledButton.styleFrom(
                            backgroundColor: accent,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(cta,
                              style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800)),
                        )
                      : OutlinedButton(
                          onPressed: onTap,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: accent,
                            side: BorderSide(color: accent.withOpacity(0.45)),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(cta,
                              style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800)),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
