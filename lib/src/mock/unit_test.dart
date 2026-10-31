import '../models/models.dart';
import '../scope/unit_tree.dart';
import 'mock_exam.dart';

/// 単元テストの結果の 3 段階。子どもには点数や偏差値を出さず、この 3 つで返す。
enum UnitTestLevel {
  /// できた（8 割以上）。
  done,

  /// もう少し（5 割以上 8 割未満）。
  almost,

  /// 復習しよう（5 割未満）。
  review,
}

/// 単元・章の小さなテスト（5〜15 問）。やさしい→ふつう→難しいの順に並ぶ（最初は必ず解けそうな問題から）。
class UnitTest {
  const UnitTest({
    required this.exam,
    required this.coveredTags,
    required this.missedTags,
  });

  /// 出題。制限時間なし。[scoreUnitTest] で採点する。
  final MockExam exam;

  /// 出題に含めた誤解の型。
  final Set<String> coveredTags;

  /// 範囲にはあるが、問題数の都合で入らなかった誤解の型。
  final Set<String> missedTags;

  List<Question> get questions => exam.questions;
  bool get shortfall => exam.shortfall;
}

/// 単元テストの結果。
class UnitTestResult {
  const UnitTestResult({
    required this.level,
    required this.exam,
    required this.mistakeTags,
  });

  final UnitTestLevel level;

  /// 点数・単元別・履歴（mode は `unit_test`）。点数は保護者向け。
  final MockExamResult exam;

  /// 誤答から分かった誤解の型 → 回数（誤答が `misconceptionTags` の鍵と一致したものだけ）。
  final Map<String, int> mistakeTags;
}

const _easyMax = 1 / 3, _normalMax = 2 / 3;

int _band(double d) => d < _easyMax ? 0 : (d < _normalMax ? 1 : 2);

/// 範囲 [unitIds] から [count]（5〜15）問の単元テストを作る。
/// - 難しさは [difficultyMix]（やさしい : ふつう : 難しい。既定 3:5:2）の比に合わせる（足りない帯は他の帯で埋める）。
/// - 誤解の型（`misconceptionTags` の値）をなるべく満遍なく入れる（まだ入っていない型を持つ問題を優先）。
/// - 暗記カードと [excludeQuestionIds] は出さない。問題が足りなければ全部出して `shortfall` を true にする。
/// 同じ入力なら同じ結果。
UnitTest buildUnitTest({
  required List<Question> questions,
  required UnitTree tree,
  required Iterable<String> unitIds,
  int count = 10,
  int seed = 0,
  List<int> difficultyMix = const [3, 5, 2],
  Set<String> excludeQuestionIds = const {},
}) {
  if (count < 5 || count > 15) throw ArgumentError('count must be 5..15');
  if (difficultyMix.length != 3 || difficultyMix.any((w) => w < 0) || difficultyMix.every((w) => w == 0)) {
    throw ArgumentError('difficultyMix must be 3 non-negative weights');
  }
  final leaves = tree.resolveLeaves(unitIds).map((u) => u.id).toSet();
  final pool = [
    for (final q in questions)
      if (leaves.contains(q.unitId) && q.type != 'card' && !excludeQuestionIds.contains(q.id)) q,
  ]..sort((a, b) => a.id.compareTo(b.id));
  // 同じ seed なら同じ順の「並び番号」（同点のときの決め手）
  final shuffled = buildMockExam(
    questions: pool,
    tree: tree,
    unitIds: leaves,
    count: pool.isEmpty ? 1 : pool.length,
    timeLimit: null,
    seed: seed,
  ).questions;
  final rank = {for (var i = 0; i < shuffled.length; i++) shuffled[i].id: i};

  final allTags = {for (final q in pool) ...q.misconceptionTags.values};
  final target = count < pool.length ? count : pool.length;

  // 帯ごとの本数（最大剰余法）
  final total = difficultyMix.fold<int>(0, (s, w) => s + w);
  final quota = [for (final w in difficultyMix) target * w ~/ total];
  final order = [0, 1, 2]..sort((a, b) {
      final c = ((target * difficultyMix[b]) % total).compareTo((target * difficultyMix[a]) % total);
      return c != 0 ? c : difficultyMix[b].compareTo(difficultyMix[a]);
    });
  var left = target - quota.fold<int>(0, (s, n) => s + n);
  for (final b in order) {
    if (left == 0) break;
    quota[b]++;
    left--;
  }

  final chosen = <Question>[];
  final covered = <String>{};
  final perUnit = <String, int>{};
  final remaining = [...pool];

  Question pick(List<Question> from) {
    Question? best;
    int bestNew = -1, bestUnit = 0;
    for (final q in from) {
      final fresh = q.misconceptionTags.values.toSet().difference(covered).length;
      final u = perUnit[q.unitId] ?? 0;
      final better = best == null ||
          fresh > bestNew ||
          (fresh == bestNew && (u < bestUnit || (u == bestUnit && rank[q.id]! < rank[best.id]!)));
      if (better) {
        best = q;
        bestNew = fresh;
        bestUnit = u;
      }
    }
    return best!;
  }

  void take(Question q) {
    chosen.add(q);
    remaining.remove(q);
    covered.addAll(q.misconceptionTags.values);
    perUnit[q.unitId] = (perUnit[q.unitId] ?? 0) + 1;
  }

  var shortBands = 0;
  for (var b = 0; b < 3; b++) {
    for (var i = 0; i < quota[b]; i++) {
      final from = [for (final q in remaining) if (_band(q.difficulty) == b) q];
      if (from.isEmpty) {
        shortBands++;
        continue;
      }
      take(pick(from));
    }
  }
  // 足りなかった帯の分は、残りの問題から（誤解の型・単元の偏りを見て）埋める
  for (var i = 0; i < shortBands; i++) {
    take(pick(remaining));
  }

  final ordered = [...chosen]..sort((a, b) {
      final c = _band(a.difficulty).compareTo(_band(b.difficulty));
      return c != 0 ? c : rank[a.id]!.compareTo(rank[b.id]!);
    });
  return UnitTest(
    exam: MockExam(questions: ordered, requestedCount: count, seed: seed),
    coveredTags: covered,
    missedTags: allTags.difference(covered),
  );
}

/// 単元テストの採点。履歴の mode は `unit_test`。[answers] などは [scoreMockExam] と同じ。
UnitTestResult scoreUnitTest(
  UnitTest test,
  Map<String, String> answers, {
  required DateTime answeredAt,
  Map<String, int> perQuestionMs = const {},
  Map<String, bool> confident = const {},
  String decimalSeparator = '.',
}) {
  final r = scoreMockExam(
    test.exam,
    answers,
    answeredAt: answeredAt,
    perQuestionMs: perQuestionMs,
    confident: confident,
    decimalSeparator: decimalSeparator,
    mode: 'unit_test',
  );
  final wrong = {for (final a in r.attempts) if (!a.correct) a.questionId: a.chosenId};
  final tags = <String, int>{};
  for (final q in test.questions) {
    final input = wrong[q.id];
    final tag = input == null ? null : q.misconceptionTags[input];
    if (tag != null) tags[tag] = (tags[tag] ?? 0) + 1;
  }
  final rate = r.rate;
  return UnitTestResult(
    level: rate >= 0.8 ? UnitTestLevel.done : (rate >= 0.5 ? UnitTestLevel.almost : UnitTestLevel.review),
    exam: r,
    mistakeTags: tags,
  );
}
