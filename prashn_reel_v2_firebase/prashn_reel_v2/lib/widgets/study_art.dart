import 'package:flutter/material.dart';

import '../models.dart';

/// ऐप भर की सजावट — बंडल किए हुए वेक्टर चित्र और उभरे हुए कार्ड.
///
/// सब कुछ यहीं कोड से बनता है (कोई इंटरनेट-इमेज नहीं), इसलिए बिना नेट भी
/// वैसा ही दिखता है, तेज़ खुलता है, और APK हल्का रहता है. रंग हल्के-गरम
/// रखे हैं — काग़ज़ जैसी क्रीम पर पढ़ाई का माहौल, आँखों पर ज़ोर नहीं.

/// हल्के सजावटी रंग — [P] के गहरे रंगों के साथ मेल खाते, पर मुलायम.
class Tint {
  static const sky = Color(0xFFEAF2FB); // हल्का आसमानी
  static const skyInk = Color(0xFF3E6DA6);
  static const mint = Color(0xFFE7F4EC); // हल्का हरा
  static const mintInk = Color(0xFF2E7D57);
  static const peach = Color(0xFFFDEDE1); // हल्का आड़ू
  static const peachInk = Color(0xFFC2680C);
  static const lilac = Color(0xFFEFEAF7); // हल्का बैंगनी
  static const lilacInk = Color(0xFF6A54A8);
  static const cream = Color(0xFFFBF5E9); // हल्की सुनहरी क्रीम
  static const goldInk = Color(0xFF9C7A16);
}

/// कौन-सा वेक्टर चित्र बनाना है.
enum StudyMotif { book, target, cap, bulb }

/// एक उभरा हुआ (embossed) कार्ड — मुलायम परछाई और ऊपर हल्की चमक.
///
/// पहले कार्ड सपाट थे; अब दो परछाइयाँ (एक गहरी नीचे, एक हल्की चमक ऊपर)
/// और भीतर ऊपर-से-नीचे हल्का ढाल डालने से काग़ज़ ऊपर उठा हुआ लगता है.
class RaisedCard extends StatelessWidget {
  final Widget child;
  final Color accent;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;

  /// ज़्यादा उभार — मुख्य/भरे हुए कार्ड के लिए.
  final bool elevated;

  const RaisedCard({
    super.key,
    required this.child,
    this.accent = P.brand,
    this.padding = const EdgeInsets.all(16),
    this.radius = 20,
    this.onTap,
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    final card = Container(
      decoration: BoxDecoration(
        borderRadius: r,
        // ऊपर हाथीदाँती, नीचे ज़रा-सी गरम छाया — काग़ज़ का उभार
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFEFB), Color(0xFFFBF6EC)],
        ),
        border: Border.all(color: accent.withOpacity(elevated ? 0.30 : 0.14)),
        boxShadow: [
          // गहरी, दूर तक फैली परछाई — उठान का अहसास
          BoxShadow(
            color: accent.withOpacity(elevated ? 0.16 : 0.09),
            blurRadius: elevated ? 26 : 18,
            offset: const Offset(0, 10),
          ),
          // पास की मुलायम परछाई — किनारे को ज़मीन से जोड़ती
          BoxShadow(
            color: const Color(0xFF3B2A17).withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      borderRadius: r,
      child: InkWell(onTap: onTap, borderRadius: r, child: card),
    );
  }
}

/// गोल डिब्बे में रखा वेक्टर चित्र — कार्ड/बैनर के कोने में सजाने को.
class MotifBadge extends StatelessWidget {
  final StudyMotif motif;
  final Color color;
  final double size;

  const MotifBadge({
    super.key,
    required this.motif,
    required this.color,
    this.size = 46,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Center(
        child: CustomPaint(
          size: Size(size * 0.58, size * 0.58),
          painter: _MotifPainter(motif, color),
        ),
      ),
    );
  }
}

/// पढ़ाई का बड़ा बैनर — हल्के ढाल पर वेक्टर दृश्य और उसके ऊपर लिखा हुआ.
///
/// पहले पन्ने और डैशबोर्ड के सिर पर लगता है ताकि खुलते ही "यह पढ़ाई की ऐप
/// है" वाला अहसास हो — बिना किसी भारी फ़ोटो के.
class StudyHero extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color tint;
  final Color tintInk;
  final StudyMotif motif;

