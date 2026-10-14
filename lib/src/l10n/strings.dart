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
    ZhStrings(),
    ZhStrings(traditional: true),
  ];

  /// 小数点の記号。数値入力の `checkAnswer(..., decimalSeparator:)` にもこの値を渡す。
  String get decimalSeparator => '.';

  /// 点数などの小数の表記（小数点は国で違う）。整数は小数点なし。
  String formatNumber(double v) => v == v.roundToDouble()
      ? v.round().toString()
      : v.toStringAsFixed(1).replaceAll('.', decimalSeparator);

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

  // --- 成長の年輪・目安偏差値 ---
  String get ringsTitle;
  String ringsSemantics(int totalDays);
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
  String get deviationLabel => '目安偏差値';
  @override
  String deviationRange(String low, String high) => '$low〜$high';
  @override
  String get deviationNote => '想定した集団の平均を50とした目安です。全国の偏差値ではありません。';
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
  String get deviationLabel => 'Estimated score index';
  @override
  String deviationRange(String low, String high) => '$low–$high';
  @override
  String get deviationNote =>
      'A rough index where 50 is the average of an assumed group. It is not a nationwide ranking.';
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
  String get deviationLabel => 'Índice de pontuação (estimado)';
  @override
  String deviationRange(String low, String high) => '$low–$high';
  @override
  String get deviationNote =>
      'Um índice aproximado em que 50 é a média de um grupo de referência. Não é uma classificação nacional.';
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
  String get deviationLabel => 'Índice de puntuación (estimado)';
  @override
  String deviationRange(String low, String high) => '$low–$high';
  @override
  String get deviationNote =>
      'Un índice aproximado en el que 50 es el promedio de un grupo de referencia. No es una clasificación nacional.';
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
  String get deviationLabel => 'Indice de score (estimé)';
  @override
  String deviationRange(String low, String high) => '$low–$high';
  @override
  String get deviationNote =>
      'Un indice approximatif où 50 correspond à la moyenne d’un groupe de référence. Ce n’est pas un classement national.';
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
  String get deviationLabel => '예상 점수 지수';
  @override
  String deviationRange(String low, String high) => '$low~$high';
  @override
  String get deviationNote => '가정한 집단의 평균을 50으로 둔 대략적인 지수예요. 전국 순위가 아니에요.';
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
  String get deviationLabel => _t('预估分数指数', '預估分數指數');
  @override
  String deviationRange(String low, String high) => '$low~$high';
  @override
  String get deviationNote => _t('以假定群体的平均值为50的大致指数，并非全国排名。', '以假定群體的平均值為50的大致指數，並非全國排名。');
}
