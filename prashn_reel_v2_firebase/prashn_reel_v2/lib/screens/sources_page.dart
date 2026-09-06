import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../exams.dart';
import '../models.dart';
import '../widgets/study_art.dart';

/// स्रोत और अस्वीकरण.
///
/// ── यह पन्ना क्यों है ──
///
/// 2 सितंबर 2026 को Google Play ने ऐप को **Misleading Claims** नीति के
/// तहत रोका था. वजह दो थीं:
///
/// 1. ऐप सरकारी परीक्षाओं की जानकारी देता है पर कहीं यह नहीं बताता कि वह
///    जानकारी किस सरकारी स्रोत से आई है;
/// 2. कहीं यह साफ़ नहीं लिखा कि ब्रह्मास्त्र सरकारी ऐप नहीं है.
///
/// इसीलिए यहाँ दोनों बातें एक ही जगह, साफ़ शब्दों में हैं — और आयोग की
/// वेबसाइट का लिंक छूने लायक है, सिर्फ़ लिखा हुआ पता नहीं. इस पन्ने को
/// हटाइए मत; ऐप फिर उसी नीति में फँसेगा.
///
/// साथ वाली दो जगहें भी इसी वजह से हैं — पहले पन्ने की पट्टी
/// (`landing_page.dart`) और प्रश्नों वाले मेन्यू की कतार (`home_page.dart`).
class SourcesPage extends StatelessWidget {
  const SourcesPage({super.key});

