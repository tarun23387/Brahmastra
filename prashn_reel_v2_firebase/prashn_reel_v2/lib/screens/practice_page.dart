import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../models.dart';
import '../question_card.dart';
import '../repository.dart';

/// एक अध्याय पढ़ने के बाद उसी अध्याय के प्रश्नों का अभ्यास.
///
/// प्रश्न अलग से नहीं उतरते: प्रश्नपत्र के जो प्रश्न होम के लिए पहले से कैश
/// में हैं (packs से), उन्हीं में से अध्याय की ids छाँटी जाती हैं. इसलिए यहाँ
/// कोई नई Firestore read नहीं लगती, और बिना इंटरनेट भी अभ्यास चलता है.
///
/// उत्तर यहाँ के सत्र तक ही रहते हैं; होम के उत्तरों (AnswerStore) में नहीं
/// मिलाए जाते, ताकि अभ्यास दोबारा करने पर प्रश्न फिर से ख़ाली मिलें.
class PracticePage extends StatefulWidget {
  final String paperId;
  final List<String> ids;
  final String title;
  final Color accent;

  const PracticePage({
    super.key,
    required this.paperId,
    required this.ids,
    required this.title,
    required this.accent,
  });

  @override
  State<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage> {
  final pc = PageController();
  List<Question> _qs = [];
  bool _loading = true;
  final Map<String, int> _answers = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    pc.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final res = await QuestionRepo.load(paperId: widget.paperId);
    final byId = {for (final q in res.questions) q.id: q};
    if (!mounted) return;
    setState(() {
      _qs = [for (final id in widget.ids) if (byId[id] != null) byId[id]!];
      _loading = false;
    });
  }

  void _jump(int delta) {
    if (!pc.hasClients) return;
    final page = (pc.page ?? 0).round() + delta;
    if (page < 0 || page > _qs.length) return;
    pc.animateToPage(page,
        duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: P.bg,
      appBar: AppBar(
        backgroundColor: P.card,
        surfaceTintColor: P.card,
        elevation: 0,
        title: Text('अभ्यास · ${widget.title}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        leading: IconButton(
          icon: const FaIcon(FontAwesomeIcons.arrowLeft, size: 17),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2.4))
            : _qs.isEmpty
                ? _empty()
                : PageView.builder(
                    controller: pc,
                    scrollDirection: Axis.vertical,
                    itemCount: _qs.length + 1,
                    itemBuilder: (context, page) {
                      if (page == _qs.length) return _summary();
                      final q = _qs[page];
                      return QuestionCard(
                        q: q,
                        number: page + 1,
                        total: _qs.length,
                        selected: _answers[q.id],
                        onSelect: (opt) {
                          if (_answers.containsKey(q.id)) return;
                          setState(() => _answers[q.id] = opt);
                        },
                        showHint: page == 0,
                        onNext: () => _jump(1),
                        onPrev: page == 0 ? null : () => _jump(-1),
                      );
                    },
                  ),
      ),
    );
  }

  /// प्रश्न कैश में न मिलें — आम तौर पर तब, जब होम पर यह प्रश्नपत्र अभी
  /// एक बार भी नहीं खुला या सिंक नहीं हुआ.
  Widget _empty() => Padding(
        padding: const EdgeInsets.all(28),
        child: Center(
          child: Text(
            'इस अध्याय के प्रश्न अभी फ़ोन में नहीं हैं।\n'
            'होम पर जाकर एक बार प्रश्न सिंक कीजिए, फिर यहाँ लौटिए।',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, height: 1.6, color: P.muted),
          ),
        ),
      );

  Widget _summary() {
    final done = _answers.length;
    final right = _qs.where((q) => _answers[q.id] == q.answer).length;
    final pct = done == 0 ? 0 : (right * 100 / done).round();
    final wrong = _qs.where((q) => _answers.containsKey(q.id) && _answers[q.id] != q.answer).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 30, 22, 40),
      children: [
        Text('अभ्यास का नतीजा',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w800, color: widget.accent)),
        const SizedBox(height: 10),
        Text('$right / $done सही',
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(
          done < _qs.length
              ? '${_qs.length} में से $done प्रश्न किए · $pct%'
              : 'सारे ${_qs.length} प्रश्न किए · $pct%',
          style: TextStyle(fontSize: 14, color: P.muted),
        ),
        const SizedBox(height: 18),
        Text(
          pct >= 80
              ? 'बहुत अच्छा। यह अध्याय पक्का है; अगले अध्याय पर चलिए।'
              : 'ग़लत हुए प्रश्नों की व्याख्या पढ़िए और अध्याय एक बार फिर देखिए; '
                  'ख़ास तौर पर उसकी सारणियाँ।',
          style: const TextStyle(fontSize: 15, height: 1.6, color: P.ink),
        ),
        if (wrong.isNotEmpty) ...[
          const SizedBox(height: 22),
          Text('ग़लत हुए प्रश्न',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800, color: widget.accent)),
          const SizedBox(height: 8),
          for (final q in wrong)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () => pc.animateToPage(_qs.indexOf(q),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic),
                child: Text('Q.${_qs.indexOf(q) + 1}  ${q.question.split('\n').first}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, height: 1.5, color: P.ink)),
              ),
            ),
        ],
        const SizedBox(height: 26),
        OutlinedButton(
          onPressed: () {
            setState(_answers.clear);
            pc.jumpToPage(0);
          },
          child: const Text('फिर से अभ्यास करें'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('अध्याय पर लौटें'),
        ),
      ],
    );
  }
}
