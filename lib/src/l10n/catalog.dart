import 'strings.dart';

/// 翻訳確認用: [s] の全文言を、代表的な引数（件数 0・1・2・5、数の読み上げ、プレースホルダ）で
/// 呼び出した一覧。キーは全言語で同じ。言語を足したら [ChukoreStrings.supported] に足せば自動で載る。
///
/// プレースホルダは `{subject}` `{points}` `{headline}` `{level}` `{title}` の形で残す
/// （訳でこれが落ちていないかをテストで検査する）。
Map<String, String> stringsCatalog(ChukoreStrings s) {
  final m = <String, String>{};
  m['cardTitle'] = s.cardTitle('{subject}');
  m['headlinePersonalBest'] = s.headlinePersonalBest;
  m['headlineFirst'] = s.headlineFirst;
  m['headlineUp'] = s.headlineUp('{points}');
  m['headlineSame'] = s.headlineSame;
  m['headlineDown'] = s.headlineDown;
  m['nextLevel'] = s.nextLevel('{points}');
  for (final v in [1.0, 1.5, 5.0]) {
    m['nextLevel(${v.toString().replaceAll('.0', '')})'] = s.nextLevel(s.formatNumber(v));
  }
  m['topLevel'] = s.topLevel;
  for (final n in [0, 1, 2, 5]) {
    m['streakDays($n)'] = s.streakDays(n);
  }
  m['statStamps'] = s.statStamps;
  m['statSolvable'] = s.statSolvable;
  for (final n in [0, 1, 2, 5]) {
    m['solvableValue($n)'] = s.solvableValue(n);
  }
  m['cardSemantics'] = s.cardSemantics('{headline}', '{level}');
  m['mapSemantics'] = s.mapSemantics;
  for (final y in [-500, 1868]) {
    m['formatYear($y)'] = s.formatYear(y);
  }
  for (final (d, a) in [(0, 0), (1, 1), (2, 5)]) {
    m['reportHeader($d,$a)'] = s.reportHeader(d, a);
  }
  m['reportImprovedTitle'] = s.reportImprovedTitle;
  m['reportItem'] = s.reportItem('{title}', 40, 70);
  m['reportEmpty'] = s.reportEmpty;
  for (final n in [100, 101, 271, 280, 482, 1500]) {
    m['gateNumberWords($n)'] = s.gateNumberWords(n);
  }
  m['teacherPrompt'] = s.teacherPrompt;
  m['teacherCorrect'] = s.teacherCorrect;
  m['teacherWrong'] = s.teacherWrong;
  m['ringsTitle'] = s.ringsTitle;
  for (final n in [0, 1, 2, 30]) {
    m['ringsSemantics($n)'] = s.ringsSemantics(n);
  }
  m['deviationLabel'] = s.deviationLabel;
  m['deviationRange'] = s.deviationRange('{low}', '{high}');
  m['deviationNote'] = s.deviationNote;
  m['markCorrect'] = s.markCorrect;
  m['markWrong'] = s.markWrong;
  m['sheetTitle'] = s.sheetTitle;
  m['sheetQuestion'] = s.sheetQuestion;
  m['sheetAnswer'] = s.sheetAnswer;
  m['sheetExplanation'] = s.sheetExplanation;
  m['sheetEmpty'] = s.sheetEmpty;
  m['decimalSeparator'] = s.decimalSeparator;
  return m;
}

/// 翻訳確認用の CSV（1行目 `key,<言語タグ>...`）。スプレッドシートで開いて、ネイティブに確認してもらう。
String stringsCatalogCsv([List<ChukoreStrings> languages = ChukoreStrings.supported]) {
  final catalogs = [for (final l in languages) stringsCatalog(l)];
  String q(String v) => '"${v.replaceAll('"', '""')}"';
  final b = StringBuffer()..writeln(['key', for (final l in languages) l.tag].map(q).join(','));
  for (final key in catalogs.first.keys) {
    b.writeln([key, for (final c in catalogs) c[key] ?? ''].map(q).join(','));
  }
  return b.toString();
}