  /// जिन परीक्षाओं के प्रश्न ऐप में हैं, उनके आयोग — एक आयोग एक ही बार.
  static List<Exam> get _authorities {
    final seen = <String>{};
    return kExams.values.where((e) => seen.add(e.sourceUrl)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: P.bg,
      appBar: AppBar(
        backgroundColor: P.card,
        foregroundColor: P.ink,
        elevation: 0,
        title: const Text('स्रोत और अस्वीकरण',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        leading: IconButton(
          icon: const FaIcon(FontAwesomeIcons.arrowLeft, size: 17),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
          children: [
            // ── अस्वीकरण — सबसे ऊपर, सबसे बड़ा ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Tint.peach,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Tint.peachInk.withOpacity(0.28)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      FaIcon(FontAwesomeIcons.circleInfo,
                          size: 15, color: Tint.peachInk),
                      SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'यह सरकारी ऐप नहीं है',
                          style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: Tint.peachInk),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'ब्रह्मास्त्र एक निजी ऐप है, जिसे परीक्षा की तैयारी करने वालों के '
                    'अभ्यास के लिए बनाया गया है। यह किसी सरकारी संस्था का ऐप नहीं है। '
                    'यह उत्तर प्रदेश सरकार, भारत सरकार, उत्तर प्रदेश लोक सेवा आयोग '
                    '(UPPSC), उत्तर प्रदेश अधीनस्थ सेवा चयन आयोग (UPSSSC) या किसी भी '
                    'अन्य सरकारी विभाग, आयोग या एजेंसी का प्रतिनिधित्व नहीं करता, न '
                    'उनसे जुड़ा है, न उनके द्वारा समर्थित या अधिकृत है।',
                    style: TextStyle(fontSize: 13.5, height: 1.6, color: P.ink),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'ऐप किसी सरकारी सेवा — जैसे आवेदन, शुल्क, प्रवेश-पत्र या '
                    'परिणाम — के लिए रास्ता नहीं देता और न ही इनसे जुड़ी कोई '
                    'सुविधा उपलब्ध कराता है।',
                    style: TextStyle(fontSize: 13.5, height: 1.6, color: P.ink),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            _heading('जानकारी कहाँ से आई है'),
            const SizedBox(height: 8),
            const Text(
              'ऐप के प्रश्न इन आयोगों के पिछले वर्षों के प्रश्नपत्रों और उनके '
              'प्रकाशित पाठ्यक्रम पर आधारित हैं। परीक्षा से जुड़ी हर आधिकारिक '
              'बात — विज्ञप्ति, पाठ्यक्रम, तिथियाँ, प्रश्नपत्र, उत्तर-कुंजी और '
              'परिणाम — इन्हीं वेबसाइटों पर मिलती है। कोई अंतर दिखे तो सही वही '
              'है जो आयोग की वेबसाइट पर है।',
              style: TextStyle(fontSize: 13.5, height: 1.65, color: P.muted),
            ),
            const SizedBox(height: 10),
            // तकनीकी भर्तियों के प्रश्न पिछले वर्षों के नहीं, हमारे अपने बनाए
            // अभ्यास-प्रश्न हैं. यह अंतर छिपाना ठीक वही Misleading Claims
            // वाली भूल होगी जिसकी वजह से 2 सितंबर 2026 को ऐप रोकी गई थी.
            const Text(
              'वरिष्ठ प्रोग्रामर, प्रबंधक (सिस्टम) और प्रोग्रामर ग्रेड-2 — इन '
              'तीन भर्तियों के प्रश्न पिछले वर्षों के प्रश्नपत्र नहीं हैं। ये '
              'विज्ञापन सं. A-2/E-1/2026 के परिशिष्ट-2 (परीक्षा योजना) और '
              'परिशिष्ट-3 (पाठ्यक्रम) को देखकर अभ्यास के लिए स्वयं तैयार किए गए '
              'प्रश्न हैं। ये आयोग के वास्तविक प्रश्न नहीं हैं और न ही आयोग '
              'द्वारा जारी किए गए हैं।',
              style: TextStyle(fontSize: 13.5, height: 1.65, color: P.muted),
            ),
            const SizedBox(height: 14),

            ..._authorities.map((e) => _SourceCard(
                  authority: e.authorityFullName,
                  exams: kExams.values
                      .where((x) => x.sourceUrl == e.sourceUrl)
                      .map((x) => x.shortLabel)
                      .join(' · '),
                  url: e.sourceUrl,
                )),

            const SizedBox(height: 10),
            const _SourceCard(
              authority: 'भारत सरकार का राष्ट्रीय पोर्टल',
              exams: 'सामान्य अध्ययन — विभागों और योजनाओं की आधिकारिक जानकारी',
              url: 'https://www.india.gov.in',
            ),
            const _SourceCard(
              authority: 'उत्तर प्रदेश सरकार का आधिकारिक पोर्टल',
              exams: 'उत्तर प्रदेश विशेष — ज़िले, विभाग और राज्य की जानकारी',
              url: 'https://up.gov.in',
            ),
            const _SourceCard(
              authority: 'भारतीय सर्वेक्षण विभाग (Survey of India)',
              exams: 'मानचित्र — भारत और उत्तर प्रदेश की सीमाएँ',
              url: 'https://surveyofindia.gov.in',
            ),

            const SizedBox(height: 24),
            _heading('मानचित्रों के बारे में'),
            const SizedBox(height: 8),
            const Text(
              'ऐप के मानचित्र सिर्फ़ पढ़ाई और पहचान के अभ्यास के लिए बनाए गए '
              'रेखाचित्र हैं। ये न आधिकारिक हैं, न नाप के हिसाब से सही। किसी भी '
              'सरकारी या क़ानूनी काम के लिए भारतीय सर्वेक्षण विभाग का प्रकाशित '
              'मानचित्र ही मान्य है।',
              style: TextStyle(fontSize: 13.5, height: 1.65, color: P.muted),
            ),

            const SizedBox(height: 24),
            _heading('ग़लती दिखे तो'),
            const SizedBox(height: 8),
            const Text(
              'किसी प्रश्न, उत्तर या जानकारी में ग़लती लगे तो लिखिए — '
              'ts23387@gmail.com। जाँचकर सुधार दिया जाएगा।',
              style: TextStyle(fontSize: 13.5, height: 1.65, color: P.muted),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  static Widget _heading(String text) => Text(
        text,
        style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w800, color: P.ink),
      );
}

/// एक सरकारी स्रोत — नाम, किस काम का, और खुलने वाला पता.
class _SourceCard extends StatelessWidget {
  final String authority;
  final String exams;
  final String url;

  const _SourceCard({
    required this.authority,
    required this.exams,
    required this.url,
  });

  /// लिंक ब्राउज़र में खोलता है.
  ///
  /// न खुल पाए — फ़ोन में ब्राउज़र ही न हो, या Android का package-visibility
  /// पहरा रास्ता रोक दे — तो पता क्लिपबोर्ड पर रख देते हैं. समीक्षक के हाथ
  /// में पता तब भी रहे, यही ज़्यादा ज़रूरी है.
  Future<void> _open(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    var opened = false;
    try {
      opened = await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (opened) return;

    await Clipboard.setData(ClipboardData(text: url));
    messenger.showSnackBar(SnackBar(
      content: Text('पता कॉपी हो गया — $url'),
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: P.card,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => _open(context),
          onLongPress: () async {
            await Clipboard.setData(ClipboardData(text: url));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('पता कॉपी हो गया'),
                behavior: SnackBarBehavior.floating,
              ));
            }
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: P.line),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(authority,
                          style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              height: 1.35)),
                      const SizedBox(height: 3),
                      Text(exams,
                          style: const TextStyle(
                              fontSize: 12.5, color: P.muted, height: 1.4)),
                      const SizedBox(height: 7),
                      // पूरा पता दिखता रहे — छूने लायक भी, पढ़ने लायक भी.
                      Text(url,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: P.brand,
                            decoration: TextDecoration.underline,
                            decorationColor: P.brand,
                          )),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: FaIcon(FontAwesomeIcons.arrowUpRightFromSquare,
                      size: 13, color: P.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
