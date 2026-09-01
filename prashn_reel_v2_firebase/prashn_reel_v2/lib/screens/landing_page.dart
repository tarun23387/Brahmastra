import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../auth.dart';
import '../models.dart';
import '../widgets/study_art.dart';
import 'exam_picker_page.dart';
import 'login_page.dart';

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

  static const _green = Tint.mintInk;
  static const _gold = P.gold;

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
                  Container(
                    width: 4,
                    height: 34,
                    decoration: BoxDecoration(
                        color: P.brand, borderRadius: BorderRadius.circular(3)),
                  ),
                  const SizedBox(width: 11),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('ब्रह्मास्त्र',
                            style: TextStyle(
                                fontSize: 23,
                                fontWeight: FontWeight.w800,
                                height: 1.1)),
                        SizedBox(height: 2),
                        Text('यूपीपीसीएस · आरओ/एआरओ · पीईटी',
                            style: TextStyle(fontSize: 12.5, color: P.muted)),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // ── पढ़ाई का बैनर ──
              // const StudyHero(
              //   title: 'UPPET — पूरा मुफ़्त',
              //   subtitle: 'रील की तरह स्क्रॉल कीजिए — कोई फ़िल्टर, कोई झंझट नहीं।',
              //   tint: Tint.mint,
              //   tintInk: Tint.mintInk,
              //   motif: StudyMotif.book,
              // ),

              const SizedBox(height: 18),

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

              // ── कार्ड 1: पूरा पीईटी मुफ़्त ──
              _Card(
                accent: _green,
                icon: FontAwesomeIcons.listCheck,
                title: 'UPPET — पूरा एक्सेस मुफ़्त',
                subtitle: 'कोई आईडी नहीं, कोई पैसा नहीं',
                bullets: const [
                  'पूरा UP PET पेपर — सारे 15 खंड',
                  'हर विषय के प्रश्न और सभी मानचित्र',
                  'बिना इंटरनेट भी चलता है',
                ],
                cta: 'Click Here For PET Free Access',
                filled: true,
                onTap: onFreeSample,
              ),

              const SizedBox(height: 14),

              // ── कार्ड 2: पूरा एक्सेस — सदस्य को नहीं दिखाना ──
              if (onContinue == null) _Card(
                accent: _gold,
                icon: FontAwesomeIcons.crown,
                title: 'यूपीपीसीएस · आरओ/एआरओ',
                subtitle: 'बड़ी परीक्षा की तैयारी',
                bullets: const [
                  'दोनों पेपर के सारे प्रश्न व विषय',
                  'सभी मानचित्र',
                  'हर हफ़्ते नए करेंट अफेयर्स',
                ],
                cta: 'परीक्षा चुनें',
                filled: false,
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const ExamPickerPage(),
                  ));
                },
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
                    color: const Color(0xFFC2680C).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Row(
                    children: [
                      const FaIcon(FontAwesomeIcons.wifi,
                          size: 13, color: Color(0xFFC2680C)),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'अभी सर्वर से जुड़ नहीं पाए — लॉगिन के लिए इंटरनेट चाहिए।',
                          style: TextStyle(
                              fontSize: 12.5,
                              color: const Color(0xFFC2680C),
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
          colors: [Color(0xFFFFFEFB), Color(0xFFFBF6EC)],
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
            color: const Color(0xFF3B2A17).withOpacity(0.05),
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
