import 'package:chukore_kit/chukore_kit.dart';
import 'package:test/test.dart';

ExamAggregate _agg(List<double> scores) =>
    scores.fold(ExamAggregate.empty, (a, s) => a.add(s));

void main() {
  test('3値から平均と標準偏差が導ける', () {
    final a = _agg([40, 50, 60]);
    expect(a.count, 3);
    expect(a.mean, closeTo(50, 1e-9));
    expect(a.stdDev, closeTo(8.1649658, 1e-6));
  });

  test('100件未満・分散0は段階2を出さない', () {
    expect(deviationFromAggregate(_agg([40, 50, 60]), 60), isNull);
    expect(deviationFromAggregate(_agg(List.filled(100, 50)), 60), isNull);
  });

  test('100件以上なら平均・標準偏差から換算', () {
    final a = _agg([for (var i = 0; i < 100; i++) i.isEven ? 40.0 : 60.0]);
    final d = deviationFromAggregate(a, 60)!;
    expect(d.value, closeTo(60, 1e-9)); // 平均50, SD10 → 50+10*1
    expect(d.low, 55);
  });

  test('段階2が出せない間は段階1にフォールバック', () {
    final rates = List.filled(30, 0.6);
    final d = selectDeviation(baseRates: rates, score: 18, aggregate: _agg([50]));
    expect(d.value, closeTo(50, 1e-9));
  });

  test('キーは教科・学年・版で分かれる', () {
    expect(examStatsKey(subject: 'en', grade: 1, examVersion: 2), 'en_g1_v2');
    expect(examStatsKey(subject: 'en', grade: 1, examVersion: 2, unitGroup: 'grammar'),
        'en_g1_grammar_v2');
  });
}
