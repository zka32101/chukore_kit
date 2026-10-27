import '../models/models.dart';
import '../ports/ports.dart';
import 'real_tests.dart';

/// 浮動小数点の誤差（0.63 − 0.60 が 0.03 をわずかに超えるなど）で、境界ちょうどの差が変わらないようにする。
const _eps = 1e-9;

/// 前回（または使う前）と比べた変化。
enum OutcomeChange {
  /// 比べる相手がまだ無い（最初の記録で、使う前の点も無い）。
  first,

  /// ノイズ幅を超えて上がった。
  up,

  /// ノイズ幅以内（ほぼ同じ）。
  same,

  /// ノイズ幅を超えて下がった。責めない文面で扱うこと。
  down,
}

/// 1回のテストの変化と、その前に使った量。
class OutcomeEntry {
  const OutcomeEntry({
    required this.record,
    required this.change,
    required this.deltaRatio,
    required this.deltaFromBaseline,
    required this.activeDays,
    required this.questions,
    this.comparedToBaseline = false,
  });

  final RealTestRecord record;
  final OutcomeChange change;

  /// 前回（無ければ使う前）との比の差（-1〜1）。比べる相手が無ければ null。
  final double? deltaRatio;

  /// 使う前の点との比の差。使う前の点が無ければ null。
  final double? deltaFromBaseline;

  /// 比べた相手が、使う前の点か（前回の本番ではなく）。
  final bool comparedToBaseline;

  /// テスト前の期間に学習した日数（学習日で数える）。
  final int activeDays;

  /// テスト前の期間に解いた問題数。
  final int questions;
}

/// 本番の点の変化のまとめ（本人にだけ見せる。送らない）。
class OutcomeSummary {
  const OutcomeSummary(this.entries, this.skipped);

  /// 日付順。
  final List<OutcomeEntry> entries;

  /// 点が範囲外などで使えなかった記録の数。
  final int skipped;

  /// 比べられた回のうち、上がった回の数。
  int get ups => entries.where((e) => e.change == OutcomeChange.up).length;

  /// 比べられた回の数（最初の記録を除く）。
  int get compared => entries.where((e) => e.change != OutcomeChange.first).length;

  /// 自己ベスト（100 点満点換算）。記録が無ければ null。
  double? get bestNormalized =>
      entries.isEmpty ? null : entries.map((e) => e.record.normalizedScore).reduce((a, b) => a > b ? a : b);
}

/// 本番の点の変化を、端末内で求める。**本人にだけ見せるもので、基盤は集めない・送らない。**
///
/// - [kind] の記録だけを比べる（種類をまたがない）。点が範囲外の記録は数えず [OutcomeSummary.skipped] に数える
/// - 変化は満点比（点 ÷ 満点）で比べ、前回との差が [noise]（既定 0.03＝100点満点で3点）以内なら
///   [OutcomeChange.same]。前回が無ければ [baseline]（使う前の点）と比べ、それも無ければ [OutcomeChange.first]
/// - 使った量は、テストの前日までの [lookbackDays] 日間の学習日数と問題数（[studyDay] の学習日で数える）
OutcomeSummary buildOutcomeSummary(
  Iterable<RealTestRecord> records,
  Iterable<Attempt> attempts, {
  RealTestRecord? baseline,
  RealTestKind kind = RealTestKind.regular,
  double noise = 0.03,
  int lookbackDays = 28,
  StudyDay studyDay = const StudyDay(),
}) {
  if (noise < 0) throw ArgumentError('noise must not be negative');
  if (lookbackDays < 1) throw ArgumentError('lookbackDays must be positive');
  final ofKind = records.where((r) => r.kind == kind).toList();
  final valid = <RealTestRecord>[];
  var skipped = 0;
  for (final r in ofKind) {
    r.isValid ? valid.add(r) : skipped++;
  }
  final indexed = [for (var i = 0; i < valid.length; i++) (i, valid[i])]
    ..sort((a, b) {
      final c = a.$2.date.compareTo(b.$2.date);
      return c != 0 ? c : a.$1.compareTo(b.$1);
    });

  final byDay = <DateTime, int>{};
  for (final a in attempts) {
    final d = dateOnly(studyDay.of(a.answeredAt));
    byDay[d] = (byDay[d] ?? 0) + 1;
  }

  final baseRatio = (baseline != null && baseline.isValid) ? baseline.ratio : null;
  final entries = <OutcomeEntry>[];
  double? prev;
  for (final (_, r) in indexed) {
    final testDay = dateOnly(r.date);
    final from = testDay.subtract(Duration(days: lookbackDays));
    var days = 0, questions = 0;
    for (final e in byDay.entries) {
      if (!e.key.isBefore(from) && e.key.isBefore(testDay)) {
        days++;
        questions += e.value;
      }
    }
    final ref = prev ?? baseRatio;
    final delta = ref == null ? null : r.ratio - ref;
    entries.add(
      OutcomeEntry(
        record: r,
        change: delta == null
            ? OutcomeChange.first
            : delta > noise + _eps
            ? OutcomeChange.up
            : delta < -noise - _eps
            ? OutcomeChange.down
            : OutcomeChange.same,
        deltaRatio: delta,
        deltaFromBaseline: baseRatio == null ? null : r.ratio - baseRatio,
        activeDays: days,
        questions: questions,
        comparedToBaseline: prev == null && baseRatio != null,
      ),
    );
    prev = r.ratio;
  }
  return OutcomeSummary(entries, skipped);
}
