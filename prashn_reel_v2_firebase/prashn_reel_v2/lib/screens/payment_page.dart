import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../app_config.dart';
import '../exams.dart';
import '../models.dart';
import 'login_page.dart';

/// भुगतान का पन्ना — UPI आईडी, फ़ोन और ईमेल दिखाता है.
///
/// ये तीनों Firestore के `config/contact` doc से आते हैं, ऐप में लिखे नहीं हैं.
/// इसलिए नंबर या UPI बदलना हो तो नया APK बाँटने की ज़रूरत नहीं.
class PaymentPage extends StatelessWidget {
  final Exam exam;

  const PaymentPage({super.key, required this.exam});

  static const _gold = P.gold;

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
    final price = AppConfig.priceMonthly;

    return Scaffold(
      backgroundColor: P.bg,
      appBar: AppBar(
        backgroundColor: P.card,
        surfaceTintColor: P.card,
        elevation: 0,
        title: const Text('भुगतान',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        leading: IconButton(
          icon: const FaIcon(FontAwesomeIcons.arrowLeft, size: 17),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── कितना, किसके लिए ──
              Container(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                decoration: BoxDecoration(
                  color: P.card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _gold.withOpacity(0.28)),
                ),
                child: Column(
                  children: [
                    const FaIcon(FontAwesomeIcons.crown,
                        size: 22, color: _gold),
                    const SizedBox(height: 10),
                    Text(exam.shortLabel,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text('₹$price',
                        style: const TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.w800,
                            height: 1.05,
                            color: _gold)),
                    Text('एक महीने के लिए',
                        style: TextStyle(fontSize: 13, color: P.muted)),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── तीन चरण ──
              const _StepHead(n: '1', text: 'नीचे वाली UPI आईडी पर पैसे भेजिए'),
              const SizedBox(height: 10),

              if (AppConfig.upiId.isNotEmpty)
                _CopyRow(
                  icon: FontAwesomeIcons.indianRupeeSign,
                  label: 'UPI आईडी',
                  value: AppConfig.upiId,
                  onCopy: () => _copy(context, AppConfig.upiId, 'UPI आईडी'),
                )
              else
                const _Missing(what: 'UPI आईडी'),

              const SizedBox(height: 18),
              const _StepHead(
                  n: '2', text: 'भुगतान का स्क्रीनशॉट भेजिए'),
              const SizedBox(height: 10),

              if (AppConfig.phone.isNotEmpty)
                _CopyRow(
                  icon: FontAwesomeIcons.whatsapp,
                  label: 'व्हाट्सऐप',
                  value: AppConfig.phone,
                  onCopy: () => _copy(context, AppConfig.phone, 'नंबर'),
                )
              else
                const _Missing(what: 'फ़ोन नंबर'),

              const SizedBox(height: 8),

              if (AppConfig.email.isNotEmpty)
                _CopyRow(
                  icon: FontAwesomeIcons.envelope,
                  label: 'ईमेल',
                  value: AppConfig.email,
                  onCopy: () => _copy(context, AppConfig.email, 'ईमेल'),
                ),

              const SizedBox(height: 18),
              const _StepHead(
                  n: '3', text: 'आईडी और पासवर्ड मिलते ही लॉगिन कीजिए'),
              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: P.card,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: P.line),
                ),
                child: Text(
                  'स्क्रीनशॉट देखकर हम आपको आईडी और पासवर्ड भेज देंगे। '
                  'उससे लॉगिन कीजिए, पूरे प्रश्न खुल जाएँगे — एक महीने तक।',
                  style: TextStyle(
                      fontSize: 13, color: P.muted, height: 1.55),
                ),
              ),

              if (AppConfig.note.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(AppConfig.note,
                    style: TextStyle(
                        fontSize: 12.5, color: P.muted, height: 1.5)),
              ],

              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                  );
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: P.line),
                  foregroundColor: P.brand,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13)),
                ),
                icon: const FaIcon(FontAwesomeIcons.rightToBracket, size: 15),
                label: const Text('आईडी मिल गई? लॉगिन कीजिए',
                    style:
                        TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepHead extends StatelessWidget {
  final String n;
  final String text;
  const _StepHead({required this.n, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 23,
          height: 23,
          decoration: const BoxDecoration(
              color: P.brand, shape: BoxShape.circle),
          child: Center(
            child: Text(n,
                style: const TextStyle(
                    color: P.card,
                    fontSize: 12,
                    fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, height: 1.35)),
        ),
      ],
    );
  }
}

class _CopyRow extends StatelessWidget {
  final FaIconData icon;
  final String label;
  final String value;
  final VoidCallback onCopy;

  const _CopyRow({
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
        color: P.card,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: P.line),
      ),
      child: Row(
        children: [
          FaIcon(icon, size: 15, color: P.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    style: TextStyle(fontSize: 11.5, color: P.muted)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        height: 1.25)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'कॉपी करें',
            onPressed: onCopy,
            icon: const FaIcon(FontAwesomeIcons.copy,
                size: 15, color: P.brand),
          ),
        ],
      ),
    );
  }
}

/// config में जानकारी न भरी हो तो साफ़-साफ़ बता देते हैं,
/// खाली जगह छोड़ने से बेहतर है.
class _Missing extends StatelessWidget {
  final String what;
  const _Missing({required this.what});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: P.wrong.withOpacity(0.07),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: P.wrong.withOpacity(0.22)),
      ),
      child: Row(
        children: [
          const FaIcon(FontAwesomeIcons.circleExclamation,
              size: 14, color: P.wrong),
          const SizedBox(width: 10),
          Expanded(
            child: Text('$what अभी सेट नहीं हुई — हमें मैसेज कीजिए।',
                style: const TextStyle(
                    fontSize: 13, color: P.wrong, height: 1.4)),
          ),
        ],
      ),
    );
  }
}
