import '../models/models.dart';
import '../question/card.dart';

/// ユーザーに見せる文言と、国ごとに違う表記の集まり。
/// 対応言語を増やすときは [ChukoreStrings] を実装して [ChukoreStrings.forLocale] に足す。
abstract class ChukoreStrings {
  const ChukoreStrings();

  /// 言語コード（`en`、`pt-BR`、`pt_PT` など）に合う文言。未対応の言語は英語。
  /// ポルトガル語は地域で綴りが違うので、`PT`（ポルトガル）のときだけ欧州式にする。
  /// 中国語は簡体（既定）・繁体（`Hant`・`TW`・`HK`・`MO`）。
  /// フランス語は `BE`・`CH` で 70・90 を septante・nonante と言う。
  /// スペイン語は地域で小数点が違う（メキシコなどは `.`、スペインなど多くは `,`）。
  factory ChukoreStrings.forLocale(String locale) {
    final parts = locale.toLowerCase().split(RegExp('[-_]'));
    return switch (parts.first) {
      'ja' => const JaStrings(),
      'pt' => parts.length > 1 && parts[1] == 'pt' ? const PtStrings(european: true) : const PtStrings(),
      'ko' => const KoStrings(),
      // `in` は Android・Java で使われる旧式のインドネシア語のコード
      'id' || 'in' => const IdStrings(),
      'vi' => const ViStrings(),
      'tr' => const TrStrings(),
      'th' => const ThStrings(),
      'hi' => const HiStrings(),
      'ar' => const ArStrings(),
      'ru' => const RuStrings(),
      'it' => const ItStrings(),
      'nl' => const NlStrings(),
      'pl' => const PlStrings(),
      // スイス・リヒテンシュタインは小数点が `.`、ß を使わない（ss）
      'de' => DeStrings(swiss: parts.length > 1 && DeStrings.swissRegions.contains(parts[1])),
      'zh' => ZhStrings(traditional: ZhStrings.isTraditional(parts)),
      'fr' => FrStrings(septanteNonante: parts.length > 1 && FrStrings.septanteNonanteRegions.contains(parts[1])),
      'es' => EsStrings(decimalComma: !(parts.length > 1 && EsStrings.decimalPointRegions.contains(parts[1]))),
      _ => const EnStrings(),
    };
  }

  String get languageCode;

  /// 一覧・確認用の識別子（地域で内容が違う言語は地域つき。例: `pt-BR`・`pt-PT`）。
  String get tag => languageCode;

  /// その言語での言語名（設定画面の言語リストに出す。例: `日本語`・`Deutsch (Schweiz)`）。
  /// 地域で内容が違う言語は地域つき。[tag] ごとに決まった名前を返す。
  String get languageName => _languageNames[tag] ?? tag;

  static const Map<String, String> _languageNames = {
    'ja': '日本語',
    'en': 'English',
    'pt-BR': 'Português (Brasil)',
    'pt-PT': 'Português (Portugal)',
    'es': 'Español (España)',
    'es-MX': 'Español (México)',
    'fr': 'Français (France)',
    'fr-BE': 'Français (Belgique)',
    'ko': '한국어',
    'id': 'Bahasa Indonesia',
    'vi': 'Tiếng Việt',
    'tr': 'Türkçe',
    'th': 'ไทย',
    'hi': 'हिन्दी',
    'ar': 'العربية',
    'ru': 'Русский',
    'it': 'Italiano',
    'nl': 'Nederlands',
    'pl': 'Polski',
    'de': 'Deutsch (Deutschland)',
    'de-CH': 'Deutsch (Schweiz)',
    'zh-Hans': '简体中文',
    'zh-Hant': '繁體中文',
  };

  /// 対応している文言の一覧（翻訳確認の書き出し・検査に使う）。言語を足したらここにも足す。
  static const List<ChukoreStrings> supported = [
    JaStrings(),
    EnStrings(),
    PtStrings(),
    PtStrings(european: true),
    EsStrings(),
    EsStrings(decimalComma: false),
    FrStrings(),
    FrStrings(septanteNonante: true),
    KoStrings(),
    IdStrings(),
    ViStrings(),
    TrStrings(),
    ThStrings(),
    HiStrings(),
    ArStrings(),
    RuStrings(),
    ItStrings(),
    NlStrings(),
    PlStrings(),
    DeStrings(),
    DeStrings(swiss: true),
    ZhStrings(),
    ZhStrings(traditional: true),
  ];

  /// 右から左に書く言語か（アラビア語など）。画面部品は、これを見て文字の向きと並びを決める。
  bool get rightToLeft => false;

  /// 小数点の記号。数値入力の `checkAnswer(..., decimalSeparator:)` にもこの値を渡す。
  String get decimalSeparator => '.';

  /// 点数などの小数の表記（小数点は国で違う）。整数は小数点なし。
  String formatNumber(double v) {
    // 先に小数1桁へ丸める（2.96 → 3、0.04 → 0、-0.04 → 0。「3.0」「-0.0」にしない）
    final r = (v * 10).round() / 10;
    return r == r.roundToDouble()
        ? r.round().toString()
        : r.toStringAsFixed(1).replaceAll('.', decimalSeparator);
  }

  // --- 保護者ゲート ---
  /// 出題する数（100〜999）の読み上げ表記。ja は漢数字、en は英単語。
  String gateNumberWords(int n);

  // --- 成長カード ---
  String cardTitle(String subject);
  String get headlinePersonalBest;
  String get headlineFirst;
  String headlineUp(String points);
  String get headlineSame;

  /// 点が下がった回。数字は出さず、落ち込ませない。
  String get headlineDown;
  String nextLevel(String points);
  String get topLevel;
  String streakDays(int days);
  String get statStamps;
  String get statSolvable;
  String solvableValue(int count);
  String cardSemantics(String headline, String level);

  // --- 地図・年表 ---
  String get mapSemantics;

  /// 西暦。紀元前は負の値。
  String formatYear(int year);

  // --- 週次レポート ---
  String reportHeader(int activeDays, int attempts);
  String get reportImprovedTitle;
  String reportItem(String title, int beforePercent, int afterPercent);
  String get reportEmpty;

  // --- 範囲カードの共有（QR）---
  String get scopeQrTitle;
  String get scopeQrHint;
  String get scopeQrSemantics;

  // --- 当日チェック・直前5分カード ---
  String get checklistTitle;
  String checklistProgress(int done, int total);
  String get checklistAllDone;
  String get fiveMinuteTitle;

  /// 持ち物の既定の項目（IDは全言語で同じ）。
  List<(String id, String label)> get checklistDefaults;

  // --- 直前プリント ---
  String get sheetTitle;
  String get sheetQuestion;
  String get sheetAnswer;
  String get sheetExplanation;
  String get sheetEmpty;

  // --- アクセシビリティ（色だけに頼らない）---
  String get markCorrect;
  String get markWrong;

  // --- 成長の年輪・アプリ内偏差値 ---
  String get ringsTitle;
  String ringsSemantics(int totalDays);

  /// 最新の月の学習日数。[month] は `2026-10` の形（言語に依らない数字の表記）。
  String ringsLatestMonth(String month, int days);
  String get deviationLabel;
  String deviationRange(String low, String high);
  String get deviationNote;

  // --- 先生役モード（まちがいキャラ）---
  String get teacherPrompt;
  String get teacherCorrect;
  String get teacherWrong;

  /// 学習を促す通知の文言（数字を含めない短い文。回数や日数は呼び出し側が添える）。
  /// 責める言い方はしない。決め方は [decideNudge]。
  String get nudgeTestSoon;
  String get nudgeReview;
  String get nudgeStreak;

  /// 子ども本人が見る週のふりかえりの見出し（数字を含まない、責めない短い文）。決め方は [buildMyWeek]。
  String get myWeekGrew;
  String get myWeekOvercame;
  String get myWeekKept;
  String get myWeekStarted;
  String get myWeekRest;

  /// 間違えたあとに理由を聞く文言（答えなくてもよい）と、選択肢のラベル。
  String get reasonPrompt;
  String get reasonDontKnow;
  String get reasonForgot;
  String get reasonCareless;
  String get reasonTimeShort;

  /// 休憩を勧める文言（責めない短い文。数字を含まない）。決め方は [suggestBreak]。
  String get breakLong;
  String get breakMistakes;
  String get breakSlowing;
  String get breakRushing;

  /// 問題の多い日が近づいたときの予告（数字を含まない、責めない一文）。決め方は [findPeakAhead]。
  String get peakAhead;

  /// 保護者への「声かけ」の提案（責めない、結果より取り組みをほめる、他の子や先週と比べない。数字を含まない）。決め方は [suggestGuardianTalk]。
  String get talkGrew;
  String get talkOvercame;
  String get talkSteady;
  String get talkStarted;
  String get talkRest;

  /// 本番の点を入れるかの案内（入れなくてよい）。
  String get outcomeAsk;

  /// 点の入力を今はしない。
  String get outcomeSkip;

  /// 使い始める前の点を任意で聞く。
  String get outcomeBaselineAsk;

  /// 最初の記録（比べる相手がまだ無い）。
  String get outcomeFirst;

  /// 前より上がった（ノイズ幅を超えて）。
  String get outcomeUp;

  /// ほぼ同じ。
  String get outcomeSame;

  /// 前より下がった。責めない。
  String get outcomeDown;

  /// 自分で入れた記録で、結果の保証ではない。
  String get outcomeDisclaimer;

  /// 前日・当日に出す一言（新しいことを増やさない、落ち着いて。数字を含まない）。使い方は [guardLastDays]。
  String get eveNotice;
  String get testDayNotice;

  /// 暗記カードの自己採点ボタン（わからない・あやしい・わかった）と、カードをめくるボタン。
  String get cardAgain;
  String get cardHard;
  String get cardGood;
  String get cardFlip;

  /// [CardRating] に合うボタンのラベル。
  String cardRatingLabel(CardRating r) => switch (r) {
        CardRating.again => cardAgain,
        CardRating.hard => cardHard,
        CardRating.good => cardGood,
      };

  /// [LossReason] に合うラベル。
  String reasonLabel(LossReason r) => switch (r) {
        LossReason.dontKnow => reasonDontKnow,
        LossReason.forgot => reasonForgot,
        LossReason.careless => reasonCareless,
        LossReason.timeShort => reasonTimeShort,
      };
}

class JaStrings extends ChukoreStrings {
  const JaStrings();

  static const _digits = ['', '一', '二', '三', '四', '五', '六', '七', '八', '九'];

  @override
  String get languageCode => 'ja';

  @override
  String gateNumberWords(int n) {
    if (n < 1 || n > 9999) throw RangeError.range(n, 1, 9999, 'n');
    final b = StringBuffer();
    void unit(int d, String u) {
      if (d == 0) return;
      if (d != 1) b.write(_digits[d]);
      b.write(u);
    }

    unit(n ~/ 1000, '千');
    unit(n % 1000 ~/ 100, '百');
    unit(n % 100 ~/ 10, '十');
    b.write(_digits[n % 10]);
    return b.toString();
  }

  @override
  String cardTitle(String subject) => '$subject  成長カード';
  @override
  String get headlinePersonalBest => '自己ベスト更新！';
  @override
  String get headlineFirst => 'はじめの一歩';
  @override
  String headlineUp(String points) => '前回より +$points点';
  @override
  String get headlineSame => '前回と同じ。安定してきた';
  @override
  String get headlineDown => 'ここからまた伸ばそう';
  @override
  String nextLevel(String points) => 'あと$points点で次のレベル';
  @override
  String get topLevel => '最高レベルに到達！';
  @override
  String streakDays(int days) => '$days日 続けている';
  @override
  String get statStamps => '克服スタンプ';
  @override
  String get statSolvable => 'できるようになった';
  @override
  String solvableValue(int count) => '$count問';
  @override
  String cardSemantics(String headline, String level) => '成長カード。$headline。レベル$level';
  @override
  String get mapSemantics => '地図。タップして答えを選ぶ';
  @override
  String formatYear(int year) => year < 0 ? '前${-year}年' : '$year年';
  @override
  String reportHeader(int activeDays, int attempts) => '今週の学習: $activeDays日 / $attempts問';
  @override
  String get reportImprovedTitle => '今週伸びた所:';
  @override
  String reportItem(String title, int b, int a) => '・$title（$b% → $a%）';
  @override
  String get reportEmpty => '今週は新しく伸びた単元はありませんでした。来週もゆっくり続けましょう。';
  @override
  String get teacherPrompt => 'まちがいキャラのここ、どこが違う？';
  @override
  String get teacherCorrect => '正解！ちゃんと直せたね';
  @override
  String get teacherWrong => 'おしい！もう一度、よく読んでみよう';
  @override
  String get nudgeTestSoon => 'テストが近づいてきたよ。今日の分、少しだけやってみよう';
  @override
  String get nudgeReview => '忘れる前に、ちょっと復習しよう';
  @override
  String get nudgeStreak => '今日も少しだけやって、連続記録をのばそう';
  @override
  String get myWeekGrew => 'のびたところがあるよ！';
  @override
  String get myWeekOvercame => 'つまずきをのりこえたよ！';
  @override
  String get myWeekKept => 'こつこつ続けられたね';
  @override
  String get myWeekStarted => 'はじめの一歩、いいね！';
  @override
  String get myWeekRest => 'ひとやすみの週。またいつでも始めよう';
  @override
  String get reasonPrompt => 'どうして間違えたかな？（答えなくてもいいよ）';
  @override
  String get reasonDontKnow => 'わからなかった';
  @override
  String get reasonForgot => '忘れていた';
  @override
  String get reasonCareless => 'うっかり';
  @override
  String get reasonTimeShort => '時間が足りなかった';
  @override
  String get breakLong => 'ずっとがんばっているね。ちょっと休んで水を飲もう';
  @override
  String get breakMistakes => 'つづけて間違えちゃったね。ひと休みしてからもう一度やろう';
  @override
  String get breakSlowing => '少し疲れてきたかな？ひと休みしよう';
  @override
  String get breakRushing => 'はやく答えすぎているかも。ゆっくり深呼吸して、問題をよく読もう';
  @override
  String get peakAhead => "あした以降に、問題の多い日があるよ。少しずつ先にやっておこう";
  @override
  String get talkGrew => '伸びたところを、お子さんに教えてもらいましょう。「どうやったの？」と聞いてみてください';
  @override
  String get talkOvercame => 'つまずきを乗りこえました。結果よりも、取り組んだことをほめましょう';
  @override
  String get talkSteady => 'こつこつ続けられています。続けていること自体をほめましょう';
  @override
  String get talkStarted => 'はじめの一歩が出ています。少しでも十分です。「やってみたんだね」と声をかけましょう';
  @override
  String get talkRest => '今週はお休みでした。責めずに、「いつでも始められるよ」と伝えましょう';
  @override
  String get outcomeAsk => 'テストの点を入れてみる？ 入れなくても大丈夫だよ';
  @override
  String get outcomeSkip => 'あとで';
  @override
  String get outcomeBaselineAsk => '使い始める前の、いちばん最近のテストの点があれば入れてね。なくても大丈夫だよ';
  @override
  String get outcomeFirst => '記録したよ。次のテストのときに、並べて見られるよ';
  @override
  String get outcomeUp => '前より点が上がったね。やったね！';
  @override
  String get outcomeSame => '前とほぼ同じだったよ。続けているのがすごいよ';
  @override
  String get outcomeDown => '今回は前より低かったよ。大丈夫、どこが難しかったか、いっしょに見てみよう';
  @override
  String get outcomeDisclaimer => '自分で入れた点の記録だよ。点が上がることを約束するものではないよ';
  @override
  String get eveNotice => 'あしたはテスト。新しいことは増やさず、やったところの見直しだけにしよう';
  @override
  String get testDayNotice => 'きょうはテスト。軽く見直すだけで大丈夫。いつもどおりにね';
  @override
  String get cardAgain => 'わからない';
  @override
  String get cardHard => 'あやしい';
  @override
  String get cardGood => 'わかった';
  @override
  String get cardFlip => 'めくる';
  @override
  String get ringsTitle => '成長の年輪';
  @override
  String ringsSemantics(int totalDays) => '成長の年輪。これまで合計$totalDays日 学習しました';
  @override
  String ringsLatestMonth(String month, int days) =>
      '直近の月（$month）は$days日 学習しました';
  @override
  String get deviationLabel => 'アプリ内偏差値';
  @override
  String deviationRange(String low, String high) => '$low〜$high';
  @override
  String get deviationNote => '想定した集団の平均を50とした、アプリ内だけの目安です。全国の偏差値ではありません。';
  @override
  String get markCorrect => '正解';
  @override
  String get markWrong => '不正解';
  @override
  String get sheetTitle => '直前プリント';
  @override
  String get sheetQuestion => '問題';
  @override
  String get sheetAnswer => '答え';
  @override
  String get sheetExplanation => '解説';
  @override
  String get sheetEmpty => '直すところは今のところありません。よくがんばったね！';
  @override
  String get checklistTitle => '当日チェック';
  @override
  String checklistProgress(int done, int total) => '$done/$total そろった';
  @override
  String get checklistAllDone => 'ぜんぶそろったよ！いってらっしゃい';
  @override
  String get fiveMinuteTitle => '直前5分カード';
  @override
  List<(String, String)> get checklistDefaults => [
        ('pencil', '筆記用具'),
        ('eraser', '消しゴム'),
        ('ruler', '定規・コンパス'),
        ('watch', '時計'),
        ('tissue', 'ハンカチ・ティッシュ'),
        ('notes', '直前ノート'),
      ];
  @override
  String get scopeQrTitle => 'テスト範囲を渡す';
  @override
  String get scopeQrHint => '友達や家族に読み取ってもらうと、同じ範囲を設定できます。名前や成績は入っていません。';
  @override
  String get scopeQrSemantics => 'テスト範囲のQRコード';
}

class EnStrings extends ChukoreStrings {
  const EnStrings();

  static const _ones = [
    '', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten',
    'eleven', 'twelve', 'thirteen', 'fourteen', 'fifteen', 'sixteen', 'seventeen',
    'eighteen', 'nineteen',
  ];
  static const _tens = ['', '', 'twenty', 'thirty', 'forty', 'fifty', 'sixty', 'seventy', 'eighty', 'ninety'];

  @override
  String get languageCode => 'en';

  @override
  String gateNumberWords(int n) {
    if (n < 1 || n > 9999) throw RangeError.range(n, 1, 9999, 'n');
    final parts = <String>[];
    if (n >= 1000) parts.add('${_ones[n ~/ 1000]} thousand');
    final h = n % 1000 ~/ 100;
    if (h > 0) parts.add('${_ones[h]} hundred');
    final r = n % 100;
    if (r > 0) {
      parts.add(r < 20
          ? _ones[r]
          : (r % 10 == 0 ? _tens[r ~/ 10] : '${_tens[r ~/ 10]}-${_ones[r % 10]}'));
    }
    return parts.join(' ');
  }

  @override
  String cardTitle(String subject) => '$subject Growth Card';
  @override
  String get headlinePersonalBest => 'New personal best!';
  @override
  String get headlineFirst => 'A great start';
  @override
  String headlineUp(String points) => '+$points from last time';
  @override
  String get headlineSame => 'Steady, same as last time';
  @override
  String get headlineDown => "Let's build from here";
  @override
  String nextLevel(String points) =>
      points == '1' ? '1 more point to the next level' : '$points more points to the next level';
  @override
  String get topLevel => 'Top level reached!';
  @override
  String streakDays(int days) => days == 1 ? '1-day streak' : '$days-day streak';
  @override
  String get statStamps => 'Mastered';
  @override
  String get statSolvable => 'Can now solve';
  @override
  String solvableValue(int count) => count == 1 ? '1 question' : '$count questions';
  @override
  String cardSemantics(String headline, String level) => 'Growth card. $headline. Level $level';
  @override
  String get mapSemantics => 'Map. Tap to choose your answer';
  @override
  String formatYear(int year) => year < 0 ? '${-year} BCE' : '$year CE';
  @override
  String reportHeader(int activeDays, int attempts) =>
      'This week: ${activeDays == 1 ? '1 day' : '$activeDays days'} / '
      '${attempts == 1 ? '1 question' : '$attempts questions'}';
  @override
  String get reportImprovedTitle => 'Improved this week:';
  @override
  String reportItem(String title, int b, int a) => '- $title ($b% -> $a%)';
  @override
  String get reportEmpty => 'No new improvements this week. Keep going at your own pace.';
  @override
  String get teacherPrompt => 'What is wrong here? Fix the mistake';
  @override
  String get teacherCorrect => 'Correct! You fixed it';
  @override
  String get teacherWrong => 'Almost! Read it once more';
  @override
  String get nudgeTestSoon => 'Your test is getting close. Try a little today';
  @override
  String get nudgeReview => 'A quick review keeps it fresh';
  @override
  String get nudgeStreak => 'Keep your streak going with a little practice today';
  @override
  String get myWeekGrew => 'You made progress this week!';
  @override
  String get myWeekOvercame => 'You got past a tricky spot!';
  @override
  String get myWeekKept => 'Nice and steady, keep it up';
  @override
  String get myWeekStarted => 'A great first step!';
  @override
  String get myWeekRest => 'A quiet week. Start again whenever you like';
  @override
  String get reasonPrompt => 'Why did it go wrong? (You can skip this)';
  @override
  String get reasonDontKnow => "I didn't know it";
  @override
  String get reasonForgot => 'I forgot';
  @override
  String get reasonCareless => 'A careless slip';
  @override
  String get reasonTimeShort => 'I ran out of time';
  @override
  String get breakLong => 'You have worked hard. Take a short break and have some water';
  @override
  String get breakMistakes => 'A few misses in a row. Take a short break, then try again';
  @override
  String get breakSlowing => 'Getting tired? Take a short break';
  @override
  String get breakRushing => 'Answering very fast. Take a breath and read each question carefully';
  @override
  String get peakAhead => "A busier day is coming up. Let’s get a little ahead of it";
  @override
  String get talkGrew => 'Ask your child to teach you what improved. "How did you do it?" is a good start';
  @override
  String get talkOvercame => 'Your child got past a stumbling block. Praise the effort rather than the result';
  @override
  String get talkSteady => 'Your child is keeping at it steadily. Praise the steady effort itself';
  @override
  String get talkStarted => 'A first step has been taken, and a little is enough. Try saying "You gave it a go"';
  @override
  String get talkRest => 'This was a rest week. No blame; just let them know they can start any time';
  @override
  String get outcomeAsk => 'Want to add your test score? It is fine to skip.';
  @override
  String get outcomeSkip => 'Later';
  @override
  String get outcomeBaselineAsk => 'If you have your most recent test score from before you started, add it. It is fine if you do not.';
  @override
  String get outcomeFirst => 'Saved. You can see it next to your next test.';
  @override
  String get outcomeUp => 'Your score is higher than last time. Nice work!';
  @override
  String get outcomeSame => 'About the same as last time. Sticking with it is great.';
  @override
  String get outcomeDown => 'It was lower this time. That is okay. Let us look at what felt hard together.';
  @override
  String get outcomeDisclaimer => 'This is a record of the scores you entered. It does not promise your score will go up.';
  @override
  String get eveNotice => 'The test is tomorrow. No new material now; just look back over what you have already done';
  @override
  String get testDayNotice => 'The test is today. A light look back is plenty. Just be yourself';
  @override
  String get cardAgain => "Don't know";
  @override
  String get cardHard => 'Not sure';
  @override
  String get cardGood => 'Got it';
  @override
  String get cardFlip => 'Flip';
  @override
  String get ringsTitle => 'Growth rings';
  @override
  String ringsSemantics(int totalDays) =>
      'Growth rings. ${totalDays == 1 ? '1 day' : '$totalDays days'} of practice in total';
  @override
  String ringsLatestMonth(String month, int days) =>
      'Latest month, $month: ${days == 1 ? '1 day' : '$days days'} of practice';
  @override
  String get deviationLabel => 'In-app score index';
  @override
  String deviationRange(String low, String high) => '$low–$high';
  @override
  String get deviationNote =>
      'A rough index used only within this app, where 50 is the average of an assumed group. It is not a nationwide ranking.';
  @override
  String get markCorrect => 'correct';
  @override
  String get markWrong => 'incorrect';
  @override
  String get sheetTitle => 'Last-minute sheet';
  @override
  String get sheetQuestion => 'Question';
  @override
  String get sheetAnswer => 'Answer';
  @override
  String get sheetExplanation => 'Explanation';
  @override
  String get sheetEmpty => 'Nothing to fix right now. Great work!';
  @override
  String get checklistTitle => 'Test-day check';
  @override
  String checklistProgress(int done, int total) => '$done of $total ready';
  @override
  String get checklistAllDone => 'Everything is ready. Good luck!';
  @override
  String get fiveMinuteTitle => 'Last 5 minutes card';
  @override
  List<(String, String)> get checklistDefaults => [
        ('pencil', 'Pens and pencils'),
        ('eraser', 'Eraser'),
        ('ruler', 'Ruler and compass'),
        ('watch', 'Watch'),
        ('tissue', 'Handkerchief and tissues'),
        ('notes', 'Review notes'),
      ];
  @override
  String get scopeQrTitle => 'Share your test scope';
  @override
  String get scopeQrHint => 'Friends or family can scan this to set the same scope. It contains no names or scores.';
  @override
  String get scopeQrSemantics => 'QR code for the test scope';
}

