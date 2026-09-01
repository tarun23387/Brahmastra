import 'package:flutter/material.dart';

import '../models.dart';
import 'geo_render.dart';
import 'map_data.dart';

/// लेयर सेटिंग पूरे ऐप में एक जैसी रहे, इसलिए यहाँ रखी है.
class MapLayers {
  static final ValueNotifier<bool> states = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> districts = ValueNotifier<bool>(false);
}

// किताब के एटलस जैसा — क्रीम ज़मीन, हल्का नीला पानी, भूरी स्याही की सीमाएँ.
// पहले पूरा पैलेट ठंडा नीला-धूसर था, जो क्रीम पृष्ठभूमि पर बेमेल लगता था.
const _sea = Color(0xFFDCE7E5);
const _land = Color(0xFFFFFCF6);
const _coast = Color(0xFF5A4632);
const _stateLine = Color(0xFFA89479);
const _distLine = Color(0xFFDCD2C0);

/// राज्यों के लिए हल्के, आँख को सुकून देने वाले रंग
const List<Color> _tints = [
  Color(0xFFECEFE2), Color(0xFFF1EAEE), Color(0xFFFAEEE0),
  Color(0xFFE8EDEE), Color(0xFFF7EDE4), Color(0xFFE9F0EA),
  Color(0xFFF4EFDE),
];

class MapPainter extends CustomPainter {
  final MapItem? item;
  final bool showStates;
  final bool showDistricts;
  final double scale;

  MapPainter({
    required this.item,
    required this.showStates,
    required this.showDistricts,
    required this.scale,
  });

  double get _k => 1 / scale; // स्क्रीन पर आकार एक जैसा रखने के लिए

  void _label(Canvas c, Offset at, String txt, Color col,
      {double size = 9.5,
      bool bold = false,
      bool alignRight = false,
      bool plate = true}) {
    final tp = TextPainter(
      text: TextSpan(
        text: txt,
        style: TextStyle(
          fontSize: size * _k,
          height: 1.2,
          color: col,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 2,
    )..layout(maxWidth: 110 * _k);
    final dx = alignRight ? at.dx - tp.width : at.dx;
    if (plate) {
      final r = Rect.fromLTWH(
          dx - 2.5 * _k, at.dy - 1.5 * _k, tp.width + 5 * _k, tp.height + 3 * _k);
      c.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(3 * _k)),
        Paint()..color = P.card.withOpacity(0.86),
      );
    }
    tp.paint(c, Offset(dx, at.dy));
  }

