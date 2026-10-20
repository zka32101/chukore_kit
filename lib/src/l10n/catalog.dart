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
  m['nudgeTestSoon'] = s.nudgeTestSoon;
  m['nudgeReview'] = s.nudgeReview;
  m['nudgeStreak'] = s.nudgeStreak;
  m['myWeekGrew'] = s.myWeekGrew;
  m['myWeekOvercame'] = s.myWeekOvercame;
  m['myWeekKept'] = s.myWeekKept;
  m['myWeekStarted'] = s.myWeekStarted;
  m['myWeekRest'] = s.myWeekRest;
  m['reasonPrompt'] = s.reasonPrompt;
  m['reasonDontKnow'] = s.reasonDontKnow;
  m['reasonForgot'] = s.reasonForgot;
  m['reasonCareless'] = s.reasonCareless;
  m['reasonTimeShort'] = s.reasonTimeShort;
  m['breakLong'] = s.breakLong;
  m['breakMistakes'] = s.breakMistakes;
  m['breakSlowing'] = s.breakSlowing;
  m['breakRushing'] = s.breakRushing;
  m['peakAhead'] = s.peakAhead;
  m['talkGrew'] = s.talkGrew;
  m['talkOvercame'] = s.talkOvercame;
  m['talkSteady'] = s.talkSteady;
  m['talkStarted'] = s.talkStarted;
  m['talkRest'] = s.talkRest;
  m['eveNotice'] = s.eveNotice;
  m['testDayNotice'] = s.testDayNotice;
  m['cardAgain'] = s.cardAgain;
  m['cardHard'] = s.cardHard;
  m['cardGood'] = s.cardGood;
  m['cardFlip'] = s.cardFlip;
  m['ringsTitle'] = s.ringsTitle;
  for (final n in [0, 1, 2, 30]) {
    m['ringsSemantics($n)'] = s.ringsSemantics(n);
  }
  for (final n in [0, 1, 2, 30]) {
    m['ringsLatestMonth($n)'] = s.ringsLatestMonth('{month}', n);
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
  m['checklistTitle'] = s.checklistTitle;
  m['checklistProgress'] = s.checklistProgress(2, 6);
  m['checklistAllDone'] = s.checklistAllDone;
  m['fiveMinuteTitle'] = s.fiveMinuteTitle;
  for (final (id, label) in s.checklistDefaults) {
    m['checklistDefault($id)'] = label;
  }
  m['scopeQrTitle'] = s.scopeQrTitle;
  m['scopeQrHint'] = s.scopeQrHint;
  m['scopeQrSemantics'] = s.scopeQrSemantics;
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

/// キー `checklistDefault(id)` や `nudgeReview` から、文言のまとまり（接頭辞。最初の小文字の連なり）を取り出す。
String stringsKeyGroup(String key) {
  for (final p in _twoWordGroups) {
    if (key.startsWith(p)) return p;
  }
  return RegExp(r'^[a-z]+').firstMatch(key)?.group(0) ?? key;
}

/// 単語 2 つでひとまとまりの接頭辞（`myWeekGrew` を `my` ではなく `myWeek` にまとめる）。
const _twoWordGroups = ['myWeek', 'scopeQr', 'fiveMinute', 'testDay'];

final _placeholder = RegExp(r'\{[A-Za-z]+\}');

/// ネイティブの人に渡す、1 言語ぶんの確認シート（CSV）。列は
/// `key, まとまり, 日本語, English, <この言語>, 長さ, 残すもの, 直した文言, 理由`。
/// - 「長さ」= この言語の文字数 ÷ 日本語の文字数（ボタンに入るか・折り返すかの目安。日本語は漢字で短いので 3 倍くらいまでは普通）
/// - 「残すもの」= 訳の中に残すプレースホルダ（`{subject}` など）
/// - 最後の 2 列は、直したい文言と理由を書いてもらう欄（空）
String reviewPacketCsv(ChukoreStrings language) {
  String q(String v) => '"${v.replaceAll('"', '""')}"';
  final ja = stringsCatalog(ChukoreStrings.forLocale('ja'));
  final en = stringsCatalog(ChukoreStrings.forLocale('en'));
  final mine = stringsCatalog(language);
  final b = StringBuffer()
    ..writeln(['key', 'まとまり', '日本語', 'English', language.tag, '長さ', '残すもの', '直した文言', '理由'].map(q).join(','));
  for (final key in mine.keys) {
    final text = mine[key] ?? '';
    final base = ja[key] ?? '';
    final ratio = base.isEmpty ? '' : (text.runes.length / base.runes.length).toStringAsFixed(1);
    final keep = _placeholder.allMatches(base).map((m) => m.group(0)).toSet().join(' ');
    b.writeln([key, stringsKeyGroup(key), base, en[key] ?? '', text, ratio, keep, '', ''].map(q).join(','));
  }
  return b.toString();
}

/// 保護者ゲートの数の読み上げのうち、境目になる数（確認はこれを中心に）。
const reviewBoundaryNumbers = [
  1, 2, 9, 10, 11, 12, 13, 19, 20, 21, 22, 30, 40, 99, 100, 101, 110, 111, 200, 999, 1000, 1001, 1100, 1999, 2000, 2021, 9999 //
];

/// 数の読み上げの確認用 TSV（`数<タブ>読み`）。[numbers] 省略時は境目の数 [reviewBoundaryNumbers]。
String numberWordsTsv(ChukoreStrings language, [Iterable<int>? numbers]) {
  final b = StringBuffer();
  for (final n in numbers ?? reviewBoundaryNumbers) {
    b.writeln('$n\t${language.gateNumberWords(n)}');
  }
  return b.toString();
}