/// ポルトガル語。既定はブラジル式（pt-BR）。[european] が true ならポルトガル式（pt-PT）の綴り。
class PtStrings extends ChukoreStrings {
  const PtStrings({this.european = false});

  /// pt-PT の綴り（dezasseis・dezassete・dezanove）にする。
  final bool european;

  static const _units = ['', 'um', 'dois', 'três', 'quatro', 'cinco', 'seis', 'sete', 'oito', 'nove'];
  static const _teensBr = [
    'dez', 'onze', 'doze', 'treze', 'catorze', 'quinze', 'dezesseis', 'dezessete', 'dezoito', 'dezenove',
  ];
  static const _teensPt = [
    'dez', 'onze', 'doze', 'treze', 'catorze', 'quinze', 'dezasseis', 'dezassete', 'dezoito', 'dezanove',
  ];
  static const _tens = ['', '', 'vinte', 'trinta', 'quarenta', 'cinquenta', 'sessenta', 'setenta', 'oitenta', 'noventa'];
  static const _hundreds = [
    '', 'cento', 'duzentos', 'trezentos', 'quatrocentos', 'quinhentos', 'seiscentos', 'setecentos',
    'oitocentos', 'novecentos',
  ];

  @override
  String get languageCode => 'pt';

  @override
  String get tag => european ? 'pt-PT' : 'pt-BR';

  @override
  String get decimalSeparator => ',';

  /// 1〜999 の読み（「cem」「cento e um」「quatrocentos e oitenta e dois」）。
  String _below1000(int n) {
    final h = n ~/ 100, r = n % 100;
    if (n == 100) return 'cem';
    final parts = <String>[];
    if (h > 0) parts.add(_hundreds[h]);
    if (r > 0) {
      parts.add(r < 10
          ? _units[r]
          : r < 20
              ? (european ? _teensPt : _teensBr)[r - 10]
              : (r % 10 == 0 ? _tens[r ~/ 10] : '${_tens[r ~/ 10]} e ${_units[r % 10]}'));
    }
    return parts.join(' e ');
  }

  @override
  String gateNumberWords(int n) {
    if (n < 1 || n > 9999) throw RangeError.range(n, 1, 9999, 'n');
    final th = n ~/ 1000, r = n % 1000;
    final thousands = th == 0 ? '' : (th == 1 ? 'mil' : '${_units[th]} mil');
    if (r == 0) return thousands;
    // 「mil e quinhentos」「mil e vinte」だが「mil trezentos e quarenta」（余りが100未満か百の位だけのとき e）
    final joiner = (r < 100 || r % 100 == 0) ? ' e ' : ' ';
    return th == 0 ? _below1000(r) : '$thousands$joiner${_below1000(r)}';
  }

  @override
  String cardTitle(String subject) => '$subject · Cartão de progresso';
  @override
  String get headlinePersonalBest => 'Novo recorde pessoal!';
  @override
  String get headlineFirst => 'Um ótimo começo';
  @override
  String headlineUp(String points) => '+$points desde a última vez';
  @override
  String get headlineSame => 'Estável, igual à última vez';
  @override
  String get headlineDown => 'Vamos crescer a partir daqui';
  @override
  String nextLevel(String points) =>
      points == '1' ? 'Falta 1 ponto para o próximo nível' : 'Faltam $points pontos para o próximo nível';
  @override
  String get topLevel => 'Nível máximo alcançado!';
  @override
  String streakDays(int days) => days == 1 ? '1 dia seguido' : '$days dias seguidos';
  @override
  String get statStamps => 'Superados';
  @override
  String get statSolvable => 'Já sei resolver';
  @override
  String solvableValue(int count) => count == 1 ? '1 questão' : '$count questões';
  @override
  String cardSemantics(String headline, String level) => 'Cartão de progresso. $headline. Nível $level';
  @override
  String get mapSemantics => 'Mapa. Toque para escolher a resposta';
  @override
  String formatYear(int year) => year < 0 ? '${-year} a.C.' : '$year d.C.';
  @override
  String reportHeader(int activeDays, int attempts) =>
      'Esta semana: ${activeDays == 1 ? '1 dia' : '$activeDays dias'} / '
      '${attempts == 1 ? '1 questão' : '$attempts questões'}';
  @override
  String get reportImprovedTitle => 'Evoluiu esta semana:';
  @override
  String reportItem(String title, int b, int a) => '- $title ($b% -> $a%)';
  @override
  String get reportEmpty => 'Nenhuma evolução nova esta semana. Continue no seu ritmo.';
  @override
  String get teacherPrompt => 'O que está errado aqui? Corrija o erro';
  @override
  String get teacherCorrect => 'Correto! Você corrigiu';
  @override
  String get teacherWrong => 'Quase! Leia mais uma vez';
  @override
  String get nudgeTestSoon => 'A prova está chegando. Faça um pouquinho hoje';
  @override
  String get nudgeReview => 'Uma revisão rápida ajuda a não esquecer';
  @override
  String get nudgeStreak => 'Mantenha sua sequência com um pouco de prática hoje';
  @override
  String get myWeekGrew => 'Você progrediu esta semana!';
  @override
  String get myWeekOvercame => 'Você superou um ponto difícil!';
  @override
  String get myWeekKept => 'Constância é tudo, continue assim';
  @override
  String get myWeekStarted => 'Um ótimo primeiro passo!';
  @override
  String get myWeekRest => 'Uma semana tranquila. Recomece quando quiser';
  @override
  String get reasonPrompt => 'Por que errou? (pode pular)';
  @override
  String get reasonDontKnow => 'Não sabia';
  @override
  String get reasonForgot => 'Esqueci';
  @override
  String get reasonCareless => 'Distração';
  @override
  String get reasonTimeShort => 'Faltou tempo';
  @override
  String get breakLong => 'Você estudou bastante. Faça uma pausa e beba água';
  @override
  String get breakMistakes => 'Alguns erros seguidos. Faça uma pausa e tente de novo';
  @override
  String get breakSlowing => 'Cansou um pouco? Faça uma pausa';
  @override
  String get breakRushing => 'Respondendo rápido demais. Respire e leia cada pergunta com calma';
  @override
  String get peakAhead => "Vem aí um dia com mais questões. Vamos adiantar um pouquinho";
  @override
  String get talkGrew => 'Peça para seu filho ensinar o que melhorou. "Como você fez?" é um bom começo';
  @override
  String get talkOvercame => 'Seu filho superou uma dificuldade. Elogie o esforço, mais do que o resultado';
  @override
  String get talkSteady => 'Seu filho está sendo constante. Elogie a constância em si';
  @override
  String get talkStarted => 'O primeiro passo foi dado, e um pouco já basta. Experimente dizer "Você tentou"';
  @override
  String get talkRest => 'Esta foi uma semana de descanso. Sem cobrança; diga que ele pode começar quando quiser';
  @override
  String get outcomeAsk => 'Quer registrar a nota da sua prova? Pode pular, sem problema.';
  @override
  String get outcomeSkip => 'Depois';
  @override
  String get outcomeBaselineAsk => 'Se tiver a nota da sua prova mais recente, de antes de começar, pode registrar. Se não tiver, tudo bem.';
  @override
  String get outcomeFirst => 'Registrado. Você poderá ver ao lado da próxima prova.';
  @override
  String get outcomeUp => 'Sua nota subiu em relação à anterior. Parabéns!';
  @override
  String get outcomeSame => 'Ficou quase igual à anterior. Manter a constância é muito bom.';
  @override
  String get outcomeDown => 'Dessa vez foi mais baixa. Tudo bem. Vamos ver juntos o que foi difícil.';
  @override
  String get outcomeDisclaimer => 'Este é um registro das notas que você informou. Não é uma promessa de que a nota vai subir.';
  @override
  String get eveNotice => 'A prova é amanhã. Sem conteúdo novo agora; só revise o que você já estudou';
  @override
  String get testDayNotice => 'A prova é hoje. Uma revisão leve basta. Fique tranquilo, como sempre';
  @override
  String get cardAgain => 'Não sei';
  @override
  String get cardHard => 'Em dúvida';
  @override
  String get cardGood => 'Entendi';
  @override
  String get cardFlip => 'Virar';
  @override
  String get ringsTitle => 'Anéis de crescimento';
  @override
  String ringsSemantics(int totalDays) =>
      'Anéis de crescimento. ${totalDays == 1 ? '1 dia' : '$totalDays dias'} de estudo no total';
  @override
  String ringsLatestMonth(String month, int days) =>
      'Mês mais recente, $month: ${days == 1 ? '1 dia' : '$days dias'} de estudo';
  @override
  String get deviationLabel => 'Índice de pontuação do app';
  @override
  String deviationRange(String low, String high) => '$low–$high';
  @override
  String get deviationNote =>
      'Um índice aproximado, válido só dentro do app, em que 50 é a média de um grupo de referência. Não é uma classificação nacional.';
  @override
  String get markCorrect => 'correto';
  @override
  String get markWrong => 'incorreto';
  @override
  String get sheetTitle => 'Folha de revisão final';
  @override
  String get sheetQuestion => 'Questão';
  @override
  String get sheetAnswer => 'Resposta';
  @override
  String get sheetExplanation => 'Explicação';
  @override
  String get sheetEmpty => 'Nada para corrigir agora. Ótimo trabalho!';
  @override
  String get checklistTitle => 'Checklist do dia da prova';
  @override
  String checklistProgress(int done, int total) => '$done de $total prontos';
  @override
  String get checklistAllDone => 'Tudo pronto. Boa sorte!';
  @override
  String get fiveMinuteTitle => 'Cartão dos últimos 5 minutos';
  @override
  List<(String, String)> get checklistDefaults => [
        ('pencil', 'Canetas e lápis'),
        ('eraser', 'Borracha'),
        ('ruler', 'Régua e compasso'),
        ('watch', 'Relógio'),
        ('tissue', 'Lenço e lenços de papel'),
        ('notes', 'Anotações de revisão'),
      ];
  @override
  String get scopeQrTitle => 'Compartilhar o conteúdo da prova';
  @override
  String get scopeQrHint =>
      'Amigos ou família podem escanear para definir o mesmo conteúdo. Não contém nomes nem notas.';
  @override
  String get scopeQrSemantics => 'Código QR do conteúdo da prova';
}

/// スペイン語。[decimalComma] が false なら小数点が `.` の地域（メキシコ・米国・中米の一部など）。
class EsStrings extends ChukoreStrings {
  const EsStrings({this.decimalComma = true});

  /// 小数点が `.` の地域（`es-MX` など。ベストエフォート。他の地域は `EsStrings(decimalComma: false)` で個別指定）。
  static const decimalPointRegions = {'mx', 'us', 'gt', 'hn', 'ni', 'sv', 'do', 'pr', 'pa'};

  final bool decimalComma;

  static const _units = ['', 'uno', 'dos', 'tres', 'cuatro', 'cinco', 'seis', 'siete', 'ocho', 'nueve'];
  static const _teens = [
    'diez', 'once', 'doce', 'trece', 'catorce', 'quince', 'dieciséis', 'diecisiete', 'dieciocho', 'diecinueve',
  ];
  static const _twenties = [
    'veinte', 'veintiuno', 'veintidós', 'veintitrés', 'veinticuatro', 'veinticinco', 'veintiséis',
    'veintisiete', 'veintiocho', 'veintinueve',
  ];
  static const _tens = ['', '', '', 'treinta', 'cuarenta', 'cincuenta', 'sesenta', 'setenta', 'ochenta', 'noventa'];
  static const _hundreds = [
    '', 'ciento', 'doscientos', 'trescientos', 'cuatrocientos', 'quinientos', 'seiscientos', 'setecientos',
    'ochocientos', 'novecientos',
  ];

  @override
  String get languageCode => 'es';

  @override
  String get tag => decimalComma ? 'es' : 'es-MX';

  @override
  String get decimalSeparator => decimalComma ? ',' : '.';

  /// 1〜999 の読み（「cien」「ciento uno」「cuatrocientos ochenta y dos」）。
  String _below1000(int n) {
    if (n == 100) return 'cien';
    final h = n ~/ 100, r = n % 100;
    final parts = <String>[];
    if (h > 0) parts.add(_hundreds[h]);
    if (r > 0) {
      parts.add(r < 10
          ? _units[r]
          : r < 20
              ? _teens[r - 10]
              : r < 30
                  ? _twenties[r - 20]
                  : (r % 10 == 0 ? _tens[r ~/ 10] : '${_tens[r ~/ 10]} y ${_units[r % 10]}'));
    }
    return parts.join(' ');
  }

  @override
  String gateNumberWords(int n) {
    if (n < 1 || n > 9999) throw RangeError.range(n, 1, 9999, 'n');
    final th = n ~/ 1000, r = n % 1000;
    final thousands = th == 0 ? '' : (th == 1 ? 'mil' : '${_units[th]} mil');
    if (r == 0) return thousands;
    return th == 0 ? _below1000(r) : '$thousands ${_below1000(r)}';
  }

  @override
  String cardTitle(String subject) => '$subject · Tarjeta de progreso';
  @override
  String get headlinePersonalBest => '¡Nuevo récord personal!';
  @override
  String get headlineFirst => 'Un gran comienzo';
  @override
  String headlineUp(String points) => '+$points desde la última vez';
  @override
  String get headlineSame => 'Estable, igual que la última vez';
  @override
  String get headlineDown => 'Sigamos creciendo desde aquí';
  @override
  String nextLevel(String points) =>
      points == '1' ? 'Falta 1 punto para el siguiente nivel' : 'Faltan $points puntos para el siguiente nivel';
  @override
  String get topLevel => '¡Nivel máximo alcanzado!';
  @override
  String streakDays(int days) => days == 1 ? '1 día seguido' : '$days días seguidos';
  @override
  String get statStamps => 'Superados';
  @override
  String get statSolvable => 'Ya sé resolver';
  @override
  String solvableValue(int count) => count == 1 ? '1 pregunta' : '$count preguntas';
  @override
  String cardSemantics(String headline, String level) => 'Tarjeta de progreso. $headline. Nivel $level';
  @override
  String get mapSemantics => 'Mapa. Toca para elegir tu respuesta';
  @override
  String formatYear(int year) => year < 0 ? '${-year} a. C.' : '$year d. C.';
  @override
  String reportHeader(int activeDays, int attempts) =>
      'Esta semana: ${activeDays == 1 ? '1 día' : '$activeDays días'} / '
      '${attempts == 1 ? '1 pregunta' : '$attempts preguntas'}';
  @override
  String get reportImprovedTitle => 'Mejoraste esta semana:';
  @override
  String reportItem(String title, int b, int a) => '- $title ($b% -> $a%)';
  @override
  String get reportEmpty => 'No hay mejoras nuevas esta semana. Sigue a tu ritmo.';
  @override
  String get teacherPrompt => '¿Qué está mal aquí? Corrige el error';
  @override
  String get teacherCorrect => '¡Correcto! Lo corregiste';
  @override
  String get teacherWrong => '¡Casi! Léelo una vez más';
  @override
  String get nudgeTestSoon => 'El examen se acerca. Practica un poquito hoy';
  @override
  String get nudgeReview => 'Un repaso rápido ayuda a no olvidar';
  @override
  String get nudgeStreak => 'Mantén tu racha con un poco de práctica hoy';
  @override
  String get myWeekGrew => '¡Avanzaste esta semana!';
  @override
  String get myWeekOvercame => '¡Superaste un punto difícil!';
  @override
  String get myWeekKept => 'Constante y firme, sigue así';
  @override
  String get myWeekStarted => '¡Un gran primer paso!';
  @override
  String get myWeekRest => 'Una semana tranquila. Empieza de nuevo cuando quieras';
  @override
  String get reasonPrompt => '¿Por qué fallaste? (puedes omitirlo)';
  @override
  String get reasonDontKnow => 'No lo sabía';
  @override
  String get reasonForgot => 'Lo olvidé';
  @override
  String get reasonCareless => 'Un descuido';
  @override
  String get reasonTimeShort => 'Me faltó tiempo';
  @override
  String get breakLong => 'Has trabajado mucho. Haz una pausa y bebe agua';
  @override
  String get breakMistakes => 'Varios fallos seguidos. Descansa un momento y vuelve a intentarlo';
  @override
  String get breakSlowing => '¿Te estás cansando? Haz una pausa';
  @override
  String get breakRushing => 'Estás respondiendo muy rápido. Respira y lee cada pregunta con calma';
  @override
  String get peakAhead => "Se acerca un día con más preguntas. Vamos adelantando un poco";
  @override
  String get talkGrew => 'Pida a su hijo que le enseñe lo que mejoró. «¿Cómo lo hiciste?» es un buen comienzo';
  @override
  String get talkOvercame => 'Su hijo superó un obstáculo. Elogie el esfuerzo más que el resultado';
  @override
  String get talkSteady => 'Su hijo se mantiene constante. Elogie la constancia en sí';
  @override
  String get talkStarted => 'Se dio el primer paso, y con poco basta. Pruebe a decir «Lo intentaste»';
  @override
  String get talkRest => 'Esta fue una semana de descanso. Sin reproches; dígale que puede empezar cuando quiera';
  @override
  String get outcomeAsk => '¿Quieres anotar la nota de tu examen? Puedes saltarlo, no pasa nada.';
  @override
  String get outcomeSkip => 'Luego';
  @override
  String get outcomeBaselineAsk => 'Si tienes la nota de tu examen más reciente, de antes de empezar, puedes anotarla. Si no la tienes, no pasa nada.';
  @override
  String get outcomeFirst => 'Anotado. Podrás verlo junto a tu próximo examen.';
  @override
  String get outcomeUp => 'Tu nota subió respecto a la anterior. ¡Bien hecho!';
  @override
  String get outcomeSame => 'Quedó casi igual que la anterior. Mantener la constancia es muy valioso.';
  @override
  String get outcomeDown => 'Esta vez fue más baja. No pasa nada. Veamos juntos qué se te hizo difícil.';
  @override
  String get outcomeDisclaimer => 'Es un registro de las notas que anotaste tú. No promete que tu nota vaya a subir.';
  @override
  String get eveNotice => 'El examen es mañana. Nada nuevo ahora; solo repasa lo que ya hiciste';
  @override
  String get testDayNotice => 'El examen es hoy. Un repaso ligero es suficiente. Como siempre, con calma';
  @override
  String get cardAgain => 'No lo sé';
  @override
  String get cardHard => 'Dudoso';
  @override
  String get cardGood => 'Lo sé';
  @override
  String get cardFlip => 'Girar';
  @override
  String get ringsTitle => 'Anillos de crecimiento';
  @override
  String ringsSemantics(int totalDays) =>
      'Anillos de crecimiento. ${totalDays == 1 ? '1 día' : '$totalDays días'} de estudio en total';
  @override
  String ringsLatestMonth(String month, int days) =>
      'Mes más reciente, $month: ${days == 1 ? '1 día' : '$days días'} de estudio';
  @override
  String get deviationLabel => 'Índice de puntuación de la app';
  @override
  String deviationRange(String low, String high) => '$low–$high';
  @override
  String get deviationNote =>
      'Un índice aproximado, válido solo dentro de la app, en el que 50 es el promedio de un grupo de referencia. No es una clasificación nacional.';
  @override
  String get markCorrect => 'correcto';
  @override
  String get markWrong => 'incorrecto';
  @override
  String get sheetTitle => 'Hoja de repaso final';
  @override
  String get sheetQuestion => 'Pregunta';
  @override
  String get sheetAnswer => 'Respuesta';
  @override
  String get sheetExplanation => 'Explicación';
  @override
  String get sheetEmpty => 'No hay nada que corregir ahora. ¡Buen trabajo!';
  @override
  String get checklistTitle => 'Lista del día del examen';
  @override
  String checklistProgress(int done, int total) => '$done de $total listos';
  @override
  String get checklistAllDone => 'Todo listo. ¡Buena suerte!';
  @override
  String get fiveMinuteTitle => 'Tarjeta de los últimos 5 minutos';
  @override
  List<(String, String)> get checklistDefaults => [
        ('pencil', 'Bolígrafos y lápices'),
        ('eraser', 'Goma de borrar'),
        ('ruler', 'Regla y compás'),
        ('watch', 'Reloj'),
        ('tissue', 'Pañuelo y pañuelos de papel'),
        ('notes', 'Apuntes de repaso'),
      ];
  @override
  String get scopeQrTitle => 'Compartir el temario del examen';
  @override
  String get scopeQrHint =>
      'Amigos o familiares pueden escanearlo para configurar el mismo temario. No contiene nombres ni notas.';
  @override
  String get scopeQrSemantics => 'Código QR del temario del examen';
}

/// フランス語。[septanteNonante] が true ならベルギー・スイス式（septante・nonante）。
/// 数詞は伝統的な綴り（十の位と一の位はハイフン、百・千の前後は空白、`et un`）。
class FrStrings extends ChukoreStrings {
  const FrStrings({this.septanteNonante = false});

  /// 70・90 を septante・nonante と言う地域（`fr-BE`・`fr-CH`）。80 は quatre-vingts のまま。
  static const septanteNonanteRegions = {'be', 'ch'};

  final bool septanteNonante;

  static const _small = [
    '', 'un', 'deux', 'trois', 'quatre', 'cinq', 'six', 'sept', 'huit', 'neuf', 'dix', 'onze',
    'douze', 'treize', 'quatorze', 'quinze', 'seize',
  ];
  static const _tens = ['', '', 'vingt', 'trente', 'quarante', 'cinquante', 'soixante', 'septante', '', 'nonante'];

  @override
  String get languageCode => 'fr';

  @override
  String get tag => septanteNonante ? 'fr-BE' : 'fr';

  @override
  String get decimalSeparator => ',';

  /// 複数形は 2 から（フランス語では 1,5 は単数）。
  static bool _plural(double v) => v >= 2;

  static String _pointWord(String points) =>
      _plural(double.tryParse(points.replaceAll(',', '.')) ?? 2) ? 'points' : 'point';

  /// 1〜19。
  static String _upTo19(int n) => n <= 16 ? _small[n] : 'dix-${_small[n - 10]}';

