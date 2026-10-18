import '../models/models.dart';
import '../planner/planner.dart';
import '../review/spaced_review.dart';
import '../weak/weak_notes.dart';

/// 出題の枠。
enum PracticeSlot {
  /// 間隔反復で期限が来た問題（短い想起から始める）。
  review,

  /// 重点枠（今日の範囲の単元から、習熟度に合う難しさで）。
  focus,

  /// 弱点枠（誤解の型・間違えた問題）。
  weak,

  /// 枠が足りなかった分の補充（習熟度の低い単元から）。
  extra,
}

class PickedQuestion {
  const PickedQuestion(this.question, this.slot);

  final Question question;
  final PracticeSlot slot;
}

/// 今日の出題。
class PracticeSet {
  const PracticeSet({required this.items, required this.shortfall});

  /// 出す順。復習 → 重点（単元ごとにやさしい順）→ 弱点 → 補充。
  final List<PickedQuestion> items;

  /// 枠ごとに、問題が足りず出せなかった数（0 の枠は含まない）。
  final Map<PracticeSlot, int> shortfall;

  List<Question> get questions => [for (final i in items) i.question];

  int countOf(PracticeSlot slot) => items.where((i) => i.slot == slot).length;
}

/// 出題選びの設定。値は仮決定（ソフトローンチで検証）。
class PickerConfig {
  const PickerConfig({
    this.easiestTarget = 0.85,
    this.hardestTarget = 0.5,
    this.recentCorrectDays = 3,
  });

  /// 習熟度 0 の人に当てたい基準正答率（やさしめ）。
  final double easiestTarget;

  /// 習熟度 1 の人に当てたい基準正答率（歯ごたえのある難しさ）。
  final double hardestTarget;

  /// 正解してからこの日数以内の問題は、他に選べるものがあるうちは出さない。
  final int recentCorrectDays;

  /// 習熟度 [mastery]（0〜1）に合わせて当てたい基準正答率。習熟度が高いほど難しい問題へ。
  double targetFor(double mastery) {
    final m = mastery.clamp(0.0, 1.0);
    return easiestTarget - (easiestTarget - hardestTarget) * m;
  }
}

