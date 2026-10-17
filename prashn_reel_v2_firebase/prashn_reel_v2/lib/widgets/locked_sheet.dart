import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../build_flags.dart';
import '../exams.dart';
import '../models.dart';
import '../screens/login_page.dart';
import 'exam_thumb.dart';

/// आईडी देने वाले admin का नंबर — ताले वाले course पर यही दिखता है.
const String kAdminPhone = '8299361252';

/// ताले वाले course को छूने पर — "यह आईडी-पासवर्ड से खुलेगा".
///
/// ── दो build, दो बर्ताव ──
///
/// Direct APK में admin का नंबर, फ़ोन करने और WhatsApp के बटन दिखते हैं.
/// Play build में नंबर **नहीं** — वहाँ ऐप के बाहर पैसे देकर course खोलने
/// की तरफ़ इशारा करना भी Play की Payments नीति के ख़िलाफ़ है (build_flags.dart).
/// वहाँ बस बताया जाता है कि course आईडी-पासवर्ड से खुलता है, और लॉगिन का बटन.
///
/// लॉगिन सफल हुआ तो true लौटता है.
Future<bool> showLockedCourse(BuildContext context, Exam exam) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: P.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _LockedSheet(exam: exam),
  );
  return ok ?? false;
}

class _LockedSheet extends StatelessWidget {
  final Exam exam;
  const _LockedSheet({required this.exam});

  Future<void> _open(BuildContext context, String url) async {
    final ok = await launchUrl(Uri.parse(url),
        mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      await Clipboard.setData(const ClipboardData(text: kAdminPhone));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('नंबर कॉपी हो गया — $kAdminPhone'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final look = lookOf(exam.id);
    final col = look.colors.first;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: P.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Center(
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: look.colors),
                ),
                child: const Center(
                  child: FaIcon(FontAwesomeIcons.lock,
                      size: 22, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '${look.code} — locked',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 19, fontWeight: FontWeight.w800, color: col),
            ),
            const SizedBox(height: 6),
            Text(
              kIsPlayBuild
                  ? 'यह course आईडी-पासवर्ड से खुलता है। आईडी है तो लॉगिन कीजिए।'
                  : 'यह course आईडी-पासवर्ड से ही खुलेगा।\nआईडी के लिए Admin से संपर्क कीजिए।',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, height: 1.5, color: P.muted),
            ),

            if (!kIsPlayBuild) ...[
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: P.bg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: P.line),
                ),
                child: Row(
                  children: [
                    const FaIcon(FontAwesomeIcons.userShield,
                        size: 16, color: P.brand),
                    const SizedBox(width: 11),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Contact Admin',
                              style: TextStyle(
                                  fontSize: 12.5, color: P.muted)),
                          Text('+91 $kAdminPhone',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5)),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'कॉपी',
                      onPressed: () async {
                        await Clipboard.setData(
                            const ClipboardData(text: kAdminPhone));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('नंबर कॉपी हो गया')));
                      },
                      icon: const FaIcon(FontAwesomeIcons.copy,
                          size: 15, color: P.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _open(context, 'tel:$kAdminPhone'),
                      style: FilledButton.styleFrom(
                        backgroundColor: P.brand,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const FaIcon(FontAwesomeIcons.phone, size: 14),
                      label: const Text('कॉल करें',
                          style: TextStyle(
                              fontSize: 14.5, fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _open(context,
                          'https://wa.me/91$kAdminPhone?text=${Uri.encodeComponent('नमस्ते, मुझे ब्रह्मास्त्र में ${look.code} की आईडी चाहिए।')}'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1E8E4E),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 16),
                      label: const Text('WhatsApp',
                          style: TextStyle(
                              fontSize: 14.5, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                final ok = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
                if (ok == true && context.mounted) {
                  Navigator.of(context).pop(true);
                }
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: P.brand,
                side: BorderSide(color: P.brand.withOpacity(0.4)),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const FaIcon(FontAwesomeIcons.rightToBracket, size: 14),
              label: const Text('आईडी है? लॉगिन करें',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}