  const StudyHero({
    super.key,
    required this.title,
    required this.subtitle,
    this.tint = Tint.cream,
    this.tintInk = Tint.goldInk,
    this.motif = StudyMotif.book,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 128,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tint, Color.lerp(tint, Colors.white, 0.6)!],
        ),
        border: Border.all(color: tintInk.withOpacity(0.16)),
        boxShadow: [
          BoxShadow(
            color: tintInk.withOpacity(0.12),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            // पीछे बड़ा, धुँधला-सा चित्र — सजावट भर
            Positioned(
              right: -14,
              bottom: -18,
              child: Opacity(
                opacity: 0.9,
                child: CustomPaint(
                  size: const Size(150, 150),
                  painter: _ScenePainter(motif, tintInk),
                ),
              ),
            ),
            // बाईं ओर लिखा हुआ
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 120, 0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                      color: P.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: P.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// छोटे बैज वाले चित्र — साफ़ रेखाओं में.
class _MotifPainter extends CustomPainter {
  final StudyMotif motif;
  final Color c;
  _MotifPainter(this.motif, this.c);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.09
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = c.withOpacity(0.18)
      ..style = PaintingStyle.fill;

    _draw(canvas, size, stroke, fill);
  }

  void _draw(Canvas canvas, Size s, Paint stroke, Paint fill) {
    final w = s.width, h = s.height;
    switch (motif) {
      case StudyMotif.book:
        final spine = Offset(w * 0.5, h * 0.22);
        final bottom = h * 0.82;
        final left = Path()
          ..moveTo(spine.dx, spine.dy)
          ..lineTo(w * 0.08, h * 0.34)
          ..lineTo(w * 0.08, bottom)
          ..lineTo(spine.dx, h * 0.7);
        final right = Path()
          ..moveTo(spine.dx, spine.dy)
          ..lineTo(w * 0.92, h * 0.34)
          ..lineTo(w * 0.92, bottom)
          ..lineTo(spine.dx, h * 0.7);
        canvas.drawPath(left, fill);
        canvas.drawPath(right, fill);
        canvas.drawPath(left, stroke);
        canvas.drawPath(right, stroke);
        canvas.drawLine(Offset(spine.dx, h * 0.7), Offset(spine.dx, bottom), stroke);
        break;
      case StudyMotif.target:
        final ctr = Offset(w * 0.5, h * 0.5);
        canvas.drawCircle(ctr, w * 0.42, stroke);
        canvas.drawCircle(ctr, w * 0.26, stroke);
        canvas.drawCircle(ctr, w * 0.09, fill);
        canvas.drawCircle(ctr, w * 0.09, stroke);
        break;
      case StudyMotif.cap:
        final top = h * 0.32;
        final cap = Path()
          ..moveTo(w * 0.5, h * 0.16)
          ..lineTo(w * 0.94, top)
          ..lineTo(w * 0.5, h * 0.48)
          ..lineTo(w * 0.06, top)
          ..close();
        canvas.drawPath(cap, fill);
        canvas.drawPath(cap, stroke);
        // नीचे का हिस्सा
        canvas.drawArc(
          Rect.fromLTRB(w * 0.22, h * 0.4, w * 0.78, h * 0.78),
          0.15, 2.84, false, stroke);
        // झालर
        canvas.drawLine(Offset(w * 0.9, top), Offset(w * 0.9, h * 0.66), stroke);
        canvas.drawCircle(Offset(w * 0.9, h * 0.7), w * 0.05, fill);
        break;
      case StudyMotif.bulb:
        final ctr = Offset(w * 0.5, h * 0.42);
        canvas.drawCircle(ctr, w * 0.3, fill);
        canvas.drawCircle(ctr, w * 0.3, stroke);
        canvas.drawLine(Offset(w * 0.38, h * 0.72), Offset(w * 0.62, h * 0.72), stroke);
        canvas.drawLine(Offset(w * 0.4, h * 0.84), Offset(w * 0.6, h * 0.84), stroke);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _MotifPainter old) =>
      old.motif != motif || old.c != c;
}

/// बैनर के पीछे का बड़ा दृश्य — पढ़ाई की मेज़ जैसा, हल्के रंगों में.
class _ScenePainter extends CustomPainter {
  final StudyMotif motif;
  final Color c;
  _ScenePainter(this.motif, this.c);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    // पीछे हल्के गोल — गहराई के लिए
    final soft = Paint()..color = c.withOpacity(0.10);
    canvas.drawCircle(Offset(w * 0.62, h * 0.42), w * 0.34, soft);
    canvas.drawCircle(Offset(w * 0.30, h * 0.66), w * 0.18,
        Paint()..color = c.withOpacity(0.08));

    final stroke = Paint()
      ..color = c.withOpacity(0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = c.withOpacity(0.16);

    // खुली किताब — बैनर के लिए हमेशा एक-सी, नीचे मोटिफ़ ऊपर तैरता है
    final cx = w * 0.5;
    final book = Path()
      ..moveTo(cx, h * 0.42)
      ..cubicTo(w * 0.30, h * 0.30, w * 0.14, h * 0.36, w * 0.10, h * 0.42)
      ..lineTo(w * 0.10, h * 0.74)
      ..cubicTo(w * 0.14, h * 0.68, w * 0.32, h * 0.62, cx, h * 0.72);
    final book2 = Path()
      ..moveTo(cx, h * 0.42)
      ..cubicTo(w * 0.70, h * 0.30, w * 0.86, h * 0.36, w * 0.90, h * 0.42)
      ..lineTo(w * 0.90, h * 0.74)
      ..cubicTo(w * 0.86, h * 0.68, w * 0.68, h * 0.62, cx, h * 0.72);
    canvas.drawPath(book, fill);
    canvas.drawPath(book2, fill);
    canvas.drawPath(book, stroke);
    canvas.drawPath(book2, stroke);
    canvas.drawLine(Offset(cx, h * 0.42), Offset(cx, h * 0.72), stroke);
    // पन्नों की रेखाएँ
    for (var i = 1; i <= 2; i++) {
      final y = h * (0.42 + i * 0.09);
      canvas.drawLine(Offset(w * 0.18, y), Offset(w * 0.42, y + h * 0.02),
          Paint()
            ..color = c.withOpacity(0.30)
            ..strokeWidth = 2);
    }

    // ऊपर तैरता छोटा मोटिफ़ — किताब से निकलता विचार
    canvas.save();
    canvas.translate(w * 0.6, h * 0.14);
    _MotifPainter(motif, c).paint(canvas, const Size(40, 40));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ScenePainter old) =>
      old.motif != motif || old.c != c;
}
