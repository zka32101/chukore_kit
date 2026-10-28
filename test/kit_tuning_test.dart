import 'dart:convert';
import 'dart:io';

import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

RealTestRecord t(int month, double score, {int day = 10}) => RealTestRecord(DateTime(2026, month, day), score);
Attempt a(DateTime when) => Attempt(questionId: 'q', unitId: 'u', correct: true, answeredAt: when);

void main() {
  group('読み込み', () {
    test('docs/kit_tuning/default.json は既定値と一致する（既定を変えたらここも更新する）', () {
      final fromFile = KitTuning.parse(File('docs/kit_tuning/default.json').readAsStringSync());
      expect(fromFile.toJson(), const KitTuning().toJson());
    });

    test('省略した項目は既定値。toJson → parse で元に戻る', () {
      final t = KitTuning.fromJson({'version': 2, 'outcomeNoise': 0.05});
      expect(t.version, 2);
      expect(t.outcomeNoise, 0.05);
      expect(t.outcomeBig, 0.10);
      expect(KitTuning.parse(jsonEncode(t.toJson())).toJson(), t.toJson());
      expect(KitTuning.fromJson(const {}).toJson(), const KitTuning().toJson());
      expect(KitTuning.fromJson({'outcomeNoise': 0}).outcomeNoise, 0, reason: '整数の 0 も数として読む');
    });

    test('書き間違い・範囲外・矛盾は FormatException', () {
      for (final bad in <Object?>[
        [],
        'x',
        {'versoin': 2},
        {'version': 0},
        {'version': 1.5},
        {'outcomeNoise': -0.1},
        {'outcomeNoise': 0.6},
        {'outcomeNoise': '0.03'},
        {'outcomeBig': 0.03}, // noise と同じ
        {'outcomeNoise': 0.2, 'outcomeBig': 0.1},
        {'usageMidFrom': 12}, // high と同じ
        {'usageMidFrom': 0},
        {'usageHighFrom': 40}, // lookback より大きい
        {'lookbackDays': 0},
        {'promptWindowDays': 0},
        {'promptMatchDays': -1},
        {'minCell': 0},
        {'funnelMinN': 10001},
      ]) {
        expect(() => KitTuning.fromJson(bad), throwsFormatException, reason: '$bad');
      }
      expect(() => KitTuning.parse('not json'), throwsFormatException);
    });
  });

  group('しきい値が各関数に届く', () {
    final attempts = [for (var d = 1; d <= 5; d++) a(DateTime(2026, 6, d, 12))];

    test('ノイズ幅: 3点差は既定だと同じ、幅を 1点にすると上がった', () {
      final records = [t(4, 60), t(6, 63)];
      expect(const KitTuning().outcomeSummary(records, attempts).entries[1].change, OutcomeChange.same);
      expect(const KitTuning(outcomeNoise: 0.01).outcomeSummary(records, attempts).entries[1].change, OutcomeChange.up);
    });

    test('使った量の期間: lookbackDays を短くすると学習日数が減る', () {
      final records = [t(4, 60), t(6, 70, day: 15)];
      final wide = const KitTuning().outcomeSummary(records, [a(DateTime(2026, 6, 1, 12))]).entries[1];
      final narrow = const KitTuning(
        lookbackDays: 7,
        usageHighFrom: 7,
      ).outcomeSummary(records, [a(DateTime(2026, 6, 1, 12))]).entries[1];
      expect(wide.activeDays, 1);
      expect(narrow.activeDays, 0);
    });

    test('報告に版が入り、区分の境界・使った量の境界がしきい値に従う', () {
      final records = [t(4, 60), t(6, 75)];
      final s = const KitTuning(version: 3).outcomeSummary(records, attempts);
      final r = const KitTuning(
        version: 3,
        usageMidFrom: 6,
        usageHighFrom: 12,
      ).outcomeReports(s, subject: 'math', region: 'BR');
      expect(r.single.tuning, 3);
      expect(r.single.toJson()['tuning'], 3);
      expect(r.single.usage, UsageBand.low, reason: '5日学習・中は6日から');
      final r2 = const KitTuning(outcomeBig: 0.20, outcomeNoise: 0.03).outcomeReports(s, subject: 'math', region: 'BR');
      expect(r2.single.band, OutcomeBand.up, reason: '15点差は大きく(0.20)に届かない');
      expect(const KitTuning().outcomeReports(s, subject: 'math', region: 'BR').single.band, OutcomeBand.bigUp);
    });

    test('報告の区分のノイズ幅もしきい値に従う（4点差は既定だと上がった、幅5点だとほぼ同じ）', () {
      final s = const KitTuning().outcomeSummary([t(4, 60), t(6, 64)], attempts);
      expect(const KitTuning().outcomeReports(s, subject: 'math', region: 'BR').single.band, OutcomeBand.up);
      expect(
        const KitTuning(outcomeNoise: 0.05).outcomeReports(s, subject: 'math', region: 'BR').single.band,
        OutcomeBand.same,
      );
    });

    test('集計: minCell が効く。版が違う報告は別のマスに分かれ、混ざらない', () {
      OutcomeReport rep(int v) => OutcomeReport(
        band: OutcomeBand.up,
        hasBaseline: false,
        usage: UsageBand.mid,
        kind: RealTestKind.regular,
        subject: 'math',
        region: 'BR',
        tuning: v,
      );
      final reports = [for (var i = 0; i < 20; i++) rep(1), for (var i = 0; i < 20; i++) rep(2)];
      expect(const KitTuning().tally(reports), isEmpty, reason: '20+20 は混ぜない。どちらも30未満');
      expect(const KitTuning(minCell: 20).tally(reports).map((c) => c.tuning), [1, 2]);
      expect(tallyOutcomes([...reports, for (var i = 0; i < 10; i++) rep(1)]).single.tuning, 1);
    });

    test('割合: funnelMinN が効く', () {
      final counts = {'score_prompt_shown': 12, 'score_entered': 9};
      expect(const KitTuning().rates(counts).scoreEntry, isNull);
      expect(const KitTuning(funnelMinN: 10).rates(counts).scoreEntry!.rate, 0.75);
    });

    test('点を聞く: promptWindowDays・promptMatchDays が効く', () {
      DateTime d(int m, int day) => DateTime(2026, m, day);
      final base = t(1, 50, day: 1);
      expect(
        const KitTuning().scorePrompt(today: d(6, 30), testDates: [d(6, 10)], records: const [], baseline: base),
        isNull,
        reason: '20日後は14日の外',
      );
      expect(
        const KitTuning(
          promptWindowDays: 30,
        ).scorePrompt(today: d(6, 30), testDates: [d(6, 10)], records: const [], baseline: base),
        isNotNull,
      );
      expect(
        const KitTuning().scorePrompt(
          today: d(6, 12),
          testDates: [d(6, 10)],
          records: [t(6, 80, day: 12)],
          baseline: base,
        ),
        isNull,
      );
      expect(
        const KitTuning(
          promptMatchDays: 1,
        ).scorePrompt(today: d(6, 12), testDates: [d(6, 10)], records: [t(6, 80, day: 12)], baseline: base),
        isNotNull,
      );
    });
  });
}