  /// 1〜99。[last] は数の末尾か（quatre-vingts の s は末尾のときだけ）。
  String _below100(int n, {required bool last}) {
    if (n < 20) return _upTo19(n);
    final t = n ~/ 10, u = n % 10;
    String withUnit(String name) =>
        u == 0 ? name : (u == 1 ? '$name et un' : '$name-${_small[u]}');
    if (t <= 6) return withUnit(_tens[t]);
    if (t == 7 || t == 9) {
      if (septanteNonante) return withUnit(_tens[t]);
      if (t == 7 && u == 1) return 'soixante et onze';
      return '${t == 7 ? 'soixante' : 'quatre-vingt'}-${_upTo19(n - (t == 7 ? 60 : 80))}';
    }
    return u == 0 ? (last ? 'quatre-vingts' : 'quatre-vingt') : 'quatre-vingt-${_small[u]}';
  }

  /// 1〜999。cent の s も末尾で数が割り切れるときだけ（deux cents / deux cent un）。
  String _below1000(int n, {required bool last}) {
    final h = n ~/ 100, r = n % 100;
    final parts = <String>[];
    if (h == 1) {
      parts.add('cent');
    } else if (h > 1) {
      parts.add('${_small[h]} cent${r == 0 && last ? 's' : ''}');
    }
    if (r > 0) parts.add(_below100(r, last: last));
    return parts.join(' ');
  }

  @override
  String gateNumberWords(int n) {
    if (n < 1 || n > 9999) throw RangeError.range(n, 1, 9999, 'n');
    final th = n ~/ 1000, r = n % 1000;
    final thousands = th == 0 ? '' : (th == 1 ? 'mille' : '${_small[th]} mille');
    if (r == 0) return thousands;
    final rest = _below1000(r, last: true);
    return th == 0 ? rest : '$thousands $rest';
  }

  // フランス語の約物（! ? : %）の前は改行されない空白を入れる。
  static const _nb = '\u00A0';

  @override
  String cardTitle(String subject) => '$subject · Carte de progression';
  @override
  String get headlinePersonalBest => 'Nouveau record personnel$_nb!';
  @override
  String get headlineFirst => 'Un excellent début';
  @override
  String headlineUp(String points) => '+$points depuis la dernière fois';
  @override
  String get headlineSame => 'Stable, comme la dernière fois';
  @override
  String get headlineDown => 'Repartons de là pour progresser';
  @override
  String nextLevel(String points) => 'Plus que $points ${_pointWord(points)} pour le niveau suivant';
  @override
  String get topLevel => 'Niveau maximal atteint$_nb!';
  @override
  String streakDays(int days) => days < 2 ? '$days jour de suite' : '$days jours de suite';
  @override
  String get statStamps => 'Maîtrisés';
  @override
  String get statSolvable => 'Je sais maintenant résoudre';
  @override
  String solvableValue(int count) => count < 2 ? '$count question' : '$count questions';
  @override
  String cardSemantics(String headline, String level) => 'Carte de progression. $headline. Niveau $level';
  @override
  String get mapSemantics => 'Carte. Touchez pour choisir votre réponse';
  @override
  String formatYear(int year) => year < 0 ? '${-year} av. J.-C.' : '$year apr. J.-C.';
  @override
  String reportHeader(int activeDays, int attempts) =>
      'Cette semaine$_nb: ${activeDays < 2 ? '$activeDays jour' : '$activeDays jours'} / '
      '${attempts < 2 ? '$attempts question' : '$attempts questions'}';
  @override
  String get reportImprovedTitle => 'Progrès de la semaine$_nb:';
  @override
  String reportItem(String title, int b, int a) => '- $title ($b$_nb% -> $a$_nb%)';
  @override
  String get reportEmpty => 'Aucun nouveau progrès cette semaine. Continuez à votre rythme.';
  @override
  String get teacherPrompt => 'Qu’est-ce qui ne va pas ici$_nb? Corrigez l’erreur';
  @override
  String get teacherCorrect => 'Correct$_nb! Vous l’avez corrigé';
  @override
  String get teacherWrong => 'Presque$_nb! Relisez encore une fois';
  @override
  String get nudgeTestSoon => "L'examen approche. Faites un petit exercice aujourd'hui";
  @override
  String get nudgeReview => 'Une courte révision aide à ne pas oublier';
  @override
  String get nudgeStreak => "Gardez votre série avec un peu d'entraînement aujourd'hui";
  @override
  String get myWeekGrew => 'Vous avez progressé cette semaine$_nb!';
  @override
  String get myWeekOvercame => 'Vous avez dépassé un point difficile$_nb!';
  @override
  String get myWeekKept => 'Régulier et constant, continuez comme ça';
  @override
  String get myWeekStarted => 'Un beau premier pas$_nb!';
  @override
  String get myWeekRest => 'Une semaine tranquille. Reprenez quand vous voulez';
  @override
  String get reasonPrompt => 'Pourquoi cette erreur$_nb? (facultatif)';
  @override
  String get reasonDontKnow => 'Je ne savais pas';
  @override
  String get reasonForgot => "J'ai oublié";
  @override
  String get reasonCareless => 'Une étourderie';
  @override
  String get reasonTimeShort => 'Pas assez de temps';
  @override
  String get breakLong => 'Vous avez bien travaillé. Faites une pause et buvez un peu d’eau';
  @override
  String get breakMistakes => "Quelques erreurs d'affilée. Faites une courte pause, puis réessayez";
  @override
  String get breakSlowing => 'Un peu fatigué$_nb? Faites une courte pause';
  @override
  String get breakRushing => 'Vous répondez très vite. Respirez et lisez bien chaque question';
  @override
  String get peakAhead => "Un jour plus chargé approche. Prenons un peu d’avance";
  @override
  String get talkGrew => 'Demandez à votre enfant de vous expliquer ce qui s’est amélioré. « Comment as-tu fait ? » est un bon début';
  @override
  String get talkOvercame => 'Votre enfant a surmonté une difficulté. Félicitez l’effort plutôt que le résultat';
  @override
  String get talkSteady => 'Votre enfant persévère régulièrement. Félicitez la régularité elle-même';
  @override
  String get talkStarted => 'Un premier pas a été fait, et un peu suffit. Essayez de dire « Tu as essayé »';
  @override
  String get talkRest => 'Ce fut une semaine de repos. Sans reproche ; dites simplement qu’il peut recommencer quand il veut';
  @override
  String get outcomeAsk => 'Veux-tu enregistrer ta note de contrôle\u00A0? Tu peux passer, ce n’est pas grave.';
  @override
  String get outcomeSkip => 'Plus tard';
  @override
  String get outcomeBaselineAsk => 'Si tu as la note de ton dernier contrôle, d’avant de commencer, tu peux l’enregistrer. Sinon, ce n’est pas grave.';
  @override
  String get outcomeFirst => 'C’est enregistré. Tu pourras la voir à côté de ton prochain contrôle.';
  @override
  String get outcomeUp => 'Ta note est plus haute que la dernière fois. Bravo\u00A0!';
  @override
  String get outcomeSame => 'À peu près pareil que la dernière fois. Rester régulier, c’est déjà très bien.';
  @override
  String get outcomeDown => 'Cette fois, c’est plus bas. Ce n’est pas grave. Regardons ensemble ce qui t’a semblé difficile.';
  @override
  String get outcomeDisclaimer => 'C’est un relevé des notes que tu as saisies toi-même. Il ne promet pas que ta note va monter.';
  @override
  String get eveNotice => 'Le contrôle est demain. Rien de nouveau maintenant ; revois seulement ce que tu as déjà fait';
  @override
  String get testDayNotice => 'Le contrôle est aujourd’hui. Une relecture légère suffit. Comme d’habitude, en confiance';
  @override
  String get cardAgain => 'Je ne sais pas';
  @override
  String get cardHard => 'Hésitant';
  @override
  String get cardGood => 'Je sais';
  @override
  String get cardFlip => 'Retourner';
  @override
  String get ringsTitle => 'Anneaux de croissance';
  @override
  String ringsSemantics(int totalDays) =>
      'Anneaux de croissance. ${totalDays < 2 ? '$totalDays jour' : '$totalDays jours'} d’étude au total';
  @override
  String ringsLatestMonth(String month, int days) =>
      'Mois le plus récent, $month\u00A0: ${days < 2 ? '$days jour' : '$days jours'} d’étude';
  @override
  String get deviationLabel => 'Indice de score dans l’appli';
  @override
  String deviationRange(String low, String high) => '$low–$high';
  @override
  String get deviationNote =>
      'Un indice approximatif, valable uniquement dans l’appli, où 50 correspond à la moyenne d’un groupe de référence. Ce n’est pas un classement national.';
  @override
  String get markCorrect => 'correct';
  @override
  String get markWrong => 'incorrect';
  @override
  String get sheetTitle => 'Fiche de dernière minute';
  @override
  String get sheetQuestion => 'Question';
  @override
  String get sheetAnswer => 'Réponse';
  @override
  String get sheetExplanation => 'Explication';
  @override
  String get sheetEmpty => 'Rien à corriger pour le moment. Bravo$_nb!';
  @override
  String get checklistTitle => 'Check-list du jour J';
  @override
  String checklistProgress(int done, int total) => '$done sur $total prêts';
  @override
  String get checklistAllDone => 'Tout est prêt. Bonne chance$_nb!';
  @override
  String get fiveMinuteTitle => 'Carte des 5 dernières minutes';
  @override
  List<(String, String)> get checklistDefaults => [
        ('pencil', 'Stylos et crayons'),
        ('eraser', 'Gomme'),
        ('ruler', 'Règle et compas'),
        ('watch', 'Montre'),
        ('tissue', 'Mouchoirs'),
        ('notes', 'Notes de révision'),
      ];
  @override
  String get scopeQrTitle => 'Partager le périmètre du test';
  @override
  String get scopeQrHint =>
      'Vos amis ou votre famille peuvent le scanner pour définir le même périmètre. Il ne contient ni nom ni note.';
  @override
  String get scopeQrSemantics => 'QR code du périmètre du test';
}

/// 韓国語。数の読み上げは漢字語の数詞（사백팔십이）。
class KoStrings extends ChukoreStrings {
  const KoStrings();

  static const _digit = ['', '일', '이', '삼', '사', '오', '육', '칠', '팔', '구'];

  @override
  String get languageCode => 'ko';

  @override
  String gateNumberWords(int n) {
    if (n < 1 || n > 9999) throw RangeError.range(n, 1, 9999, 'n');
    final b = StringBuffer();
    const units = ['천', '백', '십'];
    final digits = [n ~/ 1000, n % 1000 ~/ 100, n % 100 ~/ 10];
    for (var i = 0; i < 3; i++) {
      final d = digits[i];
      if (d == 0) continue;
      if (d != 1) b.write(_digit[d]); // 천・백・십の前の「일」は言わない
      b.write(units[i]);
    }
    b.write(_digit[n % 10]);
    return b.toString();
  }

  @override
  String cardTitle(String subject) => '$subject 성장 카드';
  @override
  String get headlinePersonalBest => '개인 최고 기록 갱신!';
  @override
  String get headlineFirst => '멋진 첫걸음';
  @override
  String headlineUp(String points) => '지난번보다 +$points점';
  @override
  String get headlineSame => '지난번과 같아요. 안정적이에요';
  @override
  String get headlineDown => '여기서부터 다시 키워 봐요';
  @override
  String nextLevel(String points) => '다음 레벨까지 $points점';
  @override
  String get topLevel => '최고 레벨 달성!';
  @override
  String streakDays(int days) => '$days일 연속';
  @override
  String get statStamps => '극복 스탬프';
  @override
  String get statSolvable => '이제 풀 수 있는 문제';
  @override
  String solvableValue(int count) => '$count문제';
  @override
  String cardSemantics(String headline, String level) => '성장 카드. $headline. 레벨 $level';
  @override
  String get mapSemantics => '지도. 탭해서 정답을 고르세요';
  @override
  String formatYear(int year) => year < 0 ? '기원전 ${-year}년' : '$year년';
  @override
  String reportHeader(int activeDays, int attempts) => '이번 주 학습: $activeDays일 / $attempts문제';
  @override
  String get reportImprovedTitle => '이번 주 성장한 부분:';
  @override
  String reportItem(String title, int b, int a) => '- $title ($b% -> $a%)';
  @override
  String get reportEmpty => '이번 주에는 새로 성장한 단원이 없어요. 천천히 이어 가요.';
  @override
  String get teacherPrompt => '여기 어디가 틀렸을까요? 고쳐 보세요';
  @override
  String get teacherCorrect => '정답! 잘 고쳤어요';
  @override
  String get teacherWrong => '아깝다! 한 번 더 읽어 봐요';
  @override
  String get nudgeTestSoon => '시험이 다가오고 있어요. 오늘도 조금만 해 봐요';
  @override
  String get nudgeReview => '잊기 전에 잠깐 복습해 봐요';
  @override
  String get nudgeStreak => '오늘도 조금만 해서 연속 기록을 이어 가요';
  @override
  String get myWeekGrew => '이번 주에 실력이 늘었어요!';
  @override
  String get myWeekOvercame => '어려운 부분을 넘어섰어요!';
  @override
  String get myWeekKept => '꾸준히 잘하고 있어요';
  @override
  String get myWeekStarted => '멋진 첫걸음이에요!';
  @override
  String get myWeekRest => '조용한 한 주였어요. 언제든 다시 시작해요';
  @override
  String get reasonPrompt => '왜 틀렸을까요? (건너뛰어도 돼요)';
  @override
  String get reasonDontKnow => '몰랐어요';
  @override
  String get reasonForgot => '잊어버렸어요';
  @override
  String get reasonCareless => '실수했어요';
  @override
  String get reasonTimeShort => '시간이 부족했어요';
  @override
  String get breakLong => '열심히 했어요. 잠깐 쉬면서 물을 마셔요';
  @override
  String get breakMistakes => '연속으로 틀렸어요. 잠깐 쉬었다가 다시 해 봐요';
  @override
  String get breakSlowing => '조금 피곤한가요? 잠깐 쉬어요';
  @override
  String get breakRushing => '너무 빨리 답하고 있어요. 숨을 고르고 문제를 잘 읽어 봐요';
  @override
  String get peakAhead => "문제가 많은 날이 다가오고 있어요. 조금씩 미리 해 둬요";
  @override
  String get talkGrew => '좋아진 부분을 아이에게 가르쳐 달라고 해 보세요. "어떻게 했어?"라고 물어보면 좋아요';
  @override
  String get talkOvercame => '어려움을 이겨 냈어요. 결과보다 노력을 칭찬해 주세요';
  @override
  String get talkSteady => '꾸준히 이어 가고 있어요. 꾸준함 자체를 칭찬해 주세요';
  @override
  String get talkStarted => '첫걸음을 뗐어요. 조금이어도 충분해요. "해 봤구나"라고 말해 주세요';
  @override
  String get talkRest => '이번 주는 쉬었어요. 탓하지 말고 "언제든 시작할 수 있어"라고 전해 주세요';
  @override
  String get outcomeAsk => '시험 점수를 기록해 볼까요? 건너뛰어도 괜찮아요.';
  @override
  String get outcomeSkip => '나중에';
  @override
  String get outcomeBaselineAsk => '앱을 쓰기 전에 본 가장 최근 시험 점수가 있으면 적어 주세요. 없어도 괜찮아요.';
  @override
  String get outcomeFirst => '기록했어요. 다음 시험 때 나란히 볼 수 있어요.';
  @override
  String get outcomeUp => '지난번보다 점수가 올랐어요. 잘했어요!';
  @override
  String get outcomeSame => '지난번과 거의 비슷해요. 꾸준히 하고 있는 것만으로도 대단해요.';
  @override
  String get outcomeDown => '이번에는 지난번보다 낮았어요. 괜찮아요. 무엇이 어려웠는지 같이 살펴봐요.';
  @override
  String get outcomeDisclaimer => '직접 입력한 점수의 기록이에요. 점수가 오른다고 약속하는 것은 아니에요.';
  @override
  String get eveNotice => '내일은 시험이에요. 새로운 건 늘리지 말고, 했던 부분만 다시 살펴봐요';
  @override
  String get testDayNotice => '오늘은 시험이에요. 가볍게 훑어보는 것으로 충분해요. 평소처럼 해요';
  @override
  String get cardAgain => '몰라요';
  @override
  String get cardHard => '헷갈려요';
  @override
  String get cardGood => '알아요';
  @override
  String get cardFlip => '뒤집기';
  @override
  String get ringsTitle => '성장 나이테';
  @override
  String ringsSemantics(int totalDays) => '성장 나이테. 지금까지 모두 $totalDays일 학습했어요';
  @override
  String ringsLatestMonth(String month, int days) =>
      '가장 최근 달($month): $days일 학습했어요';
  @override
  String get deviationLabel => '앱 내 점수 지수';
  @override
  String deviationRange(String low, String high) => '$low~$high';
  @override
  String get deviationNote => '앱 안에서만 쓰는 대략적인 지수로, 가정한 집단의 평균을 50으로 둬요. 전국 순위가 아니에요.';
  @override
  String get markCorrect => '정답';
  @override
  String get markWrong => '오답';
  @override
  String get sheetTitle => '시험 직전 프린트';
  @override
  String get sheetQuestion => '문제';
  @override
  String get sheetAnswer => '정답';
  @override
  String get sheetExplanation => '해설';
  @override
  String get sheetEmpty => '지금은 고칠 곳이 없어요. 정말 잘했어요!';
  @override
  String get checklistTitle => '시험 당일 체크';
  @override
  String checklistProgress(int done, int total) => '$total개 중 $done개 준비됨';
  @override
  String get checklistAllDone => '모두 준비됐어요. 행운을 빌어요!';
  @override
  String get fiveMinuteTitle => '직전 5분 카드';
  @override
  List<(String, String)> get checklistDefaults => [
        ('pencil', '필기구'),
        ('eraser', '지우개'),
        ('ruler', '자와 컴퍼스'),
        ('watch', '시계'),
        ('tissue', '손수건과 휴지'),
        ('notes', '직전 요약 노트'),
      ];
  @override
  String get scopeQrTitle => '시험 범위 공유하기';
  @override
  String get scopeQrHint => '친구나 가족이 스캔하면 같은 범위를 설정할 수 있어요. 이름이나 성적은 들어 있지 않아요.';
  @override
  String get scopeQrSemantics => '시험 범위 QR 코드';
}

/// 中国語。[traditional] が true なら繁体字（`zh-Hant`・`zh-TW`・`zh-HK`）、false なら簡体字。
class ZhStrings extends ChukoreStrings {
  const ZhStrings({this.traditional = false});

  final bool traditional;

  /// ロケールの要素（小文字）から繁体字か判定。スクリプト（hans・hant）が地域より優先。
  static bool isTraditional(List<String> parts) {
    if (parts.contains('hans')) return false;
    if (parts.contains('hant')) return true;
    return parts.any(const {'tw', 'hk', 'mo'}.contains);
  }

  static const _digit = ['', '一', '二', '三', '四', '五', '六', '七', '八', '九'];

  String _t(String hans, String hant) => traditional ? hant : hans;

  @override
  String get languageCode => 'zh';

  @override
  String get tag => traditional ? 'zh-Hant' : 'zh-Hans';

  /// 数の読み（簡体・繁体で同じ字）。零の入れ方: 途中の 0 の桁は「零」を1つ（一百零五）、
  /// 末尾の 0 は言わない（一百）。10〜19 だけは「十五」、百の位以上のあとは「一十」（一百一十）。
  @override
  String gateNumberWords(int n) {
    if (n < 1 || n > 9999) throw RangeError.range(n, 1, 9999, 'n');
    const units = ['千', '百', '十', ''];
    final digits = [n ~/ 1000, n % 1000 ~/ 100, n % 100 ~/ 10, n % 10];
    final b = StringBuffer();
    var started = false, zeroPending = false;
    for (var i = 0; i < 4; i++) {
      final d = digits[i];
      if (d == 0) {
        if (started) zeroPending = true;
        continue;
      }
      if (zeroPending) b.write('零');
      zeroPending = false;
      if (d == 1 && units[i] == '十' && !started) {
        b.write('十');
      } else {
        b.write('${_digit[d]}${units[i]}');
      }
      started = true;
    }
    return b.toString();
  }

