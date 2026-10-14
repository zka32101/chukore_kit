// 問題集を検証する。使い方: `dart run tool/validate_bank.dart <units.json> <questions.json> [<prerequisites.json>]`
// エラーがあれば終了コード 1。形式は docs/question_bank_format.md。
import 'dart:convert';
import 'dart:io';

import 'package:chukore_kit/chukore_kit.dart';

void main(List<String> args) {
  if (args.length != 2 && args.length != 3) {
    stderr.writeln('usage: dart run tool/validate_bank.dart <units.json> <questions.json> [<prerequisites.json>]');
    exit(64);
  }
  final unitsJson = jsonDecode(File(args[0]).readAsStringSync()) as Map<String, dynamic>;
  final bankJson = jsonDecode(File(args[1]).readAsStringSync()) as Map<String, dynamic>;

  final issues = <ValidationIssue>[];
  final units = <Unit>[];
  for (final raw in (unitsJson['units'] as List? ?? const [])) {
    try {
      units.add(Unit.fromJson(Map<String, dynamic>.from(raw as Map)));
    } catch (e) {
      issues.add(ValidationIssue(IssueSeverity.error, 'malformed', '${(raw as Map?)?['id'] ?? '?'}', 'unit を読めません: $e'));
    }
  }
  issues.addAll(validateUnitList(units));

  final bank = parseQuestionBank(bankJson);
  issues
    ..addAll(bank.issues)
    ..addAll(validateQuestionBank(
      questions: bank.questions,
      tree: UnitTree(unitsJson['version'] as int? ?? 1, units),
      mistakeLines: bank.mistakeLines,
    ));

  // 単元の前提（さかのぼり診断用。省略可）
  if (args.length == 3) {
    final prereqJson = jsonDecode(File(args[2]).readAsStringSync()) as Map<String, dynamic>;
    final raw = <PrereqNode>[];
    for (final n in (prereqJson['prerequisites'] as List? ?? const [])) {
      try {
        raw.add(PrereqNode.fromJson(Map<String, dynamic>.from(n as Map)));
      } catch (e) {
        issues.add(ValidationIssue(IssueSeverity.error, 'malformed', '${(n as Map?)?['unitId'] ?? '?'}', 'prerequisite を読めません: $e'));
      }
    }
    issues.addAll(PrerequisiteGraph(raw).validate(UnitTree(unitsJson['version'] as int? ?? 1, units), rawNodes: raw));
  }

  for (final i in issues) {
    stdout.writeln(i);
  }
  final errors = issues.where((i) => i.isError).length;
  stdout.writeln('units: ${units.length}, questions: ${bank.questions.length}, '
      'mistakeLines: ${bank.mistakeLines.length} / errors: $errors, warnings: ${issues.length - errors}');
  exit(errors == 0 ? 0 : 1);
}
