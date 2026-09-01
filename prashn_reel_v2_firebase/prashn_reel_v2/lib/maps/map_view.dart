import 'package:flutter/material.dart';

import '../models.dart';
import 'geo_render.dart';
import 'map_canvas.dart';
import 'map_data.dart';

/// एक मानचित्र कार्ड — ऊपर रेखाचित्र, नीचे याद रखने लायक तथ्य.
class MapCard extends StatelessWidget {
  final MapItem item;
  final int number;
  final int total;
  final VoidCallback? onNext;
  final VoidCallback? onPrev;

  const MapCard({
    super.key,
    required this.item,
    required this.number,
    required this.total,
    this.onNext,
    this.onPrev,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey('map-$number'),
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 340),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, (1 - t) * 22), child: child),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 4, 14, 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [item.color.withOpacity(0.12), P.card],
            stops: const [0.0, 0.40],
          ),
          border: Border.all(color: item.color.withOpacity(0.16)),
          boxShadow: [
            BoxShadow(
              color: item.color.withOpacity(0.11),
              blurRadius: 26,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: _MapScrollChain(
          onNext: onNext,
          onPrev: onPrev,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: item.color.withOpacity(0.13),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(item.category,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: item.color)),
                    ),
                    const Spacer(),
                    Text('${number.toString().padLeft(2, '0')} / $total',
                        style: TextStyle(
                            fontSize: 12,
                            letterSpacing: 1.1,
                            color: P.muted.withOpacity(0.9))),
                  ],
                ),
                const SizedBox(height: 12),
                Text(item.title,
                    style: const TextStyle(
                        fontSize: 19, fontWeight: FontWeight.w800, height: 1.3)),
                const SizedBox(height: 3),
                Text(item.subtitle,
                    style: TextStyle(fontSize: 13, color: P.muted)),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: P.line),
                    ),
                    child: AspectRatio(
                      aspectRatio: Proj.aspect,
                      child: MapCanvas(item: item),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.pinch_outlined,
                        size: 14, color: P.muted.withOpacity(0.85)),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text('दो उंगलियों से ज़ूम करें · खींचकर घुमाएँ',
                          style: TextStyle(
                              fontSize: 11.5, color: P.muted.withOpacity(0.9))),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => MapFullScreen(item: item),
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: item.color.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.fullscreen,
                                size: 15, color: item.color),
                            const SizedBox(width: 4),
                            Text('पूरी स्क्रीन',
                                style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: item.color)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                for (final f in item.facts) _fact(f),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 13, color: P.muted.withOpacity(0.75)),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        'सीमाएँ 2011 जनगणना के आधिकारिक डेटा से; सरलीकृत रूप में '
                        'दिखाई गई हैं. आधिकारिक संदर्भ हेतु सर्वे ऑफ़ इंडिया देखें.',
                        style: TextStyle(
                            fontSize: 11, color: P.muted.withOpacity(0.85)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fact(String f) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 7),
              width: 5,
              height: 5,
              decoration:
                  BoxDecoration(color: item.color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(f,
                  style: const TextStyle(
                      fontSize: 14, height: 1.55, color: Color(0xFF3B3229))),
            ),
          ],
        ),
      );
}

class _MapScrollChain extends StatefulWidget {
  final Widget child;
  final VoidCallback? onNext;
  final VoidCallback? onPrev;
  const _MapScrollChain({required this.child, this.onNext, this.onPrev});

  @override
  State<_MapScrollChain> createState() => _MapScrollChainState();
}

class _MapScrollChainState extends State<_MapScrollChain> {
  double _acc = 0;
  bool _fired = false;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollStartNotification || n is ScrollEndNotification) {
          _acc = 0;
          _fired = false;
        } else if (n is OverscrollNotification && !_fired) {
          _acc += n.overscroll;
          if (_acc > 42 && widget.onNext != null) {
            _fired = true;
            widget.onNext!();
          } else if (_acc < -42 && widget.onPrev != null) {
            _fired = true;
            widget.onPrev!();
          }
        }
        return false;
      },
      child: widget.child,
    );
  }
}

/// मानचित्रों की रील — प्रश्नों की तरह ही ऊपर-नीचे स्क्रॉल.
class MapReel extends StatefulWidget {
  final ValueChanged<int>? onPageChanged;
  const MapReel({super.key, this.onPageChanged});

  @override
  State<MapReel> createState() => MapReelState();
}

class MapReelState extends State<MapReel> {
  final PageController pc = PageController();
  int current = 0;

  @override
  void dispose() {
    pc.dispose();
    super.dispose();
  }

  void _jump(int delta) {
    if (!pc.hasClients) return;
    final t = current + delta;
    if (t < 0 || t >= kMaps.length) return;
    pc.animateToPage(t,
        duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: pc,
      scrollDirection: Axis.vertical,
      itemCount: kMaps.length,
      onPageChanged: (p) {
        setState(() => current = p);
        widget.onPageChanged?.call(p);
      },
      itemBuilder: (context, i) => MapCard(
        item: kMaps[i],
        number: i + 1,
        total: kMaps.length,
        onNext: i == kMaps.length - 1 ? null : () => _jump(1),
        onPrev: i == 0 ? null : () => _jump(-1),
      ),
    );
  }
}