  @override
  String cardTitle(String subject) => _t('$subject 成长卡片', '$subject 成長卡片');
  @override
  String get headlinePersonalBest => _t('刷新个人最佳！', '刷新個人最佳！');
  @override
  String get headlineFirst => _t('好的开始', '好的開始');
  @override
  String headlineUp(String points) => '比上次 +$points分';
  @override
  String get headlineSame => _t('和上次一样，很稳定', '和上次一樣，很穩定');
  @override
  String get headlineDown => _t('从这里再出发吧', '從這裡再出發吧');
  @override
  String nextLevel(String points) => _t('距离下一级还差$points分', '距離下一級還差$points分');
  @override
  String get topLevel => _t('已达到最高等级！', '已達到最高等級！');
  @override
  String streakDays(int days) => _t('连续$days天', '連續$days天');
  @override
  String get statStamps => '已攻克';
  @override
  String get statSolvable => _t('现在会做的题', '現在會做的題目');
  @override
  String solvableValue(int count) => _t('$count题', '$count題');
  @override
  String cardSemantics(String headline, String level) =>
      _t('成长卡片。$headline。等级$level', '成長卡片。$headline。等級$level');
  @override
  String get mapSemantics => _t('地图。点击选择答案', '地圖。點選以選擇答案');
  @override
  String formatYear(int year) => year < 0 ? '公元前${-year}年' : '$year年';
  @override
  String reportHeader(int activeDays, int attempts) =>
      _t('本周学习：$activeDays天 / $attempts题', '本週學習：$activeDays天 / $attempts題');
  @override
  String get reportImprovedTitle => _t('本周进步的地方：', '本週進步的地方：');
  @override
  String reportItem(String title, int b, int a) => '- $title（$b% -> $a%）';
  @override
  String get reportEmpty =>
      _t('本周没有新的进步单元。按自己的节奏继续吧。', '本週沒有新的進步單元。按自己的節奏繼續吧。');
  @override
  String get teacherPrompt => _t('这里哪里不对？请改正', '這裡哪裡不對？請改正');
  @override
  String get teacherCorrect => _t('答对了！你改正了', '答對了！你改正了');
  @override
  String get teacherWrong => _t('差一点！再读一遍吧', '差一點！再讀一遍吧');
  @override
  String get nudgeTestSoon => _t('考试快到了，今天也练一点吧', '考試快到了，今天也練一點吧');
  @override
  String get nudgeReview => _t('快速复习一下，就不容易忘记', '快速複習一下，就不容易忘記');
  @override
  String get nudgeStreak => _t('今天也练一点，保持连续记录', '今天也練一點，保持連續記錄');
  @override
  String get myWeekGrew => _t('这周有进步啦！', '這週有進步囉！');
  @override
  String get myWeekOvercame => _t('你克服了一个难点！', '你克服了一個難點！');
  @override
  String get myWeekKept => _t('一步一个脚印，继续加油', '一步一個腳印，繼續加油');
  @override
  String get myWeekStarted => _t('漂亮的第一步！', '漂亮的第一步！');
  @override
  String get myWeekRest => _t('安静的一周。想开始时随时再来', '安靜的一週。想開始時隨時再來');
  @override
  String get reasonPrompt => _t('为什么做错了？（可以跳过）', '為什麼做錯了？（可以跳過）');
  @override
  String get reasonDontKnow => _t('不会', '不會');
  @override
  String get reasonForgot => _t('忘记了', '忘記了');
  @override
  String get reasonCareless => _t('粗心', '粗心');
  @override
  String get reasonTimeShort => _t('时间不够', '時間不夠');
  @override
  String get breakLong => _t('学了很久了。休息一下，喝点水吧', '學了很久了。休息一下，喝點水吧');
  @override
  String get breakMistakes => _t('连续错了几题。先休息一下再试试', '連續錯了幾題。先休息一下再試試');
  @override
  String get breakSlowing => _t('有点累了吗？休息一下吧', '有點累了嗎？休息一下吧');
  @override
  String get breakRushing => _t('答得太快了。深呼吸，仔细读题', '答得太快了。深呼吸，仔細讀題');
  @override
  String get peakAhead => _t('即将迎来题目较多的一天。提前做一点吧', '即將迎來題目較多的一天。提前做一點吧');
  @override
  String get talkGrew => _t('请孩子教教你哪里进步了。问一句“你是怎么做到的？”就是好的开始', '請孩子教教你哪裡進步了。問一句「你是怎麼做到的？」就是好的開始');
  @override
  String get talkOvercame => _t('孩子克服了一个难点。比起结果，更要表扬努力', '孩子克服了一個難點。比起結果，更要稱讚努力');
  @override
  String get talkSteady => _t('孩子在坚持学习。表扬坚持本身', '孩子在持續學習。稱讚持續本身');
  @override
  String get talkStarted => _t('迈出了第一步，一点点就足够。可以说“你试过了呢”', '踏出了第一步，一點點就足夠。可以說「你試過了呢」');
  @override
  String get talkRest => _t('这周休息了。不必责备，告诉孩子随时都可以重新开始', '這週休息了。不必責備，告訴孩子隨時都可以重新開始');
  @override
  String get outcomeAsk => _t('要记录一下考试分数吗？不记录也没关系。', '要記錄一下考試分數嗎？不記錄也沒關係。');
  @override
  String get outcomeSkip => _t('以后再说', '以後再說');
  @override
  String get outcomeBaselineAsk => _t('如果有开始使用之前最近一次的考试分数，可以填一下。没有也没关系。', '如果有開始使用之前最近一次的考試分數，可以填一下。沒有也沒關係。');
  @override
  String get outcomeFirst => _t('已记录。下次考试后可以并排查看。', '已記錄。下次考試後可以並排查看。');
  @override
  String get outcomeUp => _t('分数比上次高了。真棒！', '分數比上次高了。真棒！');
  @override
  String get outcomeSame => _t('和上次差不多。能一直坚持就很了不起。', '和上次差不多。能一直堅持就很了不起。');
  @override
  String get outcomeDown => _t('这次比上次低一些。没关系，一起看看哪里有点难。', '這次比上次低一些。沒關係，一起看看哪裡有點難。');
  @override
  String get outcomeDisclaimer => _t('这是你自己填写的分数记录，并不保证分数一定会提高。', '這是你自己填寫的分數記錄，並不保證分數一定會提高。');
  @override
  String get eveNotice => _t('明天考试。现在不再学新的，只回顾已经做过的内容就好', '明天考試。現在不再學新的，只回顧已經做過的內容就好');
  @override
  String get testDayNotice => _t('今天考试。轻轻回顾一下就足够了，和平时一样就好', '今天考試。輕輕回顧一下就足夠了，和平常一樣就好');
  @override
  String get cardAgain => _t('不会', '不會');
  @override
  String get cardHard => _t('不确定', '不確定');
  @override
  String get cardGood => _t('会了', '會了');
  @override
  String get cardFlip => _t('翻面', '翻面');
  @override
  String get ringsTitle => _t('成长年轮', '成長年輪');
  @override
  String ringsSemantics(int totalDays) => _t('成长年轮。累计学习$totalDays天', '成長年輪。累計學習$totalDays天');
  @override
  String ringsLatestMonth(String month, int days) =>
      _t('最近一个月（$month）：学习$days天', '最近一個月（$month）：學習$days天');
  @override
  String get deviationLabel => _t('应用内分数指数', '應用程式內分數指數');
  @override
  String deviationRange(String low, String high) => '$low~$high';
  @override
  String get deviationNote =>
      _t('仅在应用内使用的大致指数，以假定群体的平均值为50，并非全国排名。', '僅在應用程式內使用的大致指數，以假定群體的平均值為50，並非全國排名。');
  @override
  String get markCorrect => _t('正确', '正確');
  @override
  String get markWrong => _t('错误', '錯誤');
  @override
  String get sheetTitle => _t('考前复习单', '考前複習單');
  @override
  String get sheetQuestion => _t('题目', '題目');
  @override
  String get sheetAnswer => '答案';
  @override
  String get sheetExplanation => '解析';
  @override
  String get sheetEmpty => _t('现在没有需要改正的地方。做得很好！', '現在沒有需要改正的地方。做得很好！');
  @override
  String get checklistTitle => _t('考试当天检查', '考試當天檢查');
  @override
  String checklistProgress(int done, int total) => _t('已准备 $done/$total', '已準備 $done/$total');
  @override
  String get checklistAllDone => _t('都准备好了，加油！', '都準備好了，加油！');
  @override
  String get fiveMinuteTitle => _t('考前5分钟卡片', '考前5分鐘卡片');
  @override
  List<(String, String)> get checklistDefaults => traditional
      ? [
        ('pencil', '筆'),
        ('eraser', '橡皮擦'),
        ('ruler', '尺和圓規'),
        ('watch', '手錶'),
        ('tissue', '手帕和面紙'),
        ('notes', '複習筆記'),
      ]
      : [
        ('pencil', '笔'),
        ('eraser', '橡皮'),
        ('ruler', '尺子和圆规'),
        ('watch', '手表'),
        ('tissue', '手帕和纸巾'),
        ('notes', '复习笔记'),
      ];
  @override
  String get scopeQrTitle => _t('分享考试范围', '分享考試範圍');
  @override
  String get scopeQrHint =>
      _t('朋友或家人扫描后即可设置相同的范围。不含姓名或成绩。', '朋友或家人掃描後即可設定相同的範圍。不含姓名或成績。');
  @override
  String get scopeQrSemantics => _t('考试范围二维码', '考試範圍 QR 碼');
}

/// インドネシア語。複数形は無い。数詞は規則的（seratus・sebelas・belas・puluh・ratus・ribu）。
/// 小数点はカンマ、桁区切りはドット。
class IdStrings extends ChukoreStrings {
  const IdStrings();

  static const _units = ['', 'satu', 'dua', 'tiga', 'empat', 'lima', 'enam', 'tujuh', 'delapan', 'sembilan'];

  @override
  String get languageCode => 'id';

  @override
  String get decimalSeparator => ',';

  /// 1〜99（「sepuluh」「sebelas」「dua belas」「dua puluh satu」）。
  String _below100(int n) {
    if (n < 10) return _units[n];
    if (n == 10) return 'sepuluh';
    if (n == 11) return 'sebelas';
    if (n < 20) return '${_units[n - 10]} belas';
    final unit = n % 10;
    return '${_units[n ~/ 10]} puluh${unit == 0 ? '' : ' ${_units[unit]}'}';
  }

  /// 1〜999（「seratus」「seratus satu」「dua ratus」）。
  String _below1000(int n) {
    final h = n ~/ 100, r = n % 100;
    final parts = <String>[];
    if (h == 1) {
      parts.add('seratus');
    } else if (h > 1) {
      parts.add('${_units[h]} ratus');
    }
    if (r > 0) parts.add(_below100(r));
    return parts.join(' ');
  }

  @override
  String gateNumberWords(int n) {
    if (n < 1 || n > 9999) throw RangeError.range(n, 1, 9999, 'n');
    final th = n ~/ 1000, r = n % 1000;
    final thousands = th == 0 ? '' : (th == 1 ? 'seribu' : '${_units[th]} ribu');
    if (r == 0) return thousands;
    return th == 0 ? _below1000(r) : '$thousands ${_below1000(r)}';
  }

  @override
  String cardTitle(String subject) => '$subject · Kartu Perkembangan';
  @override
  String get headlinePersonalBest => 'Rekor pribadi baru!';
  @override
  String get headlineFirst => 'Awal yang bagus';
  @override
  String headlineUp(String points) => '+$points dari sebelumnya';
  @override
  String get headlineSame => 'Stabil, sama seperti sebelumnya';
  @override
  String get headlineDown => 'Mari tingkatkan lagi dari sini';
  @override
  String nextLevel(String points) => '$points poin lagi menuju level berikutnya';
  @override
  String get topLevel => 'Level tertinggi tercapai!';
  @override
  String streakDays(int days) => '$days hari berturut-turut';
  @override
  String get statStamps => 'Berhasil diatasi';
  @override
  String get statSolvable => 'Kini bisa dijawab';
  @override
  String solvableValue(int count) => '$count soal';
  @override
  String cardSemantics(String headline, String level) => 'Kartu perkembangan. $headline. Level $level';
  @override
  String get mapSemantics => 'Peta. Ketuk untuk memilih jawaban';
  @override
  String formatYear(int year) => year < 0 ? '${-year} SM' : '$year M';
  @override
  String reportHeader(int activeDays, int attempts) => 'Minggu ini: $activeDays hari / $attempts soal';
  @override
  String get reportImprovedTitle => 'Yang meningkat minggu ini:';
  @override
  String reportItem(String title, int b, int a) => '- $title ($b% -> $a%)';
  @override
  String get reportEmpty => 'Belum ada peningkatan baru minggu ini. Lanjutkan sesuai kecepatanmu.';
  @override
  String get scopeQrTitle => 'Bagikan cakupan ujian';
  @override
  String get scopeQrHint =>
      'Teman atau keluarga dapat memindai ini untuk mengatur cakupan yang sama. Tidak berisi nama atau nilai.';
  @override
  String get scopeQrSemantics => 'Kode QR cakupan ujian';
  @override
  String get checklistTitle => 'Cek hari ujian';
  @override
  String checklistProgress(int done, int total) => '$done dari $total siap';
  @override
  String get checklistAllDone => 'Semua sudah siap. Semoga sukses!';
  @override
  String get fiveMinuteTitle => 'Kartu 5 menit terakhir';
  @override
  List<(String, String)> get checklistDefaults => [
        ('pencil', 'Alat tulis'),
        ('eraser', 'Penghapus'),
        ('ruler', 'Penggaris dan jangka'),
        ('watch', 'Jam tangan'),
        ('tissue', 'Sapu tangan dan tisu'),
        ('notes', 'Catatan ringkasan'),
      ];
  @override
  String get sheetTitle => 'Lembar kilat sebelum ujian';
  @override
  String get sheetQuestion => 'Soal';
  @override
  String get sheetAnswer => 'Jawaban';
  @override
  String get sheetExplanation => 'Penjelasan';
  @override
  String get sheetEmpty => 'Tidak ada yang perlu diperbaiki sekarang. Kerja bagus!';
  @override
  String get markCorrect => 'benar';
  @override
  String get markWrong => 'salah';
  @override
  String get ringsTitle => 'Cincin pertumbuhan';
  @override
  String ringsSemantics(int totalDays) => 'Cincin pertumbuhan. Total $totalDays hari belajar';
  @override
  String ringsLatestMonth(String month, int days) =>
      'Bulan terbaru, $month: $days hari belajar';
  @override
  String get deviationLabel => 'Indeks skor dalam aplikasi';
  @override
  String deviationRange(String low, String high) => '$low–$high';
  @override
  String get deviationNote =>
      'Indeks kasar yang hanya berlaku di dalam aplikasi ini, dengan 50 sebagai rata-rata kelompok acuan. Bukan peringkat nasional.';
  @override
  String get teacherPrompt => 'Apa yang salah di sini? Perbaiki kesalahannya';
  @override
  String get teacherCorrect => 'Benar! Kamu berhasil memperbaikinya';
  @override
  String get teacherWrong => 'Hampir! Baca sekali lagi';
  @override
  String get nudgeTestSoon => 'Ujian sudah dekat. Latihan sedikit hari ini ya';
  @override
  String get nudgeReview => 'Ulasan singkat membantu agar tidak lupa';
  @override
  String get nudgeStreak => 'Pertahankan rentetan harimu dengan sedikit latihan hari ini';
  @override
  String get myWeekGrew => 'Kamu membuat kemajuan minggu ini!';
  @override
  String get myWeekOvercame => 'Kamu berhasil melewati bagian yang sulit!';
  @override
  String get myWeekKept => 'Stabil dan konsisten, pertahankan ya';
  @override
  String get myWeekStarted => 'Langkah pertama yang bagus!';
  @override
  String get myWeekRest => 'Minggu yang tenang. Mulai lagi kapan saja';
  @override
  String get reasonPrompt => 'Kenapa salah? (boleh dilewati)';
  @override
  String get reasonDontKnow => 'Belum tahu';
  @override
  String get reasonForgot => 'Lupa';
  @override
  String get reasonCareless => 'Ceroboh';
  @override
  String get reasonTimeShort => 'Waktu kurang';
  @override
  String get breakLong => 'Kamu sudah belajar keras. Istirahat sebentar dan minum air ya';
  @override
  String get breakMistakes => 'Beberapa kali salah berturut-turut. Istirahat sebentar, lalu coba lagi';
  @override
  String get breakSlowing => 'Mulai lelah? Istirahat sebentar ya';
  @override
  String get breakRushing => 'Menjawab terlalu cepat. Tarik napas dan baca soal dengan teliti';
  @override
  String get peakAhead => "Akan ada hari dengan lebih banyak soal. Yuk kerjakan sedikit lebih awal";
  @override
  String get talkGrew => 'Minta anak mengajari Anda apa yang membaik. "Bagaimana caramu?" adalah awal yang baik';
  @override
  String get talkOvercame => 'Anak berhasil melewati kesulitan. Pujilah usahanya, bukan hanya hasilnya';
  @override
  String get talkSteady => 'Anak belajar dengan tekun. Pujilah ketekunannya itu sendiri';
  @override
  String get talkStarted => 'Langkah pertama sudah diambil, dan sedikit pun cukup. Coba katakan "Kamu sudah mencoba"';
  @override
  String get talkRest => 'Pekan ini istirahat. Tanpa menyalahkan; katakan bahwa ia bisa mulai kapan saja';
  @override
  String get outcomeAsk => 'Mau mencatat nilai ujianmu? Boleh dilewati, tidak apa-apa.';
  @override
  String get outcomeSkip => 'Nanti saja';
  @override
  String get outcomeBaselineAsk => 'Kalau punya nilai ujian terakhir sebelum mulai memakai aplikasi ini, boleh dicatat. Kalau tidak ada, tidak apa-apa.';
  @override
  String get outcomeFirst => 'Sudah dicatat. Kamu bisa melihatnya berdampingan dengan ujian berikutnya.';
  @override
  String get outcomeUp => 'Nilaimu naik dibanding sebelumnya. Bagus sekali!';
  @override
  String get outcomeSame => 'Hampir sama dengan sebelumnya. Tetap konsisten itu hebat.';
  @override
  String get outcomeDown => 'Kali ini lebih rendah dari sebelumnya. Tidak apa-apa. Yuk lihat bersama bagian mana yang terasa sulit.';
  @override
  String get outcomeDisclaimer => 'Ini catatan nilai yang kamu isi sendiri. Ini bukan janji bahwa nilaimu akan naik.';
  @override
  String get eveNotice => 'Ujian besok. Tidak perlu materi baru; cukup ulangi yang sudah dikerjakan';
  @override
  String get testDayNotice => 'Ujian hari ini. Mengulang ringan saja sudah cukup. Tenang seperti biasa';
  @override
  String get cardAgain => 'Tidak tahu';
  @override
  String get cardHard => 'Ragu';
  @override
  String get cardGood => 'Tahu';
  @override
  String get cardFlip => 'Balik';
}

class ViStrings extends ChukoreStrings {
  const ViStrings();

  static const _units = ['', 'một', 'hai', 'ba', 'bốn', 'năm', 'sáu', 'bảy', 'tám', 'chín'];

  @override
  String get languageCode => 'vi';

  @override
  String get decimalSeparator => ',';

  /// 1〜99（「mười」「mười lăm」「hai mươi mốt」「hai mươi lăm」）。
  String _below100(int n) {
    if (n < 10) return _units[n];
    final t = n ~/ 10, u = n % 10;
    if (t == 1) {
      return switch (u) { 0 => 'mười', 5 => 'mười lăm', _ => 'mười ${_units[u]}' };
    }
    final unit = switch (u) { 0 => '', 1 => ' mốt', 5 => ' lăm', _ => ' ${_units[u]}' };
    return '${_units[t]} mươi$unit';
  }

  /// 1〜999。[zeroHundreds] は千の位より下で百の位が 0 のとき「không trăm」を読む（1005 = một nghìn không trăm lẻ năm）。
  String _below1000(int n, {bool zeroHundreds = false}) {
    final h = n ~/ 100, r = n % 100;
    final parts = <String>[];
    if (h > 0) {
      parts.add('${_units[h]} trăm');
    } else if (zeroHundreds) {
      parts.add('không trăm');
    }
    if (r > 0) {
      // 十の位が 0 の一桁は「lẻ」（北部）を挟む
      parts.add(r < 10 && parts.isNotEmpty ? 'lẻ ${_units[r]}' : _below100(r));
    }
    return parts.join(' ');
  }

  @override
  String gateNumberWords(int n) {
    if (n < 1 || n > 9999) throw RangeError.range(n, 1, 9999, 'n');
    final th = n ~/ 1000, r = n % 1000;
    final thousands = th == 0 ? '' : '${_units[th]} nghìn';
    if (r == 0) return thousands;
    return th == 0 ? _below1000(r) : '$thousands ${_below1000(r, zeroHundreds: true)}';
  }

  @override
  String cardTitle(String subject) => '$subject · Thẻ tiến bộ';
  @override
  String get headlinePersonalBest => 'Kỷ lục cá nhân mới!';
  @override
  String get headlineFirst => 'Khởi đầu tốt đẹp';
  @override
  String headlineUp(String points) => '+$points so với lần trước';
  @override
  String get headlineSame => 'Ổn định như lần trước';
  @override
  String get headlineDown => 'Cùng tiến lên từ đây nhé';
  @override
  String nextLevel(String points) => '$points điểm nữa để lên cấp tiếp theo';
  @override
  String get topLevel => 'Đã đạt cấp cao nhất!';
  @override
  String streakDays(int days) => '$days ngày liên tiếp';
  @override
  String get statStamps => 'Đã vượt qua';
  @override
  String get statSolvable => 'Giờ đã làm được';
  @override
  String solvableValue(int count) => '$count câu';
  @override
  String cardSemantics(String headline, String level) => 'Thẻ tiến bộ. $headline. Cấp $level';
  @override
  String get mapSemantics => 'Bản đồ. Chạm để chọn đáp án';
  @override
  String formatYear(int year) => year < 0 ? '${-year} TCN' : 'năm $year';
  @override
  String reportHeader(int activeDays, int attempts) => 'Tuần này: $activeDays ngày / $attempts câu';
  @override
  String get reportImprovedTitle => 'Những điều tiến bộ trong tuần này:';
  @override
  String reportItem(String title, int b, int a) => '- $title ($b% -> $a%)';
  @override
  String get reportEmpty => 'Tuần này chưa có tiến bộ mới. Cứ học theo nhịp của bạn nhé.';
  @override
  String get scopeQrTitle => 'Chia sẻ phạm vi kiểm tra';
  @override
  String get scopeQrHint =>
      'Bạn bè hoặc gia đình có thể quét mã này để đặt cùng phạm vi. Mã không chứa tên hay điểm số.';
  @override
  String get scopeQrSemantics => 'Mã QR phạm vi kiểm tra';
  @override
  String get checklistTitle => 'Kiểm tra ngày thi';
  @override
  String checklistProgress(int done, int total) => '$done/$total đã sẵn sàng';
  @override
  String get checklistAllDone => 'Mọi thứ đã sẵn sàng. Chúc bạn thi tốt!';
  @override
  String get fiveMinuteTitle => 'Thẻ 5 phút cuối';
  @override
  List<(String, String)> get checklistDefaults => [
        ('pencil', 'Bút và bút chì'),
        ('eraser', 'Cục tẩy'),
        ('ruler', 'Thước và compa'),
        ('watch', 'Đồng hồ đeo tay'),
        ('tissue', 'Khăn tay và khăn giấy'),
        ('notes', 'Ghi chú tóm tắt'),
      ];
  @override
  String get sheetTitle => 'Tờ ôn nhanh trước giờ thi';
  @override
  String get sheetQuestion => 'Câu hỏi';
  @override
  String get sheetAnswer => 'Đáp án';
  @override
  String get sheetExplanation => 'Giải thích';
  @override
  String get sheetEmpty => 'Hiện chưa có gì cần sửa. Làm tốt lắm!';
  @override
  String get markCorrect => 'đúng';
  @override
  String get markWrong => 'sai';
  @override
  String get ringsTitle => 'Vòng tăng trưởng';
  @override
  String ringsSemantics(int totalDays) => 'Vòng tăng trưởng. Tổng cộng $totalDays ngày học';
  @override
  String ringsLatestMonth(String month, int days) =>
      'Tháng gần nhất, $month: $days ngày học';
  @override
  String get deviationLabel => 'Chỉ số điểm trong ứng dụng';
  @override
  String deviationRange(String low, String high) => '$low–$high';
  @override
  String get deviationNote =>
      'Chỉ số ước lượng chỉ có giá trị trong ứng dụng này, lấy 50 làm trung bình của nhóm tham chiếu. Không phải xếp hạng toàn quốc.';
  @override
  String get teacherPrompt => 'Chỗ nào sai? Hãy sửa lại cho đúng';
  @override
  String get teacherCorrect => 'Đúng rồi! Bạn đã sửa được';
  @override
  String get teacherWrong => 'Gần đúng! Hãy đọc lại một lần nữa';
  @override
  String get nudgeTestSoon => 'Bài kiểm tra sắp đến rồi. Hôm nay luyện một chút nhé';
  @override
  String get nudgeReview => 'Ôn nhanh một chút để không quên nhé';
  @override
  String get nudgeStreak => 'Luyện một chút hôm nay để giữ chuỗi ngày liên tiếp nhé';
  @override
  String get myWeekGrew => 'Tuần này bạn đã tiến bộ!';
  @override
  String get myWeekOvercame => 'Bạn đã vượt qua một chỗ khó!';
  @override
  String get myWeekKept => 'Đều đặn và vững vàng, cứ thế nhé';
  @override
  String get myWeekStarted => 'Một bước đầu thật tốt!';
  @override
  String get myWeekRest => 'Một tuần nhẹ nhàng. Bắt đầu lại bất cứ lúc nào';
  @override
  String get reasonPrompt => 'Vì sao bị sai? (có thể bỏ qua)';
  @override
  String get reasonDontKnow => 'Mình chưa biết';
  @override
  String get reasonForgot => 'Mình quên';
  @override
  String get reasonCareless => 'Mình bất cẩn';
  @override
  String get reasonTimeShort => 'Không đủ thời gian';
  @override
  String get breakLong => 'Bạn đã học chăm chỉ rồi. Nghỉ một chút và uống nước nhé';
  @override
  String get breakMistakes => 'Sai liên tiếp vài câu. Nghỉ một chút rồi thử lại nhé';
  @override
  String get breakSlowing => 'Hơi mệt rồi à? Nghỉ một chút nhé';
  @override
  String get breakRushing => 'Bạn đang trả lời quá nhanh. Hít thở và đọc kỹ từng câu nhé';
  @override
  String get peakAhead => "Sắp có một ngày nhiều bài hơn. Mình làm trước một chút nhé";
  @override
  String get talkGrew => 'Hãy nhờ con dạy lại phần đã tiến bộ. Hỏi "Con làm thế nào vậy?" là một khởi đầu tốt';
  @override
  String get talkOvercame => 'Con đã vượt qua một khó khăn. Hãy khen sự cố gắng hơn là kết quả';
  @override
  String get talkSteady => 'Con đang học đều đặn. Hãy khen chính sự đều đặn đó';
  @override
  String get talkStarted => 'Con đã bước những bước đầu, và một chút cũng đủ. Thử nói "Con đã thử rồi nhỉ"';
  @override
  String get talkRest => 'Tuần này con nghỉ. Đừng trách; hãy cho con biết có thể bắt đầu lại bất cứ lúc nào';
  @override
  String get outcomeAsk => 'Em có muốn ghi lại điểm bài kiểm tra không? Bỏ qua cũng không sao.';
  @override
  String get outcomeSkip => 'Để sau';
  @override
  String get outcomeBaselineAsk => 'Nếu có điểm bài kiểm tra gần nhất từ trước khi bắt đầu dùng, em có thể ghi vào. Không có cũng không sao.';
  @override
  String get outcomeFirst => 'Đã ghi lại. Em sẽ xem được cạnh bài kiểm tra tiếp theo.';
  @override
  String get outcomeUp => 'Điểm cao hơn lần trước rồi. Giỏi lắm!';
  @override
  String get outcomeSame => 'Gần như bằng lần trước. Giữ được sự đều đặn là rất tốt.';
  @override
  String get outcomeDown => 'Lần này thấp hơn lần trước. Không sao đâu. Cùng xem phần nào đã thấy khó nhé.';
  @override
  String get outcomeDisclaimer => 'Đây là bản ghi điểm do chính em nhập. Điều này không đảm bảo điểm sẽ tăng.';
  @override
  String get eveNotice => 'Ngày mai là bài kiểm tra. Đừng học thêm điều mới, chỉ xem lại những gì đã làm';
  @override
  String get testDayNotice => 'Hôm nay là bài kiểm tra. Xem lại nhẹ nhàng là đủ. Cứ bình tĩnh như mọi khi';
  @override
  String get cardAgain => 'Chưa biết';
  @override
  String get cardHard => 'Chưa chắc';
  @override
  String get cardGood => 'Biết rồi';
  @override
  String get cardFlip => 'Lật';
}

