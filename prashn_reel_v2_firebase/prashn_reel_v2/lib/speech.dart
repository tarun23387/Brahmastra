import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// प्रश्न को आवाज़ में सुनाने वाला हिस्सा.
///
/// फ़ोन का अपना TTS इंजन इस्तेमाल होता है (ज़्यादातर Android पर Google TTS),
/// इसलिए इंटरनेट की ज़रूरत नहीं पड़ती — बस हिंदी आवाज़ फ़ोन में लगी होनी चाहिए.
///
/// उपयोगकर्ता जब चाहे बंद/चालू कर सकता है, और उसकी पसंद फ़ोन में सेव रहती है.
class Speaker {
  static final FlutterTts _tts = FlutterTts();

  static const _prefKey = 'speak_on_v1';
  static const _rateKey = 'speak_rate_v1';

  static SharedPreferences? _p;
  static bool _ready = false;

  /// फ़ोन में हिंदी आवाज़ मिली या नहीं.
  static bool hindiAvailable = false;

  /// उपयोगकर्ता ने चालू कर रखा है या नहीं.
  static bool enabled = false;

  /// अभी कुछ बोला जा रहा है या नहीं.
  static bool speaking = false;

  /// बोलने की रफ़्तार — 0.3 (धीमी) से 0.8 (तेज़).
  /// KBC जैसे ठहराव के लिए थोड़ी धीमी रखी है.
  static double rate = 0.42;

  /// गहरी आवाज़ के लिए pitch — 1.0 सामान्य, इससे कम = भारी/गंभीर.
  static const double _deepPitch = 0.82;

  static final StreamController<bool> _stream =
      StreamController<bool>.broadcast();

  /// चालू/बंद या बोलना शुरू-बंद होने पर UI को बताने के लिए.
  static Stream<bool> get onChange => _stream.stream;

  static Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    enabled = _p?.getBool(_prefKey) ?? false;
    rate = _p?.getDouble(_rateKey) ?? 0.42;

    try {
      // हिंदी आवाज़ है या नहीं — देख लेते हैं
      final langs = await _tts.getLanguages;
      if (langs is List) {
        hindiAvailable = langs.any((l) => '$l'.toLowerCase().startsWith('hi'));
      }

      await _tts.setLanguage('hi-IN');
      await _tts.setSpeechRate(rate);
      await _tts.setVolume(1.0);
      // गहरी, भारी आवाज़ — KBC जैसे गंभीर अंदाज़ का असर. असली कलाकार की
      // आवाज़ फ़ोन के TTS में नहीं होती, पर pitch नीचे रखने और गहरा (male)
      // स्वर चुनने से वैसी गंभीरता आती है.
      await _tts.setPitch(_deepPitch);
      await _pickDeepMaleVoice();

      // एक वाक्य ख़त्म होने पर अगला बोलने के लिए इंतज़ार करना पड़ता है
      await _tts.awaitSpeakCompletion(true);

      _tts.setCompletionHandler(() {
        speaking = false;
        _notify();
      });
      _tts.setCancelHandler(() {
        speaking = false;
        _notify();
      });
      _tts.setErrorHandler((_) {
        speaking = false;
        _notify();
      });

      _ready = true;
    } catch (_) {
      // TTS इंजन न मिले तो चुपचाप बंद रहेगा — ऐप वैसे ही चलती रहेगी
      _ready = false;
      hindiAvailable = false;
    }
  }

  static void _notify() {
    if (!_stream.isClosed) _stream.add(enabled);
  }

  /// बटन दबाने पर — चालू हो तो तुरंत बंद, बंद हो तो चालू.
  static Future<bool> toggle() async {
    enabled = !enabled;
    await _p?.setBool(_prefKey, enabled);
    if (!enabled) await stop();
    _notify();
    return enabled;
  }

  static Future<void> setRate(double r) async {
    rate = r.clamp(0.25, 0.9);
    await _p?.setDouble(_rateKey, rate);
    try {
      await _tts.setSpeechRate(rate);
    } catch (_) {}
  }

  /// फ़ोन में जो हिंदी आवाज़ें हैं उनमें से सबसे गहरी/पुरुष वाली चुनता है.
  ///
  /// हर फ़ोन में आवाज़ें अलग होती हैं और गंभीरता (gender) का नाम भी हमेशा
  /// नहीं मिलता — इसलिए यह "कोशिश" भर है: पहले नाम में 'male' ढूँढते हैं
  /// (पर 'female' नहीं), वरना कोई भी hi-IN आवाज़. न मिले तो फ़ोन की डिफ़ॉल्ट.
  static Future<void> _pickDeepMaleVoice() async {
    try {
      final voices = await _tts.getVoices;
      if (voices is! List) return;

      Map<String, String>? asVoice(dynamic v) {
        if (v is Map) {
          final name = '${v['name'] ?? ''}';
          final locale = '${v['locale'] ?? ''}';
          if (name.isEmpty) return null;
          return {'name': name, 'locale': locale};
        }
        return null;
      }

      final hindi = voices
          .map(asVoice)
          .whereType<Map<String, String>>()
          .where((v) => v['locale']!.toLowerCase().startsWith('hi'))
          .toList();
      if (hindi.isEmpty) return;

      Map<String, String> chosen = hindi.firstWhere(
        (v) {
          final n = v['name']!.toLowerCase();
          return n.contains('male') && !n.contains('female');
        },
        orElse: () => hindi.first,
      );

      await _tts.setVoice(chosen);
    } catch (_) {
      // कोई दिक़्क़त हो तो डिफ़ॉल्ट आवाज़ ही चलेगी
    }
  }

  /// पूरा प्रश्न सुनाता है — पहले प्रश्न, फिर चारों विकल्प.
  ///
  /// उत्तर और व्याख्या जान-बूझकर नहीं बोले जाते, वरना सुनते ही जवाब पता चल जाए.
  static Future<void> speakQuestion(Question q) async {
    if (!enabled || !_ready) return;

    await stop();

    final buf = StringBuffer()
      ..write(q.question)
      ..write('। ');

    for (int i = 0; i < q.options.length && i < kLetters.length; i++) {
      buf
        ..write(kLetters[i])
        ..write('। ')
        ..write(q.options[i])
        ..write('। ');
    }

    await _speak(buf.toString());
  }

  /// उत्तर चुनने के बाद व्याख्या सुनाने के लिए.
  static Future<void> speakExplanation(Question q) async {
    if (!enabled || !_ready) return;
    if (q.explanation.trim().isEmpty) return;

    await stop();
    final correct = q.answer < q.options.length ? q.options[q.answer] : '';
    await _speak('सही उत्तर — $correct। ${q.explanation}');
  }

  static Future<void> _speak(String text) async {
    if (text.trim().isEmpty) return;
    try {
      speaking = true;
      _notify();
      await _tts.speak(text);
    } catch (_) {
      speaking = false;
      _notify();
    }
  }

  /// बोलना तुरंत रोक देता है — अगला प्रश्न आने पर या ऐप पीछे जाने पर.
  static Future<void> stop() async {
    if (!_ready) return;
    try {
      await _tts.stop();
    } catch (_) {}
    speaking = false;
    _notify();
  }

  static Future<void> dispose() async {
    await stop();
  }
}
