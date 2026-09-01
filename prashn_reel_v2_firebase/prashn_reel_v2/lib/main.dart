import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_config.dart';
import 'app_gate.dart';
import 'auth.dart';
import 'device.dart';
import 'models.dart';
import 'repository.dart';
import 'speech.dart';
import 'sfx.dart';
import 'study_timer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase वैकल्पिक है: google-services.json न हो तो ऐप
  // बंडल किए 150 प्रश्नों के साथ ऑफ़लाइन चलता रहेगा.
  try {
    await Firebase.initializeApp();
    QuestionRepo.firebaseReady = true;
    await _startAppCheck();
  } catch (_) {
    QuestionRepo.firebaseReady = false;
  }

  await AnswerStore.init();
  await StudyTimer.init();
  await Speaker.init();
  await Sfx.init();
  await DeviceId.init();
  await Session.init();
  await AppConfig.load();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  runApp(const PrashnReelApp());
}

/// App Check चालू करता है — Firebase को यक़ीन दिलाने के लिए कि request
/// असली ऐप से आई है, किसी की निकाली हुई `google-services.json` से नहीं.
///
/// ── अभी यह सिर्फ़ निगरानी के लिए है, पहरे के लिए नहीं ──
///
/// Firebase Console में इसे **Monitoring** पर ही रखना है, Enforce नहीं.
/// वजह: Play Integrity सिर्फ़ उसी build को पहचानता है जो Play Store पर
/// मौजूद हो. हमारी सीधे बाँटी जाने वाली APK वहाँ है ही नहीं, इसलिए enforce
/// करते ही वे सारे छात्र बाहर हो जाएँगे जिनसे अभी कमाई हो रही है.
///
/// Enforce तभी करना जब Play ही मुख्य रास्ता बन जाए. तब तक निगरानी से यह
/// दिखता रहेगा कि कितनी requests पहचानी जा रही हैं — और असली पहरा
/// billing budget alert है.
///
/// ── यह कभी ऐप रोक नहीं सकता ──
///
/// पूरा हिस्सा try/catch में है. App Check शुरू न हो पाए (इंटरनेट नहीं,
/// Play Services पुराने, sideloaded APK) तो ऐप पहले जैसी ही चलती है —
/// क्योंकि enforce नहीं है, बिना token वाली request भी मानी जाती है.
Future<void> _startAppCheck() async {
  try {
    await FirebaseAppCheck.instance.activate(
      // debug build में Play Integrity चल ही नहीं सकता (ऐप Play पर नहीं है).
      // इसलिए वहाँ debug provider — वह console में डालने के लिए एक token
      // छापता है, जिससे `flutter run` भी बिना रोक-टोक चलता रहे.
      androidProvider:
          kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
    );
  } catch (_) {
    // चुपचाप छोड़ दें — ऊपर लिखी वजह से यह रुकावट नहीं बननी चाहिए
  }
}

class PrashnReelApp extends StatelessWidget {
  const PrashnReelApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      // Mukta — देवनागरी के लिए बना फ़ॉन्ट, ऐप में बंडल है
      fontFamily: 'Mukta',
      scaffoldBackgroundColor: P.bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: P.brand,
        brightness: Brightness.light,
      ).copyWith(surface: P.bg),
    );

    return MaterialApp(
      title: 'ब्रह्मास्त्र',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        textTheme: base.textTheme.apply(bodyColor: P.ink, displayColor: P.ink),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: P.ink,
          contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      home: const AppGate(),
    );
  }
}