  @override
  void paint(Canvas canvas, Size size) {
    GeoCache.build(size, withDistricts: showDistricts);
    final proj = Proj(size);
    final accent = item?.color ?? const Color(0xFF0B6357);

    canvas.drawRect(Offset.zero & size, Paint()..color = _sea);

    // ज़मीन के नीचे हल्की परछाईं — नक्शा उभरा हुआ लगता है
    final shadow = Paint()
      ..color = const Color(0xFF5A4632).withOpacity(0.16)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    for (final p in GeoCache.india) {
      canvas.drawPath(p.shift(Offset(0, 2.5)), shadow);
    }
    for (final p in GeoCache.india) {
      canvas.drawPath(p, Paint()..color = _land);
    }

    // राज्य
    if (showStates) {
      for (int i = 0; i < GeoCache.states.length; i++) {
        canvas.drawPath(
            GeoCache.states[i].path, Paint()..color = _tints[i % _tints.length]);
      }
    }

    // जिले — सबसे पतली रेखा
    if (showDistricts) {
      final pen = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.45 * _k
        ..color = _distLine;
      for (final p in GeoCache.districts) {
        canvas.drawPath(p, pen);
      }
    }

    if (showStates) {
      final pen = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8 * _k
        ..strokeJoin = StrokeJoin.round
        ..color = _stateLine;
      for (final s in GeoCache.states) {
        canvas.drawPath(s.path, pen);
      }
    }

    // राष्ट्रीय सीमा
    final coast = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * _k
      ..strokeJoin = StrokeJoin.round
      ..color = _coast;
    for (final p in GeoCache.india) {
      canvas.drawPath(p, coast);
    }

    // कर्क रेखा
    if (item?.tropic == true) {
      final y = proj.xy(23.5, 0).dy;
      final dash = Paint()
        ..color = const Color(0xFFA1540A)
        ..strokeWidth = 1.1 * _k;
      final step = 9 * _k;
      for (double x = 0; x < size.width; x += step) {
        canvas.drawLine(Offset(x, y), Offset(x + step * 0.55, y), dash);
      }
      _label(canvas, Offset(4 * _k, y - 13 * _k), "कर्क रेखा 23°30'N",
          const Color(0xFF7D3F06),
          bold: true);
    }

    // अक्षांश-देशांतर का घेरा
    if (item?.extent == true) {
      final r = Rect.fromPoints(proj.xy(37.1, 68.1), proj.xy(8.0, 97.5));
      final pen = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1 * _k
        ..color = accent.withOpacity(0.6);
      final step = 8 * _k;
      for (double x = r.left; x < r.right; x += step) {
        canvas.drawLine(Offset(x, r.top), Offset(x + step / 2, r.top), pen);
        canvas.drawLine(Offset(x, r.bottom), Offset(x + step / 2, r.bottom), pen);
      }
      for (double y = r.top; y < r.bottom; y += step) {
        canvas.drawLine(Offset(r.left, y), Offset(r.left, y + step / 2), pen);
        canvas.drawLine(Offset(r.right, y), Offset(r.right, y + step / 2), pen);
      }
    }

    // राज्यों के नाम — जितना ज़ूम करेंगे उतने ज़्यादा दिखेंगे
    if (showStates) {
      for (final s in GeoCache.states) {
        if (s.bounds.width * scale < 46) continue;
        final at = proj.xy(s.lat, s.lon);
        final tp = TextPainter(
          text: TextSpan(
            text: s.name,
            style: TextStyle(
              fontSize: 8.5 * _k,
              color: const Color(0xFF7A6A58),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2 * _k,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(at.dx - tp.width / 2, at.dy - tp.height / 2));
      }
    }

    final it = item;
    if (it == null) return;

    // विषय की रेखाएँ — नदियाँ, पर्वत, एक्सप्रेसवे
    for (final line in it.lines) {
      final pts = [for (final p in line.pts) proj.xy(p[0], p[1])];
      final path = smoothRing(pts, close: false);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6 * _k
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = P.card.withOpacity(0.75),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.7 * _k
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = line.color,
      );
      final end = pts.last;
      final right = end.dx > size.width * 0.72;
      _label(canvas, Offset(end.dx + (right ? -5 : 5) * _k, end.dy - 5 * _k),
          line.label, line.color,
          bold: true, alignRight: right);
    }

    // निशान
    for (final m in it.markers) {
      final at = proj.xy(m.lat, m.lon);
      canvas.drawCircle(at, 4.6 * _k, Paint()..color = P.card);
      canvas.drawCircle(at, 3.4 * _k, Paint()..color = accent);
      final right = at.dx > size.width * 0.66;
      _label(canvas, Offset(at.dx + (right ? -7 : 7) * _k, at.dy - 5.5 * _k),
          m.label, P.ink,
          alignRight: right);
    }
  }

  @override
  bool shouldRepaint(covariant MapPainter old) =>
      old.item != item ||
      old.showStates != showStates ||
      old.showDistricts != showDistricts ||
      old.scale != scale;
}

/// ज़ूम-पैन वाला मानचित्र बॉक्स + लेयर बटन.
class MapCanvas extends StatefulWidget {
  final MapItem? item;
  final bool fullScreen;
  const MapCanvas({super.key, this.item, this.fullScreen = false});

  @override
  State<MapCanvas> createState() => _MapCanvasState();
}

class _MapCanvasState extends State<MapCanvas> {
  final TransformationController tc = TransformationController();
  double scale = 1;

  @override
  void initState() {
    super.initState();
    tc.addListener(() {
      final s = tc.value.getMaxScaleOnAxis();
      if ((s - scale).abs() > 0.02) setState(() => scale = s);
    });
  }

  @override
  void dispose() {
    tc.dispose();
    super.dispose();
  }

