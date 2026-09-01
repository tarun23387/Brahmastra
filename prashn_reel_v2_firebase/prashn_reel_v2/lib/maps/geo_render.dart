import 'dart:math' as math;
import 'dart:ui';

import 'india_geo.dart';

/// encoded polyline को (देशांतर, अक्षांश) बिंदुओं में खोलता है.
List<Offset> decodeRing(String s) {
  final pts = <Offset>[];
  int i = 0, lat = 0, lon = 0;
  while (i < s.length) {
    int shift = 0, result = 0, b;
    do {
      b = s.codeUnitAt(i++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

    shift = 0;
    result = 0;
    do {
      b = s.codeUnitAt(i++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    lon += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

    pts.add(Offset(lon / 1e4, lat / 1e4));
  }
  return pts;
}

/// मर्केटर प्रक्षेप — वही जो गूगल मैप्स जैसे नक्शों में दिखता है,
/// इसलिए आकृति जानी-पहचानी लगती है.
class Proj {
  static const double lonMin = 67.0;
  static const double lonMax = 98.6;
  static const double latMin = 6.2;
  static const double latMax = 37.6;

  static double _my(double lat) =>
      math.log(math.tan(math.pi / 4 + lat * math.pi / 360));

  static final double _yMin = _my(latMin);
  static final double _yMax = _my(latMax);

  /// मानचित्र बॉक्स का चौड़ाई/ऊँचाई अनुपात
  static double get aspect =>
      ((lonMax - lonMin) * math.pi / 180) / (_yMax - _yMin);

  final Size size;
  const Proj(this.size);

  Offset xy(double lat, double lon) {
    final x = (lon - lonMin) / (lonMax - lonMin) * size.width;
    final y = (1 - (_my(lat) - _yMin) / (_yMax - _yMin)) * size.height;
    return Offset(x, y);
  }

  Offset ofPoint(Offset lonLat) => xy(lonLat.dy, lonLat.dx);
}

/// कोनों को गोल करके चिकनी रेखा — बिंदुओं के बीच के मध्य-बिंदुओं से
/// होकर वक्र खींचा जाता है, इससे सीमाएँ नुकीली नहीं दिखतीं.
Path smoothRing(List<Offset> p, {bool close = true}) {
  final path = Path();
  if (p.length < 3) {
    if (p.isEmpty) return path;
    path.moveTo(p.first.dx, p.first.dy);
    for (final o in p.skip(1)) {
      path.lineTo(o.dx, o.dy);
    }
    return path;
  }

  Offset mid(Offset a, Offset b) =>
      Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);

  if (close) {
    final start = mid(p[p.length - 1], p[0]);
    path.moveTo(start.dx, start.dy);
    for (int i = 0; i < p.length; i++) {
      final c = p[i];
      final n = p[(i + 1) % p.length];
      final m = mid(c, n);
      path.quadraticBezierTo(c.dx, c.dy, m.dx, m.dy);
    }
    path.close();
  } else {
    path.moveTo(p[0].dx, p[0].dy);
    for (int i = 1; i < p.length - 1; i++) {
      final m = mid(p[i], p[i + 1]);
      path.quadraticBezierTo(p[i].dx, p[i].dy, m.dx, m.dy);
    }
    path.lineTo(p[p.length - 1].dx, p[p.length - 1].dy);
  }
  return path;
}

class StatePaths {
  final String name;
  final double lat;
  final double lon;
  final Path path;
  final Rect bounds;
  const StatePaths(this.name, this.lat, this.lon, this.path, this.bounds);
}

/// रास्ते एक बार बनाकर रख लेते हैं — हर बार ज़ूम पर दोबारा नहीं बनते.
class GeoCache {
  static Size? _size;
  static List<Path> india = const [];
  static List<StatePaths> states = const [];
  static List<Path> districts = const [];
  static bool _districtsBuilt = false;

  static Path _fromGroup(Proj proj, List<String> group) {
    final path = Path()..fillType = PathFillType.evenOdd;
    for (final ring in group) {
      path.addPath(smoothRing(decodeRing(ring).map(proj.ofPoint).toList()),
          Offset.zero);
    }
    return path;
  }

  static void build(Size size, {bool withDistricts = false}) {
    if (_size != size) {
      _size = size;
      _districtsBuilt = false;
      final proj = Proj(size);

      india = [for (final g in kIndiaPolys) _fromGroup(proj, g)];

      states = [
        for (final s in kStates)
          () {
            final p = Path()..fillType = PathFillType.evenOdd;
            for (final g in s.polys) {
              p.addPath(_fromGroup(proj, g), Offset.zero);
            }
            return StatePaths(s.name, s.lat, s.lon, p, p.getBounds());
          }()
      ];
      districts = const [];
    }

    if (withDistricts && !_districtsBuilt) {
      final proj = Proj(size);
      districts = [for (final g in kDistrictPolys) _fromGroup(proj, g)];
      _districtsBuilt = true;
    }
  }
}
