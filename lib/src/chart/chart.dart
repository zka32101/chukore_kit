import 'dart:convert';
import 'dart:math' as math;

/// 資料のグラフ（棒・折れ線・雨温図・人口ピラミッド・円）の仕様と SVG。教科によらない（社会の資料・理科のデータ）。
/// 値はそのまま持つ。文言（題・説明）は ID だけ（`altId`）、目盛りの数値と軸は値から作る。
/// 色は `currentColor` だけ（系列は濃さと線の種類で分ける）。画面は SVG を表示するか、系列の値から自分で描く。
enum ChartKind { bars, line, climate, pyramid, pie }

/// 系列 1 つ。[values] は [ChartSpec.categories] と同じ長さ。
class ChartSeries {
  const ChartSeries(this.id, this.values);

  /// 系列の ID（英数字と `_`）。凡例などの文言はコンテンツ側がこの ID で引く。
  final String id;
  final List<double> values;
}

/// 目盛り（きりのよい刻み）。
class NiceScale {
  const NiceScale(this.min, this.max, this.step);

  final double min, max, step;

  /// 目盛りの値の一覧（[min] から [max] まで）。
  List<double> get ticks {
    final n = ((max - min) / step + 1e-9).floor();
    return [for (var i = 0; i <= n; i++) _round(min + i * step)];
  }

  static double _round(double v) => (v * 1e9).roundToDouble() / 1e9;
}

/// [lo]〜[hi] を含む、1・2・5 × 10^k の刻みの目盛り（[target] 本前後）。[lo] == [hi] なら 0 を含む幅にする。
NiceScale niceScale(double lo, double hi, {int target = 5}) {
  if (lo > hi) throw ArgumentError('lo は hi 以下');
  if (target < 1) throw ArgumentError('target は 1 以上');
  if (lo == hi) {
    // 1 つの値だけ: 0 を含む幅にする（0 だけなら 0〜1）
    if (lo == 0) {
      hi = 1;
    } else {
      lo = math.min(0, lo);
      hi = math.max(0, hi);
    }
  }
  final range = hi - lo;
  final raw = range / target;
  final mag = math.pow(10, (math.log(raw) / math.ln10).floorToDouble()).toDouble();
  final norm = raw / mag;
  final step = (norm <= 1.0 + 1e-9 ? 1 : (norm <= 2.0 + 1e-9 ? 2 : (norm <= 5.0 + 1e-9 ? 5 : 10))) * mag;
  final min = (lo / step + 1e-9).floor() * step;
  final max = (hi / step - 1e-9).ceil() * step;
  return NiceScale(NiceScale._round(min), NiceScale._round(max), NiceScale._round(step));
}

/// グラフ 1 つ。
class ChartSpec {
  const ChartSpec._({
    required this.kind,
    required this.altId,
    required this.categories,
    required this.series,
  });

  final ChartKind kind;

  /// 図の説明文の ID（文言はコンテンツ側）。
  final String altId;

  /// 横軸（円は項目、ピラミッドは年齢層、雨温図は月）の表示。そのまま描く。
  final List<String> categories;
  final List<ChartSeries> series;

  static const _keys = {'kind', 'altId', 'categories', 'series'};

