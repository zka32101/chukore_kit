import 'dart:convert';

import '../bank/question_bank.dart';

/// コンテンツの文言（教科書のような説明・問題文・解説・場面の説明）。`texts.json` に **ID → 本文** で持つ（言語ごとに 1 ファイル）。
/// 本文の中の `{…}` は、変種の値を差し込む場所（`{a}`・`{c-b}`・`{+b}` など。型の書き方と同じ）。
/// 基盤は何も集めず・送らない。文言の持ち方と検証だけを持つ。
class ContentTexts {
  const ContentTexts({required this.locale, required this.texts});

  /// 言語（`ja`・`pt-BR` など。目録の `locale` と同じ）。
  final String locale;

  /// ID → 本文。
  final Map<String, String> texts;

  static final _idPattern = RegExp(r'^[A-Za-z0-9_]+$');

  /// 読めなければ [FormatException]。
  factory ContentTexts.parse(String source) {
    final Object? j;
    try {
      j = jsonDecode(source);
    } on FormatException catch (e) {
      throw FormatException('文言の JSON を読めません: ${e.message}');
    }
    if (j is! Map<String, dynamic> || j.keys.any((k) => !const {'version', 'locale', 'texts'}.contains(k))) {
      throw const FormatException('文言は {"version":1,"locale":…,"texts":{…}} だけ');
    }
    if (j['version'] != 1) throw FormatException('未対応の版: ${j['version']}');
    final locale = j['locale'];
    if (locale is! String || !RegExp(r'^[a-z]{2,3}(-[A-Z]{2})?$').hasMatch(locale)) {
      throw FormatException('locale は言語コード（ja・pt-BR など）: $locale');
    }
    final raw = j['texts'];
    if (raw is! Map) throw const FormatException('texts は ID → 本文');
    final out = <String, String>{};
    for (final e in raw.entries) {
      final id = e.key as String;
      if (!_idPattern.hasMatch(id)) throw FormatException('文言の ID は英数字と _ だけ: $id');
      final v = e.value;
      if (v is! String || v.trim().isEmpty) throw FormatException('$id: 本文は空でない文字列');
      out[id] = v;
    }
    return ContentTexts(locale: locale, texts: out);
  }

  /// 本文の中の `{…}` の中身（差し込む式）の一覧。
  static List<String> placeholders(String text) => [for (final m in RegExp(r'\{([^{}]*)\}').allMatches(text)) m.group(1)!];

  /// `{` と `}` の数・入れ子が合っているか。
  static bool balanced(String text) {
    var depth = 0;
    for (final c in text.runes) {
      if (c == 0x7B) {
        depth++;
        if (depth > 1) return false; // 入れ子は使わない
      } else if (c == 0x7D) {
        depth--;
        if (depth < 0) return false;
      }
    }
    return depth == 0;
  }

  /// 長すぎる本文の目安（文字数）。1 つの説明は短く区切る（教科書の 1 段落ほど）。
  static const longText = 300;
}

/// 文言の検証。エラー: `text_unbalanced_braces`（`{` `}` が合わない）。警告: `text_too_long`（[ContentTexts.longText] 文字超）。
List<ValidationIssue> validateContentTexts(ContentTexts t) {
  final issues = <ValidationIssue>[];
  for (final e in t.texts.entries) {
    if (!ContentTexts.balanced(e.value)) {
      issues.add(ValidationIssue(IssueSeverity.error, 'text_unbalanced_braces', e.key, '`{` と `}` が合っていません'));
    }
    if (e.value.runes.length > ContentTexts.longText) {
      issues.add(ValidationIssue(IssueSeverity.warning, 'text_too_long', e.key, '長すぎます（${e.value.runes.length} 文字。${ContentTexts.longText} 文字までを目安に区切る）'));
    }
  }
  return issues;
}
