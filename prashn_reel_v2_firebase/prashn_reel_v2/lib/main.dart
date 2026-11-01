import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dart:async';

import 'app_config.dart';
import 'app_gate.dart';
import 'auth.dart';
import 'device.dart';
import 'engage.dart';
import 'exam_dates.dart';
import 'models.dart';
import 'reminders.dart';
import 'repository.dart';
import 'screens/quick_question_page.dart';
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
  await ExamDates.load();
  await Engage.init();
  await Reminders.init();
  // ऐप खुला है — पहले से तय घंटियाँ अब नहीं बजनी चाहिए
  await Reminders.cancelPending();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: P.bg,
    systemNavigationBarIconBrightness: Brightness.dark,
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

class PrashnReelApp extends StatefulWidget {
  const PrashnReelApp({super.key});

  @override
  State<PrashnReelApp> createState() => _PrashnReelAppState();
}

class _PrashnReelAppState extends State<PrashnReelApp> {
  /// notification छूने पर प्रश्न का पन्ना किसी भी परदे के ऊपर खोलने के लिए.
  final _nav = GlobalKey<NavigatorState>();

  late final AppLifecycleListener _life;
  StreamSubscription<Question>? _taps;

  @override
  void initState() {
    super.initState();
    // प्रश्न-घंटी: ऐप पीछे गया तो घंटियाँ तय, सामने आया तो रद्द —
    // ताकि "5 घंटे" हमेशा आख़िरी बार खोलने से गिने जाएँ.
    _life = AppLifecycleListener(
      onHide: Reminders.schedule,
      onShow: Reminders.cancelPending,
    );
    _taps = Reminders.onTap.listen(_openQuestion);

    // ऐप बंद था और notification से ही खुला
    final q = Reminders.launchQuestion;
    if (q != null) {
      Reminders.launchQuestion = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => _openQuestion(q));
    }
  }

  void _openQuestion(Question q) {
    _nav.currentState?.push(MaterialPageRoute(
      builder: (_) => QuickQuestionPage(q: q, title: 'प्रश्न-घंटी'),
    ));
  }

  @override
  void dispose() {
    _life.dispose();
    _taps?.cancel();
    super.dispose();
  }

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

    // बटनों का एक ही ढंग — हर पन्ने पर अलग-अलग गोलाई और गाढ़ापन था
    final btnShape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
    const btnText = TextStyle(
        fontFamily: 'Mukta', fontSize: 14.5, fontWeight: FontWeight.w700);

    return MaterialApp(
      navigatorKey: _nav,
      title: 'Brahmastra',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        textTheme: base.textTheme.apply(bodyColor: P.ink, displayColor: P.ink),
        appBarTheme: const AppBarTheme(
          backgroundColor: P.card,
          surfaceTintColor: P.card,
          foregroundColor: P.ink,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          shape: Border(bottom: BorderSide(color: P.line)),
          titleTextStyle: TextStyle(
              fontFamily: 'Mukta',
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: P.ink),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: P.brand,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: btnShape,
            textStyle: btnText,
            elevation: 0,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: P.goldBright,
            foregroundColor: P.onSaffron,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: btnShape,
            textStyle: btnText,
            elevation: 0,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: P.brand,
            side: const BorderSide(color: P.line, width: 1.2),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            shape: btnShape,
            textStyle: btnText,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: P.brand,
            textStyle: btnText.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: P.card,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: P.line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: P.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: P.brand, width: 1.6),
          ),
          labelStyle: const TextStyle(color: P.muted),
          hintStyle: TextStyle(color: P.muted.withOpacity(0.7)),
        ),
        cardTheme: CardThemeData(
          color: P.card,
          surfaceTintColor: P.card,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: P.line),
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: P.card,
          surfaceTintColor: P.card,
          showDragHandle: false,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: P.card,
          surfaceTintColor: P.card,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        ),
        dividerTheme: const DividerThemeData(color: P.line, thickness: 1),
        progressIndicatorTheme:
            const ProgressIndicatorThemeData(color: P.brand),
        listTileTheme: const ListTileThemeData(iconColor: P.brand),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: P.brandDeep,
          actionTextColor: P.goldBright,
          contentTextStyle: const TextStyle(
              fontFamily: 'Mukta', color: Colors.white, fontSize: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      home: const AppGate(),
    );
  }
}
