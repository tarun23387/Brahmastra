import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'repository.dart';

/// छात्र को रोज़ लौटाने वाली गिनती — लगातार कितने दिन, आज कितने प्रश्न.
///
/// सब कुछ फ़ोन में ही रहता है (shared_preferences), सर्वर पर कुछ नहीं जाता —
/// Spark plan की 50k reads/दिन वाली दीवार पर इसका कोई बोझ नहीं.
class Engage {
  static SharedPreferences? _p;

  /// रोज़ का लक्ष्य — असली पेपर के 100 प्रश्नों का पाँचवाँ हिस्सा.
  static const int dailyGoal = 20;

  /// डैशबोर्ड इसी को सुनता है — प्रश्न हल होते ही 🔥 और घेरा बदल जाएँ.
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);

  /// नोटिफ़िकेशन और "आज का प्रश्न" इन्हीं में से चुने जाते हैं.
  ///
  /// होम पन्ना जो प्रश्न लोड करता है उनमें से कुछ यहाँ रख लिए जाते हैं —
  /// ताकि प्रोग्रामर वाले छात्र को PET का GK नहीं, उसकी अपनी परीक्षा का
  /// प्रश्न जाए. कुछ न हो तो बंडल वाले मुफ़्त प्रश्न.
  static const _poolKey = 'engage_pool_v1';
  static const int _poolSize = 80;

  static Future<void> init() async {
    _p = await SharedPreferences.getInstance();
  }

  static String _dayKey(DateTime d) => '${d.year}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static String get _today => _dayKey(DateTime.now());
  static String get _yesterday =>
      _dayKey(DateTime.now().subtract(const Duration(days: 1)));

  /// आज कितने प्रश्नों का उत्तर दिया.
  static int get todayCount => _p?.getInt('done_$_today') ?? 0;

  /// लगातार कितने दिन — आज अभी कुछ न किया हो तो कल तक की गिनती बची रहती
  /// है, शून्य तभी होती है जब पूरा एक दिन छूट जाए.
  static int get streak {
    final last = _p?.getString('streak_day');
    if (last == _today || last == _yesterday) {
      return _p?.getInt('streak_n') ?? 0;
    }
    return 0;
  }

  static int get bestStreak => _p?.getInt('streak_best') ?? 0;

  /// आज की लय पक्की हुई या अभी बाक़ी है.
  static bool get doneToday => _p?.getString('streak_day') == _today;

  /// पिछले सात दिन, आज सबसे आख़िर में — किस दिन कुछ हल किया.
  static List<bool> lastWeek() {
    final now = DateTime.now();
    return [
      for (int i = 6; i >= 0; i--)
        (_p?.getInt('done_${_dayKey(now.subtract(Duration(days: i)))}') ?? 0) >
            0,
    ];
  }

  /// हर उत्तर पर.
  static Future<void> recordAnswer() async {
    final p = _p;
    if (p == null) return;

    await p.setInt('done_$_today', todayCount + 1);

    final last = p.getString('streak_day');
    if (last != _today) {
      final n = last == _yesterday ? (p.getInt('streak_n') ?? 0) + 1 : 1;
      await p.setString('streak_day', _today);
      await p.setInt('streak_n', n);
      if (n > bestStreak) await p.setInt('streak_best', n);
    }

    _cleanOld(p);
    changes.value++;
  }

  /// 40 दिन से पुरानी गिनती हटा देते हैं — हफ़्ते की पट्टी को 7 ही चाहिए.
  static void _cleanOld(SharedPreferences p) {
    final keys = p.getKeys().where((k) => k.startsWith('done_')).toList();
    if (keys.length <= 40) return;
    keys.sort();
    for (final k in keys.take(keys.length - 40)) {
      p.remove(k);
    }
  }

  // ───────────────────────── प्रश्नों का भंडार ─────────────────────────

  /// होम पन्ने से — अभी जो प्रश्न चल रहे हैं उनमें से कुछ याद रख लो.
  static Future<void> rememberPool(List<Question> qs) async {
    final p = _p;
    if (p == null || qs.isEmpty) return;
    // बहुत लंबे और सूची-मिलान वाले प्रश्न notification में पढ़े नहीं जाते
    final good = qs
        .where((q) => q.match == null && q.question.length <= 220)
        .toList()
      ..shuffle(Random());
    if (good.isEmpty) return;
    await p.setString(
      _poolKey,
      jsonEncode(good.take(_poolSize).map((q) => q.toMap()).toList()),
    );
  }

  static List<Question> pool() {
    final raw = _p?.getString(_poolKey);
    if (raw != null) {
      try {
        final list = <Question>[];
        for (final m in jsonDecode(raw) as List) {
          final map = Map<String, dynamic>.from(m as Map);
          final q = Question.fromMap('${map['id']}', map);
          if (q != null) list.add(q);
        }
        if (list.isNotEmpty) return list;
      } catch (_) {
        // ख़राब कैश — नीचे बंडल वाले प्रश्न
      }
    }
    return QuestionRepo.seedQuestions()
        .where((q) => q.match == null && q.question.length <= 220)
        .toList();
  }

  /// आज के प्रश्न का चुना हुआ विकल्प — अभी हल न किया हो तो null.
  static int? get dailyChoice => _p?.getInt('qod_$_today');

  static Future<void> saveDailyChoice(int option) async {
    final p = _p;
    if (p == null) return;
    // कल वाला हटा दो — एक ही key काफ़ी है
    // (qod_q_ वाला आज का प्रश्न है — उसे नहीं छूना)
    for (final k in p.getKeys()
        .where((k) => k.startsWith('qod_') && !k.startsWith('qod_q_'))
        .toList()) {
      if (k != 'qod_$_today') await p.remove(k);
    }
    await p.setInt('qod_$_today', option);
    changes.value++;
  }

  /// आज का प्रश्न — पूरे दिन वही रहता है, कल बदल जाता है.
  static Question? questionOfDay() {
    final p = _p;
    final key = 'qod_q_$_today';

    // आज का चुना हुआ प्रश्न सहेजा हुआ है — वही. भंडार (pool) हर बार
    // अभ्यास खोलने पर नए सिरे से भरता है; सिर्फ़ उससे चुनते तो दिन के बीच
    // प्रश्न बदल जाता और सहेजा उत्तर किसी और प्रश्न पर दिखता (फ़ोन पर पकड़ा).
    final saved = p?.getString(key);
    if (saved != null) {
      try {
        final m = Map<String, dynamic>.from(jsonDecode(saved) as Map);
        final q = Question.fromMap('${m['id']}', m);
        if (q != null) return q;
      } catch (_) {}
    }

    final all = pool();
    if (all.isEmpty) return null;
    all.sort((a, b) => a.id.compareTo(b.id));
    final n = DateTime.now();
    final dayNo = DateTime(n.year, n.month, n.day)
        .difference(DateTime(2026, 1, 1))
        .inDays;
    final q = all[dayNo.abs() % all.length];

    if (p != null) {
      for (final k in p.getKeys().where((k) => k.startsWith('qod_q_')).toList()) {
        p.remove(k);
      }
      p.setString(key, jsonEncode(q.toMap()));
    }
    return q;
  }
}
