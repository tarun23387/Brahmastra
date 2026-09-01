import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prashn_reel/auth.dart';
import 'package:prashn_reel/exams.dart';
import 'package:prashn_reel/models.dart';
import 'package:prashn_reel/question_card.dart';

void main() {
  group('Question.fromMap — ख़राब प्रश्न रुकने चाहिए', () {
    Map<String, dynamic> good() => {
          'subject': 'itihas',
          'question': 'भारत छोड़ो आंदोलन कब शुरू हुआ?',
          'options': ['1940', '1942', '1944', '1946'],
          'answer': 1,
          'explanation': 'अगस्त 1942.',
        };

    test('सही प्रश्न बनता है', () {
      final q = Question.fromMap('t1', good());
      expect(q, isNotNull);
      expect(q!.answer, 1);
      expect(q.options.length, 4);
      expect(q.subject, 'itihas');
    });

    test('खाली प्रश्न रुकता है', () {
      final q = Question.fromMap('t2', good()..['question'] = '   ');
      expect(q, isNull);
    });

    test('answer सीमा से बाहर हो तो रुकता है', () {
      expect(Question.fromMap('t3', good()..['answer'] = 4), isNull);
      expect(Question.fromMap('t4', good()..['answer'] = -1), isNull);
    });

    test('विकल्प दो से कम हों तो रुकता है', () {
      final q = Question.fromMap('t5', good()..['options'] = ['सिर्फ़ एक']);
      expect(q, isNull);
    });

    test('options सूची न हो तो रुकता है', () {
      expect(Question.fromMap('t6', good()..['options'] = 'नहीं सूची'), isNull);
    });

    test('answer टेक्स्ट में आए तो भी पढ़ लेता है', () {
      final q = Question.fromMap('t7', good()..['answer'] = '2');
      expect(q?.answer, 2);
    });

    test('अनजान विषय ca बन जाता है', () {
      final q = Question.fromMap('t8', good()..['subject'] = 'kuch-bhi');
      expect(q?.subject, 'ca');
    });
  });

  group('PYQ का वर्ष — ठप्पा इसी से लगता है', () {
    Map<String, dynamic> good() => {
          'subject': 'itihas',
          'question': 'हाथीगुम्फा अभिलेख किस शासक से जुड़ा है?',
          'options': ['खारवेल', 'अशोक', 'हर्षवर्धन', 'कनिष्क'],
          'answer': 0,
          'explanation': 'उदयगिरि, ओडिशा.',
        };

    test('वर्ष दिया हो तो पढ़ लेता है', () {
      final q = Question.fromMap('y1', good()..['year'] = 2018);
      expect(q?.year, 2018);
    });

    test('वर्ष टेक्स्ट में आए तो भी पढ़ लेता है', () {
      final q = Question.fromMap('y2', good()..['year'] = '2023');
      expect(q?.year, 2023);
    });

    // पुराने कैश और बिना-वर्ष वाले प्रश्नों का रास्ता — प्रश्न बनना चाहिए,
    // बस ठप्पा नहीं दिखेगा.
    test('वर्ष न हो तो प्रश्न फिर भी बनता है', () {
      final q = Question.fromMap('y3', good());
      expect(q, isNotNull);
      expect(q!.year, isNull);
    });

    test('बेतुका वर्ष चुपचाप गिर जाता है, प्रश्न नहीं रुकता', () {
      for (final bad in [1800, 3000, 'कुछ भी', '']) {
        final q = Question.fromMap('y4', good()..['year'] = bad);
        expect(q, isNotNull, reason: 'year=$bad पर प्रश्न रुकना नहीं चाहिए');
        expect(q!.year, isNull, reason: 'year=$bad स्वीकार नहीं होना चाहिए');
      }
    });

    // कैश यही रास्ता लेता है — toMap से लिखा, fromMap से पढ़ा.
    test('कैश में जाकर वापस आने पर वर्ष बचा रहता है', () {
      final q = Question.fromMap('y5', good()..['year'] = 2014);
      final back = Question.fromMap('y5', q!.toMap());
      expect(back?.year, 2014);
    });

    test('वर्ष न हो तो toMap में फ़ील्ड जाती ही नहीं', () {
      final q = Question.fromMap('y6', good());
      expect(q!.toMap().containsKey('year'), isFalse);
    });

    // कार्ड पर ठप्पा सचमुच छपता है या नहीं — मॉडल तक सही होना काफ़ी नहीं.
    Widget card(Question q) => MaterialApp(
          home: Scaffold(
            body: QuestionCard(
              q: q,
              number: 1,
              total: 1,
              selected: null,
              onSelect: (_) {},
            ),
          ),
        );

    testWidgets('वर्ष हो तो कार्ड पर ठप्पा दिखता है', (tester) async {
      await tester.pumpWidget(card(Question.fromMap('y7', good()..['year'] = 2018)!));
      expect(find.text('2018'), findsOneWidget);
      expect(find.text('Q.1'), findsOneWidget);
    });

    testWidgets('वर्ष न हो तो सिर्फ़ Q.N दिखता है', (tester) async {
      await tester.pumpWidget(card(Question.fromMap('y8', good())!));
      expect(find.text('Q.1'), findsOneWidget);
      expect(find.textContaining(RegExp(r'^\d{4}$')), findsNothing);
    });
  });

  group('Entitlement — हर परीक्षा की अपनी अवधि', () {
    Entitlement make(Map<String, DateTime?> exams, {bool active = true}) =>
        Entitlement(
          uid: 'u1',
          name: 'टेस्ट',
          phone: '',
          courses: exams.map((k, v) =>
              MapEntry(k, Course(examId: k, expiresAt: v))),
          active: active,
        );

    final future = DateTime.now().add(const Duration(days: 20));
    final past = DateTime.now().subtract(const Duration(days: 1));

    test('आगे की तारीख़ = चालू', () {
      final e = make({'roaro': future});
      expect(e.isSubscribed, isTrue);
      expect(e.daysLeft, greaterThan(18));
      expect(e.canAccessExam('roaro'), isTrue);
    });

    test('बीती तारीख़ = बंद', () {
      final e = make({'roaro': past});
      expect(e.isSubscribed, isFalse);
      expect(e.canAccessExam('roaro'), isFalse);
      expect(e.expiredCourses.length, 1);
    });

    test('एक परीक्षा चालू, दूसरी ख़त्म — दोनों अलग-अलग', () {
      final e = make({'roaro': future, 'uppcs': past});
      expect(e.isSubscribed, isTrue);
      expect(e.canAccessExam('roaro'), isTrue);
      expect(e.canAccessExam('uppcs'), isFalse);
      expect(e.activeCourses.length, 1);
      expect(e.expiredCourses.length, 1);
    });

    test('दिन उसी के गिनते हैं जो पहले ख़त्म हो रही है', () {
      final soon = DateTime.now().add(const Duration(days: 3));
      final e = make({'roaro': future, 'uppcs': soon});
      expect(e.daysLeft, lessThanOrEqualTo(3));
      expect(e.isExpiringSoon, isTrue);
    });

    test('खाता बंद हो तो तारीख़ आगे होने पर भी कुछ नहीं खुलता', () {
      final e = make({'roaro': future}, active: false);
      expect(e.isSubscribed, isFalse);
      expect(e.canAccessExam('roaro'), isFalse);
    });

    test('प्रश्नपत्र उसी परीक्षा का खुलता है जो ली हुई है', () {
      final e = make({'roaro': future});
      expect(e.canAccessPaper('roaro-gs'), isTrue);
      expect(e.canAccessPaper('roaro-hindi'), isTrue);
      expect(e.canAccessPaper('uppcs-gs1'), isFalse);
    });

    test('बिना सदस्यता वाला कुछ नहीं खोल सकता', () {
      expect(Entitlement.none.isSubscribed, isFalse);
      expect(Entitlement.none.canAccessPaper('roaro-gs'), isFalse);
      expect(Entitlement.none.activeCourses, isEmpty);
    });

    test('पुराने रूप वाला doc भी पढ़ लेता है', () {
      final e = Entitlement.fromDoc('u1', {
        'name': 'पुराना',
        'active': true,
        'exams': ['roaro', 'uppcs'],
        'expiresAt': Timestamp.fromDate(future),
      });
      expect(e.isSubscribed, isTrue);
      expect(e.canAccessExam('roaro'), isTrue);
      expect(e.canAccessExam('uppcs'), isTrue);
    });
  });

  group('परीक्षा की सूची', () {
    test('तीनों परीक्षाएँ मौजूद हैं', () {
      expect(kExams.keys, containsAll(['uppcs', 'roaro', 'pet']));
    });

    test('हर परीक्षा के पेपर सचमुच बने हुए हैं', () {
      for (final exam in kExams.values) {
        for (final pid in exam.paperIds) {
          expect(kPapers[pid], isNotNull, reason: '$pid नहीं मिला');
          expect(kPapers[pid]!.examId, exam.id);
        }
      }
    });

    test('हर पेपर के विषय पहचाने हुए हैं', () {
      for (final p in kPapers.values) {
        for (final s in p.subjects) {
          final known =
              kSubjects.containsKey(s) || kNewSubjectColors.containsKey(s);
          expect(known, isTrue, reason: '${p.id} में अनजान विषय "$s"');
        }
      }
    });

    test('विषय-से-पेपर नक्शा सही पेपरों पर जाता है', () {
      for (final entry in kSubjectToPapers.entries) {
        for (final pid in entry.value) {
          expect(kPapers[pid], isNotNull,
              reason: '${entry.key} → $pid नहीं मिला');
        }
      }
    });
  });
}
