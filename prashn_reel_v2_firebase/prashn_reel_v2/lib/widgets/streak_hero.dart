import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../engage.dart';
import '../models.dart';
import '../reminders.dart';
import '../screens/quick_question_page.dart';

/// डैशबोर्ड का सबसे ऊपर का हिस्सा — 🔥 लय, आज का लक्ष्य, हफ़्ता.
///
/// छात्र को लौटाने वाली चीज़ यही है: एक गिनती जो रोज़ बढ़ती है और एक दिन
/// छूटते ही शून्य हो जाती है. इसलिए यह पन्ने पर सबसे बड़ी और सबसे गहरी
/// चीज़ है, बाक़ी सब हल्का.
class StreakHero extends StatelessWidget {
  const StreakHero({super.key});

  static const _days = ['र', 'सो', 'मं', 'बु', 'गु', 'शु', 'श'];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: Engage.changes,
      builder: (context, _, __) {
        final streak = Engage.streak;
        final done = Engage.todayCount;
        final goal = Engage.dailyGoal;
        final week = Engage.lastWeek();
        final now = DateTime.now();

        return Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [P.brand, P.brandDeep],
            ),
            boxShadow: [
              BoxShadow(
                color: P.brand.withOpacity(0.35),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  // ── 🔥 लय ── (देर तक दबाने पर प्रश्न-घंटी की जाँच)
                  GestureDetector(
                    onLongPress: () async {
                      await Reminders.askOnce();
                      final ok = await Reminders.testNow();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(ok
                            ? 'प्रश्न-घंटी भेजी — ऊपर notification देखिए'
                            : 'घंटी नहीं चल पाई — Settings में notification की अनुमति देखिए'),
                      ));
                    },
                    child: _Flame(lit: Engage.doneToday),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: streak.toDouble()),
                          duration: const Duration(milliseconds: 900),
                          curve: Curves.easeOutCubic,
                          builder: (_, v, __) => Text(
                            '${v.round()} दिन',
                            style: const TextStyle(
                              fontSize: 30,
                              height: 1.05,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Text(
                          streak == 0
                              ? 'आज एक प्रश्न से लय शुरू कीजिए'
                              : Engage.doneToday
                                  ? 'लगातार अभ्यास — आज की लय पक्की ✓'
                                  : 'लगातार — आज एक प्रश्न, वरना लय टूटेगी',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.white.withOpacity(0.82),
                          ),
                        ),
                        if (Engage.bestStreak > 1)
                          Text(
                            'सबसे लंबी लय: ${Engage.bestStreak} दिन',
                            style: TextStyle(
                              fontSize: 11,
                              color: const Color(0xFFF2CF6E).withOpacity(0.9),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // ── आज का लक्ष्य ──
                  _GoalRing(done: done, goal: goal),
                ],
              ),
              const SizedBox(height: 16),

              // ── हफ़्ता ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (int i = 0; i < 7; i++)
                    _DayDot(
                      label: _days[now.subtract(Duration(days: 6 - i)).weekday % 7],
                      done: week[i],
                      today: i == 6,
                    )
                        .animate(delay: (60 * i).ms)
                        .fadeIn(duration: 250.ms)
                        .scale(begin: const Offset(0.6, 0.6)),
                ],
              ),
            ],
          ),
        ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.08, end: 0);
      },
    );
  }
}

class _Flame extends StatelessWidget {
  final bool lit;
  const _Flame({required this.lit});

  @override
  Widget build(BuildContext context) {
    final flame = Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(lit ? 0.16 : 0.08),
      ),
      child: Center(
        child: FaIcon(
          FontAwesomeIcons.fire,
          size: 26,
          color: lit ? const Color(0xFFFFB547) : Colors.white.withOpacity(0.45),
        ),
      ),
    );
    if (!lit) {
      // बुझी आग धीरे-धीरे धड़कती है — "मुझे जलाइए"
      return flame
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scale(
            begin: const Offset(1, 1),
            end: const Offset(1.08, 1.08),
            duration: 900.ms,
            curve: Curves.easeInOut,
          );
    }
    return flame
        .animate(onPlay: (c) => c.repeat())
        .shimmer(duration: 2200.ms, color: const Color(0xFFFFE08A));
  }
}

