import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

/// आज कितने मिनट पढ़ाई हुई — यह हर तारीख़ के हिसाब से अलग सेव होता है.
/// समय तभी बढ़ता है जब ऐप सामने खुला हो.
class StudyTimer {
  static SharedPreferences? _p;
  static Timer? _tick;
  static int _seconds = 0;
  static String _day = '';
  static int _unsaved = 0;

  /// हर सेकंड बदलने पर UI को बताने के लिए.
  static final StreamController<int> _stream =
      StreamController<int>.broadcast();
  static Stream<int> get onTick => _stream.stream;

  static String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }

  static Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    _day = _today();
    _seconds = _p?.getInt('study_$_day') ?? 0;
    _cleanOld();
  }

  /// पंद्रह दिन से पुराने रिकॉर्ड हटा देते हैं ताकि कचरा जमा न हो.
  static void _cleanOld() {
    final keys = _p?.getKeys().where((k) => k.startsWith('study_')).toList();
    if (keys == null || keys.length <= 20) return;
    keys.sort();
    for (final k in keys.take(keys.length - 20)) {
      _p?.remove(k);
    }
  }

  static int get seconds => _seconds;
  static int get minutes => _seconds ~/ 60;

  static void start() {
    if (_tick != null) return;
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      // आधी रात के बाद नया दिन शुरू
      final d = _today();
      if (d != _day) {
        _flush();
        _day = d;
        _seconds = _p?.getInt('study_$_day') ?? 0;
      }
      _seconds++;
      _unsaved++;
      if (_unsaved >= 20) _flush();
      if (!_stream.isClosed) _stream.add(_seconds);
    });
  }

  static void stop() {
    _tick?.cancel();
    _tick = null;
    _flush();
  }

  static void _flush() {
    if (_unsaved == 0) return;
    _unsaved = 0;
    _p?.setInt('study_$_day', _seconds);
  }

  /// पिछले सात दिनों का समय (मिनट में), आज सबसे आख़िर में.
  static List<int> lastWeek() {
    final out = <int>[];
    final now = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      final key = 'study_${d.year}-${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';
      out.add((_p?.getInt(key) ?? 0) ~/ 60);
    }
    return out;
  }
}
