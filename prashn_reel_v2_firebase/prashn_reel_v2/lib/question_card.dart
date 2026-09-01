import 'package:flutter/material.dart';
import 'models.dart';

/// लंबे प्रश्नों में कार्ड का अपना स्क्रॉल चालू हो जाता है और वही
/// उंगली पकड़ लेता है, जिससे PageView अगला प्रश्न नहीं दिखा पाता.
/// यह विजेट किनारे पर पहुँचने के बाद का खिंचाव पकड़कर
/// अगले/पिछले प्रश्न पर ले जाता है.
class _ScrollChain extends StatefulWidget {
  final Widget child;
  final VoidCallback? onNext;
  final VoidCallback? onPrev;

  const _ScrollChain({required this.child, this.onNext, this.onPrev});

  @override
  State<_ScrollChain> createState() => _ScrollChainState();
}

class _ScrollChainState extends State<_ScrollChain> {
  static const double _threshold = 42;
  double _acc = 0;
  bool _fired = false;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollStartNotification || n is ScrollEndNotification) {
          _acc = 0;
          _fired = false;
        } else if (n is OverscrollNotification && !_fired) {
          _acc += n.overscroll;
          if (_acc > _threshold && widget.onNext != null) {
            _fired = true;
            widget.onNext!();
          } else if (_acc < -_threshold && widget.onPrev != null) {
            _fired = true;
            widget.onPrev!();
          }
        }
        return false;
      },
      child: widget.child,
    );
  }
}

class QuestionCard extends StatelessWidget {
  final Question q;
  final int number;
  final int total;
  final int? selected;
  final ValueChanged<int> onSelect;
  final bool showHint;
  final VoidCallback? onNext;
  final VoidCallback? onPrev;

  const QuestionCard({
    super.key,
    required this.q,
    required this.number,
    required this.total,
    required this.selected,
    required this.onSelect,
    this.showHint = false,
    this.onNext,
    this.onPrev,
  });