  /// 読めなければ [FormatException]。
  /// `{"kind":"climate","altId":"a","categories":["1","2"],"series":[{"id":"temp","values":[5,7]},{"id":"rain","values":[50,70]}]}`
  /// 雨温図は 2 系列（1 つ目が気温＝折れ線、2 つ目が降水量＝棒）、人口ピラミッドは 2 系列（左・右）、円は 1 系列。
  factory ChartSpec.fromJson(Map<String, dynamic> j) {
    final unknown = j.keys.where((k) => !_keys.contains(k));
    if (unknown.isNotEmpty) throw FormatException('未知のキー: ${unknown.join(', ')}');
    final kindName = j['kind'];
    final kind = ChartKind.values.where((k) => k.name == kindName).firstOrNull;
    if (kind == null) throw FormatException('未対応の kind: $kindName');
    final altId = j['altId'];
    if (altId is! String || altId.isEmpty) throw const FormatException('altId は空でない文字列');
    final rc = j['categories'];
    if (rc is! List || rc.isEmpty || rc.length > 60 || rc.any((e) => e is! String || e.isEmpty)) {
      throw const FormatException('categories は 1〜60 個の文字列');
    }
    final categories = [for (final c in rc) c as String];
    final rs = j['series'];
    if (rs is! List || rs.isEmpty || rs.length > 6) throw const FormatException('series は 1〜6 個');
    final series = <ChartSeries>[];
    for (final s in rs) {
      if (s is! Map || s.keys.any((k) => k != 'id' && k != 'values')) throw const FormatException('系列は id と values だけ');
      final id = s['id'];
      if (id is! String || !RegExp(r'^[A-Za-z0-9_]+$').hasMatch(id)) throw FormatException('系列の id は英数字と _ だけ: $id');
      if (series.any((e) => e.id == id)) throw FormatException('系列の id が重複: $id');
      final v = s['values'];
      if (v is! List || v.length != categories.length || v.any((e) => e is! num || e.isNaN || e.isInfinite)) {
        throw FormatException('$id: values は categories と同じ数（${categories.length}）の数');
      }
      series.add(ChartSeries(id, [for (final e in v) (e as num).toDouble()]));
    }
    final need = switch (kind) {
      ChartKind.climate || ChartKind.pyramid => 2,
      ChartKind.pie => 1,
      _ => 0,
    };
    if (need > 0 && series.length != need) throw FormatException('${kind.name} は系列が $need 個');
    // 棒・ピラミッド・円・雨温図の降水量は 0 以上
    final nonNegative = switch (kind) {
      ChartKind.bars || ChartKind.pyramid || ChartKind.pie => series,
      ChartKind.climate => [series[1]],
      ChartKind.line => const <ChartSeries>[],
    };
    for (final s in nonNegative) {
      if (s.values.any((x) => x < 0)) throw FormatException('${s.id}: 値は 0 以上');
    }
    if (kind == ChartKind.pie && series[0].values.fold<double>(0, (a, b) => a + b) <= 0) {
      throw const FormatException('円グラフは合計が 0 より大きい');
    }
    return ChartSpec._(kind: kind, altId: altId, categories: categories, series: series);
  }

  factory ChartSpec.parse(String source) {
    final Object? j;
    try {
      j = jsonDecode(source);
    } on FormatException catch (e) {
      throw FormatException('グラフの JSON を読めません: ${e.message}');
    }
    if (j is! Map<String, dynamic>) throw const FormatException('グラフの JSON はオブジェクトです');
    return ChartSpec.fromJson(j);
  }

  ChartSeries? seriesById(String id) => series.where((s) => s.id == id).firstOrNull;

  ChartSeries _need(String id) {
    final s = seriesById(id);
    if (s == null) throw ArgumentError('系列がありません: $id');
    return s;
  }

  /// 系列 [seriesId] が最大の項目の位置（同じなら先の方）。「最も降水量が多い月」などの正解づくり。
  int argMax(String seriesId) {
    final v = _need(seriesId).values;
    var best = 0;
    for (var i = 1; i < v.length; i++) {
      if (v[i] > v[best]) best = i;
    }
    return best;
  }

  /// 系列 [seriesId] が最小の項目の位置（同じなら先の方）。
  int argMin(String seriesId) {
    final v = _need(seriesId).values;
    var best = 0;
    for (var i = 1; i < v.length; i++) {
      if (v[i] < v[best]) best = i;
    }
    return best;
  }

  /// 系列 [seriesId] の合計。年降水量など。
  double total(String seriesId) => _need(seriesId).values.fold<double>(0, (a, b) => a + b);

  /// 系列 [seriesId] の平均。年平均気温など。
  double mean(String seriesId) => total(seriesId) / categories.length;

  /// 円グラフの項目 [index] の割合（0〜1）。円グラフ以外は [StateError]。
  double shareOf(int index) {
    if (kind != ChartKind.pie) throw StateError('円グラフではありません');
    return series[0].values[index] / total(series[0].id);
  }

