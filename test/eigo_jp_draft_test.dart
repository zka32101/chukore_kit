import 'dart:convert';
import 'dart:io';

import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('英語（日本）中1前半の草案は検証エラー・警告なし', () {
    Map<String, dynamic> read(String f) =>
        jsonDecode(File('docs/content_drafts/eigo_jp_chu1/$f').readAsStringSync()) as Map<String, dynamic>;
    final tree = UnitTree.fromJson(read('units.json'));
    final bank = parseQuestionBank(read('questions.json'));
    expect(bank.issues, isEmpty);
    final issues = validateQuestionBank(questions: bank.questions, tree: tree, mistakeLines: bank.mistakeLines);
    expect(issues, isEmpty, reason: issues.join('\n'));
    expect(PrerequisiteGraph.fromJson(read('prerequisites.json')).validate(tree), isEmpty);
  });
}
