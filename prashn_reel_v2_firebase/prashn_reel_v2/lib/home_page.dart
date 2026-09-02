import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'build_flags.dart';
import 'exams.dart';
import 'maps/map_data.dart';
import 'maps/map_view.dart';
import 'models.dart';
import 'question_card.dart';
import 'auth.dart';
import 'repository.dart';
import 'screens/sources_page.dart';
import 'sfx.dart';
import 'speech.dart';
import 'study_timer.dart';

class HomePage extends StatefulWidget {
  /// सदस्यता न हो तो सिर्फ़ मुफ़्त नमूना दिखता है.
  final bool freeOnly;

  /// लॉगआउट का बटन — सदस्यता चालू हो तभी दिखता है.
  final Future<void> Function()? onSignOut;

  /// नमूने से पहले पन्ने पर वापस जाने के लिए.
  final VoidCallback? onExit;

  /// सिर्फ़ इसी प्रश्नपत्र के प्रश्न. null मतलब सब.
  final String? paperId;

  /// उसी में से एक विषय. null मतलब पूरा पेपर.
  final String? subject;

  /// ऊपर क्या छाँटा हुआ है, यह दिखाने के लिए.
  final String? practiceLabel;

  const HomePage({
    super.key,
    this.freeOnly = false,
    this.onSignOut,
    this.onExit,
    this.paperId,
    this.subject,
    this.practiceLabel,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  List<Question> questions = <Question>[];
  Map<String, int> answers = <String, int>{};

  bool loading = true;
  bool syncing = false;
  SourceKind source = SourceKind.seed;
  DateTime? syncedAt;

  final PageController pc = PageController();
  int current = 0;

  /// होम के नीचे विषय-चिप से चुना हुआ विषय. null मतलब "सभी".
  String? _subjectFilter;

  /// जो प्रश्न सामने आ चुके हैं — चाहे उत्तर दिया हो या नहीं.
  ///
  /// इसी से ऊपर वाला धूसर डिब्बा बनता है: देखे तो, पर छोड़ दिए. सिर्फ़
  /// गिनती रखने से काम नहीं चलता — विषय बदलने पर पन्ने की संख्या शून्य
  /// से शुरू हो जाती है, इसलिए प्रश्न की पहचान ही जोड़ते हैं.
  final Set<String> _seenIds = <String>{};

  /// हर प्रश्न पर सोचने का समय — असली परीक्षा में 100 प्रश्न, 120 मिनट,
  /// यानी औसतन इतना ही मिलता है.
  static const int kAnswerSeconds = 45;

  Timer? _clock;
  int _left = kAnswerSeconds;

  /// जिनका जवाब समय बीतने पर अपने आप खुला — छात्र ने चुना नहीं.
  ///
  /// ये answers में नहीं डाले जाते, इसीलिए न सही गिने जाते हैं न ग़लत.
  /// परदे पर सही विकल्प वैसे ही हरा दिखता है, पर अंक नहीं मिलते — असली
  /// परीक्षा में भी न दिया गया जवाब शून्य ही होता है. सहेजे भी नहीं जाते,
  /// ताकि ऐप दोबारा खोलने पर वही प्रश्न फिर एक मौक़ा दे.
  final Set<String> _revealedIds = <String>{};

  // मानचित्र मोड
  bool mapMode = false;
  int mapPage = 0;

  StreamSubscription<int>? _tick;
  StreamSubscription<bool>? _speech;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    answers = AnswerStore.load();
    StudyTimer.start();
    _tick = StudyTimer.onTick.listen((sec) {
      // हर मिनट पर ही दोबारा बनाते हैं, हर सेकंड नहीं
      if (sec % 60 == 0 && mounted) setState(() {});
    });
    // बोलना शुरू/बंद होने पर बटन का रूप बदलता है
    _speech = Speaker.onChange.listen((_) {
      if (mounted) setState(() {});
    });
    _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // समय तभी गिना जाए जब ऐप सामने खुला हो
    if (state == AppLifecycleState.resumed) {
      StudyTimer.start();
      _restartClock();
    } else {
      StudyTimer.stop();
      // ऐप पीछे जाते ही आवाज़ और घड़ी दोनों रुकें — पीछे बैठा फ़ोन
      // छात्र का जवाब ख़ुद न भर दे
      Speaker.stop();
      _stopClock();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
    _speech?.cancel();
    StudyTimer.stop();
    Speaker.stop();
    _stopClock();
    pc.dispose();
    super.dispose();
  }

  /// नया प्रश्न सामने आने पर उसे सुनाना (अगर आवाज़ चालू है).
  void _speakCurrent(int page) {
    if (!Speaker.enabled) return;
    final vis = _visible;
    if (mapMode || page >= vis.length) {
      Speaker.stop();
      return;
    }
    Speaker.speakQuestion(vis[page]);
  }

  Future<void> _toggleSpeech() async {
    final on = await Speaker.toggle();
    if (!mounted) return;

    if (on) {
      _speakCurrent(current);
    }

    final msg = !Speaker.hindiAvailable && on
        ? 'हिंदी आवाज़ फ़ोन में नहीं मिली — Settings → भाषा → वाक् (TTS) में हिंदी जोड़ें'
        : on
            ? 'आवाज़ चालू — प्रश्न अपने आप पढ़े जाएँगे'
            : 'आवाज़ बंद';

    _toast(msg, seconds: !Speaker.hindiAvailable && on ? 5 : 2);
  }

  Future<void> _load({bool forceRemote = false}) async {
    final res = await QuestionRepo.load(
      forceRemote: forceRemote,
      freeOnly: widget.freeOnly,
      paperId: widget.paperId,
      subject: widget.subject,
    );
    if (!mounted) return;
    final list = List<Question>.from(res.questions)..shuffle(Random());
    setState(() {
      questions = list;
      source = res.source;
      syncedAt = res.syncedAt;
      loading = false;
      _markSeen(0); // पहला प्रश्न सामने है ही
    });
    _restartClock();

    // सदस्य को बंडल वाले प्रश्न मिल रहे हैं, यानी न सर्वर मिला न कैश.
    // उसे बताना ज़रूरी है कि उसकी सदस्यता ठीक है, बस एक बार जुड़ना है —
    // वरना लगेगा कि पैसे देकर भी 25 ही प्रश्न मिले.
    if (res.source == SourceKind.seed &&
        !widget.freeOnly &&
        Session.isSubscribed) {
      _toast(
        'एक बार इंटरनेट से जोड़िए — उसके बाद सारे प्रश्न बिना इंटरनेट भी चलेंगे।',
        seconds: 6,
        action: SnackBarAction(
          label: 'अभी जोड़ें',
          textColor: const Color(0xFFFFC46B),
          onPressed: _sync,
        ),
      );
    }
  }

  Future<void> _sync() async {
    if (syncing) return;
    setState(() => syncing = true);
    final before = questions.length;
    await _load(forceRemote: true);
    if (!mounted) return;
    setState(() => syncing = false);

    final diff = questions.length - before;
    final msg = source == SourceKind.firebase
        ? (diff > 0
            ? '$diff नए प्रश्न जुड़े — कुल ${questions.length}'
            : 'प्रश्न अपडेट हो गए — कुल ${questions.length}')
        : 'सर्वर से जुड़ नहीं पाए, सेव किए प्रश्न दिखा रहे हैं';
    _toast(msg);
  }

  void _select(String id, int option) {
    if (answers.containsKey(id)) return;
    _stopClock(); // जवाब आ गया, अब गिनने की ज़रूरत नहीं
    setState(() => answers[id] = option);
    AnswerStore.save(answers);

    // उत्तर चुनते ही व्याख्या सुना देते हैं
    if (Speaker.enabled) {
      final q = questions.firstWhere((x) => x.id == id);
      Speaker.speakExplanation(q);
    }
  }

  /// नीचे दिखने वाली छोटी पट्टी — तय समय बाद ख़ुद बंद.
  ///
  /// Flutter का अपना `duration` भरोसे लायक़ नहीं निकला: जिस पट्टी पर
  /// बटन होता है, उसे फ़ोन में कोई accessibility सेवा चालू होने पर वह
  /// अपने आप बंद नहीं करता — पट्टी परदे पर अटकी रह जाती है और छात्र को
  /// हाथ से हटानी पड़ती है. इसलिए अपनी घड़ी लगाकर ख़ुद बंद करते हैं.
  void _toast(String msg, {SnackBarAction? action, int seconds = 2}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    final bar = messenger.showSnackBar(SnackBar(
      duration: Duration(seconds: seconds),
      content: Text(msg),
      action: action,
    ));

    // छात्र ने पहले ही हटा दी हो तो यह चुपचाप कुछ नहीं करता
    Timer(Duration(seconds: seconds), bar.close);
  }

  /// सिर्फ़ उत्तर मिटते हैं — प्रश्न और उनका क्रम वैसा ही रहता है,
  /// ताकि दोबारा विकल्प चुने जा सकें.
  void _resetAnswers() {
    if (answers.isEmpty) {
      _toast('अभी कोई उत्तर दिया ही नहीं गया');
      return;
    }
    final backup = Map<String, int>.from(answers);
    setState(() {
      answers = <String, int>{};
      _revealedIds.clear(); // समय बीते प्रश्न भी फिर से खुले मिलें
    });
    AnswerStore.save(answers);
    _restartClock(); // सब मिट गया, तो घड़ी भी फिर से

    _toast(
      'रीसेट हो गया',
      action: SnackBarAction(
        label: 'वापस लाएँ',
        textColor: const Color(0xFFFFC46B),
        onPressed: () {
          setState(() => answers = backup);
          AnswerStore.save(answers);
        },
      ),
    );
  }

  /// लंबे प्रश्न में कार्ड का स्क्रॉल ख़त्म होने पर अगला/पिछला प्रश्न.
  void _jump(int delta) {
    if (!pc.hasClients) return;
    final target = current + delta;
    if (target < 0 || target > _visible.length) return;
    pc.animateToPage(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _shuffle() {
    setState(() {
      questions = List<Question>.from(questions)..shuffle(Random());
      current = 0;
    });
    if (pc.hasClients) pc.jumpToPage(0);
  }

  /// अभी दिख रहे प्रश्न — विषय-चिप की छाँट लगने के बाद.
  List<Question> get _visible => _subjectFilter == null
      ? questions
      : questions.where((q) => q.subject == _subjectFilter).toList();

  /// लोड हुए प्रश्नों में जो-जो विषय हैं — kSubjects के क्रम में.
  List<String> get _subjects {
    final present = questions.map((q) => q.subject).toSet();
    return kSubjects.keys.where(present.contains).toList();
  }

  /// विषय-चिप दबाने पर — छाँट बदलो और पहले प्रश्न पर लौटो.
  void _setFilter(String? subject) {
    if (_subjectFilter == subject) return;
    setState(() {
      _subjectFilter = subject;
      current = 0;
      _markSeen(0);
    });
    if (pc.hasClients) pc.jumpToPage(0);
    _speakCurrent(0);
    _restartClock();
  }

  /// अभी सामने जो प्रश्न है — मानचित्र/नतीजे के पन्ने पर कोई नहीं.
  Question? get _currentQuestion {
    if (mapMode || loading) return null;
    final vis = _visible;
    if (current < 0 || current >= vis.length) return null;
    return vis[current];
  }

  /// इस प्रश्न का पन्ना बंद हो चुका — या तो जवाब दिया, या समय बीत गया.
  bool _isDone(Question q) =>
      answers.containsKey(q.id) || _revealedIds.contains(q.id);

  /// समय ख़त्म — सही जवाब खोल दो, पर अंक किसी को नहीं.
  void _revealAnswer(Question q) {
    if (_isDone(q)) return;
    setState(() => _revealedIds.add(q.id));
    if (Speaker.enabled) Speaker.speakExplanation(q);
  }

  /// घड़ी नए सिरे से — नया प्रश्न सामने आने पर.
  ///
  /// उत्तर दे चुके प्रश्न पर घड़ी नहीं चलती, वरना पीछे लौटने पर सही जवाब
  /// दोबारा "अपने आप" चुना जाता और गिनती बिगड़ जाती.
  void _restartClock() {
    _clock?.cancel();
    _clock = null;
    if (mounted) setState(() => _left = kAnswerSeconds);

    final q = _currentQuestion;
    if (q == null || _isDone(q)) return;

    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final cur = _currentQuestion;
      if (cur == null || _isDone(cur)) {
        _stopClock();
        return;
      }
      setState(() => _left--);
      if (_left <= 0) {
        _stopClock();
        // दिखने में वैसा ही जैसे छात्र ने सही दबाया हो — गिनती में नहीं
        _revealAnswer(cur);
      }
    });
  }

  void _stopClock() {
    _clock?.cancel();
    _clock = null;
  }

  /// मानचित्र और प्रश्न के बीच आना-जाना — घड़ी भी उसी हिसाब से.
  void _toggleMap() {
    setState(() => mapMode = !mapMode);
    _restartClock();
  }

  /// इस पन्ने का प्रश्न "देखा हुआ" मान लो.
  void _markSeen(int page) {
    final vis = _visible;
    if (page >= 0 && page < vis.length) _seenIds.add(vis[page].id);
  }

  /// ऊपर पट्टी में दिखने वाला परीक्षा का नाम.
  ///
  /// कौन-सा पेपर चल रहा है, उसी से परीक्षा निकलती है. नमूने में कोई पेपर
  /// नहीं चुना होता — वहाँ UPPET ही है, क्योंकि मुफ़्त पूरा पेपर वही है.
  String get _examName {
    final p = widget.paperId == null ? null : paperOf(widget.paperId!);
    final e = p == null ? null : examOf(p.examId);
    return e?.shortLabel ?? 'UPPET';
  }

  Color get accent {
    if (mapMode) return kMaps[mapPage.clamp(0, kMaps.length - 1)].color;
    final vis = _visible;
    if (vis.isEmpty || current >= vis.length) {
      return P.brand;
    }
    return subjectOf(vis[current].subject).color;
  }

  int get attempted =>
      _visible.where((q) => answers.containsKey(q.id)).length;
  int get correct =>
      _visible.where((q) => answers[q.id] == q.answer).length;

  @override
  Widget build(BuildContext context) {
    final vis = _visible;
    return PopScope(
      // फ़ोन का बैक बटन ऐप से बाहर न फेंके — पहले छाँट/मानचित्र/होम पर लौटे.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(),
            if (!mapMode && !loading && _subjects.length > 1) _subjectBar(),
            Expanded(
              child: mapMode
                  ? MapReel(onPageChanged: (p) => setState(() => mapPage = p))
                  : loading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2.4))
                  : vis.isEmpty
                      ? _empty()
                      : PageView.builder(
                          controller: pc,
                          scrollDirection: Axis.vertical,
                          itemCount: vis.length + 1,
                          onPageChanged: (p) {
                            setState(() {
                              current = p;
                              _markSeen(p);
                            });
                            // नए प्रश्न पर KBC जैसा छोटा cue (नतीजे वाले पन्ने पर नहीं)
                            if (p < vis.length) Sfx.play();
                            _speakCurrent(p);
                            _restartClock();
                          },
                          itemBuilder: (context, page) {
                            if (page == vis.length) return _summary();
                            final q = vis[page];
                            return QuestionCard(
                              q: q,
                              number: page + 1,
                              total: vis.length,
                              selected: answers[q.id] ??
                                  (_revealedIds.contains(q.id)
                                      ? q.answer
                                      : null),
                              onSelect: (opt) => _select(q.id, opt),
                              showHint: page == 0,
                              onNext: () => _jump(1),
                              onPrev: page == 0 ? null : () => _jump(-1),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  /// फ़ोन के बैक बटन का बर्ताव — एक-एक परत पीछे हटाओ, तभी ऐप छोड़ो.
  void _handleBack() {
    if (mapMode) {
      setState(() => mapMode = false);
      return;
    }
    if (_subjectFilter != null) {
      _setFilter(null); // पहले "सभी" पर लौटो
      return;
    }
    if (widget.onExit != null) {
      widget.onExit!(); // होम/डैशबोर्ड पर लौटो
      return;
    }
    // और कोई परत नहीं — अब ऐप से बाहर
    SystemNavigator.pop();
  }

  /// होम के नीचे विषय-चिप की पट्टी — दबाकर उसी विषय के प्रश्न देखे जा सकें.
  ///
  /// पहले हर प्रश्न के ऊपर विषय का नाम लिखा आता था; अब वह हटाकर यहाँ
  /// एक ही जगह सारे विषय दिखते हैं. "सभी" दबाने पर पूरी सूची लौट आती है.
  Widget _subjectBar() {
    final subs = _subjects;
    return Container(
      height: 40,
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _chip(label: 'सभी', color: P.brand, selected: _subjectFilter == null,
              onTap: () => _setFilter(null)),
          for (final s in subs)
            _chip(
              label: subjectOf(s).label,
              color: subjectOf(s).color,
              icon: subjectOf(s).icon,
              selected: _subjectFilter == s,
              onTap: () => _setFilter(s),
            ),
        ],
      ),
    );
  }

  Widget _chip({
    required String label,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
            decoration: BoxDecoration(
              color: selected ? color : color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: selected ? color : color.withOpacity(0.28)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon,
                      size: 13,
                      color: selected ? Colors.white : color),
                  const SizedBox(width: 6),
                ],
                Text(label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : color,
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────────── header ─────────────────────────

  // ───────────────────────── ऊपर की पट्टी ─────────────────────────

  /// हेडर और पढ़ाई वाली पट्टी — दोनों एक ही कतार में.
  ///
  /// पहले ये दो अलग हिस्से थे और मिलकर क़रीब 105px खा जाते थे. सबसे बड़ी
  /// फ़िज़ूलख़र्ची "ब्रह्मास्त्र" नाम था, जो पूरी एक लाइन घेरता था — जबकि
  /// छात्र को पता ही है कि वह किस ऐप में है. नाम अब सिर्फ़ पहले पन्ने और
  /// डैशबोर्ड पर है; यहाँ उसकी जगह प्रश्न को मिल गई.
  Widget _header() {
    final vis = _visible;
    final total = mapMode ? kMaps.length : vis.length;

    final m = StudyTimer.minutes;

    // चार डिब्बों की गिनती — जो चिप चुनी है उसी के भीतर की.
    // समय बीते प्रश्न answers में जाते ही नहीं, इसलिए अपने आप यहीं गिने जाते हैं
    final skipped = vis
        .where((q) => _seenIds.contains(q.id) && !answers.containsKey(q.id))
        .length;
    final right = correct;
    final wrong = attempted - correct;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      padding: const EdgeInsets.fromLTRB(12, 4, 8, 5),
      decoration: BoxDecoration(
        // नेविगेशन को थोड़ा रंग — अभी जो विषय चल रहा है उसी की हल्की छाँव.
        // गहरा नहीं, बस क्रीम पर एक रंगीन झलक ताकि पट्टी जीवंत लगे.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent.withOpacity(0.16), P.card],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
              color: accent.withOpacity(0.12),
              blurRadius: 16,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // परीक्षा का नाम — छात्र को एक नज़र में पता रहे किसकी तैयारी है
              Text(
                _examName,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: P.brand,
                  letterSpacing: 0.2,
                  height: 1.1,
                ),
              ),
              const Spacer(),
              _speechToggle(),
              _iconBtn(
                tip: mapMode ? 'प्रश्न' : 'मानचित्र',
                icon: mapMode
                    ? FontAwesomeIcons.circleQuestion
                    : FontAwesomeIcons.globe,
                color: const Color(0xFF0B6357),
                on: mapMode,
                onTap: _toggleMap,
              ),
              _iconBtn(
                tip: 'पहले पन्ने पर',
                icon: FontAwesomeIcons.house,
                color: const Color(0xFFC2680C),
                onTap: widget.onExit,
              ),
              _iconBtn(
                tip: 'मेन्यू',
                icon: FontAwesomeIcons.bars,
                color: P.ink,
                onTap: _openMenu,
              ),
            ],
          ),
          const SizedBox(height: 4),

          // आज का अभ्यास और चारों गिनतियाँ — एक ही कतार में.
          //
          // पहले ये दो लाइनें थीं और डिब्बे पूरी चौड़ाई में फैले थे; पट्टी
          // भारी लगती थी और प्रश्न के लिए जगह कम बचती थी. अब बाएँ समय,
          // दाएँ चार छोटे डिब्बे — एक नज़र, एक लाइन.
          Row(
            children: [
              Text('Today Practice',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: P.muted)),
              const SizedBox(width: 6),
              Text('$m',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: P.ink)),
              const SizedBox(width: 2),
              Text('Min',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: P.muted)),
              const SizedBox(width: 7),
              _sourceDot(),
              const Spacer(),

              // छोड़े हुए, सही, ग़लत, कुल
              _statBox(skipped, P.muted, icon: Icons.priority_high),
              _statBox(right, P.right, icon: Icons.check),
              _statBox(wrong, P.wrong, icon: Icons.close),
              _statBox(total, P.brand),
              const SizedBox(width: 6),
              _answerClock(),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOut,
              tween: Tween<double>(
                begin: 0.0,
                end: total == 0
                    ? 0.0
                    : (mapMode ? mapPage : current.clamp(0, total)) / total,
              ),
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 3.5,
                backgroundColor: P.line,
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// छोटा गोल बटन — चौड़ाई बचाने के लिए सिर्फ़ निशान, कोई शब्द नहीं.
  Widget _iconBtn({
    required String tip,
    required FaIconData icon,
    required VoidCallback? onTap,
    Color? color,
    bool on = false,
  }) {
    // धूसर निशान मरे हुए लगते थे. हर बटन का अपना रंग है — पट्टी बिना
    // शब्दों के भी पहचान में आ जाती है.
    final base = color ?? P.muted;
    return Tooltip(
      message: tip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          // उँगली के लिए 40px का घेरा बनता है — छोटा दिखता है पर दबता आराम से है
          padding: const EdgeInsets.all(9),
          child: FaIcon(
            icon,
            size: 18,
            color: on
                ? accent
                : (onTap == null ? base.withOpacity(0.3) : base),
          ),
        ),
      ),
    );
  }

  /// 45 सेकंड की घड़ी — कुल वाले डिब्बे के ठीक बग़ल में.
  ///
  /// घेरा घटता जाता है और बीच में बचे सेकंड दिखते हैं. आख़िरी 10 सेकंड
  /// लाल हो जाते हैं — दबाव असली परीक्षा जैसा ही रहे. समय बीतते ही सही
  /// उत्तर अपने आप खुल जाता है, फिर यहाँ हरा निशान रह जाता है.
  Widget _answerClock() {
    final q = _currentQuestion;
    final running = _clock != null && q != null;
    final done = q != null && _isDone(q);

    final c = _left <= 10
        ? P.wrong
        : _left <= 20
            ? P.gold
            : P.right;

    return SizedBox(
      width: 28,
      height: 28,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              value: running ? (_left / kAnswerSeconds).clamp(0.0, 1.0) : 1.0,
              strokeWidth: 2.4,
              backgroundColor: P.line,
              valueColor: AlwaysStoppedAnimation<Color>(
                  running ? c : (done ? P.right : P.line)),
            ),
          ),
          if (running)
            Text('$_left',
                style: TextStyle(
                    fontSize: 10.5, fontWeight: FontWeight.w900, color: c))
          else if (done)
            const Icon(Icons.check, size: 13, color: P.right)
          else
            Icon(Icons.timer_outlined,
                size: 12, color: P.muted.withOpacity(0.55)),
        ],
      ),
    );
  }

  /// ऊपर वाला छोटा डिब्बा — सिर्फ़ गिनती, कोई शब्द नहीं.
  ///
  /// रंग ही बताता है कि क्या है: धूसर = देखा पर छोड़ दिया, हरा = सही,
  /// लाल = ग़लत, भूरा = कुल. लिखने की ज़रूरत नहीं पड़ी.
  Widget _statBox(int value, Color color, {IconData? icon}) => Container(
        margin: const EdgeInsets.only(left: 5),
        constraints: const BoxConstraints(minWidth: 30),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.30)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$value',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
                color: color,
                height: 1.15,
              ),
            ),
            // अंक के बग़ल में छोटा निशान — रंग अकेला काफ़ी नहीं था.
            //
            // धुँधली रोशनी में या रंग न पहचान पाने वाले छात्र के लिए हरा
            // और लाल एक जैसे दिख सकते हैं. निशान से माने में कोई संदेह
            // नहीं रहता: ! छोड़े हुए, ✓ सही, ✗ ग़लत.
            if (icon != null) ...[
              const SizedBox(width: 2),
              Icon(icon, size: 11, color: color),
            ],
          ],
        ),
      );


  /// मेन्यू — नाम, बचे दिन, और घर/रीसेट/लॉगआउट.
  ///
  /// पहले प्रश्नों की स्क्रीन से वापस जाने का कोई रास्ता ही नहीं था.
  void _openMenu() {
    final e = Session.entitlement;
    final paid = e.isSubscribed;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: P.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                  color: P.line, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),

            // ── कौन है, कितने दिन बचे ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.11),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Center(
                      child: FaIcon(
                          paid
                              ? FontAwesomeIcons.solidUser
                              : FontAwesomeIcons.userLarge,
                          size: 17,
                          color: accent),
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(paid ? e.name : 'UPPET Exam',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                height: 1.25)),
                        const SizedBox(height: 2),
                        Text(
                          paid
                              ? '${e.daysLeft} दिन बचे'
                              // Play वाली build में न्योता नहीं दिया जाता —
                              // वहाँ ऐप के बाहर ख़रीदने की तरफ़ इशारा करना भी
                              // नीति के ख़िलाफ़ है, सिर्फ़ बटन नहीं. इसलिए यहाँ
                              // बस हाल बताया जाता है. वजह build_flags.dart में.
                              : kIsPlayBuild
                                  ? 'UPPCS · RO/ARO सदस्यता वाले हैं'
                                  : 'UPPCS · RO/ARO के लिए सदस्यता लीजिए',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: paid && e.isExpiringSoon ? P.wrong : P.muted,
                            fontWeight: paid && e.isExpiringSoon
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),
            const Divider(height: 1, color: P.line),

            // सिंक अब हेडर से हटकर यहाँ — रोज़ का काम नहीं है, और ऊपर की
            // कतार में जगह प्रश्न के लिए ज़्यादा क़ीमती है.
            _menuRow(
              icon: FontAwesomeIcons.cloudArrowDown,
              label: syncing ? 'नए प्रश्न आ रहे हैं…' : 'नए प्रश्न लाएँ',
              enabled: !syncing,
              onTap: () {
                Navigator.pop(sheetCtx);
                _sync();
              },
            ),
            _menuRow(
              icon: FontAwesomeIcons.arrowRotateLeft,
              label: 'उत्तर रीसेट करें',
              onTap: () {
                Navigator.pop(sheetCtx);
                _resetAnswers();
              },
            ),
            _menuRow(
              icon: FontAwesomeIcons.shuffle,
              label: 'क्रम बदलें',
              onTap: () {
                Navigator.pop(sheetCtx);
                _shuffle();
              },
            ),
            _menuRow(
              icon: Sfx.enabled
                  ? FontAwesomeIcons.volumeHigh
                  : FontAwesomeIcons.volumeXmark,
              label: Sfx.enabled ? 'प्रश्न साउंड बंद करें' : 'प्रश्न साउंड चालू करें',
              onTap: () async {
                Navigator.pop(sheetCtx);
                await Sfx.toggle();
                if (mounted) setState(() {});
              },
            ),
            // प्रश्नों की स्क्रीन से भी स्रोत तक रास्ता चाहिए — बहुत से छात्र
            // पहला पन्ना एक ही बार देखते हैं और फिर सीधे यहीं रहते हैं.
            _menuRow(
              icon: FontAwesomeIcons.circleInfo,
              label: 'स्रोत और अस्वीकरण',
              onTap: () {
                Navigator.pop(sheetCtx);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SourcesPage()),
                );
              },
            ),
            if (paid)
              _menuRow(
                icon: FontAwesomeIcons.rightFromBracket,
                label: 'लॉगआउट',
                danger: true,
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  await widget.onSignOut?.call();
                },
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _menuRow({
    required FaIconData icon,
    required String label,
    required VoidCallback onTap,
    bool danger = false,
    bool enabled = true,
  }) {
    final color = !enabled ? P.muted.withOpacity(0.4) : (danger ? P.wrong : P.ink);
    return ListTile(
      enabled: enabled,
      onTap: enabled ? onTap : null,
      leading: FaIcon(icon, size: 16, color: color),
      title: Text(label,
          style: TextStyle(
              fontSize: 14.5, fontWeight: FontWeight.w600, color: color)),
      dense: true,
      visualDensity: const VisualDensity(vertical: -1),
    );
  }

  /// आवाज़ चालू/बंद करने वाला बटन.
  ///
  /// बोलते समय आइकन बदल जाता है, ताकि पता चले कि अभी पढ़ा जा रहा है.
  /// आवाज़ का बटन — अब सिर्फ़ निशान, कोई शब्द नहीं.
  ///
  /// पहले चालू होने पर "आवाज़"/"पढ़ रहे" भी लिखा आता था, जो ऊपर की कतार में
  /// क़ीमती चौड़ाई खा रहा था. चालू है या नहीं, यह रंग से पता चल जाता है;
  /// और बोलते समय निशान अपने आप बदल जाता है.
  Widget _speechToggle() {
    final on = Speaker.enabled;
    return Tooltip(
      message: on ? 'आवाज़ बंद करें' : 'प्रश्न सुनें',
      child: InkWell(
        onTap: _toggleSpeech,
        // बोलते समय दबाकर रखने पर सिर्फ़ यही प्रश्न रुके, आवाज़ बंद न हो
        onLongPress: Speaker.speaking ? Speaker.stop : null,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: FaIcon(
            !on
                ? FontAwesomeIcons.volumeXmark
                : Speaker.speaking
                    ? FontAwesomeIcons.volumeHigh
                    : FontAwesomeIcons.volumeLow,
            size: 17,
            color: on ? accent : P.muted,
          ),
        ),
      ),
    );
  }

  Widget _sourceDot() {
    late Color c;
    late String label;
    switch (source) {
      case SourceKind.firebase:
        c = P.right;
        label = 'लाइव';
        break;
      case SourceKind.cache:
        c = const Color(0xFFC2680C);
        label = 'सेव';
        break;
      case SourceKind.seed:
        c = P.muted;
        label = 'ऑफ़लाइन';
        break;
    }
    // एक ही लाइन में सब आना है, इसलिए यहाँ सिर्फ़ बिंदु — शब्द दबाने पर.
    return Tooltip(
      message: label,
      child: Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
    );
  }

  // ───────────────────────── pages ─────────────────────────

  Widget _empty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(34),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox_outlined, size: 44, color: P.muted.withOpacity(0.6)),
              const SizedBox(height: 12),
              Text('कोई प्रश्न नहीं मिला।\nऊपर सिंक बटन दबाकर दोबारा कोशिश करें।',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14.5, height: 1.6, color: P.muted)),
            ],
          ),
        ),
      );

  Widget _summary() {
    final total = questions.length;
    final pct = attempted == 0 ? 0 : ((correct / attempted) * 100).round();
    final left = total - attempted;

    return Center(
      child: SingleChildScrollView(
        child: Container(
          margin: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
          decoration: BoxDecoration(
            color: P.card,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: accent.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                  color: accent.withOpacity(0.10),
                  blurRadius: 24,
                  offset: const Offset(0, 10)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.emoji_events_outlined, size: 40, color: accent),
              const SizedBox(height: 12),
              Text(left == 0 ? 'सभी प्रश्न पूरे हुए' : 'अब तक की प्रगति',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(
                left == 0
                    ? '$total में से $total प्रश्न हल किए'
                    : '$total में से $attempted हल · $left बाकी',
                style: TextStyle(fontSize: 14, color: P.muted),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _stat('$correct', 'सही', P.right),
                  _stat('${attempted - correct}', 'गलत', P.wrong),
                  _stat('$pct%', 'शुद्धता', accent),
                ],
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    _resetAnswers();
                    if (pc.hasClients) {
                      pc.animateToPage(0,
                          duration: const Duration(milliseconds: 340),
                          curve: Curves.easeOutCubic);
                    }
                  },
                  icon: const Icon(Icons.restart_alt, size: 19),
                  label: const Text('उत्तर रीसेट करें',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14.5)),
                ),
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        side: const BorderSide(color: P.line),
                        foregroundColor: P.muted,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13)),
                      ),
                      onPressed: _shuffle,
                      icon: const Icon(Icons.shuffle, size: 17),
                      label: const Text('क्रम बदलें',
                          style: TextStyle(fontSize: 13.5)),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        side: const BorderSide(color: P.line),
                        foregroundColor: P.muted,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13)),
                      ),
                      onPressed: syncing ? null : _sync,
                      icon: const Icon(Icons.cloud_sync_outlined, size: 17),
                      label: const Text('नए प्रश्न',
                          style: TextStyle(fontSize: 13.5)),
                    ),
                  ),
                ],
              ),
              if (syncedAt != null) ...[
                const SizedBox(height: 14),
                Text(
                  'अंतिम अपडेट: ${syncedAt!.day}/${syncedAt!.month} · '
                  '${syncedAt!.hour.toString().padLeft(2, '0')}:${syncedAt!.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(fontSize: 11.5, color: P.muted.withOpacity(0.9)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(String value, String label, Color color) => Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12, color: P.muted)),
        ],
      );
}