  @override
  Widget build(BuildContext context) {
    final sub = subjectOf(q.subject);
    final answered = selected != null;

    // सूची-मिलान वाले प्रश्न में ऊपर सिर्फ़ पहली पंक्ति दिखती है — दोनों
    // सूचियाँ नीचे सारणी में हैं. `question` में वे सादे पाठ में भी पड़ी
    // हैं (पुरानी APK के लिए), पर यहाँ छापने से दो बार दिख जातीं.
    final head = (q.match?.intro.isNotEmpty ?? false) ? q.match!.intro : q.question;

    return TweenAnimationBuilder<double>(
      key: ValueKey('card-${q.id}-${selected ?? -1}'),
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 340),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, (1 - t) * 22), child: child),
      ),
      child: _ScrollChain(
        onNext: onNext,
        onPrev: onPrev,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // प्रश्न का अपना कार्ड. पहले प्रश्न और विकल्प एक ही डिब्बे में
              // थे — लंबे प्रश्न में पता ही नहीं चलता था कि पढ़ना कहाँ ख़त्म
              // हुआ और चुनना कहाँ से शुरू. अब दोनों अलग-अलग कार्ड हैं.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [sub.color.withOpacity(0.14), P.card],
                    stops: const [0.0, 0.85],
                  ),
                  border: Border.all(color: sub.color.withOpacity(0.18)),
                  boxShadow: [
                    BoxShadow(
                      color: sub.color.withOpacity(0.10),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Text.rich(
                  TextSpan(children: [
                    _chip('Q.$number', sub.color),
                    // PYQ का ठप्पा — "यह सचमुच परीक्षा में आया था" वाली बात
                    // छात्र को पहली नज़र में दिखनी चाहिए. सोना, ताकि विषय के
                    // रंग वाले Q.N से अलग पढ़ा जाए.
                    if (q.year != null) _chip('${q.year}', P.gold),
                    TextSpan(text: _tight(head)),
                  ]),
                  style: TextStyle(
                    // लंबे प्रश्न के अक्षर थोड़े छोटे, ताकि पूरा एक साथ दिखे.
                    // छोटे प्रश्न बड़े — छात्र फ़ोन हाथ में लेकर पढ़ता है,
                    // और यही स्क्रीन वह घंटों देखेगा.
                    fontSize: head.length > 300
                        ? 17.0
                        : head.length > 160
                            ? 18.5
                            : 21.0,
                    height: 1.42,
                    fontWeight: FontWeight.w600,
                    color: P.ink,
                  ),
                ),
              ),

              // सूची-मिलान वाले प्रश्न — दोनों सूचियाँ आमने-सामने
              if (q.match != null) ...[
                const SizedBox(height: 10),
                _matchTable(sub.color),
              ],

              const SizedBox(height: 10),

              // विकल्पों का अलग कार्ड — व्याख्या भी इसी के भीतर खुलती है
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 2),
                decoration: BoxDecoration(
                  color: P.card,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: sub.color.withOpacity(0.14)),
                  boxShadow: [
                    BoxShadow(
                      color: sub.color.withOpacity(0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // विकल्प दो-दो की कतार में — अ ब ऊपर, स द नीचे.
                    //
                    // चारों एक के नीचे एक रखने से आधी स्क्रीन इन्हीं में
                    // चली जाती थी और लंबे प्रश्न में विकल्प दिखते ही नहीं
                    // थे. दो कतारों में वही जगह आधी रह जाती है.
                    //
                    // IntrinsicHeight इसलिए कि एक विकल्प दो लाइन का हो और
                    // दूसरा एक लाइन का, तो भी दोनों डिब्बे बराबर ऊँचाई के
                    // दिखें — वरना कतार टेढ़ी लगती है.
                    for (int i = 0; i < q.options.length; i += 2)
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: _option(i, answered)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: i + 1 < q.options.length
                                  ? _option(i + 1, answered)
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: answered && q.explanation.isNotEmpty
                          ? _explanation(selected == q.answer)
                          : const SizedBox(width: double.infinity, height: 0),
                    ),
                  ],
                ),
              ),
              if (showHint && !answered) ...[
                const SizedBox(height: 12),
                _hint(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// प्रश्न का पाठ कसकर — खाली लाइनें हटाकर.
  ///
  /// गद्यांश और सारणी वाले प्रश्नों में दो-दो खाली लाइनें आती हैं. काग़ज़
  /// पर वे ठीक लगती हैं, पर फ़ोन की छोटी स्क्रीन पर आधा पन्ना खा जाती हैं
  /// और विकल्प नीचे धकेल देती हैं.
  static String _tight(String s) =>
      s.replaceAll(RegExp(r'[ \t]*\n[ \t]*\n+'), '\n').trim();

  /// सूची-I और सूची-II की सारणी — जैसी प्रश्नपत्र में छपती है.
  ///
  /// दोनों सूचियाँ बराबर चौड़ाई की हैं और हर कतार एक ही ऊँचाई की, ताकि
  /// "A" के सामने "1" ही पड़े. लंबी प्रविष्टियाँ अपने ख़ाने में ही लिपट
  /// जाती हैं — कतार टेढ़ी नहीं होती.
  Widget _matchTable(Color accent) {
    final m = q.match!;
    final line = accent.withOpacity(0.22);

    // बहुत लंबी प्रविष्टियों में अक्षर थोड़े छोटे — वरना चार-चार लाइनें
    // बन जाती हैं और सारणी पूरी स्क्रीन ले लेती है.
    final longest = [...m.left, ...m.right]
        .fold<int>(0, (a, b) => b.length > a ? b.length : a);
    final size = longest > 34 ? 13.0 : (longest > 22 ? 14.0 : 15.0);

    Widget cell(String text, {required bool head}) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Text(
            text,
            style: TextStyle(
              fontSize: head ? 13.0 : size,
              height: 1.32,
              fontWeight: head ? FontWeight.w700 : FontWeight.w500,
              color: head ? accent : P.ink,
            ),
          ),
        );

    Widget row(String l, String r, {bool head = false}) =>
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: cell(l, head: head)),
              Container(width: 1, color: line),
              Expanded(child: cell(r, head: head)),
            ],
          ),
        );

    final children = <Widget>[
      Container(
        color: accent.withOpacity(0.10),
        child: row(m.leftTitle, m.rightTitle, head: true),
      ),
    ];
    for (int i = 0; i < m.rows; i++) {
      children.add(Container(height: 1, color: line));
      children.add(row(
        i < m.left.length ? m.left[i] : '',
        i < m.right.length ? m.right[i] : '',
      ));
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: P.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  Widget _option(int i, bool answered) {
    final isAnswer = i == q.answer;
    final isPicked = selected == i;

    Color border = P.line;
    Color bg = P.card;
    Color bubble = P.card;
    Color bubbleBorder = P.line;
    Color letterColor = P.muted;
    Color textColor = P.ink;
    FontWeight weight = FontWeight.w500;

    if (answered) {
      if (isAnswer) {
        border = P.right;
        bg = P.right.withOpacity(0.07);
        bubble = P.right;
        bubbleBorder = P.right;
        letterColor = Colors.white;
        textColor = P.right;
        weight = FontWeight.w700;
      } else if (isPicked) {
        border = P.wrong;
        bg = P.wrong.withOpacity(0.06);
        bubble = P.wrong;
        bubbleBorder = P.wrong;
        letterColor = Colors.white;
        textColor = P.wrong;
        weight = FontWeight.w600;
      } else {
        textColor = P.muted;
      }
    }

    final letter = i < kLetters.length ? kLetters[i] : '${i + 1}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: answered ? null : () => onSelect(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            // आधी चौड़ाई में आने के बाद हाशिया थोड़ा कसा — फिर भी
            // ऊपर-नीचे 11 + 24 का गोला मिलाकर उँगली लायक़ घेरा बनता है.
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                  color: border,
                  width: answered && (isAnswer || isPicked) ? 1.5 : 1),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutBack,
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: bubble,
                    shape: BoxShape.circle,
                    border: Border.all(color: bubbleBorder, width: 1.4),
                  ),
                  child: Text(letter,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: letterColor)),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    q.options[i],
                    style: TextStyle(
                        // विकल्प थोड़े बड़े — फ़ोन हाथ में लेकर पढ़ने लायक,
                        // और लाइनों के बीच खुली जगह ताकि देवनागरी की
                        // मात्राएँ आपस में न चिपकें.
                        fontSize: 14.5,
                        height: 1.35,
                        fontWeight: weight,
                        color: textColor),
                  ),
                ),
                if (answered && isAnswer)
                  const Icon(Icons.check_circle, size: 16, color: P.right),
                if (answered && isPicked && !isAnswer)
                  const Icon(Icons.cancel, size: 16, color: P.wrong),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// व्याख्या में तरकीब की शुरुआत बताने वाला निशान.
  ///
  /// प्रश्न बनाते समय व्याख्या के अंत में `ट्रिक:` लिखकर हल का तरीक़ा
  /// जोड़ा जाता है. जिन प्रश्नों में यह नहीं है, वहाँ कुछ नहीं बदलता.
  static const String _trickTag = 'ट्रिक:';

  /// प्रश्न के पाठ से पहले लगने वाला छोटा ठप्पा — Q.N और PYQ का वर्ष.
  /// पाठ के बीच में बैठता है, इसलिए WidgetSpan.
  static InlineSpan _chip(String text, Color color) => WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Padding(
          padding: const EdgeInsets.only(right: 8, bottom: 3),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.13),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              text,
              style: TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w700, color: color),
            ),
          ),
        ),
      );

  Widget _explanation(bool correct) {
    final c = correct ? P.right : P.wrong;

    final at = q.explanation.indexOf(_trickTag);
    final body = at < 0 ? q.explanation.trim() : q.explanation.substring(0, at).trim();
    final trick =
        at < 0 ? '' : q.explanation.substring(at + _trickTag.length).trim();

    final letter =
        q.answer < kLetters.length ? kLetters[q.answer] : '${q.answer + 1}';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: c.withOpacity(0.06),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(14),
          bottomRight: Radius.circular(14),
          topLeft: Radius.circular(4),
          bottomLeft: Radius.circular(4),
        ),
        border: Border(left: BorderSide(color: c, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(correct ? Icons.check_circle : Icons.lightbulb,
                  size: 15, color: c),
              const SizedBox(width: 6),
              Text(
                correct ? 'सही! शाबाश' : 'सही जवाब — $letter',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                    color: c),
              ),
            ],
          ),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 7),
            // व्याख्या बड़ी और खुली — यही वह हिस्सा है जिससे छात्र सीखता है,
            // इसलिए इसे पढ़ने में सबसे आसान होना चाहिए.
            Text(body,
                style: TextStyle(
                    fontSize: 15, height: 1.65, color: P.ink.withOpacity(0.82))),
          ],

          // हल की तरकीब — गणित और तर्कशक्ति के लिए.
          //
          // इन विषयों में सही जवाब जान लेने से कुछ नहीं मिलता; अगली बार
          // वही सवाल दूसरे अंकों के साथ आएगा. इसलिए तरकीब को व्याख्या से
          // अलग, अपने डिब्बे में रखते हैं ताकि आँख वहीं टिके.
          if (trick.isNotEmpty) ...[
            const SizedBox(height: 9),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(11, 9, 11, 10),
              decoration: BoxDecoration(
                color: P.gold.withOpacity(0.09),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: P.gold.withOpacity(0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.lightbulb_outline,
                          size: 15, color: P.gold),
                      const SizedBox(width: 5),
                      Text('तरकीब',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                            color: P.gold,
                          )),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(trick,
                      style: TextStyle(
                          fontSize: 14.5,
                          height: 1.6,
                          color: P.ink.withOpacity(0.86))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _hint() => Row(
        children: [
          Icon(Icons.swipe_up_alt_outlined,
              size: 16, color: P.muted.withOpacity(0.85)),
          const SizedBox(width: 6),
          Text('जवाब चुनिए · अगले सवाल के लिए ऊपर सरकाइए',
              style: TextStyle(fontSize: 12.5, color: P.muted.withOpacity(0.9))),
        ],
      );
}