/// ドイツ語。[swiss] が true なら スイス・リヒテンシュタイン式（小数点は `.`、ß を使わず ss）。
class DeStrings extends ChukoreStrings {
  const DeStrings({this.swiss = false});

  static const swissRegions = {'ch', 'li'};

  final bool swiss;

  static const _units = ['', 'ein', 'zwei', 'drei', 'vier', 'fünf', 'sechs', 'sieben', 'acht', 'neun'];
  static const _teens = [
    'zehn', 'elf', 'zwölf', 'dreizehn', 'vierzehn', 'fünfzehn', 'sechzehn', 'siebzehn', 'achtzehn', 'neunzehn',
  ];

  String get _thirty => swiss ? 'dreissig' : 'dreißig';

  @override
  String get languageCode => 'de';

  @override
  String get tag => swiss ? 'de-CH' : 'de';

  @override
  String get decimalSeparator => swiss ? '.' : ',';

  /// 1〜99。一の位が 1 の単独は「eins」、二十以上は「einundzwanzig」の形。
  String _below100(int n, {required bool standalone}) {
    if (n < 10) return n == 1 && standalone ? 'eins' : _units[n];
    if (n < 20) return _teens[n - 10];
    final tens = ['', '', 'zwanzig', _thirty, 'vierzig', 'fünfzig', 'sechzig', 'siebzig', 'achtzig', 'neunzig'][n ~/ 10];
    final u = n % 10;
    return u == 0 ? tens : '${_units[u]}und$tens';
  }

  @override
  String gateNumberWords(int n) {
    if (n < 1 || n > 9999) throw RangeError.range(n, 1, 9999, 'n');
    final th = n ~/ 1000, h = (n % 1000) ~/ 100, r = n % 100;
    final b = StringBuffer();
    if (th > 0) b.write('${_units[th]}tausend');
    if (h > 0) b.write('${_units[h]}hundert');
    if (r > 0) b.write(_below100(r, standalone: true));
    return b.toString();
  }

  static String _count(int n, String one, String many) => n == 1 ? '1 $one' : '$n $many';

  @override
  String cardTitle(String subject) => '$subject · Fortschrittskarte';
  @override
  String get headlinePersonalBest => 'Neuer persönlicher Rekord!';
  @override
  String get headlineFirst => 'Ein guter Start';
  @override
  String headlineUp(String points) => '+$points gegenüber dem letzten Mal';
  @override
  String get headlineSame => 'Stabil wie beim letzten Mal';
  @override
  String get headlineDown => 'Von hier aus geht es weiter nach oben';
  @override
  String nextLevel(String points) => 'Noch $points Punkte bis zur nächsten Stufe';
  @override
  String get topLevel => 'Höchste Stufe erreicht!';
  @override
  String streakDays(int days) => '${_count(days, 'Tag', 'Tage')} in Folge';
  @override
  String get statStamps => 'Gemeistert';
  @override
  String get statSolvable => 'Jetzt lösbar';
  @override
  String solvableValue(int count) => _count(count, 'Aufgabe', 'Aufgaben');
  @override
  String cardSemantics(String headline, String level) => 'Fortschrittskarte. $headline. Stufe $level';
  @override
  String get mapSemantics => 'Karte. Tippe, um die Antwort zu wählen';
  @override
  String formatYear(int year) => year < 0 ? '${-year} v. Chr.' : '$year';
  @override
  String reportHeader(int activeDays, int attempts) =>
      'Diese Woche: ${_count(activeDays, 'Tag', 'Tage')} / ${_count(attempts, 'Aufgabe', 'Aufgaben')}';
  @override
  String get reportImprovedTitle => 'Das hat sich diese Woche verbessert:';
  @override
  String reportItem(String title, int b, int a) => '- $title ($b% -> $a%)';
  @override
  String get reportEmpty => 'Diese Woche gibt es noch keine neuen Verbesserungen. Lerne in deinem eigenen Tempo weiter.';
  @override
  String get scopeQrTitle => 'Prüfungsbereich teilen';
  @override
  String get scopeQrHint =>
      'Freunde oder Familie können das scannen, um denselben Bereich einzustellen. Es enthält weder Namen noch Ergebnisse.';
  @override
  String get scopeQrSemantics => 'QR-Code für den Prüfungsbereich';
  @override
  String get checklistTitle => 'Check für den Prüfungstag';
  @override
  String checklistProgress(int done, int total) => '$done von $total bereit';
  @override
  String get checklistAllDone => 'Alles bereit. Viel Erfolg!';
  @override
  String get fiveMinuteTitle => 'Karte für die letzten 5 Minuten';
  @override
  List<(String, String)> get checklistDefaults => [
        ('pencil', 'Stifte'),
        ('eraser', 'Radiergummi'),
        ('ruler', 'Lineal und Zirkel'),
        ('watch', 'Armbanduhr'),
        ('tissue', 'Taschentücher'),
        ('notes', 'Zusammenfassung'),
      ];
  @override
  String get sheetTitle => 'Blitzblatt vor der Prüfung';
  @override
  String get sheetQuestion => 'Aufgabe';
  @override
  String get sheetAnswer => 'Antwort';
  @override
  String get sheetExplanation => 'Erklärung';
  @override
  String get sheetEmpty => 'Im Moment gibt es nichts zu wiederholen. Gut gemacht!';
  @override
  String get markCorrect => 'richtig';
  @override
  String get markWrong => 'falsch';
  @override
  String get ringsTitle => 'Wachstumsringe';
  @override
  String ringsSemantics(int totalDays) => 'Wachstumsringe. Insgesamt ${_count(totalDays, 'Lerntag', 'Lerntage')}';
  @override
  String ringsLatestMonth(String month, int days) =>
      'Letzter Monat, $month: ${_count(days, 'Lerntag', 'Lerntage')}';
  @override
  String get deviationLabel => 'Punkte-Index in der App';
  @override
  String deviationRange(String low, String high) => '$low–$high';
  @override
  String get deviationNote =>
      'Ein grober Index, der nur in dieser App gilt, mit 50 als Durchschnitt der Vergleichsgruppe. Kein bundesweites Ranking.';
  @override
  String get teacherPrompt => 'Was ist hier falsch? Verbessere den Fehler';
  @override
  String get teacherCorrect => 'Richtig! Du hast es verbessert';
  @override
  String get teacherWrong => 'Fast! Lies noch einmal nach';
  @override
  String get nudgeTestSoon => 'Die Prüfung rückt näher. Übe heute ein bisschen';
  @override
  String get nudgeReview => 'Eine kurze Wiederholung hilft gegen das Vergessen';
  @override
  String get nudgeStreak => 'Halte deine Serie mit ein bisschen Übung heute am Laufen';
  @override
  String get myWeekGrew => 'Du hast diese Woche Fortschritte gemacht!';
  @override
  String get myWeekOvercame => 'Du hast eine knifflige Stelle gemeistert!';
  @override
  String get myWeekKept => 'Schön gleichmäßig, bleib dran';
  @override
  String get myWeekStarted => 'Ein toller erster Schritt!';
  @override
  String get myWeekRest => 'Eine ruhige Woche. Fang an, wann du möchtest';
  @override
  String get reasonPrompt => 'Warum ging es schief? (Überspringen ist okay)';
  @override
  String get reasonDontKnow => 'Wusste ich nicht';
  @override
  String get reasonForgot => 'Vergessen';
  @override
  String get reasonCareless => 'Flüchtigkeitsfehler';
  @override
  String get reasonTimeShort => 'Zu wenig Zeit';
  @override
  String get breakLong => 'Du hast fleißig gelernt. Mach eine kurze Pause und trink etwas';
  @override
  String get breakMistakes => 'Ein paar Fehler hintereinander. Mach kurz Pause und versuch es dann noch einmal';
  @override
  String get breakSlowing => 'Wirst du müde? Mach eine kurze Pause';
  @override
  String get breakRushing => 'Du antwortest sehr schnell. Atme durch und lies jede Frage genau';
  @override
  String get peakAhead => "Bald kommt ein Tag mit mehr Aufgaben. Mach schon ein bisschen vor";
  @override
  String get talkGrew => 'Lassen Sie sich von Ihrem Kind zeigen, was besser geworden ist. „Wie hast du das gemacht?“ ist ein guter Anfang';
  @override
  String get talkOvercame => 'Ihr Kind hat eine Hürde überwunden. Loben Sie die Mühe mehr als das Ergebnis';
  @override
  String get talkSteady => 'Ihr Kind bleibt beständig dabei. Loben Sie die Beständigkeit selbst';
  @override
  String get talkStarted => 'Der erste Schritt ist getan, und wenig reicht schon. Sagen Sie z. B.: „Du hast es versucht“';
  @override
  String get talkRest => 'Das war eine Pausenwoche. Ohne Vorwurf; sagen Sie, dass es jederzeit wieder anfangen kann';
  @override
  String get outcomeAsk => 'Möchtest du deine Punktzahl aus dem Test eintragen? Überspringen ist völlig in Ordnung.';
  @override
  String get outcomeSkip => 'Später';
  @override
  String get outcomeBaselineAsk => 'Wenn du die Punktzahl deines letzten Tests von vor dem Start hast, kannst du sie eintragen. Wenn nicht, ist das in Ordnung.';
  @override
  String get outcomeFirst => 'Gespeichert. Du kannst sie neben deinem nächsten Test ansehen.';
  @override
  String get outcomeUp => 'Deine Punktzahl ist höher als beim letzten Mal. Gut gemacht!';
  @override
  String get outcomeSame => 'Ungefähr wie beim letzten Mal. Dranzubleiben ist stark.';
  @override
  String get outcomeDown => 'Diesmal war es weniger als beim letzten Mal. Das ist in Ordnung. Schauen wir gemeinsam, was schwierig war.';
  @override
  String get outcomeDisclaimer => 'Das ist eine Aufzeichnung der Punkte, die du selbst eingetragen hast. Sie ist kein Versprechen, dass deine Punkte steigen.';
  @override
  String get eveNotice => 'Morgen ist die Prüfung. Nichts Neues mehr; schau nur noch durch, was du schon gemacht hast';
  @override
  String get testDayNotice => 'Heute ist die Prüfung. Ein kurzer Blick zurück genügt. Bleib ganz du selbst';
  @override
  String get cardAgain => 'Weiß ich nicht';
  @override
  String get cardHard => 'Unsicher';
  @override
  String get cardGood => 'Weiß ich';
  @override
  String get cardFlip => 'Umdrehen';
}

/// トルコ語。数詞は分けて書き、100 は「yüz」・1000 は「bin」（「bir yüz」「bir bin」とは言わない）。
class TrStrings extends ChukoreStrings {
  const TrStrings();

  static const _units = ['', 'bir', 'iki', 'üç', 'dört', 'beş', 'altı', 'yedi', 'sekiz', 'dokuz'];
  static const _tens = ['', 'on', 'yirmi', 'otuz', 'kırk', 'elli', 'altmış', 'yetmiş', 'seksen', 'doksan'];

  @override
  String get languageCode => 'tr';

  @override
  String get decimalSeparator => ',';

  @override
  String gateNumberWords(int n) {
    if (n < 1 || n > 9999) throw RangeError.range(n, 1, 9999, 'n');
    final th = n ~/ 1000, h = (n % 1000) ~/ 100, t = (n % 100) ~/ 10, u = n % 10;
    return [
      if (th == 1) 'bin' else if (th > 1) '${_units[th]} bin',
      if (h == 1) 'yüz' else if (h > 1) '${_units[h]} yüz',
      if (t > 0) _tens[t],
      if (u > 0) _units[u],
    ].join(' ');
  }

  @override
  String cardTitle(String subject) => '$subject · Gelişim Kartı';
  @override
  String get headlinePersonalBest => 'Yeni kişisel rekor!';
  @override
  String get headlineFirst => 'Güzel bir başlangıç';
  @override
  String headlineUp(String points) => 'Geçen seferden +$points';
  @override
  String get headlineSame => 'Geçen seferki gibi istikrarlı';
  @override
  String get headlineDown => 'Buradan yeniden yükselelim';
  @override
  String nextLevel(String points) => 'Bir sonraki seviyeye $points puan kaldı';
  @override
  String get topLevel => 'En yüksek seviyeye ulaşıldı!';
  @override
  String streakDays(int days) => '$days gün üst üste';
  @override
  String get statStamps => 'Üstesinden gelinen';
  @override
  String get statSolvable => 'Artık çözülebilen';
  @override
  String solvableValue(int count) => '$count soru';
  @override
  String cardSemantics(String headline, String level) => 'Gelişim kartı. $headline. Seviye $level';
  @override
  String get mapSemantics => 'Harita. Cevabı seçmek için dokunun';
  @override
  String formatYear(int year) => year < 0 ? 'M.Ö. ${-year}' : '$year';
  @override
  String reportHeader(int activeDays, int attempts) => 'Bu hafta: $activeDays gün / $attempts soru';
  @override
  String get reportImprovedTitle => 'Bu hafta gelişenler:';
  @override
  String reportItem(String title, int b, int a) => '- $title (%$b -> %$a)';
  @override
  String get reportEmpty => 'Bu hafta henüz yeni bir gelişme yok. Kendi hızında devam et.';
  @override
  String get scopeQrTitle => 'Sınav kapsamını paylaş';
  @override
  String get scopeQrHint =>
      'Arkadaşların veya ailen bunu tarayarak aynı kapsamı ayarlayabilir. İsim veya sonuç içermez.';
  @override
  String get scopeQrSemantics => 'Sınav kapsamı QR kodu';
  @override
  String get checklistTitle => 'Sınav günü kontrolü';
  @override
  String checklistProgress(int done, int total) => '$done/$total hazır';
  @override
  String get checklistAllDone => 'Her şey hazır. Başarılar!';
  @override
  String get fiveMinuteTitle => 'Son 5 dakika kartı';
  @override
  List<(String, String)> get checklistDefaults => [
        ('pencil', 'Kalemler'),
        ('eraser', 'Silgi'),
        ('ruler', 'Cetvel ve pergel'),
        ('watch', 'Kol saati'),
        ('tissue', 'Mendil'),
        ('notes', 'Özet notlar'),
      ];
  @override
  String get sheetTitle => 'Sınav öncesi hızlı sayfa';
  @override
  String get sheetQuestion => 'Soru';
  @override
  String get sheetAnswer => 'Cevap';
  @override
  String get sheetExplanation => 'Açıklama';
  @override
  String get sheetEmpty => 'Şu an düzeltilecek bir şey yok. Aferin!';
  @override
  String get markCorrect => 'doğru';
  @override
  String get markWrong => 'yanlış';
  @override
  String get ringsTitle => 'Gelişim halkaları';
  @override
  String ringsSemantics(int totalDays) => 'Gelişim halkaları. Toplam $totalDays çalışma günü';
  @override
  String ringsLatestMonth(String month, int days) =>
      'Son ay, $month: $days çalışma günü';
  @override
  String get deviationLabel => 'Uygulama içi puan endeksi';
  @override
  String deviationRange(String low, String high) => '$low–$high';
  @override
  String get deviationNote =>
      "Yalnızca bu uygulamada geçerli, 50'nin referans grubun ortalaması olduğu kaba bir endeks. Ülke genelinde bir sıralama değildir.";
  @override
  String get teacherPrompt => 'Burada ne yanlış? Hatayı düzelt';
  @override
  String get teacherCorrect => 'Doğru! Düzeltmeyi başardın';
  @override
  String get teacherWrong => 'Neredeyse! Bir kez daha oku';
  @override
  String get nudgeTestSoon => 'Sınav yaklaşıyor. Bugün biraz çalış';
  @override
  String get nudgeReview => 'Kısa bir tekrar unutmayı önler';
  @override
  String get nudgeStreak => 'Bugün biraz çalışarak serini sürdür';
  @override
  String get myWeekGrew => 'Bu hafta ilerleme kaydettin!';
  @override
  String get myWeekOvercame => 'Zor bir yeri aştın!';
  @override
  String get myWeekKept => 'Düzenli ve istikrarlı, böyle devam';
  @override
  String get myWeekStarted => 'Harika bir ilk adım!';
  @override
  String get myWeekRest => 'Sakin bir hafta. İstediğin zaman yeniden başla';
  @override
  String get reasonPrompt => 'Neden yanlış oldu? (Atlayabilirsin)';
  @override
  String get reasonDontKnow => 'Bilmiyordum';
  @override
  String get reasonForgot => 'Unuttum';
  @override
  String get reasonCareless => 'Dikkatsizlik';
  @override
  String get reasonTimeShort => 'Zaman yetmedi';
  @override
  String get breakLong => 'Çok çalıştın. Kısa bir mola ver ve su iç';
  @override
  String get breakMistakes => 'Üst üste birkaç hata oldu. Kısa bir mola ver, sonra tekrar dene';
  @override
  String get breakSlowing => 'Yorulmaya mı başladın? Kısa bir mola ver';
  @override
  String get breakRushing => 'Çok hızlı cevap veriyorsun. Derin nefes al ve soruları dikkatle oku';
  @override
  String get peakAhead => "Yakında soruların daha çok olduğu bir gün geliyor. Biraz önceden yapalım";
  @override
  String get talkGrew => 'Çocuğunuzdan neyin geliştiğini size öğretmesini isteyin. “Nasıl yaptın?” iyi bir başlangıçtır';
  @override
  String get talkOvercame => 'Çocuğunuz bir zorluğu aştı. Sonuçtan çok çabayı övün';
  @override
  String get talkSteady => 'Çocuğunuz düzenli devam ediyor. Düzenli devam etmenin kendisini övün';
  @override
  String get talkStarted => 'İlk adım atıldı ve azı da yeter. “Denemişsin” demeyi deneyin';
  @override
  String get talkRest => 'Bu hafta dinlenme haftasıydı. Suçlamadan, istediği zaman başlayabileceğini söyleyin';
  @override
  String get outcomeAsk => 'Sınav puanını kaydetmek ister misin? Atlayabilirsin, sorun değil.';
  @override
  String get outcomeSkip => 'Sonra';
  @override
  String get outcomeBaselineAsk => 'Kullanmaya başlamadan önceki en son sınav puanın varsa girebilirsin. Yoksa sorun değil.';
  @override
  String get outcomeFirst => 'Kaydedildi. Bir sonraki sınavınla yan yana görebilirsin.';
  @override
  String get outcomeUp => 'Puanın geçen seferden yüksek. Tebrikler!';
  @override
  String get outcomeSame => 'Geçen seferle hemen hemen aynı. Düzenli devam etmek harika.';
  @override
  String get outcomeDown => 'Bu sefer geçen seferden düşük oldu. Sorun değil. Hangi kısmın zor geldiğine birlikte bakalım.';
  @override
  String get outcomeDisclaimer => 'Bu, senin girdiğin puanların kaydıdır. Puanının artacağına dair bir söz değildir.';
  @override
  String get eveNotice => 'Sınav yarın. Yeni konu eklemeyelim; sadece yaptıklarımıza göz atalım';
  @override
  String get testDayNotice => 'Sınav bugün. Hafifçe göz atmak yeterli. Her zamanki gibi sakin ol';
  @override
  String get cardAgain => 'Bilmiyorum';
  @override
  String get cardHard => 'Emin değilim';
  @override
  String get cardGood => 'Biliyorum';
  @override
  String get cardFlip => 'Çevir';
}

/// タイ語。年は仏暦（พ.ศ. = 西暦 + 543）を主にし、西暦（ค.ศ.）を添える。単語の間に空白を入れない。
class ThStrings extends ChukoreStrings {
  const ThStrings();

  static const _units = ['', 'หนึ่ง', 'สอง', 'สาม', 'สี่', 'ห้า', 'หก', 'เจ็ด', 'แปด', 'เก้า'];

  @override
  String get languageCode => 'th';

  /// 1〜99。十の位があって一の位が 1 なら「เอ็ด」、20 は「ยี่สิบ」、10 は「สิบ」（「หนึ่งสิบ」とは言わない）。
  String _below100(int n) {
    final t = n ~/ 10, u = n % 10;
    final tens = switch (t) { 0 => '', 1 => 'สิบ', 2 => 'ยี่สิบ', _ => '${_units[t]}สิบ' };
    final unit = u == 0 ? '' : (u == 1 && t > 0 ? 'เอ็ด' : _units[u]);
    return '$tens$unit';
  }

  @override
  String gateNumberWords(int n) {
    if (n < 1 || n > 9999) throw RangeError.range(n, 1, 9999, 'n');
    final th = n ~/ 1000, h = (n % 1000) ~/ 100, r = n % 100;
    final b = StringBuffer();
    if (th > 0) b.write('${_units[th]}พัน');
    if (h > 0) b.write('${_units[h]}ร้อย');
    if (r > 0) {
      // 百や千の位のあとに続く 1 も「เอ็ด」（101 = หนึ่งร้อยเอ็ด）
      b.write(r == 1 && (h > 0 || th > 0) ? 'เอ็ด' : _below100(r));
    }
    return b.toString();
  }

