import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'repository.dart';

/// संपर्क और भुगतान की जानकारी — Firestore के `config/contact` doc से आती है.
///
/// ऐप में हार्डकोड नहीं की गई, ताकि UPI आईडी या फ़ोन नंबर बदलना हो तो
/// नया APK बनाकर सबको भेजना न पड़े — Firestore में बदलिए, सबको दिख जाएगा.
///
/// एक बार पढ़कर फ़ोन में सेव कर लेते हैं, ताकि बिना इंटरनेट भी दिखे.
class AppConfig {
  static const _cacheKey = 'config_contact_v1';

  static String upiId = '';
  static String phone = '';
  static String email = '';
  static int priceMonthly = 100;
  static String note = '';

  static bool get isReady => upiId.isNotEmpty || phone.isNotEmpty;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    // पहले सेव की हुई जानकारी — ताकि स्क्रीन तुरंत भर जाए
    final cached = prefs.getStringList(_cacheKey);
    if (cached != null && cached.length >= 5) {
      upiId = cached[0];
      phone = cached[1];
      email = cached[2];
      priceMonthly = int.tryParse(cached[3]) ?? 100;
      note = cached[4];
    }

    if (!QuestionRepo.firebaseReady) return;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('config')
          .doc('contact')
          .get()
          .timeout(const Duration(seconds: 10));

      final m = snap.data();
      if (m == null) return;

      upiId = '${m['upiId'] ?? upiId}';
      phone = '${m['phone'] ?? phone}';
      email = '${m['email'] ?? email}';
      priceMonthly = (m['priceMonthly'] as num?)?.toInt() ?? priceMonthly;
      note = '${m['note'] ?? note}';

      await prefs.setStringList(_cacheKey, [
        upiId,
        phone,
        email,
        '$priceMonthly',
        note,
      ]);
    } catch (_) {
      // न मिले तो सेव की हुई जानकारी से ही काम चलेगा
    }
  }

  /// UPI ऐप सीधे खोलने के लिए लिंक.
  static String upiLink({String? name, int? amount}) {
    final amt = amount ?? priceMonthly;
    final pn = Uri.encodeComponent(name ?? 'Prashn Reel');
    return 'upi://pay?pa=$upiId&pn=$pn&am=$amt&cu=INR';
  }
}