  static String _n(double v) {
    final s = v.toStringAsFixed(2);
    return s.contains('.') ? s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '') : s;
  }

  static String _esc(String s) =>
      s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');

  // 描画領域（viewBox は 0 0 120 80）
  static const double _w = 120, _h = 80, _l = 16, _r = 104, _t = 8, _b = 62;

  static String _text(double x, double y, String s, {String anchor = 'middle', double size = 4}) =>
      '<text x="${_n(x)}" y="${_n(y)}" font-size="${_n(size)}" text-anchor="$anchor" fill="currentColor" stroke="none">${_esc(s)}</text>';

  static String _line(double x1, double y1, double x2, double y2, {bool dashed = false, bool light = false}) =>
      '<line x1="${_n(x1)}" y1="${_n(y1)}" x2="${_n(x2)}" y2="${_n(y2)}"${dashed ? ' stroke-dasharray="2 1.5"' : ''}${light ? ' stroke-opacity="0.25"' : ''}/>';

  /// SVG 文字列。色は `currentColor` だけ。文字は XML エスケープする。
  String toSvg() {
    final b = StringBuffer()
      ..write('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${_n(_w)} ${_n(_h)}" ')
      ..write('fill="none" stroke="currentColor" stroke-width="0.6" stroke-linecap="round" stroke-linejoin="round">');
    switch (kind) {
      case ChartKind.pie:
        _pie(b);
      case ChartKind.pyramid:
        _pyramid(b);
      default:
        _xy(b);
    }
    b.write('</svg>');
    return b.toString();
  }

  double _x(int i, int n) => _l + (_r - _l) * (i + 0.5) / n;

  void _axisY(StringBuffer b, NiceScale s, {required bool left}) {
    final x = left ? _l : _r;
    b.write(_line(x, _t, x, _b));
    for (final t in s.ticks) {
      final y = _b - (t - s.min) / (s.max - s.min) * (_b - _t);
      b.write(_line(left ? x - 1.2 : x, y, left ? x : x + 1.2, y));
      if (left) b.write(_line(_l, y, _r, y, light: true));
      b.write(_text(left ? x - 2 : x + 2, y + 1.4, _n(t), anchor: left ? 'end' : 'start', size: 3.5));
    }
  }

  void _categoryLabels(StringBuffer b) {
    for (var i = 0; i < categories.length; i++) {
      b.write(_text(_x(i, categories.length), _b + 5, categories[i], size: categories.length > 12 ? 3 : 4));
    }
  }

  void _xy(StringBuffer b) {
    final n = categories.length;
    final isClimate = kind == ChartKind.climate;
    // 軸: 雨温図は左が気温・右が降水量、それ以外は左だけ
    final primary = isClimate ? series[0].values : [for (final s in series) ...s.values];
    final rain = isClimate ? series[1].values : const <double>[];
    var lo = primary.reduce(math.min), hi = primary.reduce(math.max);
    if (kind == ChartKind.bars) lo = math.min(lo, 0);
    final left = niceScale(lo, hi);
    NiceScale? right;
    if (isClimate) {
      // 降水量の軸は 0 から。気温の軸と目盛りの本数をそろえて、横線を共有する
      final count = left.ticks.length - 1;
      // 刻みは niceScale が「最大 ÷ 刻み ≦ count」になるように選ぶので、count 本に伸ばせば最大値は収まる
      final rs = niceScale(0, rain.reduce(math.max), target: count);
      right = NiceScale(0, rs.step * count, rs.step);
    }
    _axisY(b, left, left: true);
    if (right != null) {
      _axisY(b, right, left: false);
    } else {
      b.write(_line(_l, _b, _r, _b));
    }
    double yOf(double v, NiceScale s) => _b - (v - s.min) / (s.max - s.min) * (_b - _t);
    final zero = yOf(0.0, left);
    b.write(_line(_l, isClimate ? _b : zero.clamp(_t, _b), _r, isClimate ? _b : zero.clamp(_t, _b)));
    final slot = (_r - _l) / n;
    if (kind == ChartKind.bars) {
      final k = series.length;
      final bw = slot * 0.7 / k;
      for (var si = 0; si < k; si++) {
        for (var i = 0; i < n; i++) {
          final x = _l + slot * i + slot * 0.15 + bw * si;
          final y = yOf(series[si].values[i], left);
          final top = math.min(y, zero), h = (y - zero).abs();
          b.write(
            '<rect x="${_n(x)}" y="${_n(top)}" width="${_n(bw)}" height="${_n(h)}" fill="currentColor" fill-opacity="${_n(k == 1 ? 0.55 : 0.55 - 0.4 * si / (k - 1))}"/>',
          );
        }
      }
    } else if (isClimate) {
      final bw = slot * 0.6;
      for (var i = 0; i < n; i++) {
        final y = yOf(rain[i], right!);
        b.write(
          '<rect x="${_n(_x(i, n) - bw / 2)}" y="${_n(y)}" width="${_n(bw)}" height="${_n(_b - y)}" fill="currentColor" fill-opacity="0.3"/>',
        );
      }
      _polyline(b, series[0].values, left, n, dashed: false);
    } else {
      for (var si = 0; si < series.length; si++) {
        _polyline(b, series[si].values, left, n, dashed: si % 2 == 1);
      }
    }
    _categoryLabels(b);
  }

  void _polyline(StringBuffer b, List<double> values, NiceScale s, int n, {required bool dashed}) {
    final pts = [
      for (var i = 0; i < n; i++)
        '${_n(_x(i, n))},${_n(_b - (values[i] - s.min) / (s.max - s.min) * (_b - _t))}',
    ];
    b.write('<polyline points="${pts.join(' ')}"${dashed ? ' stroke-dasharray="3 2"' : ''}/>');
    for (final p in pts) {
      final xy = p.split(',');
      b.write('<circle cx="${xy[0]}" cy="${xy[1]}" r="0.9" fill="currentColor"/>');
    }
  }

  void _pyramid(StringBuffer b) {
    final n = categories.length;
    final maxV = series.expand((s) => s.values).reduce(math.max);
    final sc = niceScale(0, maxV == 0 ? 1 : maxV, target: 3);
    final cx = (_l + _r) / 2, half = (_r - _l) / 2 - 6;
    final rowH = (_b - _t) / n;
    b.write(_line(cx, _t, cx, _b));
    for (final t in sc.ticks) {
      final dx = t / sc.max * half;
      for (final sign in [-1, 1]) {
        if (t == 0 && sign == 1) continue;
        final x = cx + sign * dx;
        b.write(_line(x, _b, x, _b + 1.2));
        b.write(_text(x, _b + 5, _n(t), size: 3.5));
        if (t > 0) b.write(_line(x, _t, x, _b, light: true));
      }
    }
    for (var i = 0; i < n; i++) {
      final y = _b - rowH * (i + 1);
      final bh = rowH * 0.8;
      final wl = series[0].values[i] / sc.max * half, wr = series[1].values[i] / sc.max * half;
      b.write(
        '<rect x="${_n(cx - wl)}" y="${_n(y + rowH * 0.1)}" width="${_n(wl)}" height="${_n(bh)}" fill="currentColor" fill-opacity="0.5"/>',
      );
      b.write(
        '<rect x="${_n(cx)}" y="${_n(y + rowH * 0.1)}" width="${_n(wr)}" height="${_n(bh)}" fill="currentColor" fill-opacity="0.2"/>',
      );
      b.write(_text(_l - 2, y + rowH / 2 + 1.2, categories[i], anchor: 'end', size: n > 12 ? 3 : 3.5));
    }
  }

  void _pie(StringBuffer b) {
    const cx = 60.0, cy = 40.0, r = 28.0;
    final v = series[0].values;
    final tot = total(series[0].id);
    var a0 = -math.pi / 2; // 12 時から時計回り
    final nonZero = v.where((x) => x > 0).length;
    for (var i = 0; i < v.length; i++) {
      if (v[i] <= 0) continue;
      final da = v[i] / tot * 2 * math.pi;
      final a1 = a0 + da;
      final op = _n(0.12 + 0.5 * (i % 4) / 3);
      if (nonZero == 1) {
        b.write('<circle cx="${_n(cx)}" cy="${_n(cy)}" r="${_n(r)}" fill="currentColor" fill-opacity="$op"/>');
      } else {
        final x0 = cx + r * math.cos(a0), y0 = cy + r * math.sin(a0);
        final x1 = cx + r * math.cos(a1), y1 = cy + r * math.sin(a1);
        b.write(
          '<path d="M${_n(cx)} ${_n(cy)}L${_n(x0)} ${_n(y0)}A${_n(r)} ${_n(r)} 0 ${da > math.pi ? 1 : 0} 1 ${_n(x1)} ${_n(y1)}Z" fill="currentColor" fill-opacity="$op"/>',
        );
      }
      final am = (a0 + a1) / 2;
      b.write(_text(cx + (r + 5) * math.cos(am), cy + (r + 5) * math.sin(am) + 1.2, categories[i], size: 3.5));
      a0 = a1;
    }
  }
}
