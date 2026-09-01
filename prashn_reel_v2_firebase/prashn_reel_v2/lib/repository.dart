import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/seed_questions.dart';
import 'models.dart';

enum SourceKind { firebase, cache, seed }

/// मुफ़्त में अब पूरा UP PET खुला है — कोई गिनती की सीमा नहीं.
///
/// पहले 40 चुने हुए "नमूना" प्रश्न मुफ़्त थे. अब नमूना नहीं, पूरा पीईटी पेपर
/// मुफ़्त है — server पर `subscriptions.js free-pet` उन सब प्रश्नों पर
/// `free: true` लगाता है, और नीचे [freeOnly] उन्हीं को माँगता है.

class LoadResult {
  final List<Question> questions;
  final SourceKind source;
  final DateTime? syncedAt;
  const LoadResult(this.questions, this.source, this.syncedAt);
}

/// प्रश्न कहाँ से आएँ इसका क्रम:
/// 1. Firestore (अगर Firebase जुड़ा है और इंटरनेट चल रहा है)
/// 2. पिछली बार का लोकल कैश
/// 3. ऐप में बंडल किए 150 सीड प्रश्न
class QuestionRepo {
  static const String collection = 'questions';
  static const String packCollection = 'packs';
  static const String _cacheKey = 'q_cache_v2';
  static const String _cacheTimeKey = 'q_cache_time_v2';

  static bool firebaseReady = false;

  static List<Question> seedQuestions() {
    final out = <Question>[];
    for (final m in kSeedQuestions) {
      final q = Question.fromMap('${m['id']}', Map<String, dynamic>.from(m));
      if (q != null) out.add(q);
    }
    return out;
  }

  /// प्रश्नों की ऊपरी सीमा — एक query में इससे ज़्यादा नहीं आते.
  ///
  /// पहले 1000 थी, और मुफ़्त वाला `pet-main` 25 अगस्त 2026 को 909 से बढ़कर
  /// 1333 हो गया — यानी वह सीमा चुपचाप 333 प्रश्न काटने लगती, बिना किसी
  /// एरर के. इसलिए बढ़ाई गई. आगे और प्रश्न जुड़ेंगे, तभी 3000 रखा है.
  ///
  /// ख़र्च की चिंता इसलिए नहीं कि नीचे वाला संस्करण-कैश यह query दिन में
  /// बीसियों बार नहीं चलाता — सिर्फ़ तब चलाता है जब प्रश्न सच में बदले हों.
  static const int _maxQuestions = 3000;

  /// कैश की आख़िरी हद — संस्करण न बदले तो भी इतने बाद एक बार ताज़ा कर लेते हैं.
  ///
  /// यह सिर्फ़ सुरक्षा-जाल है: कभी manifest में संस्करण बढ़ाना भूल जाएँ तो
  /// छात्र महीनों पुराने प्रश्नों पर अटका न रहे.
  static const Duration cacheMaxLife = Duration(days: 30);

  /// manifest न मिले तब की पुरानी व्यवस्था — समय से तय होने वाला कैश.
  ///
  /// पहले सिर्फ़ यही था. अब यह तभी काम आता है जब `config/manifest` पढ़ा ही
  /// न जा सके (इंटरनेट नहीं, या doc अभी बना नहीं).
  static const Duration cacheLife = Duration(hours: 24);

  /// किस छाँट का कौन-सा संस्करण फ़ोन में सेव है.
  static String _versionKey(String tag) =>
      'q_ver_v1_${tag.isEmpty ? 'all' : tag}';

  // ── manifest — एक छोटा doc जो बताता है कि क्या बदला ──
  //
  // `config/manifest` में हर प्रश्नपत्र का एक गिनती-अंक रहता है:
  //
  //   { "papers": { "pet-main": 12, "roaro-hindi": 8, "_free": 12 } }
  //
  // प्रश्न चढ़ाने पर एडमिन उस पेपर का अंक एक बढ़ा देता है. ऐप हर बार सिर्फ़
  // यही एक doc पढ़ता है — 1 read. अंक वही निकला तो कैश से चल पड़ता है, चाहे
  // वह दस दिन पुराना हो.
  //
  // पहले कैश 24 घंटे में अपने आप बासी हो जाता था, इसलिए हर छात्र रोज़ पूरा
  // पेपर दोबारा उतारता था — प्रश्न बदले हों या नहीं. हज़ार छात्र = रोज़ दस
  // लाख reads. अब वही हज़ार छात्र = रोज़ हज़ार reads.
  static Map<String, int>? _manifest;
  static DateTime? _manifestAt;

