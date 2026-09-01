// लॉन्चर आइकन बनाने वाला औज़ार — यह असल में जाँच (test) नहीं है.
//
// Flutter से ही आइकन बनवाते हैं, क्योंकि इस मशीन पर SVG को PNG में बदलने
// वाला कोई टूल नहीं है. फ़ायदा यह भी है कि देवनागरी असली Mukta फ़ॉन्ट से
// बनती है, हाथ से खींची हुई आकृति से नहीं.
//
// चलाने के लिए:
//   flutter test test/make_icon_test.dart --tags icon
//
// PNG सीधे android/app/src/main/res/mipmap-*/ में लिख जाती हैं.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Android की mipmap नाप — नाम और चौड़ाई.
const _densities = <String, int>{
  'mdpi': 48,
  'hdpi': 72,
  'xhdpi': 96,
  'xxhdpi': 144,
  'xxxhdpi': 192,
};

/// Play Store / वेबसाइट के लिए बड़ा वाला.
const _storeSize = 512;

const _deep = Color(0xFF1B2A6B);
const _mid = Color(0xFF3A55B8);
const _flame = Color(0xFFE8A33D);

/// आइकन का चित्र — गहरा नीला वृत्त, ऊपर उठता अस्त्र, बीच में "ब्र".
class _IconArt extends StatelessWidget {
  final double size;

  /// पूरा वर्ग भरना है (पुराने Android के लिए) या सिर्फ़ बीच का हिस्सा
  /// (adaptive icon का foreground, जिसे Android ख़ुद काटता है).
  final bool fullBleed;

  const _IconArt({required this.size, this.fullBleed = true});

  @override
  Widget build(BuildContext context) {
    // adaptive foreground में किनारे कट जाते हैं, इसलिए बीच में सिकोड़ते हैं
    final inner = fullBleed ? size : size * 0.62;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (fullBleed)
            Container(
              width: size,
              height: size,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_mid, _deep],
                ),
              ),
            ),
          SizedBox(
            width: inner,
            height: inner,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // अस्त्र की चमक — पीछे का हल्का घेरा
                Container(
                  width: inner * 0.94,
                  height: inner * 0.94,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _flame.withOpacity(0.30),
                        _flame.withOpacity(0.0),
                      ],
                      stops: const [0.45, 1.0],
                    ),
                  ),
                ),
                // "ब्र" — ब्रह्मास्त्र का पहला अक्षर
                Padding(
                  padding: EdgeInsets.only(bottom: inner * 0.10),
                  child: Text(
                    'ब्र',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Mukta',
                      fontWeight: FontWeight.w800,
                      fontSize: inner * 0.56,
                      height: 1.0,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: _deep.withOpacity(0.55),
                          blurRadius: inner * 0.05,
                          offset: Offset(0, inner * 0.015),
                        ),
                      ],
                    ),
                  ),
                ),
                // नीचे ऊपर की ओर इशारा — स्वाइप अप और अस्त्र, दोनों
                Positioned(
                  bottom: inner * 0.055,
                  child: CustomPaint(
                    size: Size(inner * 0.30, inner * 0.13),
                    painter: _ChevronPainter(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChevronPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = _flame
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.height * 0.42
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(size.width * 0.06, size.height * 0.88)
      ..lineTo(size.width * 0.5, size.height * 0.16)
      ..lineTo(size.width * 0.94, size.height * 0.88);

    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Future<void> _loadFont() async {
  final loader = FontLoader('Mukta');
  for (final w in ['Regular', 'SemiBold', 'Bold', 'ExtraBold']) {
    final bytes = File('assets/fonts/Mukta-$w.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)));
  }
  await loader.load();
}

Future<void> _render(
  WidgetTester tester,
  String path,
  int px, {
  bool fullBleed = true,
}) async {
  final key = GlobalKey();

  await tester.pumpWidget(
    MediaQuery(
      // ऊँची density पर बड़ी PNG मिलती है — 1.0 रखकर हम ख़ुद नाप तय करते हैं
      data: const MediaQueryData(devicePixelRatio: 1.0),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: RepaintBoundary(
            key: key,
            child: _IconArt(size: px.toDouble(), fullBleed: fullBleed),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1.0);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  testWidgets('लॉन्चर आइकन बनाएँ', (tester) async {
    await _loadFont();

    const res = 'android/app/src/main/res';

    for (final e in _densities.entries) {
      await _render(
        tester,
        '$res/mipmap-${e.key}/ic_launcher.png',
        e.value,
      );
      // adaptive icon का foreground — Android इसे गोल/चौकोर जैसा चाहे काटेगा
      await _render(
        tester,
        '$res/mipmap-${e.key}/ic_launcher_foreground.png',
        (e.value * 2.2).round(),
        fullBleed: false,
      );
    }

    // बड़ा वाला — वेबसाइट, WhatsApp, कहीं भी
    await _render(tester, 'assets/icon/icon-512.png', _storeSize);

    // ignore: avoid_print
    print('\n✅ आइकन बन गए — mipmap-* में ic_launcher.png aur foreground\n');
  }, tags: 'icon');
}
