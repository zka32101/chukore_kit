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
}