  /// एक ही session में बार-बार न पूछें — पेपर बदल-बदलकर देखने पर भी
  /// manifest आधे घंटे में एक ही बार पढ़ा जाता है.
  static const Duration _manifestLife = Duration(minutes: 30);

  /// manifest लाता है. न मिले तो null — तब पुरानी समय वाली व्यवस्था चलती है.
  static Future<Map<String, int>?> _loadManifest({bool force = false}) async {
    if (!firebaseReady) return null;

    final at = _manifestAt;
    if (!force &&
        _manifest != null &&
        at != null &&
        DateTime.now().difference(at) < _manifestLife) {
      return _manifest;
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection('config')
          .doc('manifest')
          .get()
          .timeout(const Duration(seconds: 8));

      final raw = snap.data()?['papers'];
      if (raw is! Map) return null;

      final out = <String, int>{};
      raw.forEach((k, v) {
        if (v is num) out['$k'] = v.toInt();
      });

      _manifest = out;
      _manifestAt = DateTime.now();
      return out;
    } catch (_) {
      // इंटरनेट न हो तो पिछली बार वाला manifest ही सही — उससे कैश चलता रहेगा
      return _manifest;
    }
  }

  /// इस छाँट के लिए सर्वर पर कौन-सा संस्करण है. पता न चले तो null.
  static int? _remoteVersion(
    Map<String, int>? manifest, {
    required bool freeOnly,
    String? paperId,
  }) {
    if (manifest == null) return null;
    if (freeOnly) return manifest['_free'];
    if (paperId != null) return manifest[paperId];
    return manifest['all'];
  }

  /// कैश से प्रश्न. [maxAge] दिया हो तो उससे पुराना कैश ठुकरा देता है.
  ///
  /// कुछ न मिले या पढ़ने में गड़बड़ हो तो null लौटाता है, ताकि बुलाने
  /// वाला सर्वर की ओर बढ़ जाए.
  static LoadResult? _readCache(
    SharedPreferences prefs,
    String cacheKey,
    String cacheTimeKey, {
    Duration? maxAge,
  }) {
    final at = DateTime.tryParse(prefs.getString(cacheTimeKey) ?? '');
    if (at == null) return null;
    if (maxAge != null && DateTime.now().difference(at) > maxAge) return null;

    final raw = prefs.getString(cacheKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final list = <Question>[];
      for (final e in decoded) {
        final m = Map<String, dynamic>.from(e as Map);
        final q = Question.fromMap('${m['id']}', m);
        if (q != null) list.add(q);
      }
      return list.isEmpty ? null : LoadResult(list, SourceKind.cache, at);
    } catch (_) {
      return null;
    }
  }