  @override
  String cardTitle(String subject) => '$subject · การ์ดความก้าวหน้า';
  @override
  String get headlinePersonalBest => 'สถิติส่วนตัวใหม่!';
  @override
  String get headlineFirst => 'เริ่มต้นได้ดี';
  @override
  String headlineUp(String points) => '+$points จากครั้งก่อน';
  @override
  String get headlineSame => 'คงที่เท่าครั้งก่อน';
  @override
  String get headlineDown => 'มาไปต่อจากตรงนี้กัน';
  @override
  String nextLevel(String points) => 'อีก $points คะแนนถึงระดับถัดไป';
  @override
  String get topLevel => 'ถึงระดับสูงสุดแล้ว!';
  @override
  String streakDays(int days) => '$days วันติดต่อกัน';
  @override
  String get statStamps => 'ผ่านมาได้แล้ว';
  @override
  String get statSolvable => 'ตอนนี้ทำได้';
  @override
  String solvableValue(int count) => '$count ข้อ';
  @override
  String cardSemantics(String headline, String level) => 'การ์ดความก้าวหน้า. $headline. ระดับ $level';
  @override
  String get mapSemantics => 'แผนที่ แตะเพื่อเลือกคำตอบ';
  @override
  String formatYear(int year) => year < 0 ? 'ก่อน ค.ศ. ${-year}' : 'พ.ศ. ${year + 543} (ค.ศ. $year)';
  @override
  String reportHeader(int activeDays, int attempts) => 'สัปดาห์นี้: $activeDays วัน / $attempts ข้อ';
  @override
  String get reportImprovedTitle => 'สิ่งที่ดีขึ้นในสัปดาห์นี้:';
  @override
  String reportItem(String title, int b, int a) => '- $title ($b% -> $a%)';
  @override
  String get reportEmpty => 'สัปดาห์นี้ยังไม่มีความก้าวหน้าใหม่ ค่อย ๆ ไปตามจังหวะของตัวเองนะ';
  @override
  String get scopeQrTitle => 'แชร์ขอบเขตการสอบ';
  @override
  String get scopeQrHint => 'เพื่อนหรือครอบครัวสแกนเพื่อตั้งขอบเขตเดียวกันได้ ไม่มีชื่อหรือผลคะแนน';
  @override
  String get scopeQrSemantics => 'คิวอาร์โค้ดขอบเขตการสอบ';
  @override
  String get checklistTitle => 'เช็กลิสต์วันสอบ';
  @override
  String checklistProgress(int done, int total) => 'พร้อมแล้ว $done จาก $total';
  @override
  String get checklistAllDone => 'พร้อมทุกอย่างแล้ว ขอให้โชคดี!';
  @override
  String get fiveMinuteTitle => 'การ์ด 5 นาทีสุดท้าย';
  @override
  List<(String, String)> get checklistDefaults => [
        ('pencil', 'เครื่องเขียน'),
        ('eraser', 'ยางลบ'),
        ('ruler', 'ไม้บรรทัดและวงเวียน'),
        ('watch', 'นาฬิกาข้อมือ'),
        ('tissue', 'ผ้าเช็ดหน้าและทิชชู'),
        ('notes', 'โน้ตสรุป'),
      ];
  @override
  String get sheetTitle => 'ใบสรุปด่วนก่อนสอบ';
  @override
  String get sheetQuestion => 'โจทย์';
  @override
  String get sheetAnswer => 'คำตอบ';
  @override
  String get sheetExplanation => 'คำอธิบาย';
  @override
  String get sheetEmpty => 'ตอนนี้ไม่มีอะไรต้องทบทวน เยี่ยมมาก!';
  @override
  String get markCorrect => 'ถูก';
  @override
  String get markWrong => 'ผิด';
  @override
  String get ringsTitle => 'วงแหวนการเติบโต';
  @override
  String ringsSemantics(int totalDays) => 'วงแหวนการเติบโต รวม $totalDays วันที่เรียน';
  @override
  String ringsLatestMonth(String month, int days) =>
      'เดือนล่าสุด $month: เรียน $days วัน';
  @override
  String get deviationLabel => 'ดัชนีคะแนนในแอป';
  @override
  String deviationRange(String low, String high) => '$low–$high';
  @override
  String get deviationNote =>
      'ดัชนีคร่าว ๆ ที่ใช้ได้เฉพาะในแอปนี้ โดยมี 50 เป็นค่าเฉลี่ยของกลุ่มอ้างอิง ไม่ใช่อันดับระดับประเทศ';
  @override
  String get teacherPrompt => 'ตรงไหนผิด? ช่วยแก้ให้ถูก';
  @override
  String get teacherCorrect => 'ถูกต้อง! แก้ได้แล้ว';
  @override
  String get teacherWrong => 'เกือบแล้ว! อ่านอีกครั้งนะ';
  @override
  String get nudgeTestSoon => 'ใกล้สอบแล้ว วันนี้ลองทำสักนิดนะ';
  @override
  String get nudgeReview => 'ทบทวนสั้น ๆ ช่วยไม่ให้ลืมนะ';
  @override
  String get nudgeStreak => 'ทำสักนิดวันนี้ เพื่อต่อสถิติที่ทำติดต่อกัน';
  @override
  String get myWeekGrew => 'สัปดาห์นี้คุณก้าวหน้าขึ้นแล้ว!';
  @override
  String get myWeekOvercame => 'คุณผ่านจุดที่ยากไปได้แล้ว!';
  @override
  String get myWeekKept => 'สม่ำเสมอดีมาก ทำต่อไปนะ';
  @override
  String get myWeekStarted => 'ก้าวแรกที่ดีมาก!';
  @override
  String get myWeekRest => 'สัปดาห์ที่เงียบสงบ เริ่มใหม่ได้ทุกเมื่อ';
  @override
  String get reasonPrompt => 'ทำไมถึงผิดนะ? (ข้ามได้)';
  @override
  String get reasonDontKnow => 'ไม่รู้';
  @override
  String get reasonForgot => 'ลืม';
  @override
  String get reasonCareless => 'สะเพร่า';
  @override
  String get reasonTimeShort => 'เวลาไม่พอ';
  @override
  String get breakLong => 'ตั้งใจเรียนมาเยอะแล้ว พักสักหน่อยและดื่มน้ำนะ';
  @override
  String get breakMistakes => 'ผิดติดกันหลายข้อ พักสักครู่แล้วลองใหม่นะ';
  @override
  String get breakSlowing => 'เริ่มเหนื่อยแล้วหรือเปล่า? พักสักหน่อยนะ';
  @override
  String get breakRushing => 'ตอบเร็วเกินไปหรือเปล่า หายใจลึก ๆ แล้วอ่านโจทย์ให้ดีนะ';
  @override
  String get peakAhead => "อีกไม่นานจะมีวันที่โจทย์เยอะขึ้น ทำล่วงหน้าไว้นิดหนึ่งนะ";
  @override
  String get talkGrew => 'ลองให้ลูกสอนว่าอะไรดีขึ้น การถามว่า "ทำได้ยังไง" เป็นจุดเริ่มต้นที่ดี';
  @override
  String get talkOvercame => 'ลูกผ่านอุปสรรคมาได้แล้ว ชมความพยายามมากกว่าผลลัพธ์';
  @override
  String get talkSteady => 'ลูกทำต่อเนื่องสม่ำเสมอ ชมความสม่ำเสมอนั้นเอง';
  @override
  String get talkStarted => 'ก้าวแรกเริ่มแล้ว และแค่นิดเดียวก็พอ ลองพูดว่า "ลองทำดูแล้วนะ"';
  @override
  String get talkRest => 'สัปดาห์นี้พัก ไม่ต้องตำหนิ บอกลูกว่าเริ่มใหม่ได้ทุกเมื่อ';
  @override
  String get outcomeAsk => 'อยากบันทึกคะแนนสอบไหม? ข้ามไปก็ไม่เป็นไรนะ';
  @override
  String get outcomeSkip => 'ไว้ทีหลัง';
  @override
  String get outcomeBaselineAsk => 'ถ้ามีคะแนนสอบครั้งล่าสุดก่อนเริ่มใช้ ใส่ไว้ได้เลย ถ้าไม่มีก็ไม่เป็นไร';
  @override
  String get outcomeFirst => 'บันทึกแล้ว ดูเทียบกับการสอบครั้งต่อไปได้';
  @override
  String get outcomeUp => 'คะแนนสูงกว่าครั้งที่แล้ว เก่งมาก!';
  @override
  String get outcomeSame => 'ใกล้เคียงครั้งที่แล้ว การทำต่อเนื่องก็เยี่ยมแล้ว';
  @override
  String get outcomeDown => 'ครั้งนี้ต่ำกว่าครั้งที่แล้ว ไม่เป็นไรนะ มาดูด้วยกันว่าส่วนไหนยาก';
  @override
  String get outcomeDisclaimer => 'นี่คือบันทึกคะแนนที่คุณกรอกเอง ไม่ได้รับรองว่าคะแนนจะเพิ่มขึ้น';
  @override
  String get eveNotice => 'พรุ่งนี้สอบแล้ว ไม่ต้องเพิ่มเรื่องใหม่ ทบทวนเฉพาะที่เคยทำก็พอ';
  @override
  String get testDayNotice => 'วันนี้สอบแล้ว ทบทวนเบา ๆ ก็เพียงพอ ทำตัวตามปกติได้เลย';
  @override
  String get cardAgain => 'ไม่รู้';
  @override
  String get cardHard => 'ไม่แน่ใจ';
  @override
  String get cardGood => 'รู้แล้ว';
  @override
  String get cardFlip => 'พลิกการ์ด';
}

/// ヒンディー語。数詞は 1〜99 がすべて不規則なので、0〜99 を表で持つ。100 は「एक सौ」・1000 は「एक हज़ार」。
/// 小数点はドット。年は西暦「ई.」・紀元前「ई.पू.」。
class HiStrings extends ChukoreStrings {
  const HiStrings();

  /// 0〜99 の読み。綴りの揺れがある語（तिरपन など）は一般的な綴りを採った。ネイティブ確認の対象。
  static const numbers = [
    'शून्य', 'एक', 'दो', 'तीन', 'चार', 'पाँच', 'छह', 'सात', 'आठ', 'नौ',
    'दस', 'ग्यारह', 'बारह', 'तेरह', 'चौदह', 'पंद्रह', 'सोलह', 'सत्रह', 'अठारह', 'उन्नीस',
    'बीस', 'इक्कीस', 'बाईस', 'तेईस', 'चौबीस', 'पच्चीस', 'छब्बीस', 'सत्ताईस', 'अट्ठाईस', 'उनतीस',
    'तीस', 'इकतीस', 'बत्तीस', 'तैंतीस', 'चौंतीस', 'पैंतीस', 'छत्तीस', 'सैंतीस', 'अड़तीस', 'उनतालीस',
    'चालीस', 'इकतालीस', 'बयालीस', 'तैंतालीस', 'चौवालीस', 'पैंतालीस', 'छियालीस', 'सैंतालीस', 'अड़तालीस', 'उनचास',
    'पचास', 'इक्यावन', 'बावन', 'तिरपन', 'चौवन', 'पचपन', 'छप्पन', 'सत्तावन', 'अट्ठावन', 'उनसठ',
    'साठ', 'इकसठ', 'बासठ', 'तिरसठ', 'चौंसठ', 'पैंसठ', 'छियासठ', 'सड़सठ', 'अड़सठ', 'उनहत्तर',
    'सत्तर', 'इकहत्तर', 'बहत्तर', 'तिहत्तर', 'चौहत्तर', 'पचहत्तर', 'छिहत्तर', 'सतहत्तर', 'अठहत्तर', 'उन्यासी',
    'अस्सी', 'इक्यासी', 'बयासी', 'तिरासी', 'चौरासी', 'पचासी', 'छियासी', 'सत्तासी', 'अट्ठासी', 'नवासी',
    'नब्बे', 'इक्यानवे', 'बानवे', 'तिरानवे', 'चौरानवे', 'पंचानवे', 'छियानवे', 'सत्तानवे', 'अट्ठानवे', 'निन्यानवे',
  ];

  @override
  String get languageCode => 'hi';

  @override
  String gateNumberWords(int n) {
    if (n < 1 || n > 9999) throw RangeError.range(n, 1, 9999, 'n');
    final th = n ~/ 1000, h = (n % 1000) ~/ 100, r = n % 100;
    return [
      if (th > 0) '${numbers[th]} हज़ार',
      if (h > 0) '${numbers[h]} सौ',
      if (r > 0) numbers[r],
    ].join(' ');
  }

  @override
  String cardTitle(String subject) => '$subject · प्रगति कार्ड';
  @override
  String get headlinePersonalBest => 'नया निजी रिकॉर्ड!';
  @override
  String get headlineFirst => 'बढ़िया शुरुआत';
  @override
  String headlineUp(String points) => 'पिछली बार से +$points';
  @override
  String get headlineSame => 'पिछली बार जितना ही स्थिर';
  @override
  String get headlineDown => 'यहाँ से फिर आगे बढ़ें';
  @override
  String nextLevel(String points) => 'अगले स्तर के लिए $points अंक बाकी';
  @override
  String get topLevel => 'सबसे ऊँचे स्तर पर पहुँच गए!';
  @override
  String streakDays(int days) => '$days दिन लगातार';
  @override
  String get statStamps => 'पार किए';
  @override
  String get statSolvable => 'अब हल कर सकते हैं';
  @override
  String solvableValue(int count) => '$count प्रश्न';
  @override
  String cardSemantics(String headline, String level) => 'प्रगति कार्ड। $headline। स्तर $level';
  @override
  String get mapSemantics => 'नक्शा। उत्तर चुनने के लिए छुएँ';
  @override
  String formatYear(int year) => year < 0 ? '${-year} ई.पू.' : '$year ई.';
  @override
  String reportHeader(int activeDays, int attempts) => 'इस सप्ताह: $activeDays दिन / $attempts प्रश्न';
  @override
  String get reportImprovedTitle => 'इस सप्ताह जो बेहतर हुआ:';
  @override
  String reportItem(String title, int b, int a) => '- $title ($b% -> $a%)';
  @override
  String get reportEmpty => 'इस सप्ताह अभी कोई नई प्रगति नहीं है। अपनी गति से आगे बढ़ते रहें।';
  @override
  String get scopeQrTitle => 'परीक्षा का दायरा साझा करें';
  @override
  String get scopeQrHint => 'दोस्त या परिवार इसे स्कैन करके वही दायरा सेट कर सकते हैं। इसमें नाम या परिणाम नहीं होते।';
  @override
  String get scopeQrSemantics => 'परीक्षा के दायरे का QR कोड';
  @override
  String get checklistTitle => 'परीक्षा के दिन की जाँच-सूची';
  @override
  String checklistProgress(int done, int total) => '$total में से $done तैयार';
  @override
  String get checklistAllDone => 'सब कुछ तैयार है। शुभकामनाएँ!';
  @override
  String get fiveMinuteTitle => 'आख़िरी 5 मिनट का कार्ड';
  @override
  List<(String, String)> get checklistDefaults => [
        ('pencil', 'पेन-पेंसिल'),
        ('eraser', 'रबर'),
        ('ruler', 'स्केल और कंपास'),
        ('watch', 'कलाई घड़ी'),
        ('tissue', 'रुमाल और टिशू'),
        ('notes', 'सारांश नोट्स'),
      ];
  @override
  String get sheetTitle => 'परीक्षा से पहले की झटपट शीट';
  @override
  String get sheetQuestion => 'प्रश्न';
  @override
  String get sheetAnswer => 'उत्तर';
  @override
  String get sheetExplanation => 'व्याख्या';
  @override
  String get sheetEmpty => 'अभी दोहराने के लिए कुछ नहीं है। शाबाश!';
  @override
  String get markCorrect => 'सही';
  @override
  String get markWrong => 'गलत';
  @override
  String get ringsTitle => 'विकास के छल्ले';
  @override
  String ringsSemantics(int totalDays) => 'विकास के छल्ले। कुल $totalDays दिन पढ़ाई';
  @override
  String ringsLatestMonth(String month, int days) => 'सबसे हाल का महीना, $month: $days दिन पढ़ाई';
  @override
  String get deviationLabel => 'ऐप के भीतर का अंक सूचकांक';
  @override
  String deviationRange(String low, String high) => '$low–$high';
  @override
  String get deviationNote =>
      'केवल इसी ऐप में मान्य एक मोटा सूचकांक, जिसमें 50 संदर्भ समूह का औसत है। यह राष्ट्रीय रैंकिंग नहीं है।';
  @override
  String get teacherPrompt => 'यहाँ क्या गलत है? गलती सुधारें';
  @override
  String get teacherCorrect => 'सही! आपने इसे सुधार दिया';
  @override
  String get teacherWrong => 'लगभग! एक बार फिर पढ़ें';
  @override
  String get nudgeTestSoon => 'परीक्षा पास आ रही है। आज थोड़ा अभ्यास करें';
  @override
  String get nudgeReview => 'थोड़ा दोहराने से चीज़ें याद रहती हैं';
  @override
  String get nudgeStreak => 'आज थोड़ा अभ्यास करके अपना सिलसिला बनाए रखें';
  @override
  String get myWeekGrew => 'इस हफ़्ते आपने तरक्की की!';
  @override
  String get myWeekOvercame => 'आपने एक मुश्किल जगह पार कर ली!';
  @override
  String get myWeekKept => 'लगातार अच्छा चल रहा है, ऐसे ही चलते रहें';
  @override
  String get myWeekStarted => 'बहुत अच्छी पहली शुरुआत!';
  @override
  String get myWeekRest => 'यह हफ़्ता शांत रहा। जब चाहें फिर शुरू करें';
  @override
  String get reasonPrompt => 'गलती क्यों हुई? (छोड़ सकते हैं)';
  @override
  String get reasonDontKnow => 'पता नहीं था';
  @override
  String get reasonForgot => 'याद नहीं रहा';
  @override
  String get reasonCareless => 'लापरवाही हो गई';
  @override
  String get reasonTimeShort => 'समय कम पड़ा';
  @override
  String get breakLong => 'आपने काफ़ी मेहनत की है। थोड़ा आराम करें और पानी पिएँ';
  @override
  String get breakMistakes => 'लगातार कुछ गलतियाँ हुईं। थोड़ा रुकें, फिर दोबारा कोशिश करें';
  @override
  String get breakSlowing => 'थकान लग रही है? थोड़ा आराम करें';
  @override
  String get breakRushing => 'आप बहुत जल्दी जवाब दे रहे हैं। गहरी साँस लें और सवाल ध्यान से पढ़ें';
  @override
  String get peakAhead => "जल्द ही ज़्यादा सवालों वाला दिन आने वाला है। थोड़ा पहले से कर लें";
  @override
  String get talkGrew => 'बच्चे से पूछें कि क्या बेहतर हुआ और उसे आपको सिखाने दें। "तुमने यह कैसे किया?" एक अच्छी शुरुआत है';
  @override
  String get talkOvercame => 'बच्चे ने एक मुश्किल पार कर ली। नतीजे से ज़्यादा कोशिश की तारीफ़ करें';
  @override
  String get talkSteady => 'बच्चा लगातार जुटा हुआ है। इस निरंतरता की ही तारीफ़ करें';
  @override
  String get talkStarted => 'पहला कदम उठ गया है, और थोड़ा भी काफ़ी है। कहकर देखें, "तुमने कोशिश की"';
  @override
  String get talkRest => 'इस हफ़्ते आराम रहा। बिना दोष दिए बताएँ कि वह कभी भी फिर से शुरू कर सकता है';
  @override
  String get outcomeAsk => 'क्या अपने टेस्ट का स्कोर दर्ज करना है? छोड़ दें तो भी कोई बात नहीं।';
  @override
  String get outcomeSkip => 'बाद में';
  @override
  String get outcomeBaselineAsk => 'अगर इस्तेमाल शुरू करने से पहले का सबसे ताज़ा टेस्ट स्कोर है, तो दर्ज कर दें। न हो तो कोई बात नहीं।';
  @override
  String get outcomeFirst => 'दर्ज हो गया। अगले टेस्ट के साथ इसे देखा जा सकेगा।';
  @override
  String get outcomeUp => 'पिछली बार से स्कोर बढ़ा है। शाबाश!';
  @override
  String get outcomeSame => 'पिछली बार के लगभग बराबर है। लगातार लगे रहना बहुत अच्छी बात है।';
  @override
  String get outcomeDown => 'इस बार स्कोर पिछली बार से कम रहा। कोई बात नहीं। आइए साथ देखें कि कौन-सा हिस्सा मुश्किल लगा।';
  @override
  String get outcomeDisclaimer => 'यह आपके खुद दर्ज किए स्कोर का रिकॉर्ड है। यह स्कोर बढ़ने का वादा नहीं है।';
  @override
  String get eveNotice => 'कल परीक्षा है। अब कुछ नया नहीं; बस जो पहले कर चुके हैं उसे एक बार देख लें';
  @override
  String get testDayNotice => 'आज परीक्षा है। हल्का दोहराना काफ़ी है। हमेशा की तरह शांत रहें';
  @override
  String get cardAgain => 'पता नहीं';
  @override
  String get cardHard => 'पक्का नहीं';
  @override
  String get cardGood => 'पता है';
  @override
  String get cardFlip => 'पलटें';
}

/// アラビア語（現代標準アラビア語）。右から左に書く。数字は西洋式（0〜9）で出し、
/// 入力は東洋式（٠〜٩）・ペルシア式（۰〜۹）も受け付ける。小数点はドット。
/// 数詞は男性形の基数詞（位は「و」でつなぐ）。個数の言い方（2 は双数、3〜10 は複数、11 以上は単数）に対応する。
class ArStrings extends ChukoreStrings {
  const ArStrings();

  static const _ones = ['', 'واحد', 'اثنان', 'ثلاثة', 'أربعة', 'خمسة', 'ستة', 'سبعة', 'ثمانية', 'تسعة'];
  static const _tens = ['', 'عشرة', 'عشرون', 'ثلاثون', 'أربعون', 'خمسون', 'ستون', 'سبعون', 'ثمانون', 'تسعون'];
  static const _hundreds = [
    '', 'مئة', 'مئتان', 'ثلاثمئة', 'أربعمئة', 'خمسمئة', 'ستمئة', 'سبعمئة', 'ثمانمئة', 'تسعمئة',
  ];
  static const _thousands = [
    '', 'ألف', 'ألفان', 'ثلاثة آلاف', 'أربعة آلاف', 'خمسة آلاف', 'ستة آلاف', 'سبعة آلاف', 'ثمانية آلاف', 'تسعة آلاف',
  ];

  @override
  String get languageCode => 'ar';

  @override
  bool get rightToLeft => true;

  /// 1〜99（11・12 は特別、13〜19 は「〜 عشر」、21 以上は「一の位 و 十の位」）。
  String _below100(int n) {
    if (n < 10) return _ones[n];
    if (n == 10) return 'عشرة';
    if (n == 11) return 'أحد عشر';
    if (n == 12) return 'اثنا عشر';
    if (n < 20) return '${_ones[n - 10]} عشر';
    final u = n % 10, t = n ~/ 10;
    return u == 0 ? _tens[t] : '${_ones[u]} و${_tens[t]}';
  }

  @override
  String gateNumberWords(int n) {
    if (n < 1 || n > 9999) throw RangeError.range(n, 1, 9999, 'n');
    final parts = [
      if (n >= 1000) _thousands[n ~/ 1000],
      if ((n % 1000) >= 100) _hundreds[(n % 1000) ~/ 100],
      if (n % 100 > 0) _below100(n % 100),
    ];
    return parts.first + [for (final p in parts.skip(1)) ' و$p'].join();
  }

  /// 個数の言い方: 1 は「يوم واحد」、2 は双数「يومان」、3〜10 は複数「أيام」、11 以上は単数の対格「يومًا」。
  static String _count(int n, String one, String two, String few, String many) {
    if (n == 1) return one;
    if (n == 2) return two;
    if (n >= 3 && n <= 10) return '$n $few';
    return '$n $many';
  }

  static String _days(int n) => _count(n, 'يوم واحد', 'يومان', 'أيام', 'يومًا');
  static String _questions(int n) => _count(n, 'سؤال واحد', 'سؤالان', 'أسئلة', 'سؤالًا');

