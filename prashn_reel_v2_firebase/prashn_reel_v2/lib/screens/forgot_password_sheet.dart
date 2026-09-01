import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../app_config.dart';
import '../build_flags.dart';
import '../models.dart';

/// "पासवर्ड भूल गए?" — छात्र को क्या करना है, एक ही जगह.
///
/// ── अपने आप reset क्यों नहीं होता ──
///
/// आम तरीक़ा Firebase का `sendPasswordResetEmail` है, पर यहाँ वह बेकार है:
/// लॉगिन की ईमेल असली नहीं होती. `auth.dart` का `_toEmail` छात्र की आईडी
/// `pt2601` को `pt2601@prashnreel.app` बना देता है — वह पता सिर्फ़ Firebase
/// को ख़ुश करने के लिए है, उस पर कोई डाकख़ाना नहीं. मेल भेजी तो कहीं नहीं
/// पहुँचेगी.
///
/// असली ईमेल या OTP वाला रास्ता Cloud Functions / Phone Auth माँगता है, और
/// दोनों Blaze plan चाहते हैं. प्रोजेक्ट अभी Spark पर है, इसलिए reset एडमिन
/// के हाथ से होता है: `node subscriptions.js reset-password <आईडी>`.
///
/// ── तो यह पन्ना करता क्या है ──
///
/// छात्र की मेहनत घटाता है. पहले वह सिर्फ़ "पासवर्ड भूल गया" लिखता था और
/// एडमिन को पूछना पड़ता था "आपकी आईडी क्या है?" — एक चक्कर बेकार जाता था.
/// अब आईडी समेत पूरा मैसेज बना-बनाया मिलता है, बस चिपकाकर भेजना है.
void showForgotPasswordSheet(BuildContext context, {required String userId}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: P.card,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _ForgotPasswordSheet(userId: userId.trim()),
  );
}

class _ForgotPasswordSheet extends StatelessWidget {
  final String userId;

  const _ForgotPasswordSheet({required this.userId});

  /// छात्र जो मैसेज भेजेगा — आईडी पहले से भरी हुई.
  String get _message {
    final id = userId.isEmpty ? '(अपनी आईडी यहाँ लिखिए)' : userId;
    return 'नमस्ते, मेरा पासवर्ड भूल गया हूँ।\nमेरी आईडी: $id\nकृपया नया पासवर्ड भेज दीजिए।';
  }

  void _copy(BuildContext context, String value, String what) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        duration: const Duration(seconds: 2),
        content: Text('$what कॉपी हो गया'),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final phone = AppConfig.phone;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 18,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: P.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              'पासवर्ड भूल गए?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),

            // Play वाली build में पैसे का कोई ज़िक्र नहीं — वहाँ ऐप के बाहर
            // ख़रीदने की तरफ़ इशारा करना भी नीति के ख़िलाफ़ है, सिर्फ़ बटन नहीं.
            const Text(
              kIsPlayBuild
                  ? 'कोई बात नहीं। नीचे वाला मैसेज हमें भेज दीजिए, नया पासवर्ड भेज देंगे।'
                  : 'कोई बात नहीं। नीचे वाला मैसेज उसी नंबर से भेजिए जिससे आपने संपर्क किया था — नया पासवर्ड भेज देंगे।',
              style: TextStyle(fontSize: 13, color: P.muted, height: 1.5),
            ),
            const SizedBox(height: 18),

            _Block(
              icon: FontAwesomeIcons.commentDots,
              label: 'यह मैसेज भेजिए',
              value: _message,
              onCopy: () => _copy(context, _message, 'मैसेज'),
            ),

            if (phone.isNotEmpty) ...[
              const SizedBox(height: 12),
              _Block(
                icon: FontAwesomeIcons.phone,
                label: 'इस नंबर पर',
                value: phone,
                onCopy: () => _copy(context, phone, 'नंबर'),
              ),
            ],

            const SizedBox(height: 16),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FaIcon(FontAwesomeIcons.circleInfo, size: 12, color: P.muted),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'नया पासवर्ड मिलने के बाद पुराना काम नहीं करेगा।',
                    style: TextStyle(fontSize: 12, color: P.muted, height: 1.45),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: P.brand,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                child: const Text(
                  'ठीक है',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// एक जानकारी + उसे कॉपी करने का बटन.
class _Block extends StatelessWidget {
  final FaIconData icon;
  final String label;
  final String value;
  final VoidCallback onCopy;

  const _Block({
    required this.icon,
    required this.label,
    required this.value,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: P.bg,
        border: Border.all(color: P.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: FaIcon(icon, size: 13, color: P.muted),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: P.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  value,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'कॉपी',
            icon: const FaIcon(FontAwesomeIcons.copy, size: 15, color: P.brand),
            onPressed: onCopy,
          ),
        ],
      ),
    );
  }
}