  /// pack से प्रश्न — पूरा पेपर दो-तीन reads में.
  ///
  /// packs `build-packs.js` बनाता है: वही प्रश्न, बस कुछ बड़े दस्तावेज़ों
  /// में बँधे हुए. `questions` collection ही असली ठिकाना है — pack सिर्फ़
  /// पढ़ने की सुविधा हैं, और हर बार नए सिरे से बना दिए जाते हैं.
  ///
  /// कुछ न मिले तो null — तब बुलाने वाला [_fromDocs] पर चला जाता है.
  static Future<List<Question>?> _fromPacks({
    required bool freeOnly,
    String? paperId,
  }) async {
    // बिना किसी छाँट वाला रास्ता — इसका कोई pack नहीं बनता
    final key = freeOnly ? '_free' : paperId;
    if (key == null) return null;

    try {
      Query<Map<String, dynamic>> q = FirebaseFirestore.instance
          .collection(packCollection)
          .where('key', isEqualTo: key);

      // ध्यान: `free` वाली शर्त दिखावे के लिए नहीं है.
      //
      // नियम कहते हैं `resource.data.free == true || isSubscribed()`. बिना
      // सदस्यता वाले के लिए Firestore को यह साबित होना चाहिए कि query के
      // *सारे* नतीजे मुफ़्त ही होंगे — सिर्फ़ `key == '_free'` से वह साबित
      // नहीं होता, और पूरी request 403 में ठुकरा दी जाती है (जाँच कर लिया).
      //
      // सदस्य के लिए यह शर्त नहीं लगती: वहाँ `isSubscribed()` अपने आप सच
      // है, इसलिए पेपर वाला pack बिना किसी अतिरिक्त शर्त के मिल जाता है.
      if (freeOnly) q = q.where('free', isEqualTo: true);

      final snap = await q.get().timeout(const Duration(seconds: 20));

      if (snap.docs.isEmpty) return null;

      // टुकड़े क्रम से जोड़ें. ऐप वैसे भी प्रश्न फेंटता है, पर क्रम तय रहे
      // तो कैश हर बार एक जैसा बनता है और गड़बड़ ढूँढ़ना आसान रहता है.
      final docs = snap.docs.toList()
        ..sort((a, b) {
          final x = a.data()['part'];
          final y = b.data()['part'];
          return (x is num ? x : 0).compareTo(y is num ? y : 0);
        });

      final out = <Question>[];
      for (final d in docs) {
        final raw = d.data()['questions'];
        if (raw is! List) continue;
        for (final e in raw) {
          if (e is! Map) continue;
          final m = Map<String, dynamic>.from(e);
          final q = Question.fromMap('${m['id']}', m);
          if (q != null) out.add(q);
        }
      }

      return out.isEmpty ? null : out;
    } catch (_) {
      // नियम अभी न चढ़े हों, या इंटरनेट टूटा हो — पुराना रास्ता है ही
      return null;
    }
  }

  /// पुराना रास्ता — हर प्रश्न अपना एक दस्तावेज़.
  ///
  /// pack आ जाने के बाद यह सिर्फ़ जाल है: नया पेपर जिसका pack अभी बना न
  /// हो, या वे पुरानी हालतें जहाँ pack पढ़ा न जा सके. महँगा है (एक-एक
  /// प्रश्न एक-एक read), इसलिए पहले pack ही आज़माया जाता है.
  static Future<List<Question>?> _fromDocs({
    required bool freeOnly,
    String? paperId,
  }) async {
    Query<Map<String, dynamic>> query =
        FirebaseFirestore.instance.collection(collection);

    if (freeOnly) {
      query = query.where('free', isEqualTo: true);
    } else if (paperId != null) {
      // NOTE: Firestore एक ही query में एक ही array-contains लेता है,
      // इसलिए पेपर server पर छाँटते हैं और विषय बुलाने वाले के पास.
      query = query.where('papers', arrayContains: paperId);
    }

    final snap = await query
        .limit(_maxQuestions)
        .get()
        .timeout(const Duration(seconds: 20));

    final now = DateTime.now();
    final out = <Question>[];

    for (final doc in snap.docs) {
      final data = doc.data();

      // 15 दिन पुराने साप्ताहिक प्रश्न छोड़ दें.
      // (pack में ये पहले ही छँट चुके होते हैं — build-packs.js छाँटता है.)
      final exp = data['expiresAt'];
      if (exp is Timestamp && exp.toDate().isBefore(now)) continue;

      final q = Question.fromMap(doc.id, data);
      if (q != null) out.add(q);
    }

    return out.isEmpty ? null : out;
  }

