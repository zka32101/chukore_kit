import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

RealTestRecord t(int month, double score, {RealTestKind kind = RealTestKind.regular}) =>
    RealTestRecord(DateTime(2026, month, 10), score, kind: kind);

OutcomeReport rep({
  OutcomeBand band = OutcomeBand.up,
  UsageBand usage = UsageBand.mid,
  bool baseline = false,
  String subject = 'math',
  String region = 'BR',
  int? grade = 2,
  RealTestKind kind = RealTestKind.regular,
}) => OutcomeReport(
  band: band,
  hasBaseline: baseline,
  usage: usage,
  kind: kind,
  subject: subject,
  region: region,
  grade: grade,
);

void main() {
  group('区分', () {
    test('outcomeBandOf: ノイズ幅以内は same、10点以上で大きく。境界は内側（ちょうどは same / 小さいほう）', () {
      expect(outcomeBandOf(0.0), OutcomeBand.same);
      expect(outcomeBandOf(0.03), OutcomeBand.same);
      expect(outcomeBandOf(0.0301), OutcomeBand.up);
      expect(outcomeBandOf(0.10), OutcomeBand.up);
      expect(outcomeBandOf(0.1001), OutcomeBand.bigUp);
      expect(outcomeBandOf(-0.03), OutcomeBand.same);
      expect(outcomeBandOf(-0.0301), OutcomeBand.down);
      expect(outcomeBandOf(-0.10), OutcomeBand.down);
      expect(outcomeBandOf(-0.1001), OutcomeBand.bigDown);
      expect(outcomeBandOf(0.63 - 0.60), OutcomeBand.same, reason: '浮動小数点の誤差で境界が変わらない');
      expect(() => outcomeBandOf(0, noise: 0.1, big: 0.1), throwsArgumentError);
    });

    test('usageBandOf: 3日まで少、4日から中、12日から多', () {
      expect([0, 3, 4, 11, 12, 28].map(usageBandOf), [
        UsageBand.low,
        UsageBand.low,
        UsageBand.mid,
        UsageBand.mid,
        UsageBand.high,
        UsageBand.high,
      ]);
      expect(() => usageBandOf(1, midFrom: 5, highFrom: 5), throwsArgumentError);
    });
  });

  group('buildOutcomeReports', () {
    final attempts = [
      for (var d = 1; d <= 5; d++)
        Attempt(questionId: 'q', unitId: 'u', correct: true, answeredAt: DateTime(2026, 6, d, 12)),
    ];

    test('比べる相手の無い最初の記録は含めず、前回と比べた回だけ報告になる', () {
      final s = buildOutcomeSummary([t(4, 60), t(6, 75)], attempts);
      final r = buildOutcomeReports(s, subject: 'math', region: 'pt-BR', grade: 2);
      expect(r, hasLength(1));
      expect(r.single.band, OutcomeBand.bigUp);
      expect(r.single.hasBaseline, false);
      expect(r.single.usage, UsageBand.mid); // 6/10 の前に 5 日学習
      expect(r.single.region, 'BR');
    });

    test('使う前の点と比べた回は hasBaseline が真（2回目以降は偽）', () {
      final s = buildOutcomeSummary([t(4, 58), t(6, 70)], attempts, baseline: RealTestRecord(DateTime(2026, 2, 1), 50));
      final r = buildOutcomeReports(s, subject: 'math', region: 'BR');
      expect(r.map((e) => e.hasBaseline), [true, false]);
    });

    test('地域が読めない・教科が空はエラー', () {
      final s = buildOutcomeSummary([t(4, 60), t(6, 75)], attempts);
      expect(() => buildOutcomeReports(s, subject: 'math', region: 'xx1'), throwsArgumentError);
      expect(() => buildOutcomeReports(s, subject: '', region: 'BR'), throwsArgumentError);
    });

    test('送らない項目を持たない: JSON のキーは決まった8つだけ（点・満点・日付・名前などが増えたら落ちる）', () {
      final j = rep().toJson();
      expect(j.keys.toSet(), {'band', 'baseline', 'usage', 'kind', 'subject', 'region', 'grade', 'tuning'});
      final text = j.toString();
      for (final bad in ['score', 'max', 'date', 'name', 'school', 'device', 'answer']) {
        expect(text.contains(bad), false, reason: bad);
      }
      expect(j.values.every((v) => v == null || v is String || v is bool || v is int), true, reason: '数値の点や日時を入れない');
    });
  });

  group('tallyOutcomes', () {
    test('1マスが minCell 件に満たなければ返さない（29件は返さず、30件で返す）', () {
      expect(tallyOutcomes([for (var i = 0; i < 29; i++) rep()]), isEmpty);
      final cells = tallyOutcomes([for (var i = 0; i < 30; i++) rep()]);
      expect(cells, hasLength(1));
      expect(cells.single.n, 30);
    });

    test('マスは 教科・国・学年・使った量・使う前の点の有無・種類で分かれる。足りないマスだけ伏せる', () {
      final reports = [
        for (var i = 0; i < 30; i++) rep(),
        for (var i = 0; i < 30; i++) rep(usage: UsageBand.high),
        for (var i = 0; i < 30; i++) rep(baseline: true),
        for (var i = 0; i < 30; i++) rep(region: 'TR'),
        for (var i = 0; i < 29; i++) rep(grade: 3),
      ];
      final cells = tallyOutcomes(reports);
      expect(cells, hasLength(4));
      expect(cells.any((c) => c.grade == 3), false);
    });

    test('上がった割合は up と bigUp の合計。信頼区間が割合を含む', () {
      final reports = [
        for (var i = 0; i < 12; i++) rep(band: OutcomeBand.bigUp),
        for (var i = 0; i < 8; i++) rep(band: OutcomeBand.up),
        for (var i = 0; i < 6; i++) rep(band: OutcomeBand.same),
        for (var i = 0; i < 3; i++) rep(band: OutcomeBand.down),
        for (var i = 0; i < 1; i++) rep(band: OutcomeBand.bigDown),
      ];
      final c = tallyOutcomes(reports).single;
      expect(c.n, 30);
      expect(c.counts[OutcomeBand.bigUp], 12);
      expect(c.upRate, closeTo(20 / 30, 1e-9));
      expect(c.upLow, lessThan(c.upRate));
      expect(c.upHigh, greaterThan(c.upRate));
      expect(c.upLow, greaterThan(0));
      expect(c.upHigh, lessThan(1));
    });

    test('件数の多い順に並び、同数は教科→国の順（math/TR は science/BR より先）。minCell が1未満ならエラー', () {
      final reports = [
        for (var i = 0; i < 30; i++) rep(region: 'TR'),
        for (var i = 0; i < 40; i++) rep(region: 'BR'),
        for (var i = 0; i < 30; i++) rep(region: 'BR', subject: 'science'),
      ];
      final c = tallyOutcomes(reports);
      expect(c.map((e) => '${e.subject}/${e.region}'), ['math/BR', 'math/TR', 'science/BR']);
      expect(() => tallyOutcomes(const [], minCell: 0), throwsArgumentError);
    });
  });
}
