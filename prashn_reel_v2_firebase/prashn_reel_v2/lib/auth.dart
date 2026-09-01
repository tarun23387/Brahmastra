import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'device.dart';
import 'repository.dart';

/// एक परीक्षा की सदस्यता — अपनी अलग एक्सपायरी के साथ.
///
/// हर परीक्षा अलग से ख़रीदी जाती है, इसलिए तारीख़ भी अलग होनी चाहिए.
/// पहले पूरी सदस्यता की एक ही तारीख़ थी — तब जनवरी में RO/ARO लेने वाला
/// मार्च में UPPCS लेता तो दूसरी वाली भी जनवरी से बँध जाती, और उसे पूरा
/// महीना मिलता ही नहीं.
class Course {
  final String examId;
  final DateTime? expiresAt;

  const Course({required this.examId, required this.expiresAt});

  bool get isActive =>
      expiresAt != null && expiresAt!.isAfter(DateTime.now());

  int get daysLeft {
    if (!isActive) return 0;
    final h = expiresAt!.difference(DateTime.now()).inHours;
    return h <= 0 ? 0 : (h / 24).ceil();
  }

  bool get isExpiringSoon => isActive && daysLeft <= 7;
}

/// उपयोगकर्ता को कितनी पहुँच मिली हुई है.
///
/// अभी यह Firestore के `users/{uid}` doc से आती है. आगे अगर Play Billing
/// या कोई और तरीका जोड़ें, तो सिर्फ़ यही क्लास बदलेगी — बाक़ी ऐप वैसा ही रहेगा.
class Entitlement {
  final String uid;
  final String name;
  final String phone;

  /// हर ख़रीदी हुई परीक्षा, अपनी तारीख़ के साथ.
  final Map<String, Course> courses;

  /// पूरा खाता बंद है या नहीं (एडमिन के हाथ में).
  final bool active;

  /// जिस फ़ोन पर यह आईडी दर्ज है. खाली हो तो अभी किसी पर नहीं.
  final String deviceId;

  const Entitlement({
    required this.uid,
    required this.name,
    required this.phone,
    required this.courses,
    required this.active,
    this.deviceId = '',
  });

  /// बिना सदस्यता वाला — सिर्फ़ मुफ़्त नमूना.
  static const Entitlement none = Entitlement(
    uid: '',
    name: '',
    phone: '',
    courses: <String, Course>{},
    active: false,
    deviceId: '',
  );

  /// जो परीक्षाएँ अभी चालू हैं.
  List<Course> get activeCourses {
    if (!active) return const <Course>[];
    final out = courses.values.where((c) => c.isActive).toList();
    // जिसकी तारीख़ पहले ख़त्म हो रही हो, वह ऊपर
    out.sort((a, b) => (a.expiresAt ?? DateTime(0))
        .compareTo(b.expiresAt ?? DateTime(0)));
    return out;
  }

  /// जो ख़रीदी तो थीं पर अवधि पूरी हो चुकी.
  List<Course> get expiredCourses {
    final out = courses.values.where((c) => !c.isActive).toList();
    out.sort((a, b) => (b.expiresAt ?? DateTime(0))
        .compareTo(a.expiresAt ?? DateTime(0)));
    return out;
  }

  List<String> get exams => activeCourses.map((c) => c.examId).toList();

  Course? courseFor(String examId) {
    final c = courses[examId];
    return (c != null && c.isActive && active) ? c : null;
  }

  /// यह आईडी किसी और फ़ोन पर दर्ज है.
  bool get boundElsewhere =>
      deviceId.isNotEmpty && DeviceId.ready && deviceId != DeviceId.id;

  /// अभी किसी फ़ोन पर दर्ज नहीं — पहला लॉगिन इसी को दर्ज कर लेगा.
  bool get unbound => deviceId.isEmpty;

  /// कम से कम एक परीक्षा चालू है.
  bool get isSubscribed => activeCourses.isNotEmpty;

  /// सबसे पहले ख़त्म होने वाली परीक्षा में कितने दिन बचे.
  int get daysLeft {
    final a = activeCourses;
    return a.isEmpty ? 0 : a.first.daysLeft;
  }

  bool get isExpiringSoon => isSubscribed && daysLeft <= 7;

  bool canAccessExam(String examId) => courseFor(examId) != null;