  /// [freeOnly] — बिना सदस्यता वाले उपयोगकर्ता के लिए सिर्फ़ मुफ़्त प्रश्न.
  ///
  /// ध्यान: Firestore के नियम भी यही जाँचते हैं. बिना सदस्यता के पूरी
  /// collection माँगी तो request ही ठुकरा दी जाएगी — इसलिए यहाँ फ़िल्टर
  /// लगाना ज़रूरी है, सिर्फ़ दिखावे के लिए नहीं.
  ///
  /// [paperId] — सिर्फ़ उसी प्रश्नपत्र के प्रश्न (जैसे `roaro-hindi`).
  /// [subject] — उसी में से एक विषय.
  ///
  /// हर छाँट का अपना कैश है, इसलिए एक प्रश्नपत्र देखकर दूसरे पर जाने से
  /// पहले वाला मिटता नहीं — और बिना इंटरनेट भी दोनों चलते रहते हैं.
  static Future<LoadResult> load({
    bool forceRemote = false,
    bool freeOnly = false,
    String? paperId,
    String? subject,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final tag = freeOnly
        ? '_free'
        : [
            if (paperId != null) paperId,
            if (subject != null) subject,
          ].join('_');
    final cacheKey = tag.isEmpty ? _cacheKey : '${_cacheKey}_$tag';
    final cacheTimeKey = tag.isEmpty ? _cacheTimeKey : '${_cacheTimeKey}_$tag';
    final versionKey = _versionKey(tag);

    // ── पहले कैश, तभी सर्वर ──
    //
    // सिंक बटन (`forceRemote`) इस बचत को जानबूझकर तोड़ता है — जब छात्र
    // ख़ुद नए प्रश्न माँगे, तब सर्वर से ही आना चाहिए.
    int? remoteVer;
    if (!forceRemote) {
      final manifest = await _loadManifest();
      remoteVer = _remoteVersion(manifest, freeOnly: freeOnly, paperId: paperId);

      if (remoteVer != null) {
        // संस्करण मिल गया — तो अब समय नहीं, संस्करण ही तय करेगा.
        if (prefs.getInt(versionKey) == remoteVer) {
          final hit =
              _readCache(prefs, cacheKey, cacheTimeKey, maxAge: cacheMaxLife);
          if (hit != null) return hit;
        }
      } else {
        // manifest नहीं मिला — पुरानी समय वाली व्यवस्था पर लौट जाओ
        final hit =
            _readCache(prefs, cacheKey, cacheTimeKey, maxAge: cacheLife);
        if (hit != null) return hit;
      }
    }

    if (firebaseReady) {
      try {
        // ── पहले pack, फिर एक-एक दस्तावेज़ ──
        //
        // pack में वही प्रश्न कुछ बड़े दस्तावेज़ों में बँधे होते हैं, इसलिए
        // पूरा पेपर 1333 reads नहीं, 2 reads में उतर आता है. Spark plan की
        // रोज़ की 50,000 वाली हद पर यही फ़र्क़ ~37 छात्रों और हज़ारों छात्रों
        // का है.
        //
        // pack न मिले — अभी बने न हों, नियम अभी चढ़े न हों, या नया पेपर हो —
        // तो पुराना रास्ता ज्यों का त्यों मौजूद है. इसीलिए यह बदलाव किसी
        // पुरानी चीज़ को तोड़े बिना चढ़ाया जा सकता है.
        var list = await _fromPacks(freeOnly: freeOnly, paperId: paperId);
        list ??= await _fromDocs(freeOnly: freeOnly, paperId: paperId);

        // विषय की छाँट यहाँ — Firestore एक query में दो array शर्तें नहीं
        // लेता, और pack तो पूरे पेपर का एक ही पुलिंदा है. दोनों रास्तों के
        // लिए एक ही जगह छाँटना ज़्यादा सीधा है.
        if (list != null && subject != null) {
          list = list.where((q) => q.subject == subject).toList();
        }

        if (list != null && list.isNotEmpty) {
          final now = DateTime.now();

          await prefs.setString(
            cacheKey,
            jsonEncode(list.map((q) => q.toMap()).toList()),
          );
          await prefs.setString(cacheTimeKey, now.toIso8601String());

          // संस्करण अब सेव होता है — प्रश्न सच में आ जाने के बाद. पहले सेव
          // कर देते तो query फेल होने पर फ़ोन में "नया संस्करण मिल गया" लिखा
          // रह जाता और छात्र पुराने प्रश्नों पर ही अटक जाता.
          //
          // सिंक बटन के रास्ते remoteVer भरा नहीं होता, इसलिए तब manifest
          // यहीं पढ़ते हैं — वरना अगली बार कैश बेकार चला जाता.
          final ver = remoteVer ??
              _remoteVersion(await _loadManifest(force: forceRemote),
                  freeOnly: freeOnly, paperId: paperId);
          if (ver != null) {
            await prefs.setInt(versionKey, ver);
          } else {
            await prefs.remove(versionKey);
          }

          return LoadResult(list, SourceKind.firebase, now);
        }
      } catch (_) {
        // चुपचाप कैश/सीड पर चले जाएँ
      }
    }

    // सर्वर से कुछ न मिला — कितना भी पुराना हो, कैश सीड से बेहतर है
    final stale = _readCache(prefs, cacheKey, cacheTimeKey);
    if (stale != null) return stale;

    // बंडल किए प्रश्न — यही मुफ़्त पीईटी वाला सेट है, इसलिए पूरे के पूरे देते हैं
    final seed = seedQuestions();
    return LoadResult(seed, SourceKind.seed, null);
  }
}

/// उत्तरों को फ़ोन में सेव रखने के लिए.
class AnswerStore {
  static const _key = 'answers_v2';
  static SharedPreferences? _p;