  @override
  String cardTitle(String subject) => '$subject · بطاقة التقدم';
  @override
  String get headlinePersonalBest => 'رقم قياسي شخصي جديد!';
  @override
  String get headlineFirst => 'بداية رائعة';
  @override
  String headlineUp(String points) => '+$points عن المرة السابقة';
  @override
  String get headlineSame => 'ثابت مثل المرة السابقة';
  @override
  String get headlineDown => 'لنواصل التقدم من هنا';
  @override
  String nextLevel(String points) => 'بقي $points نقطة للمستوى التالي';
  @override
  String get topLevel => 'وصلت إلى أعلى مستوى!';
  @override
  String streakDays(int days) => 'سلسلة متتالية: ${_days(days)}';
  @override
  String get statStamps => 'ما تم إتقانه';
  @override
  String get statSolvable => 'ما يمكنك حله الآن';
  @override
  String solvableValue(int count) => _questions(count);
  @override
  String cardSemantics(String headline, String level) => 'بطاقة التقدم. $headline. المستوى $level';
  @override
  String get mapSemantics => 'خريطة. المس لاختيار الإجابة';
  @override
  String formatYear(int year) => year < 0 ? '${-year} ق.م' : '$year م';
  @override
  String reportHeader(int activeDays, int attempts) => 'هذا الأسبوع: ${_days(activeDays)} / ${_questions(attempts)}';
  @override
  String get reportImprovedTitle => 'ما تحسن هذا الأسبوع:';
  @override
  String reportItem(String title, int b, int a) => '- $title (من $b% إلى $a%)';
  @override
  String get reportEmpty => 'لا تقدم جديد هذا الأسبوع بعد. واصل بالسرعة التي تناسبك.';
  @override
  String get scopeQrTitle => 'مشاركة نطاق الاختبار';
  @override
  String get scopeQrHint => 'يمكن للأصدقاء أو العائلة مسح الرمز لضبط النطاق نفسه. لا يحتوي على أسماء أو نتائج.';
  @override
  String get scopeQrSemantics => 'رمز QR لنطاق الاختبار';
  @override
  String get checklistTitle => 'قائمة يوم الاختبار';
  @override
  String checklistProgress(int done, int total) => 'جاهز $done من $total';
  @override
  String get checklistAllDone => 'كل شيء جاهز. بالتوفيق!';
  @override
  String get fiveMinuteTitle => 'بطاقة آخر 5 دقائق';
  @override
  List<(String, String)> get checklistDefaults => [
        ('pencil', 'أقلام'),
        ('eraser', 'ممحاة'),
        ('ruler', 'مسطرة وفرجار'),
        ('watch', 'ساعة يد'),
        ('tissue', 'مناديل'),
        ('notes', 'ملاحظات ملخصة'),
      ];
  @override
  String get sheetTitle => 'ورقة المراجعة السريعة قبل الاختبار';
  @override
  String get sheetQuestion => 'السؤال';
  @override
  String get sheetAnswer => 'الإجابة';
  @override
  String get sheetExplanation => 'الشرح';
  @override
  String get sheetEmpty => 'لا شيء للمراجعة الآن. أحسنت!';
  @override
  String get markCorrect => 'صحيح';
  @override
  String get markWrong => 'خطأ';
  @override
  String get ringsTitle => 'حلقات النمو';
  @override
  String ringsSemantics(int totalDays) => 'حلقات النمو. المجموع ${_days(totalDays)} من الدراسة';
  @override
  String ringsLatestMonth(String month, int days) => 'أحدث شهر، $month: ${_days(days)} من الدراسة';
  @override
  String get deviationLabel => 'مؤشر الدرجات داخل التطبيق';
  @override
  String deviationRange(String low, String high) => '$low–$high';
  @override
  String get deviationNote =>
      'مؤشر تقريبي صالح داخل هذا التطبيق فقط، وفيه 50 هو متوسط المجموعة المرجعية. وليس ترتيبا وطنيا.';
  @override
  String get teacherPrompt => 'ما الخطأ هنا؟ صحح الخطأ';
  @override
  String get teacherCorrect => 'صحيح! لقد صححته';
  @override
  String get teacherWrong => 'تقريبا! اقرأ مرة أخرى';
  @override
  String get nudgeTestSoon => 'اقترب الاختبار. تدرّب قليلاً اليوم';
  @override
  String get nudgeReview => 'مراجعة سريعة تساعدك على عدم النسيان';
  @override
  String get nudgeStreak => 'حافظ على سلسلتك بقليل من التدريب اليوم';
  @override
  String get myWeekGrew => 'تقدّمتَ هذا الأسبوع!';
  @override
  String get myWeekOvercame => 'تجاوزتَ نقطة صعبة!';
  @override
  String get myWeekKept => 'ثبات جميل، واصل هكذا';
  @override
  String get myWeekStarted => 'خطوة أولى رائعة!';
  @override
  String get myWeekRest => 'أسبوع هادئ. ابدأ من جديد متى شئت';
  @override
  String get reasonPrompt => 'لماذا حدث الخطأ؟ (يمكنك التخطي)';
  @override
  String get reasonDontKnow => 'لم أكن أعرف';
  @override
  String get reasonForgot => 'نسيت';
  @override
  String get reasonCareless => 'خطأ بسبب السهو';
  @override
  String get reasonTimeShort => 'لم يكفِ الوقت';
  @override
  String get breakLong => 'لقد تعبتَ كثيرًا في الدراسة. خذ استراحة قصيرة واشرب ماء';
  @override
  String get breakMistakes => 'عدة أخطاء متتالية. خذ استراحة قصيرة ثم حاول مرة أخرى';
  @override
  String get breakSlowing => 'هل بدأتَ تتعب؟ خذ استراحة قصيرة';
  @override
  String get breakRushing => 'تجيب بسرعة كبيرة. تنفّس بعمق واقرأ كل سؤال بعناية';
  @override
  String get peakAhead => "يقترب يوم فيه أسئلة أكثر. لنتقدّم قليلًا من الآن";
  @override
  String get talkGrew => 'اطلب من طفلك أن يعلّمك ما الذي تحسّن. سؤال «كيف فعلت ذلك؟» بداية جيدة';
  @override
  String get talkOvercame => 'تجاوز طفلك عقبة. امدح الجهد أكثر من النتيجة';
  @override
  String get talkSteady => 'طفلك مستمر بانتظام. امدح هذا الاستمرار نفسه';
  @override
  String get talkStarted => 'تمّت الخطوة الأولى، والقليل يكفي. جرّب أن تقول «لقد حاولت»';
  @override
  String get talkRest => 'كان هذا أسبوع راحة. دون لوم؛ أخبره أنه يستطيع البدء في أي وقت';
  @override
  String get outcomeAsk => 'هل تريد تسجيل درجة اختبارك؟ يمكنك التخطي، ولا بأس بذلك.';
  @override
  String get outcomeSkip => 'لاحقًا';
  @override
  String get outcomeBaselineAsk => 'إذا كانت لديك درجة آخر اختبار قبل بدء الاستخدام فيمكنك إدخالها. وإن لم تكن لديك فلا بأس.';
  @override
  String get outcomeFirst => 'تم التسجيل. يمكنك مقارنتها مع اختبارك القادم.';
  @override
  String get outcomeUp => 'درجتك أعلى من المرة السابقة. أحسنت!';
  @override
  String get outcomeSame => 'قريبة جدًا من المرة السابقة. الاستمرار في حد ذاته رائع.';
  @override
  String get outcomeDown => 'كانت الدرجة هذه المرة أقل من السابقة. لا بأس. لنرَ معًا ما الذي بدا صعبًا.';
  @override
  String get outcomeDisclaimer => 'هذا سجل للدرجات التي أدخلتها بنفسك، وليس وعدًا بأن درجتك سترتفع.';
  @override
  String get eveNotice => 'الاختبار غدًا. لا مواد جديدة الآن؛ يكفي أن تراجع ما أنجزته من قبل';
  @override
  String get testDayNotice => 'الاختبار اليوم. مراجعة خفيفة تكفي. كن هادئًا كالمعتاد';
  @override
  String get cardAgain => 'لا أعرف';
  @override
  String get cardHard => 'غير متأكد';
  @override
  String get cardGood => 'أعرف';
  @override
  String get cardFlip => 'اقلب';
}

/// ロシア語。複数形は 3 つ（1・2〜4・5 以上。11〜14 は 5 以上の形）。小数点はカンマ。
/// 数の読み上げは男性形（千は女性形: одна тысяча・две тысячи）。
class RuStrings extends ChukoreStrings {
  const RuStrings();

  static const _ones = ['', 'один', 'два', 'три', 'четыре', 'пять', 'шесть', 'семь', 'восемь', 'девять'];
  static const _teens = [
    'десять', 'одиннадцать', 'двенадцать', 'тринадцать', 'четырнадцать',
    'пятнадцать', 'шестнадцать', 'семнадцать', 'восемнадцать', 'девятнадцать',
  ];
  static const _tens = [
    '', '', 'двадцать', 'тридцать', 'сорок', 'пятьдесят', 'шестьдесят', 'семьдесят', 'восемьдесят', 'девяносто',
  ];
  static const _hundreds = [
    '', 'сто', 'двести', 'триста', 'четыреста', 'пятьсот', 'шестьсот', 'семьсот', 'восемьсот', 'девятьсот',
  ];

  @override
  String get languageCode => 'ru';

  @override
  String get decimalSeparator => ',';

  /// 数に合う名詞の形（1 / 2〜4 / 5 以上）。
  static String plural(int n, String one, String few, String many) {
    final m100 = n % 100, m10 = n % 10;
    if (m100 >= 11 && m100 <= 14) return many;
    if (m10 == 1) return one;
    if (m10 >= 2 && m10 <= 4) return few;
    return many;
  }

  @override
  String gateNumberWords(int n) {
    if (n < 1 || n > 9999) throw RangeError.range(n, 1, 9999, 'n');
    final th = n ~/ 1000, rest = n % 1000;
    final h = rest ~/ 100, r = rest % 100;
    final parts = <String>[];
    if (th > 0) {
      final w = switch (th) { 1 => 'одна', 2 => 'две', _ => _ones[th] };
      parts.add('$w ${plural(th, 'тысяча', 'тысячи', 'тысяч')}');
    }
    if (h > 0) parts.add(_hundreds[h]);
    if (r >= 10 && r < 20) {
      parts.add(_teens[r - 10]);
    } else {
      if (r >= 20) parts.add(_tens[r ~/ 10]);
      if (r % 10 > 0) parts.add(_ones[r % 10]);
    }
    return parts.join(' ');
  }

  @override
  String cardTitle(String subject) => '$subject · Карточка роста';
  @override
  String get headlinePersonalBest => 'Новый личный рекорд!';
  @override
  String get headlineFirst => 'Хорошее начало';
  @override
  String headlineUp(String points) => '+$points к прошлому разу';
  @override
  String get headlineSame => 'Стабильно, как в прошлый раз';
  @override
  String get headlineDown => 'Давай снова поднимемся';
  @override
  String nextLevel(String points) => 'До следующего уровня: $points';
  @override
  String get topLevel => 'Достигнут высший уровень!';
  @override
  String streakDays(int days) => '$days ${plural(days, 'день', 'дня', 'дней')} подряд';
  @override
  String get statStamps => 'Преодолено';
  @override
  String get statSolvable => 'Теперь получается';
  @override
  String solvableValue(int count) => '$count ${plural(count, 'вопрос', 'вопроса', 'вопросов')}';
  @override
  String cardSemantics(String headline, String level) => 'Карточка роста. $headline. Уровень $level';
  @override
  String get mapSemantics => 'Карта. Нажми, чтобы выбрать ответ';
  @override
  String formatYear(int year) => year < 0 ? '${-year} г. до н. э.' : '$year г.';
  @override
  String reportHeader(int activeDays, int attempts) =>
      'На этой неделе: $activeDays ${plural(activeDays, 'день', 'дня', 'дней')} / '
      '$attempts ${plural(attempts, 'вопрос', 'вопроса', 'вопросов')}';
  @override
  String get reportImprovedTitle => 'Что улучшилось на этой неделе:';
  @override
  String reportItem(String title, int b, int a) => '- $title ($b% -> $a%)';
  @override
  String get reportEmpty => 'На этой неделе пока нет новых улучшений. Занимайся в своём темпе.';
  @override
  String get scopeQrTitle => 'Поделиться областью экзамена';
  @override
  String get scopeQrHint =>
      'Друзья или семья могут отсканировать код и настроить ту же область. Имён и результатов в нём нет.';
  @override
  String get scopeQrSemantics => 'QR-код области экзамена';
  @override
  String get checklistTitle => 'Проверка в день экзамена';
  @override
  String checklistProgress(int done, int total) => 'Готово $done из $total';
  @override
  String get checklistAllDone => 'Всё готово. Удачи!';
  @override
  String get fiveMinuteTitle => 'Карточки на последние 5 минут';
  @override
  List<(String, String)> get checklistDefaults => [
        ('pencil', 'Карандаши и ручки'),
        ('eraser', 'Ластик'),
        ('ruler', 'Линейка и циркуль'),
        ('watch', 'Наручные часы'),
        ('tissue', 'Салфетки'),
        ('notes', 'Конспект'),
      ];
  @override
  String get sheetTitle => 'Быстрый лист перед экзаменом';
  @override
  String get sheetQuestion => 'Вопрос';
  @override
  String get sheetAnswer => 'Ответ';
  @override
  String get sheetExplanation => 'Объяснение';
  @override
  String get sheetEmpty => 'Сейчас нечего исправлять. Молодец!';
  @override
  String get markCorrect => 'верно';
  @override
  String get markWrong => 'неверно';
  @override
  String get ringsTitle => 'Кольца роста';
  @override
  String ringsSemantics(int totalDays) =>
      'Кольца роста. Всего $totalDays ${plural(totalDays, 'день', 'дня', 'дней')} занятий';
  @override
  String ringsLatestMonth(String month, int days) =>
      'Последний месяц, $month: $days ${plural(days, 'день', 'дня', 'дней')} занятий';
  @override
  String get deviationLabel => 'Индекс баллов в приложении';
  @override
  String deviationRange(String low, String high) => '$low–$high';
  @override
  String get deviationNote =>
      'Грубый индекс только внутри этого приложения: 50 — среднее значение условной группы. Это не рейтинг по стране.';
  @override
  String get teacherPrompt => 'Что здесь не так? Исправь ошибку';
  @override
  String get teacherCorrect => 'Верно! Ты исправил(а) ошибку';
  @override
  String get teacherWrong => 'Почти! Прочитай ещё раз';
  @override
  String get nudgeTestSoon => 'Экзамен приближается. Позанимайся немного сегодня';
  @override
  String get nudgeReview => 'Короткое повторение помогает не забыть';
  @override
  String get nudgeStreak => 'Продолжи серию — позанимайся немного сегодня';
  @override
  String get myWeekGrew => 'На этой неделе есть прогресс!';
  @override
  String get myWeekOvercame => 'Трудное место пройдено!';
  @override
  String get myWeekKept => 'Спокойно и стабильно, так держать';
  @override
  String get myWeekStarted => 'Отличное начало!';
  @override
  String get myWeekRest => 'Спокойная неделя. Начни снова, когда захочешь';
  @override
  String get reasonPrompt => 'Почему не получилось? (можно пропустить)';
  @override
  String get reasonDontKnow => 'Не знаю этого';
  @override
  String get reasonForgot => 'Забылось';
  @override
  String get reasonCareless => 'Невнимательность';
  @override
  String get reasonTimeShort => 'Не хватило времени';
  @override
  String get breakLong => 'Много сделано! Сделай небольшой перерыв и выпей воды';
  @override
  String get breakMistakes => 'Несколько ошибок подряд. Передохни и попробуй ещё раз';
  @override
  String get breakSlowing => 'Начинаешь уставать? Сделай небольшой перерыв';
  @override
  String get breakRushing => 'Ответы слишком быстрые. Вдохни глубже и внимательно читай вопросы';
  @override
  String get peakAhead => "Скоро день с большим количеством заданий. Давай чуть-чуть сделаем заранее";
  @override
  String get talkGrew => 'Попросите ребёнка рассказать, что стало лучше. «Как у тебя получилось?» — хорошее начало';
  @override
  String get talkOvercame => 'Ребёнок преодолел трудность. Хвалите усилия, а не только результат';
  @override
  String get talkSteady => 'Ребёнок занимается регулярно. Хвалите саму регулярность';
  @override
  String get talkStarted => 'Первый шаг сделан, и немного — это достаточно. Скажите: «Ты попробовал»';
  @override
  String get talkRest => 'Эта неделя была отдыхом. Без упрёков; скажите, что начать можно в любой момент';
  @override
  String get outcomeAsk => 'Хочешь записать оценку за тест? Можно пропустить — ничего страшного.';
  @override
  String get outcomeSkip => 'Позже';
  @override
  String get outcomeBaselineAsk => 'Если у тебя есть результат последнего теста до начала занятий, можешь записать его. Если нет — ничего страшного.';
  @override
  String get outcomeFirst => 'Записано. Ты сможешь сравнить его со следующим тестом.';
  @override
  String get outcomeUp => 'Результат выше, чем в прошлый раз. Молодец!';
  @override
  String get outcomeSame => 'Почти так же, как в прошлый раз. Заниматься регулярно — уже здорово.';
  @override
  String get outcomeDown => 'В этот раз результат ниже, чем в прошлый. Ничего страшного. Давай вместе посмотрим, что оказалось трудным.';
  @override
  String get outcomeDisclaimer => 'Это запись результатов, которые введены тобой. Это не обещание, что результат вырастет.';
  @override
  String get eveNotice => 'Контрольная завтра. Новое сейчас не берём; просто повтори то, что уже делал';
  @override
  String get testDayNotice => 'Контрольная сегодня. Лёгкого повторения достаточно. Всё как обычно, спокойно';
  @override
  String get cardAgain => 'Не знаю';
  @override
  String get cardHard => 'Сомневаюсь';
  @override
  String get cardGood => 'Знаю';
  @override
  String get cardFlip => 'Перевернуть';
}

/// イタリア語。複数形は 1 とそれ以外の 2 つ。小数点はカンマ。
/// 数の読み上げは一語に続ける形（`quattrocentottantadue`）。母音が重なるときの省略
/// （`ventuno`・`ventotto`・`centottanta`）と、末尾の 3 のアクセント（`ventitré`）に従う。
class ItStrings extends ChukoreStrings {
  const ItStrings();

  static const _ones = ['', 'uno', 'due', 'tre', 'quattro', 'cinque', 'sei', 'sette', 'otto', 'nove'];
  static const _teens = [
    'dieci', 'undici', 'dodici', 'tredici', 'quattordici', 'quindici', 'sedici', 'diciassette', 'diciotto',
    'diciannove',
  ];
  static const _tens = [
    '', '', 'venti', 'trenta', 'quaranta', 'cinquanta', 'sessanta', 'settanta', 'ottanta', 'novanta',
  ];

  @override
  String get languageCode => 'it';

  @override
  String get decimalSeparator => ',';

  /// 1〜99。10 の位の語末の母音は、1 と 8 の前で落ちる（ventuno・ventotto）。
  String _below100(int r) {
    if (r < 10) return _ones[r];
    if (r < 20) return _teens[r - 10];
    final t = _tens[r ~/ 10], u = r % 10;
    if (u == 0) return t;
    final stem = (u == 1 || u == 8) ? t.substring(0, t.length - 1) : t;
    return '$stem${_ones[u]}';
  }

  @override
  String gateNumberWords(int n) {
    if (n < 1 || n > 9999) throw RangeError.range(n, 1, 9999, 'n');
    final th = n ~/ 1000, rest = n % 1000, h = rest ~/ 100, r = rest % 100;
    var s = '';
    if (th > 0) s += th == 1 ? 'mille' : '${_ones[th]}mila';
    if (h > 0) {
      var hw = h == 1 ? 'cento' : '${_ones[h]}cento';
      // cento は otto・ottanta の前で語末の o が落ちる（centotto・centottanta）
      if ((r >= 80 && r < 90) || r == 8) hw = hw.substring(0, hw.length - 1);
      s += hw;
    }
    s += _below100(r);
    // 複合語の末尾の 3 はアクセントが付く（ventitré・centotré）。13 の tredici は対象外
    if (n > 3 && n % 10 == 3 && !(r >= 10 && r < 20)) s = '${s.substring(0, s.length - 2)}ré';
    return s;
  }

  static String _c(int n, String one, String many) => n == 1 ? one : many;

  @override
  String cardTitle(String subject) => '$subject · Scheda dei progressi';
  @override
  String get headlinePersonalBest => 'Nuovo record personale!';
  @override
  String get headlineFirst => 'Un ottimo inizio';
  @override
  String headlineUp(String points) => "+$points rispetto all'ultima volta";
  @override
  String get headlineSame => "Stabile, come l'ultima volta";
  @override
  String get headlineDown => 'Ripartiamo da qui';
  @override
  String nextLevel(String points) =>
      points == '1' ? 'Manca 1 punto al livello successivo' : 'Mancano $points punti al livello successivo';
  @override
  String get topLevel => 'Livello massimo raggiunto!';
  @override
  String streakDays(int days) => days == 1 ? '1 giorno di fila' : '$days giorni di fila';
  @override
  String get statStamps => 'Superati';
  @override
  String get statSolvable => 'Ora so risolvere';
  @override
  String solvableValue(int count) => _c(count, '1 domanda', '$count domande');
  @override
  String cardSemantics(String headline, String level) => 'Scheda dei progressi. $headline. Livello $level';
  @override
  String get mapSemantics => 'Mappa. Tocca per scegliere la risposta';
  @override
  String formatYear(int year) => year < 0 ? '${-year} a.C.' : '$year d.C.';
  @override
  String reportHeader(int activeDays, int attempts) =>
      'Questa settimana: ${_c(activeDays, '1 giorno', '$activeDays giorni')} / '
      '${_c(attempts, '1 domanda', '$attempts domande')}';
  @override
  String get reportImprovedTitle => 'Cosa è migliorato questa settimana:';
  @override
  String reportItem(String title, int b, int a) => '- $title ($b% -> $a%)';
  @override
  String get reportEmpty => 'Nessun nuovo miglioramento questa settimana. Vai pure al tuo ritmo.';
  @override
  String get scopeQrTitle => 'Condividi gli argomenti della verifica';
  @override
  String get scopeQrHint =>
      'Amici o familiari possono scansionarlo per impostare gli stessi argomenti. Non contiene nomi né risultati.';
  @override
  String get scopeQrSemantics => 'Codice QR degli argomenti della verifica';
  @override
  String get checklistTitle => 'Controllo per il giorno della verifica';
  @override
  String checklistProgress(int done, int total) => '$done su $total pronti';
  @override
  String get checklistAllDone => 'Tutto pronto. In bocca al lupo!';
  @override
  String get fiveMinuteTitle => 'Scheda degli ultimi 5 minuti';
  @override
  List<(String, String)> get checklistDefaults => [
        ('pencil', 'Penne e matite'),
        ('eraser', 'Gomma'),
        ('ruler', 'Righello e compasso'),
        ('watch', 'Orologio'),
        ('tissue', 'Fazzoletti'),
        ('notes', 'Appunti di ripasso'),
      ];
  @override
  String get sheetTitle => 'Foglio di ripasso finale';
  @override
  String get sheetQuestion => 'Domanda';
  @override
  String get sheetAnswer => 'Risposta';
  @override
  String get sheetExplanation => 'Spiegazione';
  @override
  String get sheetEmpty => "Non c'è niente da correggere adesso. Ottimo lavoro!";
  @override
  String get markCorrect => 'corretto';
  @override
  String get markWrong => 'sbagliato';
  @override
  String get ringsTitle => 'Anelli di crescita';
  @override
  String ringsSemantics(int totalDays) =>
      'Anelli di crescita. ${_c(totalDays, '1 giorno', '$totalDays giorni')} di studio in totale';
  @override
  String ringsLatestMonth(String month, int days) =>
      'Ultimo mese, $month: ${_c(days, '1 giorno', '$days giorni')} di studio';
  @override
  String get deviationLabel => "Indice di punteggio dell'app";
  @override
  String deviationRange(String low, String high) => '$low–$high';
  @override
  String get deviationNote =>
      "Un indice approssimativo, valido solo all'interno dell'app, in cui 50 è la media di un gruppo di riferimento. Non è una classifica nazionale.";
  @override
  String get teacherPrompt => "Cosa c'è che non va qui? Correggi l'errore";
  @override
  String get teacherCorrect => "Esatto! L'hai corretto";
  @override
  String get teacherWrong => 'Quasi! Rileggilo ancora una volta';
  @override
  String get nudgeTestSoon => 'La verifica si avvicina. Esercitati un pochino oggi';
  @override
  String get nudgeReview => 'Un ripasso veloce aiuta a non dimenticare';
  @override
  String get nudgeStreak => "Mantieni la tua serie con un po' di esercizio oggi";
  @override
  String get myWeekGrew => 'Questa settimana hai fatto progressi!';
  @override
  String get myWeekOvercame => 'Hai superato un punto difficile!';
  @override
  String get myWeekKept => 'Costante e regolare, continua così';
  @override
  String get myWeekStarted => 'Un ottimo primo passo!';
  @override
  String get myWeekRest => 'Una settimana tranquilla. Riparti quando vuoi';
  @override
  String get reasonPrompt => 'Perché è andata male? (puoi saltare)';
  @override
  String get reasonDontKnow => 'Non lo sapevo';
  @override
  String get reasonForgot => "L'avevo dimenticato";
  @override
  String get reasonCareless => 'Una distrazione';
  @override
  String get reasonTimeShort => 'Mi è mancato il tempo';
  @override
  String get breakLong => "Hai studiato tanto. Fai una breve pausa e bevi un po' d'acqua";
  @override
  String get breakMistakes => 'Qualche errore di fila. Fai una breve pausa, poi riprova';
  @override
  String get breakSlowing => 'Ti stai stancando? Fai una breve pausa';
  @override
  String get breakRushing => 'Stai rispondendo molto in fretta. Respira e leggi bene ogni domanda';
  @override
  String get peakAhead => "Si avvicina un giorno con più domande. Portiamoci un po’ avanti";
  @override
  String get talkGrew => 'Chieda a suo figlio di spiegarle cosa è migliorato. «Come hai fatto?» è un buon inizio';
  @override
  String get talkOvercame => 'Suo figlio ha superato una difficoltà. Lodi l’impegno più del risultato';
  @override
  String get talkSteady => 'Suo figlio procede con costanza. Lodi la costanza in sé';
  @override
  String get talkStarted => 'Il primo passo è fatto, e basta anche poco. Provi a dire «Ci hai provato»';
  @override
  String get talkRest => 'Questa è stata una settimana di pausa. Senza rimproveri; gli dica che può ricominciare quando vuole';
  @override
  String get outcomeAsk => 'Vuoi registrare il punteggio del tuo compito? Puoi anche saltare, non c’è problema.';
  @override
  String get outcomeSkip => 'Più tardi';
  @override
  String get outcomeBaselineAsk => 'Se hai il punteggio dell’ultimo compito prima di iniziare, puoi inserirlo. Se non ce l’hai, non c’è problema.';
  @override
  String get outcomeFirst => 'Registrato. Potrai vederlo accanto al tuo prossimo compito.';
  @override
  String get outcomeUp => 'Il punteggio è più alto dell’ultima volta. Bravo!';
  @override
  String get outcomeSame => 'Quasi uguale all’ultima volta. Continuare con costanza è già una gran cosa.';
  @override
  String get outcomeDown => 'Stavolta è stato più basso dell’ultima volta. Non c’è problema. Guardiamo insieme cosa è sembrato difficile.';
  @override
  String get outcomeDisclaimer => 'Questo è un registro dei punteggi che hai inserito tu. Non è una promessa che il punteggio salga.';
  @override
  String get eveNotice => 'Il compito è domani. Niente di nuovo ora; ripassa solo ciò che hai già fatto';
  @override
  String get testDayNotice => 'Il compito è oggi. Basta un ripasso leggero. Come sempre, con calma';
  @override
  String get cardAgain => 'Non so';
  @override
  String get cardHard => 'Incerto';
  @override
  String get cardGood => 'So';
  @override
  String get cardFlip => 'Gira';
}