  void _zoom(double factor) {
    final m = tc.value.clone();
    final target = (scale * factor).clamp(1.0, 9.0);
    final f = target / scale;
    final c = context.size ?? const Size(300, 320);
    m.translate(c.width / 2, c.height / 2);
    m.scale(f);
    m.translate(-c.width / 2, -c.height / 2);
    tc.value = m;
  }

  void _reset() => tc.value = Matrix4.identity();

  bool _focused = false;

  /// नक्शा खुलते ही तय जगह पर ज़ूम कर देता है (जैसे उत्तर प्रदेश).
  void _applyFocus(Size size) {
    final it = widget.item;
    if (_focused || it?.focusLat == null || it?.focusLon == null) return;
    _focused = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final z = (it!.focusZoom ?? 3.0).clamp(1.0, 9.0);
      final p = Proj(size).xy(it.focusLat!, it.focusLon!);
      tc.value = Matrix4.identity()
        ..translate(size.width / 2 - z * p.dx, size.height / 2 - z * p.dy)
        ..scale(z);
      setState(() => scale = z);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        _applyFocus(Size(box.maxWidth, box.maxHeight));
        return _stack();
      },
    );
  }

  Widget _stack() {
    return ValueListenableBuilder<bool>(
      valueListenable: MapLayers.states,
      builder: (context, st, _) => ValueListenableBuilder<bool>(
        valueListenable: MapLayers.districts,
        builder: (context, dt, __) => Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(widget.fullScreen ? 0 : 14),
                child: InteractiveViewer(
                  transformationController: tc,
                  minScale: 1,
                  maxScale: 9,
                  boundaryMargin: EdgeInsets.zero,
                  clipBehavior: Clip.hardEdge,
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: MapPainter(
                      item: widget.item,
                      showStates: st,
                      showDistricts: dt,
                      scale: scale,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(top: 8, right: 8, child: _layerButtons(st, dt)),
            Positioned(bottom: 8, right: 8, child: _zoomButtons()),
            if (scale > 1.05)
              Positioned(
                bottom: 10,
                left: 10,
                child: _chip('${scale.toStringAsFixed(1)}×', null, false),
              ),
          ],
        ),
      ),
    );
  }

  Widget _layerButtons(bool st, bool dt) => Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _chip('राज्य सीमा', () => MapLayers.states.value = !st, st),
          const SizedBox(height: 6),
          _chip('जिला सीमा', () => MapLayers.districts.value = !dt, dt),
        ],
      );

  Widget _chip(String text, VoidCallback? onTap, bool on) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: on ? const Color(0xFF5A4632) : const Color(0xFFFFFCF6).withOpacity(0.94),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: on ? const Color(0xFF5A4632) : const Color(0xFFE3D9C8)),
            boxShadow: const [
              BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2))
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onTap != null)
                Icon(on ? Icons.check_rounded : Icons.add_rounded,
                    size: 13, color: on ? P.card : P.muted),
              if (onTap != null) const SizedBox(width: 4),
              Text(text,
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: on ? P.card : P.muted)),
            ],
          ),
        ),
      );

  Widget _zoomButtons() => Container(
        decoration: BoxDecoration(
          color: P.card.withOpacity(0.94),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE3D9C8)),
          boxShadow: const [
            BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2))
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _iconBtn(Icons.add, () => _zoom(1.6)),
            Container(width: 26, height: 1, color: const Color(0xFFE3D9C8)),
            _iconBtn(Icons.remove, () => _zoom(1 / 1.6)),
            Container(width: 26, height: 1, color: const Color(0xFFE3D9C8)),
            _iconBtn(Icons.center_focus_weak, _reset),
          ],
        ),
      );

  Widget _iconBtn(IconData i, VoidCallback tap) => InkWell(
        onTap: tap,
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(i, size: 17, color: const Color(0xFF7A6A58)),
        ),
      );
}

/// पूरी स्क्रीन पर मानचित्र
class MapFullScreen extends StatelessWidget {
  final MapItem item;
  const MapFullScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _sea,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 12, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: P.ink),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(item.title,
                            style: const TextStyle(
                                fontSize: 15.5, fontWeight: FontWeight.w800)),
                        Text(item.subtitle,
                            style: TextStyle(fontSize: 11.5, color: P.muted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: MapCanvas(item: item, fullScreen: true)),
          ],
        ),
      ),
    );
  }
}