  /// प्रश्नपत्र की पहुँच — पेपर की id उसकी परीक्षा से शुरू होती है,
  /// इसलिए परीक्षा देखकर ही तय हो जाता है.
  bool canAccessPaper(String paperId) {
    for (final c in activeCourses) {
      if (paperId.startsWith('${c.examId}-')) return true;
    }
    return false;
  }

  static Entitlement fromDoc(String uid, Map<String, dynamic> m) {
    final courses = <String, Course>{};

    // नया रूप — हर परीक्षा की अपनी तारीख़
    final raw = m['courses'];
    if (raw is Map) {
      raw.forEach((k, v) {
        if (v is Map) {
          final e = v['expiresAt'];
          courses['$k'] = Course(
            examId: '$k',
            expiresAt: e is Timestamp ? e.toDate() : null,
          );
        }
      });
    }

    // पुराना रूप — `exams` सूची और एक साझा `expiresAt`.
    // पुराने खाते वैसे ही चलते रहें, इसलिए उन्हें यहीं बदल लेते हैं.
    if (courses.isEmpty) {
      final exp = m['expiresAt'];
      final at = exp is Timestamp ? exp.toDate() : null;
      for (final e in (m['exams'] as List?) ?? const []) {
        courses['$e'] = Course(examId: '$e', expiresAt: at);
      }
    }

    return Entitlement(
      uid: uid,
      name: '${m['name'] ?? ''}',
      phone: '${m['phone'] ?? ''}',
      courses: courses,
      active: m['active'] == true,
      deviceId: '${m['deviceId'] ?? ''}',
    );
  }
}

/// लॉगिन और सदस्यता — एक ही जगह.
///
/// ज़रूरी: Firebase न जुड़ा हो (ऑफ़लाइन APK, google-services.json नदारद) तो
/// यह चुपचाप "मेहमान" मोड में चला जाता है, ताकि ऐप पहले जैसी ही चलती रहे.
class Session {
  static Entitlement entitlement = Entitlement.none;
  static User? user;

  static final StreamController<Entitlement> _stream =
      StreamController<Entitlement>.broadcast();

  /// सदस्यता बदलने पर UI को बताने के लिए.
  static Stream<Entitlement> get onChange => _stream.stream;

  static StreamSubscription<User?>? _authSub;
  static StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _docSub;

  /// किस उपयोगकर्ता का सदस्यता-doc आ चुका है.
  ///
  /// सिर्फ़ "आया या नहीं" रखना काफ़ी नहीं था — ऐप खुलते ही `_onUser(null)`
  /// चलता है और उसे "आ गया" मान लिया जाता था. फिर लॉगिन के बाद इंतज़ार
  /// वाला हिस्सा तुरंत लौट आता था, सदस्यता आने से पहले ही. इसीलिए अब
  /// uid के साथ रखते हैं — तभी पता चलता है कि जवाब *इसी* उपयोगकर्ता का है.
  static String? _loadedUid;

  /// अभी वाले उपयोगकर्ता का doc आ चुका है या नहीं.
  static bool get docLoaded {
    final uid = user?.uid;
    return uid == null ? _loadedUid == '' : _loadedUid == uid;
  }

  /// doc पढ़ने में गड़बड़ी हुई हो तो उसकी वजह.
  static String? docError;

  /// असली एरर, जैसा Firestore ने दिया — गड़बड़ी ढूँढ़ने के लिए स्क्रीन पर
  /// दिखा देते हैं. सब ठीक चलने लगे तो यह हिस्सा हटाया जा सकता है.
  static String? docErrorRaw;

  /// अब तक क्या-क्या हुआ — लॉगिन के बाद अटकने पर यही बताता है कि कहाँ रुके.
  static final List<String> trace = <String>[];

  static void _note(String s) {
    trace.add(s);
    if (trace.length > 12) trace.removeAt(0);
  }

  static bool get isLoggedIn => user != null;
  static bool get isSubscribed => entitlement.isSubscribed;

  /// Firebase जुड़ा है या नहीं — `QuestionRepo.firebaseReady` से ही तय होता है.
  static bool get available => QuestionRepo.firebaseReady;

  static Future<void> init() async {
    if (!available) return;

    try {
      _authSub = FirebaseAuth.instance.authStateChanges().listen(_onUser);
      // पहली बार तुरंत पढ़ लें, stream के पहले event का इंतज़ार किए बिना
      _onUser(FirebaseAuth.instance.currentUser);
    } catch (_) {
      // Firebase Auth शुरू न हो पाए तो मेहमान मोड
    }
  }