/// オランダ語。複数形は 1 とそれ以外の 2 つ。小数点はカンマ（ベルギーのオランダ語も同じ）。
/// 数の読み上げは一語に続ける形で、一の位を十の位の前に `en` でつなぐ
/// （`eenentwintig`・`tweeëntwintig`。語末が e の `twee`・`drie` は `ën` になる）。
class NlStrings extends ChukoreStrings {
  const NlStrings();

  static const _ones = ['', 'een', 'twee', 'drie', 'vier', 'vijf', 'zes', 'zeven', 'acht', 'negen'];
  static const _teens = [
    'tien', 'elf', 'twaalf', 'dertien', 'veertien', 'vijftien', 'zestien', 'zeventien', 'achttien', 'negentien',
  ];
  static const _tens = [
    '', '', 'twintig', 'dertig', 'veertig', 'vijftig', 'zestig', 'zeventig', 'tachtig', 'negentig',
  ];

  @override
  String get languageCode => 'nl';

  @override
  String get decimalSeparator => ',';

  String _below100(int r) {
    if (r < 10) return _ones[r];
    if (r < 20) return _teens[r - 10];
    final t = _tens[r ~/ 10], u = r % 10;
    if (u == 0) return t;
    final unit = _ones[u];
    return '$unit${unit.endsWith('e') ? 'ën' : 'en'}$t';
  }

  @override
  String gateNumberWords(int n) {
    if (n < 1 || n > 9999) throw RangeError.range(n, 1, 9999, 'n');
    final th = n ~/ 1000, rest = n % 1000, h = rest ~/ 100, r = rest % 100;
    return [
      if (th == 1) 'duizend' else if (th > 1) '${_ones[th]}duizend',
      if (h == 1) 'honderd' else if (h > 1) '${_ones[h]}honderd',
      if (r > 0) _below100(r),
    ].join();
  }

  static String _c(int n, String one, String many) => n == 1 ? one : many;

  @override
  String cardTitle(String subject) => '$subject · Voortgangskaart';
  @override
  String get headlinePersonalBest => 'Nieuw persoonlijk record!';
  @override
  String get headlineFirst => 'Een mooie start';
  @override
  String headlineUp(String points) => '+$points ten opzichte van vorige keer';
  @override
  String get headlineSame => 'Stabiel, net als vorige keer';
  @override
  String get headlineDown => 'Laten we vanaf hier weer groeien';
  @override
  String nextLevel(String points) =>
      points == '1' ? 'Nog 1 punt tot het volgende niveau' : 'Nog $points punten tot het volgende niveau';
  @override
  String get topLevel => 'Hoogste niveau bereikt!';
  @override
  String streakDays(int days) => days == 1 ? '1 dag op rij' : '$days dagen op rij';
  @override
  String get statStamps => 'Overwonnen';
  @override
  String get statSolvable => 'Nu kan ik oplossen';
  @override
  String solvableValue(int count) => _c(count, '1 vraag', '$count vragen');
  @override
  String cardSemantics(String headline, String level) => 'Voortgangskaart. $headline. Niveau $level';
  @override
  String get mapSemantics => 'Kaart. Tik om je antwoord te kiezen';
  @override
  String formatYear(int year) => year < 0 ? '${-year} v.Chr.' : '$year n.Chr.';
  @override
  String reportHeader(int activeDays, int attempts) =>
      'Deze week: ${_c(activeDays, '1 dag', '$activeDays dagen')} / ${_c(attempts, '1 vraag', '$attempts vragen')}';
  @override
  String get reportImprovedTitle => 'Dit is deze week verbeterd:';
  @override
  String reportItem(String title, int b, int a) => '- $title ($b% -> $a%)';
  @override
  String get reportEmpty => 'Deze week zijn er nog geen nieuwe verbeteringen. Ga gewoon in je eigen tempo verder.';
  @override
  String get scopeQrTitle => 'Deel de leerstof van de toets';
  @override
  String get scopeQrHint =>
      'Vrienden of familie kunnen dit scannen om dezelfde leerstof in te stellen. Er staan geen namen of resultaten in.';
  @override
  String get scopeQrSemantics => 'QR-code van de leerstof van de toets';
  @override
  String get checklistTitle => 'Controlelijst voor de toetsdag';
  @override
  String checklistProgress(int done, int total) => '$done van $total klaar';
  @override
  String get checklistAllDone => 'Alles klaar. Succes!';
  @override
  String get fiveMinuteTitle => 'Kaart voor de laatste 5 minuten';
  @override
  List<(String, String)> get checklistDefaults => [
        ('pencil', 'Pennen en potloden'),
        ('eraser', 'Gum'),
        ('ruler', 'Liniaal en passer'),
        ('watch', 'Horloge'),
        ('tissue', 'Zakdoekjes'),
        ('notes', 'Samenvatting'),
      ];
  @override
  String get sheetTitle => 'Laatste herhalingsblad';
  @override
  String get sheetQuestion => 'Vraag';
  @override
  String get sheetAnswer => 'Antwoord';
  @override
  String get sheetExplanation => 'Uitleg';
  @override
  String get sheetEmpty => 'Er valt nu niets te verbeteren. Goed gedaan!';
  @override
  String get markCorrect => 'juist';
  @override
  String get markWrong => 'onjuist';
  @override
  String get ringsTitle => 'Groeiringen';
  @override
  String ringsSemantics(int totalDays) =>
      'Groeiringen. In totaal ${_c(totalDays, '1 dag', '$totalDays dagen')} studie';
  @override
  String ringsLatestMonth(String month, int days) =>
      'Laatste maand, $month: ${_c(days, '1 dag', '$days dagen')} studie';
  @override
  String get deviationLabel => 'Scoreindex van de app';
  @override
  String deviationRange(String low, String high) => '$low–$high';
  @override
  String get deviationNote =>
      'Een grove index die alleen binnen deze app geldt, waarbij 50 het gemiddelde van een referentiegroep is. Het is geen landelijke ranglijst.';
  @override
  String get teacherPrompt => 'Wat klopt hier niet? Verbeter de fout';
  @override
  String get teacherCorrect => 'Juist! Je hebt het verbeterd';
  @override
  String get teacherWrong => 'Bijna! Lees het nog een keer';
  @override
  String get nudgeTestSoon => 'De toets komt dichterbij. Oefen vandaag een klein beetje';
  @override
  String get nudgeReview => 'Een korte herhaling helpt om niets te vergeten';
  @override
  String get nudgeStreak => 'Houd je reeks vol met een beetje oefening vandaag';
  @override
  String get myWeekGrew => 'Je hebt deze week vooruitgang geboekt!';
  @override
  String get myWeekOvercame => 'Je hebt een lastig punt overwonnen!';
  @override
  String get myWeekKept => 'Mooi regelmatig, ga zo door';
  @override
  String get myWeekStarted => 'Een mooie eerste stap!';
  @override
  String get myWeekRest => 'Een rustige week. Begin weer wanneer je wilt';
  @override
  String get reasonPrompt => 'Waarom ging het mis? (overslaan mag)';
  @override
  String get reasonDontKnow => 'Wist ik niet';
  @override
  String get reasonForgot => 'Vergeten';
  @override
  String get reasonCareless => 'Slordigheidje';
  @override
  String get reasonTimeShort => 'Te weinig tijd';
  @override
  String get breakLong => 'Je hebt hard gewerkt. Neem even pauze en drink wat water';
  @override
  String get breakMistakes => 'Een paar fouten achter elkaar. Neem even pauze en probeer het opnieuw';
  @override
  String get breakSlowing => 'Word je moe? Neem even pauze';
  @override
  String get breakRushing => 'Je antwoordt heel snel. Adem diep in en lees elke vraag goed';
  @override
  String get peakAhead => "Er komt een dag met meer vragen aan. Laten we alvast een beetje voorwerk doen";
  @override
  String get talkGrew => 'Vraag je kind uit te leggen wat beter ging. „Hoe heb je dat gedaan?” is een mooi begin';
  @override
  String get talkOvercame => 'Je kind heeft een struikelblok overwonnen. Prijs de inzet meer dan het resultaat';
  @override
  String get talkSteady => 'Je kind blijft er trouw mee bezig. Prijs die volharding zelf';
  @override
  String get talkStarted => 'De eerste stap is gezet, en een beetje is genoeg. Zeg bijvoorbeeld: „Je hebt het geprobeerd”';
  @override
  String get talkRest => 'Dit was een rustweek. Zonder verwijt; laat weten dat je op elk moment kunt beginnen';
  @override
  String get outcomeAsk => 'Wil je je toetscijfer noteren? Overslaan mag ook, geen probleem.';
  @override
  String get outcomeSkip => 'Later';
  @override
  String get outcomeBaselineAsk => 'Heb je het cijfer van je laatste toets van vóór je begon? Dan kun je het invullen. Zo niet, dan is dat prima.';
  @override
  String get outcomeFirst => 'Opgeslagen. Je kunt het naast je volgende toets bekijken.';
  @override
  String get outcomeUp => 'Je cijfer is hoger dan de vorige keer. Goed gedaan!';
  @override
  String get outcomeSame => 'Ongeveer hetzelfde als de vorige keer. Volhouden is al sterk.';
  @override
  String get outcomeDown => 'Deze keer was het lager dan de vorige keer. Dat is prima. Laten we samen kijken wat lastig was.';
  @override
  String get outcomeDisclaimer => 'Dit is een overzicht van de cijfers die je zelf hebt ingevuld. Het is geen belofte dat je cijfer omhoog gaat.';
  @override
  String get eveNotice => 'De toets is morgen. Nu niets nieuws meer; kijk alleen terug op wat je al gedaan hebt';
  @override
  String get testDayNotice => 'De toets is vandaag. Even licht terugkijken is genoeg. Gewoon zoals altijd';
  @override
  String get cardAgain => 'Weet ik niet';
  @override
  String get cardHard => 'Twijfel';
  @override
  String get cardGood => 'Weet ik';
  @override
  String get cardFlip => 'Omdraaien';
}

/// ポーランド語。複数形は 3 つ（1・2〜4・それ以外。12〜14 は「それ以外」）。ロシア語と違い、21・101 などは
/// 1 の形にならない。小数点はカンマ。数の読み上げは男性形（千は 2〜4 が `tysiące`・5 以上が `tysięcy`）。
class PlStrings extends ChukoreStrings {
  const PlStrings();

  static const _ones = ['', 'jeden', 'dwa', 'trzy', 'cztery', 'pięć', 'sześć', 'siedem', 'osiem', 'dziewięć'];
  static const _teens = [
    'dziesięć', 'jedenaście', 'dwanaście', 'trzynaście', 'czternaście', 'piętnaście', 'szesnaście', 'siedemnaście',
    'osiemnaście', 'dziewiętnaście',
  ];
  static const _tens = [
    '', '', 'dwadzieścia', 'trzydzieści', 'czterdzieści', 'pięćdziesiąt', 'sześćdziesiąt', 'siedemdziesiąt',
    'osiemdziesiąt', 'dziewięćdziesiąt',
  ];
  static const _hundreds = [
    '', 'sto', 'dwieście', 'trzysta', 'czterysta', 'pięćset', 'sześćset', 'siedemset', 'osiemset', 'dziewięćset',
  ];

  @override
  String get languageCode => 'pl';

  @override
  String get decimalSeparator => ',';

  /// 数に合う名詞の形（1 / 2〜4 / それ以外）。1 だけが単数形で、21・101 は複数形。
  static String plural(int n, String one, String few, String many) {
    if (n == 1) return one;
    final m100 = n % 100, m10 = n % 10;
    if (m10 >= 2 && m10 <= 4 && !(m100 >= 12 && m100 <= 14)) return few;
    return many;
  }

  @override
  String gateNumberWords(int n) {
    if (n < 1 || n > 9999) throw RangeError.range(n, 1, 9999, 'n');
    final th = n ~/ 1000, rest = n % 1000, h = rest ~/ 100, r = rest % 100;
    return [
      if (th == 1)
        'tysiąc'
      else if (th > 1)
        '${_ones[th]} ${th <= 4 ? 'tysiące' : 'tysięcy'}',
      if (h > 0) _hundreds[h],
      if (r >= 10 && r < 20)
        _teens[r - 10]
      else ...[
        if (r >= 20) _tens[r ~/ 10],
        if (r % 10 > 0) _ones[r % 10],
      ],
    ].join(' ');
  }

  static String _days(int n) => n == 1 ? '1 dzień' : '$n dni';
  static String _questions(int n) => '$n ${plural(n, 'pytanie', 'pytania', 'pytań')}';

  @override
  String cardTitle(String subject) => '$subject · Karta postępów';
  @override
  String get headlinePersonalBest => 'Nowy rekord życiowy!';
  @override
  String get headlineFirst => 'Dobry początek';
  @override
  String headlineUp(String points) => '+$points względem poprzedniego razu';
  @override
  String get headlineSame => 'Stabilnie, tak jak ostatnio';
  @override
  String get headlineDown => 'Zacznijmy znowu piąć się w górę';
  @override
  String nextLevel(String points) =>
      points == '1' ? 'Do następnego poziomu brakuje 1 punktu' : 'Do następnego poziomu brakuje $points punktów';
  @override
  String get topLevel => 'Osiągnięto najwyższy poziom!';
  @override
  String streakDays(int days) => '${_days(days)} z rzędu';
  @override
  String get statStamps => 'Pokonane';
  @override
  String get statSolvable => 'Teraz potrafię rozwiązać';
  @override
  String solvableValue(int count) => _questions(count);
  @override
  String cardSemantics(String headline, String level) => 'Karta postępów. $headline. Poziom $level';
  @override
  String get mapSemantics => 'Mapa. Dotknij, aby wybrać odpowiedź';
  @override
  String formatYear(int year) => year < 0 ? '${-year} r. p.n.e.' : '$year r.';
  @override
  String reportHeader(int activeDays, int attempts) =>
      'W tym tygodniu: ${_days(activeDays)} / ${_questions(attempts)}';
  @override
  String get reportImprovedTitle => 'Co poprawiło się w tym tygodniu:';
  @override
  String reportItem(String title, int b, int a) => '- $title ($b% -> $a%)';
  @override
  String get reportEmpty => 'W tym tygodniu nie ma jeszcze nowych postępów. Ucz się we własnym tempie.';
  @override
  String get scopeQrTitle => 'Udostępnij zakres sprawdzianu';
  @override
  String get scopeQrHint =>
      'Znajomi lub rodzina mogą go zeskanować, aby ustawić ten sam zakres. Nie zawiera imion ani wyników.';
  @override
  String get scopeQrSemantics => 'Kod QR zakresu sprawdzianu';
  @override
  String get checklistTitle => 'Lista na dzień sprawdzianu';
  @override
  String checklistProgress(int done, int total) => 'Gotowe: $done z $total';
  @override
  String get checklistAllDone => 'Wszystko gotowe. Powodzenia!';
  @override
  String get fiveMinuteTitle => 'Karta na ostatnie 5 minut';
  @override
  List<(String, String)> get checklistDefaults => [
        ('pencil', 'Długopisy i ołówki'),
        ('eraser', 'Gumka'),
        ('ruler', 'Linijka i cyrkiel'),
        ('watch', 'Zegarek'),
        ('tissue', 'Chusteczki'),
        ('notes', 'Notatki do powtórki'),
      ];
  @override
  String get sheetTitle => 'Arkusz powtórki przed sprawdzianem';
  @override
  String get sheetQuestion => 'Pytanie';
  @override
  String get sheetAnswer => 'Odpowiedź';
  @override
  String get sheetExplanation => 'Wyjaśnienie';
  @override
  String get sheetEmpty => 'Teraz nie ma nic do poprawienia. Dobra robota!';
  @override
  String get markCorrect => 'poprawnie';
  @override
  String get markWrong => 'błędnie';
  @override
  String get ringsTitle => 'Słoje wzrostu';
  @override
  String ringsSemantics(int totalDays) => 'Słoje wzrostu. Łącznie ${_days(totalDays)} nauki';
  @override
  String ringsLatestMonth(String month, int days) => 'Ostatni miesiąc, $month: ${_days(days)} nauki';
  @override
  String get deviationLabel => 'Wskaźnik punktowy aplikacji';
  @override
  String deviationRange(String low, String high) => '$low–$high';
  @override
  String get deviationNote =>
      'Przybliżony wskaźnik obowiązujący tylko w tej aplikacji, w którym 50 to średnia grupy odniesienia. To nie jest ranking ogólnokrajowy.';
  @override
  String get teacherPrompt => 'Co tu jest nie tak? Popraw błąd';
  @override
  String get teacherCorrect => 'Dobrze! Udało Ci się poprawić';
  @override
  String get teacherWrong => 'Prawie! Przeczytaj jeszcze raz';
  @override
  String get nudgeTestSoon => 'Sprawdzian się zbliża. Poćwicz dziś chociaż trochę';
  @override
  String get nudgeReview => 'Krótka powtórka pomaga niczego nie zapomnieć';
  @override
  String get nudgeStreak => 'Podtrzymaj swoją serię, ćwicząc dziś trochę';
  @override
  String get myWeekGrew => 'W tym tygodniu są postępy!';
  @override
  String get myWeekOvercame => 'Trudne miejsce pokonane!';
  @override
  String get myWeekKept => 'Równo i spokojnie, tak trzymaj';
  @override
  String get myWeekStarted => 'Świetny pierwszy krok!';
  @override
  String get myWeekRest => 'Spokojny tydzień. Zacznij znowu, kiedy zechcesz';
  @override
  String get reasonPrompt => 'Dlaczego się nie udało? (możesz pominąć)';
  @override
  String get reasonDontKnow => 'Tego nie umiem';
  @override
  String get reasonForgot => 'Wyleciało mi z głowy';
  @override
  String get reasonCareless => 'Nieuwaga';
  @override
  String get reasonTimeShort => 'Zabrakło czasu';
  @override
  String get breakLong => 'Dużo już zrobione. Zrób krótką przerwę i napij się wody';
  @override
  String get breakMistakes => 'Kilka błędów z rzędu. Zrób krótką przerwę i spróbuj jeszcze raz';
  @override
  String get breakSlowing => 'Czujesz zmęczenie? Zrób krótką przerwę';
  @override
  String get breakRushing => 'Odpowiadasz bardzo szybko. Weź oddech i uważnie czytaj pytania';
  @override
  String get peakAhead => "Zbliża się dzień z większą liczbą zadań. Zrób trochę wcześniej";
  @override
  String get talkGrew => 'Poproś dziecko, by opowiedziało, co poszło lepiej. „Jak ci się to udało?” to dobry początek';
  @override
  String get talkOvercame => 'Dziecko pokonało trudność. Pochwal wysiłek, a nie tylko wynik';
  @override
  String get talkSteady => 'Dziecko uczy się systematycznie. Pochwal samą systematyczność';
  @override
  String get talkStarted => 'Pierwszy krok został zrobiony, a niewiele wystarczy. Powiedz: „Spróbowałeś”';
  @override
  String get talkRest => 'To był tydzień przerwy. Bez wyrzutów; powiedz, że można zacząć w każdej chwili';
  @override
  String get outcomeAsk => 'Chcesz zapisać swój wynik ze sprawdzianu? Możesz pominąć, nic się nie stanie.';
  @override
  String get outcomeSkip => 'Później';
  @override
  String get outcomeBaselineAsk => 'Jeśli masz wynik ostatniego sprawdzianu sprzed rozpoczęcia, możesz go wpisać. Jeśli nie, nic się nie stanie.';
  @override
  String get outcomeFirst => 'Zapisano. Zobaczysz go obok kolejnego sprawdzianu.';
  @override
  String get outcomeUp => 'Wynik jest wyższy niż poprzednio. Brawo!';
  @override
  String get outcomeSame => 'Prawie tak samo jak poprzednio. Systematyczność to już duży sukces.';
  @override
  String get outcomeDown => 'Tym razem wynik jest niższy niż poprzednio. Nic się nie stało. Zobaczmy razem, co sprawiło trudność.';
  @override
  String get outcomeDisclaimer => 'To zapis wyników wpisanych przez Ciebie. Nie jest obietnicą, że wynik wzrośnie.';
  @override
  String get eveNotice => 'Sprawdzian jest jutro. Nic nowego teraz; wystarczy przejrzeć to, co już zrobiłeś';
  @override
  String get testDayNotice => 'Sprawdzian jest dziś. Lekkie przejrzenie wystarczy. Spokojnie, jak zawsze';
  @override
  String get cardAgain => 'Nie wiem';
  @override
  String get cardHard => 'Niepewnie';
  @override
  String get cardGood => 'Wiem';
  @override
  String get cardFlip => 'Odwróć';
}