class _GoalRing extends StatelessWidget {
  final int done;
  final int goal;
  const _GoalRing({required this.done, required this.goal});

  @override
  Widget build(BuildContext context) {
    final t = min(done / goal, 1.0);
    return SizedBox(
      width: 72,
      height: 72,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: t),
        duration: const Duration(milliseconds: 1000),
        curve: Curves.easeOutCubic,
        builder: (_, v, __) => Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.expand(
              child: CircularProgressIndicator(
                value: v,
                strokeWidth: 6.5,
                strokeCap: StrokeCap.round,
                backgroundColor: Colors.white.withOpacity(0.14),
                valueColor: AlwaysStoppedAnimation(
                  t >= 1 ? const Color(0xFF7BE0A8) : const Color(0xFFF2CF6E),
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t >= 1 ? '✓' : '$done',
                  style: const TextStyle(
                    fontSize: 19,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  t >= 1 ? 'लक्ष्य पूरा' : '/$goal आज',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.75),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  final String label;
  final bool done;
  final bool today;
  const _DayDot({required this.label, required this.done, required this.today});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done
                ? const Color(0xFFF2CF6E)
                : Colors.white.withOpacity(0.10),
            border: today
                ? Border.all(color: Colors.white.withOpacity(0.85), width: 1.6)
                : null,
          ),
          child: Center(
            child: done
                ? const FaIcon(FontAwesomeIcons.fire,
                    size: 13, color: P.brandDeep)
                : null,
          ),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: today ? FontWeight.w800 : FontWeight.w500,
              color: Colors.white.withOpacity(today ? 0.95 : 0.65),
            )),
      ],
    );
  }
}

/// "आज का प्रश्न" — रोज़ बदलता है, छूते ही खुलता है.
class DailyQuestionCard extends StatelessWidget {
  const DailyQuestionCard({super.key});

  @override
  Widget build(BuildContext context) {
    final q = Engage.questionOfDay();
    if (q == null) return const SizedBox.shrink();
    final sub = subjectOf(q.subject);

    // हल होते ही कार्ड बदले — इसलिए Engage.changes सुनते हैं
    return ValueListenableBuilder<int>(
      valueListenable: Engage.changes,
      builder: (context, _, __) => _card(context, q, sub, Engage.dailyChoice),
    ).animate(delay: 150.ms).fadeIn(duration: 350.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _card(BuildContext context, Question q, Subject sub, int? choice) {
    final done = choice != null;
    final right = choice == q.answer;
    final accent = !done ? P.gold : (right ? P.right : P.wrong);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => QuickQuestionPage(q: q, daily: true),
        )),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: P.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent.withOpacity(0.45), width: 1.3),
            boxShadow: [
              BoxShadow(
                color: accent.withOpacity(0.14),
                blurRadius: 16,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // नीचे की पंक्ति पहले ही बताती है कि हल हुआ — ऊपर
                  // बस सही/ग़लत का निशान, दोहरा ✓ नहीं
                  FaIcon(
                      !done
                          ? FontAwesomeIcons.solidLightbulb
                          : right
                              ? FontAwesomeIcons.check
                              : FontAwesomeIcons.xmark,
                      size: 14,
                      color: accent),
                  const SizedBox(width: 8),
                  Text('आज का प्रश्न',
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: accent)),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: sub.color.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(sub.label,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: sub.color)),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Text(
                q.question,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 15, height: 1.45, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              if (!done)
                Row(
                  children: [
                    Text('छूकर उत्तर दीजिए',
                        style: TextStyle(fontSize: 12, color: P.muted)),
                    const SizedBox(width: 6),
                    FaIcon(FontAwesomeIcons.arrowRight,
                            size: 11, color: P.muted)
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .moveX(begin: 0, end: 5, duration: 700.ms),
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: FaIcon(
                          right
                              ? FontAwesomeIcons.solidCircleCheck
                              : FontAwesomeIcons.solidCircleXmark,
                          size: 13,
                          color: accent),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        right
                            ? 'हल हो गया — सही उत्तर! कल नया प्रश्न'
                            : 'हल हो गया — सही उत्तर: '
                                '(${kLetters[q.answer]}) ${q.options[q.answer]}',
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: accent),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
