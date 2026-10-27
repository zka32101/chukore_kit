import '../guardian/age_policy.dart';
import '../insight/difficulty_calibration.dart' show wilsonInterval;
import 'outcome_summary.dart';
import 'real_tests.dart';

/// 変化の区分（5段階）。点そのものではなく、粗い区分だけを外に出す。
enum OutcomeBand { bigDown, down, same, up, bigUp }

/// 使った量の区分（3段階）。
enum UsageBand { low, mid, high }

/// 変化の差（満点比）を5段階にする。[noise] 以内は [OutcomeBand.same]、[big] 以上は大きく上がる／下がる。
OutcomeBand outcomeBandOf(double delta, {double noise = 0.03, double big = 0.10}) {
  if (noise < 0 || big <= noise) throw ArgumentError('big must be greater than noise');
  const eps = 1e-9;
  if (delta > big + eps) return OutcomeBand.bigUp;
  if (delta > noise + eps) return OutcomeBand.up;
  if (delta < -big - eps) return OutcomeBand.bigDown;
  if (delta < -noise - eps) return OutcomeBand.down;
  return OutcomeBand.same;
}

/// 学習日数（テスト前の期間）を3段階にする。[midFrom] 日以上で中、[highFrom] 日以上で多（暫定値）。
UsageBand usageBandOf(int activeDays, {int midFrom = 4, int highFrom = 12}) {
  if (midFrom < 1 || highFrom <= midFrom) throw ArgumentError('highFrom must be greater than midFrom');
  if (activeDays >= highFrom) return UsageBand.high;
  if (activeDays >= midFrom) return UsageBand.mid;
  return UsageBand.low;
}

/// 外へ出してよい項目だけを持つ、1テスト分の匿名の報告。
///
/// **持たないもの**: 点・満点・日付・学校・名前・端末ID・回答の中身。これらを足さないことを、テストで固定している。
/// **送信の仕組みは基盤に無い**。法務確認（[`docs/score_outcome_measurement.md`](../../../docs/score_outcome_measurement.md) §8）が済み、
/// 保護者の同意を得るまで、アプリは使ってはいけない。
class OutcomeReport {
  const OutcomeReport({
    required this.band,
    required this.hasBaseline,
    required this.usage,
    required this.kind,
    required this.subject,
    required this.region,
    this.grade,
  });

  final OutcomeBand band;

  /// 使う前の点と比べたか（無ければ前回の本番と比べた）。別に集計する。
  final bool hasBaseline;
  final UsageBand usage;
  final RealTestKind kind;
  final String subject;

  /// 国・地域コード（大文字2文字）。市区町村・学校は持たない。
  final String region;

  /// 学年（中1〜3 なら 1〜3）。無くてもよい。
  final int? grade;

  Map<String, Object?> toJson() => {
    'band': band.name,
    'baseline': hasBaseline,
    'usage': usage.name,
    'kind': kind.name,
    'subject': subject,
    'region': region,
    'grade': grade,
  };
}

/// [OutcomeSummary] から、外へ出す報告を作る。
///
/// - 比べる相手が無い記録（[OutcomeChange.first]）は含めない
/// - [region] は地域コードかロケール（`pt-BR` など）。読めなければ [ArgumentError]
/// - 区分の境界は [noise]（[buildOutcomeSummary] と同じ値を渡すこと）・[big]・[midFrom]・[highFrom]
List<OutcomeReport> buildOutcomeReports(
  OutcomeSummary summary, {
  required String subject,
  required String region,
  int? grade,
  double noise = 0.03,
  double big = 0.10,
  int midFrom = 4,
  int highFrom = 12,
}) {
  final code = AgePolicy.regionCode(region);
  if (code.isEmpty) throw ArgumentError('region must be a country code or locale');
  if (subject.isEmpty) throw ArgumentError('subject must not be empty');
  return [
    for (final e in summary.entries)
      if (e.deltaRatio != null)
        OutcomeReport(
          band: outcomeBandOf(e.deltaRatio!, noise: noise, big: big),
          hasBaseline: e.comparedToBaseline,
          usage: usageBandOf(e.activeDays, midFrom: midFrom, highFrom: highFrom),
          kind: e.record.kind,
          subject: subject,
          region: code,
          grade: grade,
        ),
  ];
}

/// 集計の1マス（教科・学年・国・使った量・使う前の点の有無・種類ごと）。
class OutcomeCell {
  const OutcomeCell({
    required this.subject,
    required this.region,
    required this.grade,
    required this.usage,
    required this.hasBaseline,
    required this.kind,
    required this.counts,
    required this.n,
    required this.upRate,
    required this.upLow,
    required this.upHigh,
  });

  final String subject, region;
  final int? grade;
  final UsageBand usage;
  final bool hasBaseline;
  final RealTestKind kind;

  /// 区分ごとの件数。
  final Map<OutcomeBand, int> counts;
  final int n;

  /// 「上がった」（up＋bigUp）の割合と、その95%信頼区間。
  final double upRate, upLow, upHigh;
}

/// 報告を集計する。**1マスが [minCell] 件に満たなければ、そのマスは返さない**（少数から個人が推測されないように）。
/// 並びは 件数の多い順 → 教科 → 国 → 学年 → 使った量。
List<OutcomeCell> tallyOutcomes(Iterable<OutcomeReport> reports, {int minCell = 30}) {
  if (minCell < 1) throw ArgumentError('minCell must be positive');
  final groups = <String, List<OutcomeReport>>{};
  for (final r in reports) {
    final key = '${r.subject}|${r.region}|${r.grade}|${r.usage.name}|${r.hasBaseline}|${r.kind.name}';
    (groups[key] ??= []).add(r);
  }
  final out = <OutcomeCell>[];
  for (final g in groups.values) {
    if (g.length < minCell) continue;
    final first = g.first;
    final counts = {for (final b in OutcomeBand.values) b: 0};
    for (final r in g) {
      counts[r.band] = counts[r.band]! + 1;
    }
    final ups = counts[OutcomeBand.up]! + counts[OutcomeBand.bigUp]!;
    final p = ups / g.length;
    final (low, high) = wilsonInterval(p, g.length, 1.96);
    out.add(
      OutcomeCell(
        subject: first.subject,
        region: first.region,
        grade: first.grade,
        usage: first.usage,
        hasBaseline: first.hasBaseline,
        kind: first.kind,
        counts: counts,
        n: g.length,
        upRate: p,
        upLow: low,
        upHigh: high,
      ),
    );
  }
  out.sort((a, b) {
    var c = b.n.compareTo(a.n);
    if (c != 0) return c;
    c = a.subject.compareTo(b.subject);
    if (c != 0) return c;
    c = a.region.compareTo(b.region);
    if (c != 0) return c;
    c = (a.grade ?? 0).compareTo(b.grade ?? 0);
    return c != 0 ? c : a.usage.index.compareTo(b.usage.index);
  });
  return out;
}
