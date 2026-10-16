import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../engage.dart';
import '../models.dart';
import '../question_card.dart';

/// अकेला एक प्रश्न — notification छूने पर या "आज का प्रश्न" से.
///
/// यहाँ से छात्र पूरे अभ्यास में जाए, यही असली मक़सद है. इसलिए उत्तर
/// देते ही नीचे "और प्रश्न" का बड़ा बटन उभरता है.
class QuickQuestionPage extends StatefulWidget {
  final Question q;
  final String title;

  const QuickQuestionPage({
    super.key,
    required this.q,
    this.title = 'आज का प्रश्न',
  });

  @override
  State<QuickQuestionPage> createState() => _QuickQuestionPageState();
}

class _QuickQuestionPageState extends State<QuickQuestionPage> {
  int? _selected;

  void _select(int opt) {
    if (_selected != null) return;
    setState(() => _selected = opt);
    Engage.recordAnswer();
  }

  @override
  Widget build(BuildContext context) {
    final right = _selected != null && _selected == widget.q.answer;

    return Scaffold(
      backgroundColor: P.bg,
      appBar: AppBar(
        backgroundColor: P.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(widget.title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: QuestionCard(
                q: widget.q,
                number: 1,
                total: 1,
                selected: _selected,
                onSelect: _select,
              ),
            ),
            if (_selected != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      right
                          ? '🎉 सही! ऐसे ही ${Engage.dailyGoal} प्रश्न रोज़ — लय बनी रहेगी'
                          : 'कोई बात नहीं — अगला प्रश्न सही होगा 💪',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: right ? P.right : P.muted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        style: FilledButton.styleFrom(
                          backgroundColor: P.brand,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const FaIcon(FontAwesomeIcons.bolt, size: 15),
                        label: const Text('और प्रश्न हल करें',
                            style: TextStyle(
                                fontSize: 15.5, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              )
                  .animate()
                  .fadeIn(duration: 300.ms)
                  .slideY(begin: 0.3, end: 0, curve: Curves.easeOutCubic),
          ],
        ),
      ),
    );
  }
}