  static void _onUser(User? u) {
    user = u;
    _docSub?.cancel();
    _docSub = null;
    _loadedUid = null;
    docError = null;

    if (u == null) {
      _loadedUid = '';
      _set(Entitlement.none);
      return;
    }

    // सदस्यता का doc लगातार सुनते हैं — एडमिन एक्सपायरी बदले या
    // active=false करे, तो ऐप में तुरंत असर दिखे.
    _docSub = FirebaseFirestore.instance
        .collection('users')
        .doc(u.uid)
        .snapshots()
        .listen(
      (snap) {
        _loadedUid = u.uid;
        docError = null;
        docErrorRaw = null;
        final data = snap.data();
        _note(data == null
            ? 'doc आया पर ख़ाली (users/${u.uid} बना ही नहीं?)'
            : 'doc आया: active=${data['active']} expires=${data['expiresAt']}');
        _set(data == null
            ? Entitlement.none
            : Entitlement.fromDoc(u.uid, data));
      },
      onError: (e) {
        _loadedUid = u.uid;
        docErrorRaw = '$e';
        // सबसे आम वजह: Firestore के नियम अभी लगे ही नहीं हैं
        docError = '$e'.contains('permission-denied')
            ? 'permission-denied'
            : 'unavailable';
        _note('doc एरर: $docError');
        _set(Entitlement.none);
      },
    );
  }

