import '../models/models.dart';
import '../question/answer.dart';
import 'real_tests.dart';

/// 点の入力が読めなかった理由。
enum ScoreInputError {
  /// 空。
  empty,

  /// 数として読めない。
  notNumber,

  /// マイナス。
  negative,

  /// 満点を超えている。
  overMax,
}

/// 点の入力を読んだ結果。[value] か [error] のどちらか一方が入る。
class ScoreInput {
  const ScoreInput.ok(double this.value) : error = null;
  const ScoreInput.error(ScoreInputError this.error) : value = null;

  final double? value;
  final ScoreInputError? error;

  bool get isOk => value != null;
}

/// 本人が入れた点の文字を読む。全角・各地の数字・マイナス記号の違い・桁区切りを吸収する
/// （[decimalSeparator] が `,` の国では `,` が小数点）。`NaN`・`Infinity`・指数表記（`1e3`）は数として読まない。
/// 0 以上 [maxScore] 以下だけが通る。
ScoreInput parseScoreInput(String text, {required double maxScore, String decimalSeparator = '.'}) {
  if (!(maxScore > 0)) throw ArgumentError('maxScore must be positive');
  if (text.trim().isEmpty) return const ScoreInput.error(ScoreInputError.empty);
  final t = normalizeNumberInput(text, decimalSeparator);
  if (!RegExp(r'^-?\d+(\.\d+)?$').hasMatch(t)) return const ScoreInput.error(ScoreInputError.notNumber);
  final v = double.parse(t);
  if (v < 0) return const ScoreInput.error(ScoreInputError.negative);
  if (v > maxScore) return const ScoreInput.error(ScoreInputError.overMax);
  return ScoreInput.ok(v);
}

/// 点を聞く場面。
enum ScorePromptKind {
  /// テスト日を過ぎたあと。
  afterTest,

  /// 使い始め（使う前の点）。
  baseline,
}

/// 聞く内容。
class ScorePrompt {
  const ScorePrompt(this.kind, [this.testDate]);

  final ScorePromptKind kind;

  /// [ScorePromptKind.afterTest] のとき、どのテストか。
  final DateTime? testDate;
}

/// 点を聞いた履歴（アプリが保存する）。**聞いたら、入れても入れなくても、同じものを二度と聞かない。**
class ScorePromptState {
  const ScorePromptState({this.askedTests = const {}, this.baselineAsked = false, this.lastPromptedOn});

  /// すでに聞いたテスト日（日付のみ）。
  final Set<DateTime> askedTests;
  final bool baselineAsked;

  /// 最後に聞いた日。1 日に 1 回までにするため。
  final DateTime? lastPromptedOn;

  /// [prompt] を [today] に聞いたあとの状態（元は変えない）。
  ScorePromptState markPrompted(ScorePrompt prompt, DateTime today) => ScorePromptState(
    askedTests: prompt.kind == ScorePromptKind.afterTest && prompt.testDate != null
        ? {...askedTests, dateOnly(prompt.testDate!)}
        : askedTests,
    baselineAsked: baselineAsked || prompt.kind == ScorePromptKind.baseline,
    lastPromptedOn: dateOnly(today),
  );
}

/// 今日、点を聞くか。聞かないなら null。**しつこく聞かない**ための判定。
///
/// - 1 日に 1 回まで（[ScorePromptState.lastPromptedOn]）
/// - [ScorePromptKind.afterTest]: テスト日の**翌日から** [windowDays] 日以内（当日は聞かない。終わった直後の負担を避ける）。
///   すでに聞いたテスト、テスト日の前後 [matchDays] 日以内に点の記録があるテストは聞かない。複数あれば新しいテスト
/// - [ScorePromptKind.baseline]: 使う前の点が無く、記録がまだ一つも無く、一度も聞いていないときだけ。afterTest を優先する
/// - 日付は呼び出し側が `StudyDay` で学習日にそろえて渡してもよい
ScorePrompt? decideScorePrompt({
  required DateTime today,
  required Iterable<DateTime> testDates,
  required Iterable<RealTestRecord> records,
  ScorePromptState state = const ScorePromptState(),
  RealTestRecord? baseline,
  int windowDays = 14,
  int matchDays = 3,
}) {
  if (windowDays < 1) throw ArgumentError('windowDays must be positive');
  if (matchDays < 0) throw ArgumentError('matchDays must not be negative');
  final day = dateOnly(today);
  final last = state.lastPromptedOn;
  if (last != null && dateOnly(last) == day) return null;

  final recordDays = [for (final r in records) dateOnly(r.date)];
  DateTime? pick;
  for (final raw in testDates) {
    final t = dateOnly(raw);
    final ago = day.difference(t).inDays;
    if (ago < 1 || ago > windowDays) continue;
    if (state.askedTests.map(dateOnly).contains(t)) continue;
    if (recordDays.any((d) => d.difference(t).inDays.abs() <= matchDays)) continue;
    if (pick == null || t.isAfter(pick)) pick = t;
  }
  if (pick != null) return ScorePrompt(ScorePromptKind.afterTest, pick);

  if (!state.baselineAsked && baseline == null && recordDays.isEmpty) {
    return const ScorePrompt(ScorePromptKind.baseline);
  }
  return null;
}
