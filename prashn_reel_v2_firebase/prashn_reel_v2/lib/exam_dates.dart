import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'repository.dart';

/// हर परीक्षा की अधिसूचना, आवेदन की अंतिम तिथि और परीक्षा की तारीख़ —
/// course के thumbnail पर दिखाने के लिए.
///
/// Firestore के `config/exam_dates` doc से आती है, ताकि तारीख़ बदलने पर
/// नई build न बनानी पड़े. बदलने का तरीक़ा:
///
///   node firebase/admin/exam-dates.js set pet --notif 2026-08-01 \
///        --last 2026-09-07 --exam 2026-10-25
///
/// ⚠️ ये सरकारी जानकारी हैं — Play की Misleading Claims नीति के हिसाब से
/// इनका स्रोत (आयोग की साइट) ऐप में दिखना चाहिए. स्रोत वाला पन्ना और
/// पहले पन्ने की "तिथियाँ बदल सकती हैं" वाली पंक्ति इसी के लिए हैं.
/// तारीख़ भरने से पहले आयोग की अपनी सूचना से मिला लीजिए.
class ExamDate {
  /// अधिसूचना की तारीख़ — आगे की हो तो "संभावित".
  final DateTime? notif;

  /// आवेदन की अंतिम तिथि.
  final DateTime? lastDate;

  /// परीक्षा की (पहली) तारीख़.
  final DateTime? exam;

  const ExamDate({this.notif, this.lastDate, this.exam});

  static DateTime? _d(dynamic v) {
    if (v is Timestamp) return v.toDate();
    final t = DateTime.tryParse('${v ?? ''}');
    return t == null ? null : DateTime(t.year, t.month, t.day);
  }

  static ExamDate fromMap(Map m) => ExamDate(
        notif: _d(m['notif']),
        lastDate: _d(m['lastDate']),
        exam: _d(m['exam']),
      );

  Map<String, String?> toMap() => {
        'notif': notif?.toIso8601String().substring(0, 10),
        'lastDate': lastDate?.toIso8601String().substring(0, 10),
        'exam': exam?.toIso8601String().substring(0, 10),
      };
}

/// thumbnail पर क्या दिखे — ऊपर छोटी पंक्ति, नीचे मोटी.
class ExamStage {
  final String label;
  final String value;

  /// परीक्षा या अंतिम तिथि करीब (7 दिन) — चटख रंग में.
  final bool urgent;

  const ExamStage(this.label, this.value, {this.urgent = false});
}

class ExamDates {
  static const _cacheKey = 'exam_dates_v1';
  static Map<String, ExamDate> _all = {};

  /// thumbnail इसी को सुनते हैं — Firestore से नई तारीख़ें आते ही बदलें.
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw != null) {
      try {
        _all = _parse(jsonDecode(raw) as Map);
      } catch (_) {}
    }
    if (!QuestionRepo.firebaseReady) return;
    // ऐप खुलने को इसका इंतज़ार नहीं — app_config.dart वाली बात
    unawaited(_refresh(prefs));
  }

  static Future<void> _refresh(SharedPreferences prefs) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('config')
          .doc('exam_dates')
          .get()
          .timeout(const Duration(seconds: 15));
      final m = snap.data();
      if (m == null) return;
      final exams = m['exams'];
      if (exams is! Map) return;
      _all = _parse(exams);
      await prefs.setString(
        _cacheKey,
        jsonEncode(_all.map((k, v) => MapEntry(k, v.toMap()))),
      );
      changes.value++;
    } catch (_) {
      // न मिले तो सहेजी हुई तारीख़ें ही
    }
  }

  @visibleForTesting
  static void setForTest(Map<String, ExamDate> all) => _all = all;

  static Map<String, ExamDate> _parse(Map raw) => {
        for (final e in raw.entries)
          if (e.value is Map) '${e.key}': ExamDate.fromMap(e.value as Map),
      };

  /// आज के हिसाब से इस परीक्षा का पड़ाव.
  ///
  ///   अधिसूचना आगे की      → "अधिसूचना (संभावित)" + तारीख़
  ///   अधिसूचना आ चुकी,
  ///     आवेदन चालू         → "अधिसूचना 1 अग॰ जारी" + "अंतिम तिथि 7 सित॰"
  ///   आवेदन बंद, परीक्षा
  ///     की तारीख़ आ गई     → "परीक्षा 25 अक्टू॰" + "8 दिन बाक़ी"
  ///   आवेदन बंद, तारीख़ नहीं → "आवेदन बंद" + "परीक्षा तिथि जल्द"
  ///   परीक्षा हो चुकी       → कुछ नहीं
  static ExamStage? stageOf(String examId, {DateTime? now}) {
    final d = _all[examId];
    if (d == null) return null;
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);

    final lastOpen = d.lastDate != null && !d.lastDate!.isBefore(today);

    // परीक्षा की तारीख़ — आवेदन बंद हो चुका हो (या अंतिम तिथि पता ही न हो)
    if (d.exam != null && !d.exam!.isBefore(today) && !lastOpen) {
      final left = d.exam!.difference(today).inDays;
      return ExamStage(
        'परीक्षा ${fmt(d.exam!)}',
        left == 0
            ? 'आज परीक्षा है'
            : left == 1
                ? 'कल परीक्षा है'
                : '$left दिन बाक़ी',
        urgent: left <= 7,
      );
    }

    final notifOut = d.notif != null && !d.notif!.isAfter(today);

    if (notifOut && lastOpen) {
      final left = d.lastDate!.difference(today).inDays;
      return ExamStage(
        'अधिसूचना ${fmt(d.notif!)} जारी',
        'अंतिम तिथि ${fmt(d.lastDate!)}',
        urgent: left <= 7,
      );
    }

    if (d.notif != null && d.notif!.isAfter(today)) {
      return ExamStage('अधिसूचना (संभावित)', fmt(d.notif!, year: true));
    }

    // अधिसूचना आई (या अंतिम तिथि निकल चुकी), परीक्षा की तारीख़ अभी नहीं
    final lastGone = d.lastDate != null && d.lastDate!.isBefore(today);
    if ((notifOut || lastGone) && d.exam == null) {
      return const ExamStage('आवेदन बंद', 'परीक्षा तिथि जल्द');
    }

    return null; // परीक्षा हो चुकी, या कुछ पता नहीं
  }

  static const _months = [
    'जन॰', 'फ़र॰', 'मार्च', 'अप्रैल', 'मई', 'जून',
    'जुल॰', 'अग॰', 'सित॰', 'अक्टू॰', 'नव॰', 'दिस॰',
  ];

  static String fmt(DateTime d, {bool year = false}) =>
      '${d.day} ${_months[d.month - 1]}${year ? ' ${d.year}' : ''}';
}
