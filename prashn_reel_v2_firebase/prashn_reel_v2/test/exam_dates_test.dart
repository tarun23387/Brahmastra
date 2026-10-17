import 'package:flutter_test/flutter_test.dart';
import 'package:prashn_reel/exam_dates.dart';

void main() {
  DateTime d(String s) => DateTime.parse(s);
  final today = d('2026-10-17');

  ExamStage? stage(ExamDate e) {
    ExamDates.setForTest({'x': e});
    return ExamDates.stageOf('x', now: today);
  }

  test('अधिसूचना आगे की — संभावित', () {
    final s = stage(ExamDate(notif: d('2026-11-15')));
    expect(s!.label, 'अधिसूचना (संभावित)');
    expect(s.value, '15 नव॰ 2026');
  });

  test('अधिसूचना जारी, आवेदन चालू — अंतिम तिथि', () {
    final s = stage(ExamDate(
        notif: d('2026-10-01'), lastDate: d('2026-10-30'), exam: d('2026-12-20')));
    expect(s!.label, 'अधिसूचना 1 अक्टू॰ जारी');
    expect(s.value, 'अंतिम तिथि 30 अक्टू॰');
    expect(s.urgent, isFalse);
  });

  test('अंतिम तिथि 7 दिन के भीतर — urgent', () {
    final s = stage(ExamDate(notif: d('2026-10-01'), lastDate: d('2026-10-20')));
    expect(s!.urgent, isTrue);
  });

  test('आवेदन बंद, परीक्षा तय — बचे दिन (UP PET)', () {
    final s = stage(ExamDate(
        notif: d('2026-08-01'), lastDate: d('2026-09-07'), exam: d('2026-10-25')));
    expect(s!.label, 'परीक्षा 25 अक्टू॰');
    expect(s.value, '8 दिन बाक़ी');
  });

  test('UPPCS — 50 दिन', () {
    final s = stage(ExamDate(
        notif: d('2026-06-25'), lastDate: d('2026-08-03'), exam: d('2026-12-06')));
    expect(s!.value, '50 दिन बाक़ी');
  });

  test('आज और कल', () {
    expect(stage(ExamDate(exam: today))!.value, 'आज परीक्षा है');
    expect(stage(ExamDate(exam: d('2026-10-18')))!.value, 'कल परीक्षा है');
  });

  test('आवेदन बंद, परीक्षा तिथि नहीं (अधिसूचना तारीख़ भी नहीं)', () {
    final s = stage(ExamDate(lastDate: d('2026-09-03')));
    expect(s!.label, 'आवेदन बंद');
    expect(s.value, 'परीक्षा तिथि जल्द');
  });

  test('परीक्षा हो चुकी — कुछ नहीं', () {
    expect(
        stage(ExamDate(
            notif: d('2026-01-01'), lastDate: d('2026-02-01'), exam: d('2026-10-01'))),
        isNull);
  });

  test('कुछ नहीं पता — कुछ नहीं', () {
    expect(stage(const ExamDate()), isNull);
    ExamDates.setForTest({});
    expect(ExamDates.stageOf('roaro', now: today), isNull);
  });
}
