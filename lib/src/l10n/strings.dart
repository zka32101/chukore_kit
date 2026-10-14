/// ユーザーに見せる文言と、国ごとに違う表記の集まり。
/// 対応言語を増やすときは [ChukoreStrings] を実装して [ChukoreStrings.forLocale] に足す。
abstract class ChukoreStrings {
  const ChukoreStrings();

  /// 言語コード（`en`、`pt-BR`、`pt_PT` など）に合う文言。未対応の言語は英語。
  /// ポルトガル語は地域で綴りが違うので、`PT`（ポルトガル）のときだけ欧州式にする。
  /// スペイン語は地域で小数点が違う（メキシコなどは `.`、スペインなど多くは `,`）。
  factory ChukoreStrings.forLocale(String locale) {
    final parts = locale.toLowerCase().split(RegExp('[-_]'));
    return switch (parts.first) {
      'ja' => const JaStrings(),
      'pt' => parts.length > 1 && parts[1] == 'pt' ? const PtStrings(european: true) : const PtStrings(),
      'es' => EsStrings(decimalComma: !(parts.length > 1 && EsStrings.decimalPointRegions.contains(parts[1]))),
      _ => const EnStrings(),
    };
  }

  String get languageCode;

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
}
