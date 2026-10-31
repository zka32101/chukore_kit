import '../math/math_expr.dart';
import '../math/math_template.dart';
import '../math/steps.dart';
import '../math/template_text.dart';
import 'lesson.dart';

/// 数学のレッスンの検査。例題の途中式（型の値を `{…}` で差し込んだ行）を [checkSolutionSteps] で 1 行ずつ確かめ、
/// 最後の行が型の答えと合うことも確かめる。
class MathLessonChecker extends LessonChecker {
  const MathLessonChecker(this.templates);

  final TemplateSet templates;

  @override
  String? checkExample(ExampleBlock block) {
    final t = templates.templates.where((x) => x.id == block.template);
    if (t.isEmpty) return '型 ${block.template} がありません';
    final tpl = t.first;
    final Variant v;
    try {
      v = tpl.generate(block.seed);
    } on StateError catch (e) {
      return '変種を作れません: ${e.message}';
    }
    String render(String s) => renderTemplateString(s, v.params, lists: v.lists);
    final List<String> lines;
    final String? target;
    try {
      lines = [for (final l in block.lines) render(l)];
      target = block.target == null ? null : render(block.target!);
    } on FormatException catch (e) {
      return '途中式を差し込めません: ${e.message}';
    } on InexactValueException catch (e) {
      return '途中式の値が整数・分数で書けません: ${e.source}';
    }
    final r = checkSolutionSteps(lines, target: target, form: block.form);
    final bad = r.firstProblem;
    if (bad != null) {
      final verdict = r.verdicts[bad];
      final why = switch (verdict.status) {
        LineStatus.unreadable => '読めない行',
        LineStatus.kindMismatch => '式と方程式が混ざっている',
        _ => '前の行と同じ値（解）でない${verdict.tag == null ? '' : '（${verdict.tag}）'}',
      };
      return '${bad + 1} 行目 "${verdict.text}": $why';
    }
    if (target != null && !r.reachedTarget) {
      return r.finalNotSolved
          ? '最後の行 "${lines.last}" が解の形（x = 数）まで整理されていません'
          : r.finalWrongForm
          ? '最後の行 "${lines.last}" が形 ${block.form} になっていません'
          : '最後の行 "${lines.last}" が目標 "$target" に着きません';
    }
    // 最後の行が型の答えと合うか（答えが数・式のとき）
    final answer = v.question.answer;
    if (tpl.type == 'expr') {
      final last = lines.last;
      // 最後の行が解の形の方程式なら、数の側の値で、式ならその式で、型の答えと比べる
      String lastValue = last;
      if (last.contains('=') || last.contains('＝')) {
        final eq = MathEquation.parse(last);
        if (!eq.isSolvedForm) return null; // 解の形でなければ答えとは比べない
        final side = eq.left.variables.isEmpty ? eq.left : eq.right;
        lastValue = formatExact(side.eval(const {})) ?? '${side.eval(const {})}';
      }
      final verdict = judgeExpr(answer, lastValue, form: tpl.form);
      if (verdict == ExprVerdict.wrongValue) return '最後の行の値 "$lastValue" が型の答え "$answer" と違います';
    }
    return null;
  }

  @override
  bool formulaReadable(String expr) {
    final s = expr.replaceAll('＝', '=');
    if (s.contains('=')) {
      try {
        MathEquation.parse(s);
        return true;
      } on FormatException {
        return false;
      }
    }
    return MathExpr.tryParse(s) != null;
  }
}
