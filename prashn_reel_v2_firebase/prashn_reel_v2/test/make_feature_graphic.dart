// Play Store का feature graphic बनाने वाला औज़ार — यह असल में जाँच नहीं है.
//
// वही तरीक़ा जो make_icon.dart का है: Flutter से ही चित्र बनवाते हैं, क्योंकि
// इस मशीन पर SVG को PNG में बदलने वाला कोई टूल नहीं है. फ़ायदा यह भी कि
// देवनागरी असली Mukta फ़ॉन्ट से बनती है, हाथ से खींची आकृति से नहीं.
//
// चलाने के लिए:
//   flutter test test/make_feature_graphic.dart --tags graphic
//
// PNG dist/ में लिख जाती है — वहीं से Play Console पर चढ़ा दीजिए.
//
// ── नाप और नियम ──
//
// Play feature graphic ठीक 1024×500 माँगता है, JPEG या 24-bit PNG.
// यह ऐप के पन्ने पर सबसे ऊपर दिखता है और खोज के नतीजों में भी.
//
// ज़रूरी बात: Play इस चित्र के बीच से नीचे की ओर एक ▶ play बटन चिपका देता है
// जब listing में वीडियो हो, और छोटे परदों पर किनारे कट सकते हैं. इसलिए सारा
// ज़रूरी हिस्सा बीच के हिस्से में रखा है, किनारों पर सिर्फ़ सजावट.
//
// यह भी ध्यान: Play नीति कहती है कि feature graphic में क़ीमत, "मुफ़्त",
// रेटिंग, "डाउनलोड करें" जैसे विज्ञापनी शब्द या नक़ली UI नहीं होना चाहिए.
// इसीलिए यहाँ सिर्फ़ नाम, काम और परीक्षाओं के नाम हैं.

// ── एक ज्ञात अटकन ──
//
// PNG हर बार सही बनती है और सेकंडों में लिख जाती है, पर उसके बाद यह test
// अपने आप ख़त्म नहीं होता — दस मिनट बाद "did not complete" कहकर गिरता है.
// यानी आउटपुट सही, रिपोर्ट ग़लत.
//
// कोशिश करके देख लिया: ui.Image dispose करना, tester.view के बजाय
// setSurfaceSize इस्तेमाल करना, आख़िर में पेड़ हटाकर एक और frame चलाना —
// किसी से फ़र्क़ नहीं पड़ा (आख़िरी वाले ने तो फ़ाइल लिखने से पहले ही अटका दिया).
//
// चूँकि यह असल में जाँच है ही नहीं, बस चित्र बनाने का औज़ार है, इसलिए इसे
// यहीं छोड़ रखा है. **"Some tests failed" देखकर घबराइए मत — dist/ में फ़ाइल
// की तारीख़ देख लीजिए, वही असली नतीजा है.** चाहें तो Ctrl+C दबा दीजिए,
// फ़ाइल तब तक बन चुकी होती है.


import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _w = 1024;
const _h = 500;

// ऐप के अपने रंग — lib/models.dart के P से लिए हैं, ताकि store का पन्ना
// और ऐप एक ही परिवार के लगें.
const _bg = Color(0xFF231B14); // गहरा स्याही जैसा
const _bgLift = Color(0xFF32261C);
const _cream = Color(0xFFF7F3EC);
const _gold = Color(0xFFD8A93C);
const _brand = Color(0xFF8C3A1E);
const _muted = Color(0xFFBFAF9A);