  /// लॉगिन के तुरंत बाद सदस्यता आने का इंतज़ार.
  ///
  /// तय समय तक रुकने के बजाय पहला जवाब आते ही लौट आता है — धीमे नेटवर्क पर
  /// भी सही काम करता है, और तेज़ नेटवर्क पर बेकार रुकता नहीं.
  static Future<void> awaitEntitlement({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (!available) return;

    // सीधे Firebase से पूछते हैं, `user` से नहीं — authStateChanges थोड़ा
    // बाद में चलता है, और तब तक `user` पुराना (या null) हो सकता है.
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _note('इंतज़ार: currentUser null है');
      return;
    }
    if (_loadedUid == uid) {
      _note('इंतज़ार: doc पहले से आया हुआ');
      return;
    }

    _note('इंतज़ार शुरू — uid ${uid.substring(0, 6)}…');

    // NOTE: पहले यहाँ stream के एक event का इंतज़ार था, और वही गड़बड़ी की जड़
    // निकला. Firestore doc कैश से इतनी जल्दी आ जाता है कि event अक्सर हमारे
    // सुनने से पहले ही निकल चुका होता था — broadcast stream पुराने event
    // दोबारा नहीं देता, इसलिए इंतज़ार पूरे 15 सेकंड चलकर नाकाम होता था.
    // अब हालत को बार-बार देखते हैं, जिससे event छूटने का सवाल ही नहीं रहता.
    final deadline = DateTime.now().add(timeout);
    while (_loadedUid != uid && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    _note(_loadedUid == uid
        ? 'इंतज़ार पूरा'
        : 'इंतज़ार में समय निकल गया (${timeout.inSeconds}s)');
  }

  static void _set(Entitlement e) {
    entitlement = e;
    if (!_stream.isClosed) _stream.add(e);
  }

  /// ग़लत होने पर हिंदी में वजह लौटाता है, सही होने पर null.
  static Future<String?> signIn(String userId, String password) async {
    if (!available) return 'अभी इंटरनेट या सर्वर से जुड़ नहीं पाए।';

    final email = _toEmail(userId);
    try {
      await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password)
          .timeout(const Duration(seconds: 20));
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'invalid-email':
        case 'user-not-found':
          return 'यह आईडी मिली नहीं। दोबारा जाँच लें।';
        case 'wrong-password':
        case 'invalid-credential':
          return 'आईडी या पासवर्ड ग़लत है।';
        case 'user-disabled':
          return 'यह आईडी बंद कर दी गई है। हमें मैसेज कीजिए।';
        case 'too-many-requests':
          return 'बहुत बार कोशिश हो गई। थोड़ी देर बाद फिर से।';
        case 'network-request-failed':
          return 'इंटरनेट से जुड़ नहीं पाए।';
        default:
          return 'लॉगिन नहीं हो पाया। दोबारा कोशिश करें।';
      }
    } on TimeoutException {
      return 'सर्वर से जवाब नहीं आया। दोबारा कोशिश करें।';
    } catch (_) {
      return 'लॉगिन नहीं हो पाया। दोबारा कोशिश करें।';
    }
  }

  /// इस फ़ोन को सदस्यता में दर्ज कर देता है — सिर्फ़ पहली बार.
  ///
  /// नियम सर्वर पर भी लगे हैं: यह लिखाई तभी मानी जाती है जब `deviceId`
  /// अभी खाली हो, और सिर्फ़ यही तीन फ़ील्ड बदल सकते हैं. इसलिए ऐप बदलकर
  /// भी कोई अपनी एक्सपायरी आगे नहीं खिसका सकता, न किसी और का फ़ोन छुड़ा सकता.
  ///
  /// सही होने पर null, वरना हिंदी में वजह.
  static Future<String?> _bindDevice() async {
    if (!DeviceId.ready) return null; // पहचान ही न बनी तो रोकते नहीं

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    // फ़ैसला हमेशा सर्वर वाले doc पर हो, कैश वाले पर नहीं.
    //
    // `_onUser` का listener पहला snapshot Firestore के लोकल कैश से देता है,
    // और `awaitEntitlement` उसी पहले जवाब पर लौट आता है. नतीजा यह था कि
    // एडमिन फ़ोन छुड़ा देता (subscriptions.js `deviceId` हटा देता है), फिर भी
    // छात्र के फ़ोन में पुराना deviceId पड़ा रहता और नीचे वाली जाँच उसे
    // "किसी और फ़ोन पर चल रही है" कहकर रोक देती. ऐप का डेटा मिटाए बिना वह
    // कभी अंदर आ ही नहीं पाता था.
    //
    // इसलिए दर्ज करने से ठीक पहले एक बार सर्वर से ताज़ा doc माँगते हैं.
    // पूरे लॉगिन में सिर्फ़ एक अतिरिक्त read — इतना सस्ता सौदा है.
    var e = entitlement;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 12));

      final data = snap.data();
      if (data != null) {
        e = Entitlement.fromDoc(uid, data);
        _loadedUid = uid;
        _set(e);
        _note('ताज़ा doc आया: फ़ोन ${e.unbound ? "दर्ज नहीं" : "दर्ज है"}');
      }
    } catch (err) {
      // इंटरनेट न हो तो कैश वाले doc से ही काम चलाते हैं. यहाँ रुकना ग़लत
      // होगा — सही सदस्य भी सिर्फ़ नेटवर्क की वजह से बाहर रह जाएगा.
      _note('ताज़ा doc नहीं मिला: $err');
    }

    if (e.boundElsewhere) {
      return 'यह आईडी पहले से किसी और फ़ोन पर चल रही है। '
          'फ़ोन बदला हो तो हमें बताइए, हम छुड़ा देंगे।';
    }
    if (!e.unbound) return null; // इसी फ़ोन पर पहले से दर्ज है

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'deviceId': DeviceId.id,
        'deviceName': DeviceId.name,
        'deviceBoundAt': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 15));
      _note('फ़ोन दर्ज हुआ: ${DeviceId.name}');
      return null;
    } catch (err) {
      _note('फ़ोन दर्ज नहीं हुआ: $err');
      // दर्ज न हो पाना लॉगिन रोकने की वजह नहीं — इंटरनेट की दिक़्क़त भी
      // हो सकती है. अगली बार दोबारा कोशिश हो जाएगी.
      return null;
    }
  }

  /// लॉगिन के बाद फ़ोन की जाँच — बाहर से बुलाने के लिए.
  static Future<String?> checkDevice() => _bindDevice();

  static Future<void> signOut() async {
    if (!available) return;
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    _set(Entitlement.none);
  }

  /// उपयोगकर्ता सिर्फ़ आईडी टाइप करता है (जैसे `ro2401`), Firebase को
  /// ईमेल चाहिए — इसलिए पीछे से डोमेन जोड़ देते हैं. अगर उसने पूरा ईमेल
  /// डाला हो तो वैसा ही रहने देते हैं.
  static String _toEmail(String userId) {
    final id = userId.trim().toLowerCase();
    return id.contains('@') ? id : '$id@prashnreel.app';
  }

  static Future<void> dispose() async {
    await _authSub?.cancel();
    await _docSub?.cancel();
  }
}