/// 今日の計画 [plan] に沿って、実際に出す問題を選ぶ。同じ入力なら同じ結果（乱数・現在時刻に依存しない）。
///
/// - 復習枠: 期限が来た問題（`dueForReview` の順）
/// - 重点枠: `plan.focusByUnit` の単元ごとに、習熟度に合う基準正答率に近い問題。
///   最近正解した問題・直近に解いた問題は後回し（未出題が先）
/// - 弱点枠: 未克服の弱点（自信ありで誤答が多い・最近間違えた順）から 1 項目ずつ回して選ぶ
/// - 足りない枠は、習熟度の低い単元から順に補充（`extra`）。それでも足りなければ [PracticeSet.shortfall]
///
/// [scopeUnitIds] を渡すと、その単元（葉）の問題だけが対象。省略すると [questions] 全体。
PracticeSet pickPractice({
  required DayPlan plan,
  required List<Question> questions,
  required Map<String, Mastery> mastery,
  required List<Attempt> attempts,
  required DateTime today,
  Iterable<String>? scopeUnitIds,
  DateTime? testDate,
  int seed = 0,
  PickerConfig config = const PickerConfig(),
}) {
  final day = dateOnly(today);
  final scope = scopeUnitIds?.toSet();
  final pool = [
    for (final q in questions)
      if (scope == null || scope.contains(q.unitId) || plan.focusByUnit.containsKey(q.unitId)) q,
  ]..sort((a, b) => a.id.compareTo(b.id));
  final byId = {for (final q in pool) q.id: q};

  final lastAnswered = <String, DateTime>{};
  final lastCorrect = <String, DateTime>{};
  for (final a in attempts) {
    final d = dateOnly(a.answeredAt);
    if (lastAnswered[a.questionId] == null || d.isAfter(lastAnswered[a.questionId]!)) lastAnswered[a.questionId] = d;
    if (a.correct && (lastCorrect[a.questionId] == null || d.isAfter(lastCorrect[a.questionId]!))) {
      lastCorrect[a.questionId] = d;
    }
  }

  double masteryOf(String unitId) => mastery[unitId]?.score ?? 0;
  bool recentlyCorrect(Question q) {
    final d = lastCorrect[q.id];
    return d != null && day.difference(d).inDays < config.recentCorrectDays;
  }

  // 並べ替えの鍵: 最近正解していない → 当てたい難しさに近い → 長く解いていない（未出題が先）→ 固定の順
  int rank(Question a, Question b) {
    final ra = recentlyCorrect(a) ? 1 : 0, rb = recentlyCorrect(b) ? 1 : 0;
    if (ra != rb) return ra.compareTo(rb);
    final target = config.targetFor(masteryOf(a.unitId));
    // 浮動小数点の誤差で順が決まらないよう、1e-6 で丸めてから比べる
    int dist(Question x, double t) => ((x.difficulty - t).abs() * 1e6).round();
    final da = dist(a, target), db = dist(b, config.targetFor(masteryOf(b.unitId)));
    if (da != db) return da.compareTo(db);
    final la = lastAnswered[a.id], lb = lastAnswered[b.id];
    if (la != lb) {
      if (la == null) return -1;
      if (lb == null) return 1;
      return la.compareTo(lb);
    }
    final t = _tie(seed, a.id).compareTo(_tie(seed, b.id));
    return t != 0 ? t : a.id.compareTo(b.id);
  }

  final used = <String>{};
  final review = <PickedQuestion>[];
  final focus = <PickedQuestion>[];
  final weak = <PickedQuestion>[];
  final extra = <PickedQuestion>[];
  final shortfall = <PracticeSlot, int>{};

  // 復習
  final states = buildReviewStates(attempts, testDate: testDate);
  for (final s in dueForReview(states, day, unitIds: pool.map((q) => q.unitId).toSet())) {
    if (review.length >= plan.review) break;
    final q = byId[s.questionId];
    if (q != null && used.add(q.id)) review.add(PickedQuestion(q, PracticeSlot.review));
  }
  if (review.length < plan.review) shortfall[PracticeSlot.review] = plan.review - review.length;

  // 重点（単元ID順）
  final units = plan.focusByUnit.keys.toList()..sort();
  var focusMissing = 0;
  for (final u in units) {
    final want = plan.focusByUnit[u]!;
    final cands = [for (final q in pool) if (q.unitId == u && !used.contains(q.id)) q]..sort(rank);
    final picked = cands.take(want).toList();
    for (final q in picked) {
      used.add(q.id);
    }
    // 単元の中は、やさしい（基準正答率が高い）順
    picked.sort((a, b) {
      final c = b.difficulty.compareTo(a.difficulty);
      return c != 0 ? c : a.id.compareTo(b.id);
    });
    focus.addAll([for (final q in picked) PickedQuestion(q, PracticeSlot.focus)]);
    focusMissing += want - picked.length;
  }
  if (focusMissing > 0) shortfall[PracticeSlot.focus] = focusMissing;

  // 弱点: 項目ごとの候補を作り、1 項目ずつ回して選ぶ
  final entries = [
    for (final e in buildWeakNotes(attempts, byId))
      if (!e.overcome) e,
  ]..sort((a, b) {
      final c = b.confidentWrongCount.compareTo(a.confidentWrongCount);
      if (c != 0) return c;
      final d = b.lastWrongAt.compareTo(a.lastWrongAt);
      return d != 0 ? d : a.key.compareTo(b.key);
    });
  final lists = [
    for (final e in entries)
      [
        for (final q in pool)
          if (e.questionId != null
              ? q.id == e.questionId
              : q.misconceptionTags.values.contains(e.tag))
            q,
      ]..sort(rank),
  ];
  var progressed = true;
  while (weak.length < plan.weak && progressed) {
    progressed = false;
    for (final l in lists) {
      if (weak.length >= plan.weak) break;
      final next = l.where((q) => !used.contains(q.id)).firstOrNull;
      if (next == null) continue;
      used.add(next.id);
      weak.add(PickedQuestion(next, PracticeSlot.weak));
      progressed = true;
    }
  }
  if (weak.length < plan.weak) shortfall[PracticeSlot.weak] = plan.weak - weak.length;

  // 補充: 足りない分を、習熟度の低い単元から
  final missing = shortfall.values.fold<int>(0, (s, n) => s + n);
  if (missing > 0) {
    final order = pool.map((q) => q.unitId).toSet().toList()
      ..sort((a, b) {
        final c = masteryOf(a).compareTo(masteryOf(b));
        return c != 0 ? c : a.compareTo(b);
      });
    for (final u in order) {
      if (extra.length >= missing) break;
      final cands = [for (final q in pool) if (q.unitId == u && !used.contains(q.id)) q]..sort(rank);
      for (final q in cands) {
        if (extra.length >= missing) break;
        used.add(q.id);
        extra.add(PickedQuestion(q, PracticeSlot.extra));
      }
    }
    // 補充した分だけ、足りなかった数を減らす
    var left = extra.length;
    for (final slot in [PracticeSlot.review, PracticeSlot.focus, PracticeSlot.weak]) {
      final n = shortfall[slot];
      if (n == null) continue;
      final cut = n < left ? n : left;
      left -= cut;
      if (n - cut == 0) {
        shortfall.remove(slot);
      } else {
        shortfall[slot] = n - cut;
      }
    }
  }

  return PracticeSet(items: [...review, ...focus, ...weak, ...extra], shortfall: shortfall);
}

/// 実行環境に依らない固定の混ぜ方（String.hashCode は版・環境で変わるので使わない）。
/// 問題IDのハッシュに seed を混ぜてから攪拌するので、seed が変われば同順位の中の並びが変わる。
int _tie(int seed, String id) {
  var h = 0;
  for (final c in id.codeUnits) {
    h = (h * 31 + c) & 0x7FFFFFFF;
  }
  var x = (h ^ (seed * 0x9E3779B1)) & 0x7FFFFFFF;
  x = ((x ^ (x >> 15)) * 0x2C1B3C6D) & 0x7FFFFFFF;
  x = ((x ^ (x >> 12)) * 0x297A2D39) & 0x7FFFFFFF;
  return x ^ (x >> 15);
}
