import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'engage.dart';
import 'models.dart';

/// प्रश्न-घंटी — ऐप 5 घंटे न खुले तो notification में एक असली प्रश्न.
///
/// ── सब फ़ोन पर ही ──
///
/// Notification सर्वर से नहीं भेजे जाते, फ़ोन ख़ुद तय समय पर दिखाता है.
/// Spark plan पर Cloud Functions चलते ही नहीं, और इस तरीक़े में न सर्वर
/// चाहिए, न इंटरनेट, न Firestore की एक भी read.
///
/// ── कैसे ──
///
/// ऐप पीछे जाते ही (`schedule`) आगे के कुछ notification तय हो जाते हैं —
/// 5 घंटे बाद, फिर अगले दिन, फिर तीसरे दिन. ऐप फिर खुला तो सब रद्द
/// (`cancelPending`) और पीछे जाने पर फिर से. यानी घंटी तभी बजती है जब
/// सचमुच इतनी देर से ऐप न खुला हो.
///
/// रात 10 से सुबह 8 के बीच का समय सुबह 8 पर खिसका दिया जाता है — आधी
/// रात को बजा notification छात्र को चिढ़ाता है, लौटाता नहीं.
class Reminders {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  /// notification छूकर ऐप खुला — वह प्रश्न.
  static final StreamController<Question> _taps =
      StreamController<Question>.broadcast();
  static Stream<Question> get onTap => _taps.stream;

  /// ऐप बंद था और notification से खुला — पहला frame बनने के बाद दिखाना है.
  static Question? launchQuestion;

  static const _channelId = 'prashn_ghanti';
  static const _channelName = 'प्रश्न-घंटी';

  /// notification की पहचान — इन्हीं को रद्द किया जाता है.
  static const _ids = [501, 502, 503];

  /// आख़िरी उपयोग से कितनी देर बाद.
  static const _after = [
    Duration(hours: 5),
    Duration(hours: 24),
    Duration(hours: 72),
  ];

  static Future<void> init() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      tzdata.initializeTimeZones();
      // छात्र भारत में हैं; फ़ोन का zone पढ़ने के लिए अलग plugin लगाना
      // पड़ता, जिसका यहाँ कोई फ़ायदा नहीं.
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));

      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_notify'),
        ),
        onDidReceiveNotificationResponse: (r) {
          final q = _decode(r.payload);
          if (q != null) _taps.add(q);
        },
      );

      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        launchQuestion = _decode(launch!.notificationResponse?.payload);
      }
      _ready = true;
    } catch (_) {
      // घंटी न चले तो भी ऐप वैसे ही चले
      _ready = false;
    }
  }

  /// Android 13+ पर अनुमति माँगना — एक ही बार.
  ///
  /// पहली बार खोलते ही नहीं माँगते: तब छात्र को पता ही नहीं कि घंटी किस
  /// बात की है, और "नहीं" दबा देता है. तीसरे प्रश्न के बाद माँगते हैं, जब
  /// वह ऐप का मज़ा ले चुका हो.
  static Future<void> askOnce() async {
    if (!_ready) return;
    final p = await SharedPreferences.getInstance();
    if (p.getBool('notif_asked') ?? false) return;
    await p.setBool('notif_asked', true);
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (_) {}
  }

  /// ऐप सामने आया — बजने से पहले ही सब रद्द.
  static Future<void> cancelPending() async {
    if (!_ready) return;
    try {
      for (final id in _ids) {
        await _plugin.cancel(id: id);
      }
    } catch (_) {}
  }

  /// ऐप पीछे गया — आगे की घंटियाँ तय करो.
  static Future<void> schedule() async {
    if (!_ready) return;
    await cancelPending();

    final pool = Engage.pool()..shuffle(Random());
    if (pool.isEmpty) return;

    final now = tz.TZDateTime.now(tz.local);
    for (int i = 0; i < _ids.length; i++) {
      final q = pool[i % pool.length];
      final when = _awake(now.add(_after[i]));
      try {
        await _plugin.zonedSchedule(
          id: _ids[i],
          scheduledDate: when,
          title: _title(i),
          body: q.question,
          payload: jsonEncode(q.toMap()),
          notificationDetails: _details(q, _title(i)),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      } catch (_) {
        // एक न लगे तो बाक़ी लगती रहें
      }
    }
  }

  /// जाँच के लिए — अभी तुरंत एक घंटी (डैशबोर्ड पर 🔥 को देर तक दबाएँ).
  /// 5 घंटे इंतज़ार किए बिना देखना हो कि notification कैसा दिखता है.
  static Future<bool> testNow() async {
    if (!_ready) return false;
    final pool = Engage.pool()..shuffle(Random());
    if (pool.isEmpty) return false;
    final q = pool.first;
    try {
      await _plugin.show(
        id: 509,
        title: _title(0),
        body: q.question,
        payload: jsonEncode(q.toMap()),
        notificationDetails: _details(q, _title(0)),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  static NotificationDetails _details(Question q, String title) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'कुछ घंटे ऐप न खुले तो याद दिलाने के लिए एक प्रश्न',
          icon: 'ic_stat_notify',
          color: P.brand,
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
          styleInformation: BigTextStyleInformation(
            '${q.question}\n\n${_options(q)}',
            contentTitle: title,
            summaryText: 'छूकर उत्तर देखिए',
          ),
        ),
      );

  /// रात 10 से सुबह 8 तक का समय सुबह 8 बजे पर.
  static tz.TZDateTime _awake(tz.TZDateTime t) {
    if (t.hour >= 22) {
      final next = t.add(const Duration(days: 1));
      return tz.TZDateTime(tz.local, next.year, next.month, next.day, 8);
    }
    if (t.hour < 8) {
      return tz.TZDateTime(tz.local, t.year, t.month, t.day, 8);
    }
    return t;
  }

  /// पहली घंटी जिज्ञासा जगाती है, बाद वाली लय टूटने की याद दिलाती हैं.
  static String _title(int i) {
    final s = Engage.streak;
    switch (i) {
      case 0:
        return const [
          '🧠 एक प्रश्न — क्या आप जानते हैं?',
          '🎯 5 घंटे हो गए — एक प्रश्न हो जाए?',
          '⚡ 30 सेकंड का प्रश्न, जवाब दीजिए',
        ][Random().nextInt(3)];
      case 1:
        return s > 0
            ? '🔥 आपकी $s दिन की लय आज टूट जाएगी!'
            : '📚 आज का प्रश्न आपका इंतज़ार कर रहा है';
      default:
        return '🏹 ब्रह्मास्त्र — तीन दिन से अभ्यास नहीं हुआ';
    }
  }

  static String _options(Question q) {
    final b = StringBuffer();
    for (int i = 0; i < q.options.length && i < kLetters.length; i++) {
      b.writeln('(${kLetters[i]}) ${q.options[i]}');
    }
    return b.toString().trim();
  }

  static Question? _decode(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final m = Map<String, dynamic>.from(jsonDecode(payload) as Map);
      return Question.fromMap('${m['id']}', m);
    } catch (_) {
      return null;
    }
  }
}
