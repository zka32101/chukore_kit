/// ユーザーに見せる文言と、国ごとに違う表記の集まり。
/// 対応言語を増やすときは [ChukoreStrings] を実装して [ChukoreStrings.forLocale] に足す。
abstract class ChukoreStrings {
  const ChukoreStrings();

  /// 言語コードに合う文言。未対応の言語は英語。
  factory ChukoreStrings.forLocale(String languageCode) =>
      switch (languageCode.toLowerCase().split(RegExp('[-_]')).first) {
        'ja' => const JaStrings(),
        _ => const EnStrings(),
      };

  String get languageCode;

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
  String nextLevel(String points) => '$points more points to the next level';
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
}