  static Future<void> init() async {
    _p = await SharedPreferences.getInstance();
  }

  static Map<String, int> load() {
    final raw = _p?.getString(_key);
    if (raw == null || raw.isEmpty) return <String, int>{};
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return m.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      return <String, int>{};
    }
  }

  static Future<void> save(Map<String, int> answers) async {
    await _p?.setString(_key, jsonEncode(answers));
  }

  static Future<void> clear() async => _p?.remove(_key);
}

/// पढ़ने वाली सामग्री लाने वाला — प्रश्नों से अलग रास्ता.
///
/// `lessons` collection में एक विषय का एक ही दस्तावेज़ होता है, इसलिए एक
/// पाठ खोलने में एक ही read लगता है. उतना सस्ता है कि हर बार पढ़ना ठीक है;
/// फिर भी एक ही सत्र में बार-बार न पढ़ा जाए, इसके लिए स्मृति में रख लेते हैं.
///
/// यह जानबूझकर `packs` में नहीं है — build-packs.js वहाँ अपने लिखे के
/// अलावा हर दस्तावेज़ मिटा देता है.
class LessonRepo {
  static const String collection = 'lessons';

  static final Map<String, Lesson> _memory = {};

  /// एक विषय का पाठ.
  ///
  /// सदस्यता न हो तो Firestore के नियम ही request ठुकरा देते हैं और यहाँ
  /// null लौटता है — यानी ताला नियमों में है, सिर्फ़ परदे पर नहीं.
  static Future<Lesson?> load({
    required String paperId,
    required String subject,
    bool force = false,
  }) async {
    final key = 'lesson:$paperId:$subject';
    if (!force && _memory.containsKey(key)) return _memory[key];

    try {
      final snap = await FirebaseFirestore.instance
          .collection(collection)
          .where('key', isEqualTo: key)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 20));

      if (snap.docs.isEmpty) return null;

      final lesson = Lesson.fromMap(snap.docs.first.data());
      if (lesson != null) _memory[key] = lesson;
      return lesson;
    } catch (_) {
      // इंटरनेट न हो, या सदस्यता न होने पर नियम ठुकरा दें — दोनों हालत में
      // ऐप को बस इतना पता होना चाहिए कि पाठ नहीं मिला.
      return null;
    }
  }

  /// किन विषयों का पाठ तैयार है — Learn वाला हिस्सा यही पूछता है.
  ///
  /// एक query, सारे विषय. सदस्यता न हो तो ख़ाली सूची लौटती है.
  static Future<List<String>> subjectsFor(String paperId) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection(collection)
          .where('paper', isEqualTo: paperId)
          .get()
          .timeout(const Duration(seconds: 20));
      return snap.docs
          .map((d) => '${d.data()['subject'] ?? ''}')
          .where((s) => s.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
