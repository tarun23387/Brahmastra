import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// हर प्रश्न सामने आने पर बजने वाला छोटा साउंड.
///
/// KBC जैसे गंभीर "प्रश्न आ रहा है" अंदाज़ के लिए — पर आवाज़ अपनी बनाई हुई है
/// (`assets/sounds/question_sting.wav`), किसी शो की नक़ल नहीं, इसलिए कोई
/// copyright अड़चन नहीं. फ़ोन में ही रहती है, इसलिए बिना इंटरनेट भी बजती है.
///
/// उपयोगकर्ता चाहे तो बंद कर सकता है, और वह पसंद फ़ोन में सेव रहती है.
class Sfx {
  static final AudioPlayer _player = AudioPlayer(playerId: 'q_sting');
  static const _asset = 'sounds/question_sting.wav';
  static const _prefKey = 'sfx_on_v1';

  static SharedPreferences? _p;
  static bool _ready = false;

  /// उपयोगकर्ता ने चालू रखा है या नहीं — डिफ़ॉल्ट चालू.
  static bool enabled = true;

  static Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    enabled = _p?.getBool(_prefKey) ?? true;
    try {
      // बार-बार का साउंड है — बजते ही छोड़ दे, लूप न करे
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.setSource(AssetSource(_asset));
      await _player.setVolume(0.7);
      _ready = true;
    } catch (_) {
      // साउंड लोड न हो तो चुपचाप बंद — ऐप वैसे ही चलती रहे
      _ready = false;
    }
  }

  /// चालू/बंद टॉगल — और नई पसंद सेव कर देता है.
  static Future<bool> toggle() async {
    enabled = !enabled;
    await _p?.setBool(_prefKey, enabled);
    if (!enabled) {
      try {
        await _player.stop();
      } catch (_) {}
    }
    return enabled;
  }

  /// एक बार साउंड बजाता है — नए प्रश्न पर.
  ///
  /// तेज़ी से स्क्रॉल करने पर पिछली आवाज़ काटकर शुरू से बजती है, ताकि
  /// आवाज़ें एक-दूसरे पर न चढ़ें.
  static Future<void> play() async {
    if (!enabled || !_ready) return;
    try {
      await _player.stop();
      await _player.seek(Duration.zero);
      await _player.resume();
    } catch (_) {
      // कोई दिक़्क़त हो तो अनदेखा — साउंड ज़रूरी नहीं, पढ़ाई ज़रूरी है
    }
  }

  static Future<void> dispose() async {
    try {
      await _player.dispose();
    } catch (_) {}
  }
}
