import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  studyDayShift();
  test('FixedClock は差し替えた時刻を返す', () {
    final c = FixedClock(DateTime(2026, 1, 1));
    expect(c.now(), DateTime(2026, 1, 1));
    c.current = DateTime(2026, 1, 2);
    expect(c.now(), DateTime(2026, 1, 2));
    expect(const SystemClock().now().year, greaterThan(2000));
  });

  test('同意は既定でなし。取り消すと外れ、版を覚える', () async {
    final s = InMemoryConsentStore();
    expect(await s.isGranted(ConsentKind.notifications), false);
    expect(await s.grantedVersion(ConsentKind.notifications), isNull);
    await s.set(ConsentKind.notifications, true, version: 2);
    expect(await s.isGranted(ConsentKind.notifications), true);
    expect(await s.grantedVersion(ConsentKind.notifications), 2);
    expect(await s.isGranted(ConsentKind.anonymousStats), false);
    await s.set(ConsentKind.notifications, false);
    expect(await s.isGranted(ConsentKind.notifications), false);
    expect(await s.grantedVersion(ConsentKind.notifications), isNull);
  });

  test('StudyDay: 境界の前は前日、ちょうどは当日', () {
    const d = StudyDay(startHour: 4);
    expect(d.of(DateTime(2026, 10, 2, 3, 59)), DateTime(2026, 10, 1));
    expect(d.of(DateTime(2026, 10, 2, 4)), DateTime(2026, 10, 2));
    expect(d.of(DateTime(2026, 10, 1, 0, 30)), DateTime(2026, 9, 30));
    expect(const StudyDay().of(DateTime(2026, 10, 2, 0, 1)), DateTime(2026, 10, 2));
    expect(const StudyDay().of(DateTime(2026, 10, 2, 23, 59)), DateTime(2026, 10, 2));
  });
}

void studyDayShift() {
  test('shiftAttempts: 深夜の回答が前日に数えられ、他の項目は変わらない', () {
    final a = Attempt(
      questionId: 'q',
      unitId: 'u',
      correct: true,
      answeredAt: DateTime(2026, 10, 2, 1, 30),
      chosenId: 'c',
      elapsedMs: 5,
      mode: 'mock',
      confident: true,
      reason: LossReason.careless,
      hintsUsed: 2,
    );
    const d = StudyDay(startHour: 4);
    final s = d.shiftAttempts([a]).single;
    expect(dateOnly(s.answeredAt), dateOnly(DateTime(2026, 10, 1)));
    expect(
      [s.questionId, s.unitId, s.correct, s.chosenId, s.elapsedMs, s.mode, s.confident, s.reason, s.hintsUsed],
      ['q', 'u', true, 'c', 5, 'mock', true, LossReason.careless, 2],
    );
    expect(d.shift(DateTime(2026, 10, 2, 5)), DateTime(2026, 10, 2, 1));
    expect(identical(const StudyDay().shiftAttempts([a]).single, a), true);
  });
}
