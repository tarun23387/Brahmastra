import 'dart:math';

import 'package:android_id/android_id.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// इस फ़ोन की पहचान — ताकि एक आईडी एक ही फ़ोन में चले.
///
/// पहचान के दो हिस्से हैं:
///   • `id`   — Android का अपना पहचान अंक. ऐप हटाकर दोबारा डालने पर भी वही
///              रहता है, इसलिए छात्र को बार-बार छुड़वाना नहीं पड़ता.
///   • `name` — "Redmi Note 13" जैसा नाम, सिर्फ़ एडमिन को दिखाने के लिए —
///              ताकि फ़ोन बदलने की बात आए तो पता चले कौन-सा फ़ोन दर्ज है.
class DeviceId {
  static const _fallbackKey = 'device_id_fallback_v1';

  static String id = '';
  static String name = '';

  static bool get ready => id.isNotEmpty;

  static Future<void> init() async {
    name = await _readName();
    id = await _readId();
  }

  static Future<String> _readId() async {
    // पहली पसंद — Android का पहचान अंक (ऐप दोबारा डालने पर भी वही)
    try {
      final v = await const AndroidId().getId();
      if (v != null && v.trim().isNotEmpty) return v.trim();
    } catch (_) {}

    // न मिले तो अपना बनाकर फ़ोन में सेव कर लेते हैं. यह ऐप हटाने पर मिट
    // जाता है — तब छात्र को एक बार कहकर फ़ोन छुड़वाना पड़ेगा.
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_fallbackKey);
    if (saved != null && saved.isNotEmpty) return saved;

    final r = Random.secure();
    final made = List<int>.generate(16, (_) => r.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    await prefs.setString(_fallbackKey, made);
    return made;
  }

  static Future<String> _readName() async {
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      final brand = info.brand.trim();
      final model = info.model.trim();
      if (model.isEmpty) return brand.isEmpty ? 'Android' : brand;
      // "xiaomi" + "Redmi Note 13" → "Redmi Note 13" (दोहराव हटा देते हैं)
      if (brand.isEmpty ||
          model.toLowerCase().startsWith(brand.toLowerCase())) {
        return model;
      }
      return '$brand $model';
    } catch (_) {
      return 'Android';
    }
  }
}
