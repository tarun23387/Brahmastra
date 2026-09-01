import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../auth.dart';
import '../models.dart';
import 'forgot_password_sheet.dart';

/// आईडी और पासवर्ड से लॉगिन.
///
/// आईडी वही है जो एडमिन पैनल से बनी थी — जैसे `ro2601`. पूरा ईमेल
/// टाइप करने की ज़रूरत नहीं, पीछे से अपने आप जुड़ जाता है.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _id = TextEditingController();
  final _pass = TextEditingController();
  final _idFocus = FocusNode();

  bool _busy = false;
  bool _showPass = false;
  String? _error;

  @override
  void dispose() {
    _id.dispose();
    _pass.dispose();
    _idFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final id = _id.text.trim();
    final pass = _pass.text;

    if (id.isEmpty || pass.isEmpty) {
      setState(() => _error = 'आईडी और पासवर्ड दोनों भरिए।');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final err = await Session.signIn(id, pass);

    if (err != null) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = err;
      });
      return;
    }

    // सदस्यता का doc आने तक रुकते हैं — तय समय तक नहीं, जवाब आने तक
    await Session.awaitEntitlement();
    if (!mounted) return;
    setState(() => _busy = false);

    // सदस्यता ठीक है — अब देखें कि यह आईडी किसी और फ़ोन पर तो नहीं चल रही
    if (Session.entitlement.isSubscribed) {
      final deviceErr = await Session.checkDevice();
      if (!mounted) return;
      if (deviceErr != null) {
        setState(() => _error = deviceErr);
        await Session.signOut();
        return;
      }
    }

    if (Session.entitlement.isSubscribed) {
      // सिर्फ़ यह पन्ना बंद करना काफ़ी नहीं — पीछे भुगतान, परीक्षा और पहला
      // पन्ना भी खड़े हैं. सबको हटाकर जड़ तक लौटते हैं, जहाँ AppGate अब
      // सदस्यता देखकर सीधे प्रश्न दिखाएगा.
      Navigator.of(context).popUntil((r) => r.isFirst);
      return;
    }

    // यहाँ पहुँचे तो लॉगिन तो हुआ पर सदस्यता नहीं मिली — वजह अलग-अलग हो
    // सकती है, इसलिए संदेश भी अलग होना चाहिए.
    late String msg;
    if (!Session.docLoaded) {
      msg = 'सदस्यता की जानकारी नहीं आ पाई। इंटरनेट जाँचकर दोबारा कोशिश कीजिए।';
    } else if (Session.docError == 'permission-denied') {
      msg = 'सर्वर की सेटिंग अधूरी है — यह हमारी तरफ़ की गड़बड़ी है। '
          'हमें मैसेज कीजिए।';
    } else if (Session.docError != null) {
      msg = 'सर्वर से जुड़ नहीं पाए। थोड़ी देर बाद दोबारा कोशिश कीजिए।';
    } else if (Session.entitlement.uid.isEmpty) {
      msg = 'इस आईडी पर कोई सदस्यता दर्ज नहीं है। हमें मैसेज कीजिए।';
    } else if (!Session.entitlement.active) {
      msg = 'यह सदस्यता बंद कर दी गई है। दोबारा लेने के लिए हमें मैसेज कीजिए।';
    } else {
      msg = 'आपकी सदस्यता खत्म हो गई है। दोबारा लेने के लिए हमें मैसेज कीजिए।';
    }

    setState(() => _error = msg);

    // असली समाप्ति पर ही बाहर करते हैं. नेटवर्क या सेटिंग की गड़बड़ी में
    // लॉगिन बना रहने देते हैं, ताकि ठीक होते ही अपने आप चल पड़े.
    if (Session.docLoaded && Session.docError == null) {
      await Session.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: P.bg,
      appBar: AppBar(
        backgroundColor: P.card,
        surfaceTintColor: P.card,
        elevation: 0,
        title: const Text('लॉगिन',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 66,
                  height: 66,
                  decoration: BoxDecoration(
                    color: P.brand.withOpacity(0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: FaIcon(FontAwesomeIcons.rightToBracket,
                        size: 26, color: P.brand),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'अपनी आईडी से लॉगिन कीजिए',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'पैसे भेजने के बाद जो आईडी-पासवर्ड मिला था, वही डालिए।',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: P.muted, height: 1.5),
              ),
              const SizedBox(height: 26),

              _label('आईडी'),
              TextField(
                controller: _id,
                focusNode: _idFocus,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.next,
                decoration: _box('जैसे  ro2601'),
                onSubmitted: (_) => FocusScope.of(context).nextFocus(),
              ),

              const SizedBox(height: 14),
              _label('पासवर्ड'),
              TextField(
                controller: _pass,
                obscureText: !_showPass,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.done,
                decoration: _box('पासवर्ड').copyWith(
                  suffixIcon: IconButton(
                    tooltip: _showPass ? 'छिपाएँ' : 'दिखाएँ',
                    icon: FaIcon(
                      _showPass
                          ? FontAwesomeIcons.eyeSlash
                          : FontAwesomeIcons.eye,
                      size: 16,
                      color: P.muted,
                    ),
                    onPressed: () => setState(() => _showPass = !_showPass),
                  ),
                ),
                onSubmitted: (_) => _submit(),
              ),

              if (_error != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: P.wrong.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: P.wrong.withOpacity(0.25)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const FaIcon(FontAwesomeIcons.circleExclamation,
                          size: 14, color: P.wrong),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(_error!,
                            style: const TextStyle(
                                fontSize: 13, color: P.wrong, height: 1.45)),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 22),
              FilledButton(
                onPressed: _busy ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: P.brand,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13)),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.2, color: Colors.white),
                      )
                    : const Text('लॉगिन करें',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w800)),
              ),

              const SizedBox(height: 14),

              // छूने लायक — पहले यह सिर्फ़ लिखा हुआ वाक्य था, और उसमें
              // "जिस नंबर से पैसे भेजे थे" भी था. Play वाली build में पैसे की
              // तरफ़ इशारा तक नहीं जा सकता, इसलिए वह वाक्य अब भीतर वाले पन्ने
              // में है और वहाँ build के हिसाब से बदल जाता है.
              //
              // आईडी साथ भेजते हैं ताकि छात्र को दोबारा न पूछना पड़े — यही
              // अब तक की सबसे बड़ी अड़चन थी.
              Center(
                child: TextButton(
                  onPressed: _busy
                      ? null
                      : () => showForgotPasswordSheet(
                            context,
                            userId: _id.text,
                          ),
                  style: TextButton.styleFrom(
                    foregroundColor: P.brand,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                  ),
                  child: const Text(
                    'पासवर्ड भूल गए?',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6, left: 2),
        child: Text(t,
            style: TextStyle(
                fontSize: 12.5, color: P.muted, fontWeight: FontWeight.w700)),
      );

  InputDecoration _box(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: P.muted.withOpacity(0.6), fontSize: 14),
        filled: true,
        fillColor: P.card,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: P.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: P.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: P.brand, width: 1.6),
        ),
      );
}
