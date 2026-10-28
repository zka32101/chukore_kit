// 1 日の流れを、基盤の部品だけで通しで動かす例（画面なし。結線の確認と、アプリ側の実装の手本）。
// 実行: `dart run example/day_flow.dart`（パッケージのルートで）
//
// 流れ: 範囲とテスト日 → 計画 → 「今日」の窓口 → 出題 → 回答（自信・ヒントつき）→ 弱点・復習 →
//       「今日は 1 分だけ」の出題 → 週のふりかえり → 保護者への声かけ（年齢方針で見せてよいか確認）→
//       本番の点（使う前の点 → テスト後に聞く → 変化 → 匿名の報告の形）→ バックアップ → 全削除
//
// 画面・通知・保存先の選び方はアプリ側。ここでは `InMemoryAttemptStore` を使う（SQLite は `chukore_kit_sqlite.dart`）。
import 'dart:convert';
import 'dart:io';

import 'package:chukore_kit/chukore_kit.dart';

/// 1 日分の流れを動かして、画面に出す内容を行にして返す。[today] を渡せば日付を固定できる（テスト用）。
Future<List<String>> runDay({DateTime? today, ChukoreStrings strings = const JaStrings(), int age = 12}) async {
  final out = <String>[];
  void say(String s) => out.add(s);
  final day = dateOnly(today ?? DateTime.now());

  // 1. 問題集と単元（JSON）を読む。検査の指摘はここで見る
  final tree = UnitTree.fromJson(
    jsonDecode(File('docs/samples/units.sample.json').readAsStringSync()) as Map<String, dynamic>,
  );
  final bank = parseQuestionBank(
    jsonDecode(File('docs/samples/questions.sample.json').readAsStringSync()) as Map<String, dynamic>,
  );
  final byId = {for (final q in bank.questions) q.id: q};
  say('問題 ${bank.questions.length} 問 / 検査の指摘 ${bank.issues.length} 件');

  // 2. 範囲とテスト日から、今日までの計画（テスト日逆算）
  final testDate = day.add(const Duration(days: 14));
  final testPlan = TestPlan(id: 'en-1', subject: 'en', testDate: testDate, unitIds: const ['en1_be', 'en1_verbs']);
  final store = InMemoryAttemptStore();
  final plan = buildPlan(today: day, plan: testPlan, tree: tree);
  final todayPlan = plan.days.first;
  say(
    '計画 ${plan.days.length} 日 / 今日 ${todayPlan.total} 問（重点 ${todayPlan.focus}・弱点 ${todayPlan.weak}・復習 ${todayPlan.review}）',
  );

  // 3. 「今日」の窓口: 見出しと一言
  var card = buildTodayCard(
    now: day.add(const Duration(hours: 16)),
    attempts: await store.query(),
    plan: plan.days,
    testDate: testDate,
  );
  say('今日の見出し: ${card.headline.name}${card.message(strings) == null ? '' : ' / ${card.message(strings)}'}');

  // 4. 出題（習熟度に合う問題を選び、混ぜる）。前日・当日なら制限をかける
  final mastery = computeMastery(await store.query(), day);
  var set = pickPractice(
    plan: todayPlan,
    questions: bank.questions,
    mastery: mastery,
    attempts: await store.query(),
    today: day,
    testDate: testDate,
  );
  set = interleaveByUnit(set);
  final guarded = guardLastDays(set, plan: todayPlan, attempts: await store.query());
  say('出題 ${guarded.set.items.length} 問: ${guarded.set.questions.map((q) => q.id).join(', ')}');

  // 4b. 時間で選ぶ「今日は 1 分だけ」: 本人の履歴から 1 問あたりの時間を見積もり、予算に収まるよう比率を保って減らす（増やさない）
  final timed = pickPracticeForMinutes(
    minutes: 1,
    pace: buildPace(await store.query()),
    plan: todayPlan,
    questions: bank.questions,
    mastery: mastery,
    attempts: await store.query(),
    today: day,
    testDate: testDate,
  );
  say(
    '今日は 1 分だけ: ${timed.set.items.length} 問（見積もり ${timed.estimatedSeconds.round()} 秒 / 予算 ${timed.budgetSeconds} 秒、収まる: ${timed.fits}）',
  );

  // 5. 回答する（ここでは、最初の問題を間違え、あとは正解する）。自信の有無・ヒントも記録できる
  var t = day.add(const Duration(hours: 16));
  for (final (i, q) in guarded.set.questions.indexed) {
    final input = i == 0 ? q.choices.firstWhere((c) => c != q.answer, orElse: () => q.answer) : q.answer;
    final r = checkAnswer(q, input);
    t = t.add(const Duration(minutes: 1));
    await store.add(
      Attempt(
        questionId: q.id,
        unitId: q.unitId,
        correct: r.correct,
        chosenId: input,
        answeredAt: t,
        elapsedMs: 8000,
        confident: r.correct ? null : true, // 自信ありで間違えた（思い込みの疑い）
      ),
    );
    say('  ${q.id}: ${r.correct ? '正解' : '不正解${r.misconceptionTag == null ? '' : '（誤解の型 ${r.misconceptionTag}）'}'}');
  }
  final attempts = await store.query();

  // 6. 弱点の解き直しセットと、復習の期限
  final retry = buildRetrySets(attempts: attempts, questions: bank.questions);
  say('解き直しセット ${retry.length} 件${retry.isEmpty ? '' : '（先頭: ${retry.first.key}）'}');
  final states = buildReviewStates(attempts, testDate: testDate);
  say('復習の予定 ${states.length} 問（明日の期限 ${dueForReview(states, day.add(const Duration(days: 1))).length} 問）');

  // 7. 休憩の提案・今日の窓口（学習したあと）
  card = buildTodayCard(
    now: t.add(const Duration(minutes: 1)),
    attempts: attempts,
    plan: plan.days,
    testDate: testDate,
  );
  say('学習後の見出し: ${card.headline.name}');

  // 8. 週のふりかえり（子ども本人向け）と保護者への声かけ（年齢方針で見せてよいか確認）
  final report = buildWeeklyReport(attempts, tree, day.subtract(Duration(days: day.weekday - 1)), questions: byId);
  say('週のふりかえり: ${buildMyWeek(report).headline(strings)}');
  final policy = AgePolicy.forRegion('JP');
  final access = policy.accessFor(ChildFeature.weeklyReport, age: age);
  say('保護者向けレポート（$age 歳）: ${access.name}');
  if (access != Access.hidden) {
    // needsGuardianGate なら、ここで保護者ゲート（app_common_kit の requireParentalGate）を通してから見せる
    say('声かけ: ${suggestGuardianTalk(report).text(strings)}');
  }

  // 9. 本番の点（すべて端末内。外へ出すのは、法務確認と保護者の同意のあとに限る）
  //    使い始めに「使う前の点」を聞き → テスト後に点を 1 回だけ聞き → 変化を求め → 外へ出す場合の形（点を持たない区分）を作る
  const tuning = KitTuning();
  var asked = const ScorePromptState();
  final startPrompt = tuning.scorePrompt(today: day, testDates: [testDate], records: const [], state: asked);
  say('点を聞く（使い始め）: ${startPrompt?.kind.name}');
  asked = asked.markPrompted(startPrompt!, day);
  final baseline = RealTestRecord(day.subtract(const Duration(days: 30)), parseScoreInput('55', maxScore: 100).value!);
  final afterDay = testDate.add(const Duration(days: 1));
  final testPrompt = tuning.scorePrompt(
    today: afterDay,
    testDates: [testDate],
    records: const [],
    state: asked,
    baseline: baseline,
  );
  say('点を聞く（テストの翌日）: ${testPrompt?.kind.name}');
  asked = asked.markPrompted(testPrompt!, afterDay);
  final again2 = tuning.scorePrompt(
    today: afterDay.add(const Duration(days: 1)),
    testDates: [testDate],
    records: const [],
    state: asked,
    baseline: baseline,
  );
  say('次の日にもう一度聞くか: ${again2 == null ? '聞かない' : '聞く'}');
  final entered = parseScoreInput('72', maxScore: 100);
  final summary = tuning.outcomeSummary([RealTestRecord(testDate, entered.value!)], attempts, baseline: baseline);
  final entry = summary.entries.single;
  say('本番の点の変化: ${entry.change.name}（学習日 ${entry.activeDays} 日）/ ${outcomeMessage(entry.change, strings)}');
  final reports = tuning.outcomeReports(summary, subject: 'en', region: 'JP', grade: 1);
  say('外へ出す場合の形（区分だけ・点なし）: ${jsonEncode(FunnelEvent.scoreEntered(reports.single).toJson())}');

  // 10. 機種変更の引き継ぎ（書き出し → 別のストアに取り込み）と、全削除
  final file = AttemptBackup.export(attempts, now: t);
  final other = InMemoryAttemptStore();
  final imported = await AttemptBackup.importInto(other, file);
  say('バックアップ: ${attempts.length} 件を書き出し、${imported.added} 件を取り込み（重複 ${imported.duplicates}）');
  final again = await AttemptBackup.importInto(other, file);
  say('同じファイルをもう一度: 追加 ${again.added} 件（二重にならない）');
  await store.deleteAll();
  say('全削除のあとの履歴: ${(await store.query()).length} 件');
  return out;
}

Future<void> main() async {
  for (final line in await runDay()) {
    stdout.writeln(line);
  }
}