class _FeatureArt extends StatelessWidget {
  const _FeatureArt();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _w.toDouble(),
      height: _h.toDouble(),
      child: Stack(
        children: [
          // ── पृष्ठभूमि ──
          Container(
            width: _w.toDouble(),
            height: _h.toDouble(),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_bgLift, _bg],
              ),
            ),
          ),

          // कोने में हल्की सुनहरी आभा — सपाटपन तोड़ने के लिए
          Positioned(
            left: -120,
            top: -140,
            child: Container(
              width: 460,
              height: 460,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [_gold.withValues(alpha: 0.16), _gold.withValues(alpha: 0)],
                ),
              ),
            ),
          ),

          // ── दाईं ओर प्रश्न कार्डों की झलक ──
          //
          // असली स्क्रीनशॉट नहीं, सिर्फ़ आकृति — Play नक़ली UI पसंद नहीं करता,
          // पर यह इतना धुँधला और सजावटी है कि UI का दावा नहीं करता. मक़सद
          // इतना ही बताना है कि ऐप एक-एक करके प्रश्न दिखाता है.
          const Positioned(right: 92, top: 96, child: _CardGhost(depth: 2)),
          const Positioned(right: 64, top: 74, child: _CardGhost(depth: 1)),
          const Positioned(right: 36, top: 52, child: _CardGhost(depth: 0)),

          // ── बाईं ओर लिखाई ──
          Positioned(
            left: 62,
            top: 0,
            bottom: 0,
            width: 560,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // नाम
                const Text(
                  'ब्रह्मास्त्र',
                  style: TextStyle(
                    fontFamily: 'Mukta',
                    fontSize: 78,
                    height: 1.12,
                    fontWeight: FontWeight.w800,
                    color: _cream,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),

                // सुनहरी लकीर
                Container(width: 96, height: 5, color: _gold),
                const SizedBox(height: 20),

                // क्या करता है
                const Text(
                  'रील की तरह प्रश्न — एक-एक करके,\nहर उत्तर के साथ व्याख्या',
                  style: TextStyle(
                    fontFamily: 'Mukta',
                    fontSize: 27,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                    color: _muted,
                  ),
                ),
                const SizedBox(height: 30),

                // किन परीक्षाओं के लिए
                Row(
                  children: const [
                    _Chip('यूपी पीईटी'),
                    SizedBox(width: 10),
                    _Chip('आरओ / एआरओ'),
                    SizedBox(width: 10),
                    _Chip('यूपीपीसीएस'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// परीक्षा का नाम — गोल किनारों वाला छोटा टैग.
class _Chip extends StatelessWidget {
  final String text;
  const _Chip(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: _gold.withValues(alpha: 0.13),
        border: Border.all(color: _gold.withValues(alpha: 0.45), width: 1.4),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Mukta',
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: _gold,
        ),
      ),
    );
  }
}

/// प्रश्न कार्ड की झलक — पीछे जितना दूर, उतना धुँधला और छोटा.
class _CardGhost extends StatelessWidget {
  /// 0 = सबसे आगे वाला.
  final int depth;
  const _CardGhost({required this.depth});

  @override
  Widget build(BuildContext context) {
    final fade = 1.0 - depth * 0.3;
    final shrink = 1.0 - depth * 0.05;

    return Transform.scale(
      scale: shrink,
      alignment: Alignment.topRight,
      child: Container(
        width: 300,
        height: 352,
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
        decoration: BoxDecoration(
          color: _cream.withValues(alpha: 0.95 * fade),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3 * fade),
              blurRadius: 26,
              offset: const Offset(-6, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // विषय का टैग
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _brand.withValues(alpha: 0.12 * fade),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                'इतिहास',
                style: TextStyle(
                  fontFamily: 'Mukta',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _brand.withValues(alpha: fade),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // प्रश्न की जगह — लकीरें, असली पाठ नहीं
            _Line(w: 250, fade: fade),
            const SizedBox(height: 9),
            _Line(w: 214, fade: fade),
            const SizedBox(height: 22),

            // विकल्प
            for (var i = 0; i < 4; i++) ...[
              Container(
                height: 38,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: (i == 1 ? const Color(0xFF1B7A50) : _bg)
                      .withValues(alpha: (i == 1 ? 0.14 : 0.05) * fade),
                  border: Border.all(
                    color: (i == 1 ? const Color(0xFF1B7A50) : _bg)
                        .withValues(alpha: (i == 1 ? 0.5 : 0.12) * fade),
                    width: 1.2,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              if (i < 3) const SizedBox(height: 9),
            ],
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final double w;
  final double fade;
  const _Line({required this.w, required this.fade});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: w,
      height: 11,
      decoration: BoxDecoration(
        color: _bg.withValues(alpha: 0.32 * fade),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

Future<void> _loadFont() async {
  final loader = FontLoader('Mukta');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    final bytes = File('assets/fonts/Mukta-$w.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)));
  }
  await loader.load();
}

void main() {
  testWidgets('feature graphic बनाएँ', (tester) async {
    await _loadFont();

    // परदा चित्र से बड़ा रखते हैं, वरना Flutter उसे काट देता है
    await tester.binding.setSurfaceSize(const Size(1200, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final key = GlobalKey();

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(devicePixelRatio: 1.0),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: RepaintBoundary(key: key, child: const _FeatureArt()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    // नाप पहले पकड़ लेते हैं, फिर चित्र छोड़ देते हैं — सफ़ाई की आदत है,
    // पर नीचे वाली अटकन इससे नहीं सुधरती (ऊपर की टिप्पणी देखिए).
    final w = image.width;
    final h = image.height;
    image.dispose();

    final file = File('dist/feature-graphic-1024x500.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());

    // ignore: avoid_print
    print('\n✅ dist/feature-graphic-1024x500.png बन गई ($w×$h)\n');
  }, tags: 'graphic');
}
