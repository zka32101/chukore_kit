import '../models/models.dart';
import 'difficulty_calibration.dart';
import 'distractor_analysis.dart';
import 'review_tuning.dart';
import 'tag_drafts.dart';

/// 問題集の品質レポート。匿名で集めた回答の束から、難易度のずれ・誤答の選択肢の旗・型の下書き・
/// 復習間隔の提案を 1 つにまとめる（開発者が問題集を直すための材料。子どもや保護者には出さない）。
class QualityReport {
  const QualityReport({
    required this.attemptCount,
    required this.questionCount,
    required this.calibration,
    required this.distractors,
    required this.tagDrafts,
    required this.tuning,
  });

  final int attemptCount;
  final int questionCount;
  final CalibrationReport calibration;
  final List<QuestionDistractors> distractors;
  final List<TagDraft> tagDrafts;
  final ReviewTuning tuning;

  /// 直すところが 1 つも無い。
  bool get isClean => calibration.drifts.isEmpty && distractors.isEmpty && !tuning.changed;

  /// Markdown にする。各表は多い（ずれ・旗の多い）順に最大 [maxRows] 行。
  String toMarkdown({int maxRows = 20}) {
    final b = StringBuffer()
      ..writeln('# 問題集の品質レポート')
      ..writeln()
      ..writeln('- 回答 $attemptCount 件 / 問題 $questionCount 問')
      ..writeln('- 難易度を実測できた問題: ${calibration.measured} 問')
      ..writeln('- 気になる点: 難易度のずれ ${calibration.drifts.length} / 誤答の選択肢 ${distractors.length} / 誤解の型の候補 ${tagDrafts.length} / 復習間隔の変更 ${tuning.boxes.where((x) => x.oldDays != x.newDays).length}')
      ..writeln();
    if (isClean) {
      b.writeln('直すところは見つかりませんでした（回答が足りない場合は、何も出ません。「実測できた問題」の数を見てください）。');
      return b.toString();
    }

    if (calibration.drifts.isNotEmpty) {
      b
        ..writeln('## 難易度のずれ（基準正答率の見直し）')
        ..writeln()
        ..writeln('| 問題 | 単元 | 回答 | 実測 | 基準 | 提案 |')
        ..writeln('|---|---|---|---|---|---|');
      for (final d in calibration.drifts.take(maxRows)) {
        b.writeln('| ${d.questionId} | ${d.unitId} | ${d.attempts} | ${_pct(d.observed)} | ${_pct(d.nominal)} | ${d.suggested.toStringAsFixed(2)} |');
      }
      _more(b, calibration.drifts.length, maxRows);
    }

    if (distractors.isNotEmpty) {
      b
        ..writeln('## 誤答の選択肢')
        ..writeln()
        ..writeln('| 問題 | 単元 | 回答 | 正答率 | 気になる点 |')
        ..writeln('|---|---|---|---|---|');
      for (final d in distractors.take(maxRows)) {
        b.writeln('| ${d.questionId} | ${d.unitId} | ${d.attempts} | ${_pct(d.correctRate)} | ${[for (final f in DistractorFlag.values) if (d.flags.contains(f)) _flag(f)].join('・')} |');
      }
      _more(b, distractors.length, maxRows);
    }

    if (tagDrafts.isNotEmpty) {
      b
        ..writeln('## 誤解の型の候補（名前と先生役のセリフを付けて採用）')
        ..writeln()
        ..writeln('| 問題 | 選択肢 | 選ばれた回数 | 誤答の中の割合 | 仮の型名 |')
        ..writeln('|---|---|---|---|---|');
      for (final t in tagDrafts.take(maxRows)) {
        b.writeln('| ${t.questionId} | ${t.optionId} | ${t.chosen} | ${_pct(t.shareOfWrong)} | `${t.suggestedTag}` |');
      }
      _more(b, tagDrafts.length, maxRows);
    }

    if (tuning.changed) {
      b
        ..writeln('## 復習間隔の提案')
        ..writeln()
        ..writeln('| 箱 | 回答 | 思い出せた割合 | 今の間隔（日） | 提案（日） |')
        ..writeln('|---|---|---|---|---|');
      for (final x in tuning.boxes.where((x) => x.oldDays != x.newDays)) {
        b.writeln('| ${x.box} | ${x.attempts} | ${_pct(x.retention)} | ${x.oldDays} | ${x.newDays} |');
      }
      b.writeln();
    }
    return b.toString();
  }

  static String _pct(double v) => '${(v * 100).round()}%';

  static String _flag(DistractorFlag f) => switch (f) {
        DistractorFlag.popularUntagged => '型の無い人気の誤答',
        DistractorFlag.neverChosen => '選ばれない誤答',
        DistractorFlag.beatsAnswer => '誤答が正解より人気',
      };

  static void _more(StringBuffer b, int total, int shown) {
    if (total > shown) b.writeln('\n（ほか ${total - shown} 件）');
    b.writeln();
  }
}

/// 回答の束 [attempts] と問題集 [questions] から、品質レポートを作る。同じ入力なら同じ結果。
/// 各分析の閾値は、それぞれの関数の既定値（`calibrateDifficulty`・`analyzeDistractors`・`tuneReviewIntervals`）。
QualityReport buildQualityReport(Iterable<Attempt> attempts, Iterable<Question> questions) {
  final a = attempts.toList();
  final qs = questions.toList();
  final distractors = analyzeDistractors(a, qs);
  return QualityReport(
    attemptCount: a.length,
    questionCount: qs.length,
    calibration: calibrateDifficulty(a, qs),
    distractors: distractors,
    tagDrafts: suggestTagDrafts(distractors),
    tuning: tuneReviewIntervals(a),
  );
}
