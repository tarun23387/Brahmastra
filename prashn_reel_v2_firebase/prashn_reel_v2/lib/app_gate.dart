import 'dart:async';

import 'package:flutter/material.dart';

import 'auth.dart';
import 'exams.dart';
import 'home_page.dart';
import 'models.dart';
import 'screens/dashboard_page.dart';
import 'screens/landing_page.dart';

/// तय करता है कि कौन-सा पन्ना दिखे.
///
/// नियम:
///   • Firebase न जुड़ा हो        → सीधे प्रश्न (ऐप पहले जैसी ही चले)
///   • सदस्यता हो                → डैशबोर्ड, वहाँ से प्रश्नपत्र चुनकर प्रश्न
///   • नमूना चुना हो             → प्रश्न, पर सिर्फ़ मुफ़्त वाले
///   • बाक़ी सब                  → पहला पन्ना (दो कार्ड)
class AppGate extends StatefulWidget {
  const AppGate({super.key});

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> {
  StreamSubscription<Entitlement>? _sub;

  /// उपयोगकर्ता ने "मुफ़्त नमूना" दबाया है.
  bool _sampleMode = false;

  /// सदस्य अभी प्रश्न हल कर रहा है या डैशबोर्ड पर है.
  bool _practising = false;

  /// क्या छाँटकर हल कर रहा है — null मतलब सब कुछ.
  String? _paperId;
  String? _subject;

  @override
  void initState() {
    super.initState();
    _sub = Session.onChange.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  /// प्रश्नों की स्क्रीन के ऊपर क्या लिखा दिखे.
  String? get _practiceLabel {
    if (_paperId == null) return null;
    final p = kPapers[_paperId];
    if (p == null) return null;
    if (_subject == null) return p.label;
    return '${p.label} · ${subjectOf(_subject!).label}';
  }

  void _practise(String? paperId, String? subject) {
    setState(() {
      _paperId = paperId;
      _subject = subject;
      _practising = true;
    });
  }

  Future<void> _signOut() async {
    await Session.signOut();
    if (!mounted) return;
    setState(() {
      _sampleMode = false;
      _practising = false;
      _paperId = null;
      _subject = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Firebase ही न हो तो पुराना बर्ताव — बंडल प्रश्नों के साथ सीधे चलिए
    if (!Session.available) return const HomePage();

    if (Session.isSubscribed) {
      if (!_practising) {
        return DashboardPage(
          onPractise: (p, s) => _practise(p, s),
          onPractiseAll: () => _practise(null, null),
          onFreeSample: () => setState(() {
            _sampleMode = true;
            _practising = true;
          }),
          onSignOut: _signOut,
        );
      }

      return HomePage(
        // नमूना डैशबोर्ड से भी खोला जा सकता है
        freeOnly: _sampleMode,
        paperId: _sampleMode ? null : _paperId,
        subject: _sampleMode ? null : _subject,
        practiceLabel: _sampleMode ? 'UPPET Exam' : _practiceLabel,
        onExit: () => setState(() {
          _practising = false;
          _sampleMode = false;
        }),
        onSignOut: _signOut,
      );
    }

    if (_sampleMode) {
      return HomePage(
        freeOnly: true,
        practiceLabel: 'UPPET Exam',
        onExit: () => setState(() => _sampleMode = false),
      );
    }

    return LandingPage(
      onFreeSample: () => setState(() => _sampleMode = true),
      onLoggedIn: () => setState(() {
        _sampleMode = false;
        _practising = false;
      }),
    );
  }
}

/// लॉगिन/सदस्यता आने तक थोड़ी देर के लिए.
///
/// यह पन्ना जान-बूझकर native launch screen की नक़ल है — वही क्रीम रंग, वही
/// लोगो, वही नाप, ठीक बीच में. Flutter का पहला frame आते ही अगर रंग बदले या
/// लोगो सरक जाए तो खुलने में झटका दिखता है; इसलिए लोगो को हिलाया नहीं,
/// नाम और चरखी उसके नीचे अलग से रखी हैं.
///
/// लोगो की 120 की नाप res/drawable-*/splash_logo.png से मेल खाती है —
/// एक बदलें तो दूसरी भी बदलिए.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: P.bg,
      body: Stack(
        children: [
          Center(
            child: Image.asset(
              'assets/images/logo.png',
              width: 120,
              height: 120,
            ),
          ),
          Align(
            alignment: const Alignment(0, 0.42),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'ब्रह्मास्त्र',
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w700,
                    color: P.ink,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 26),
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation(P.gold.withOpacity(0.75)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
