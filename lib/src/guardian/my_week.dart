import '../l10n/strings.dart';
import 'report.dart';

/// 週のふりかえりの見出しの種類。優先は [grew] > [overcame] > [kept] > [started] > [rest]。
enum MyWeekKind {
  /// 習熟度が伸びた単元がある。
  grew,

  /// 新しく克服できたつまずきがある。
  overcame,

  /// 週に 3 日以上学習を続けた。
  kept,

  /// 学習した日が 1〜2 日（はじめの一歩）。
  started,

  /// 学習していない週（ひとやすみ）。責めずに、いつでも始められると伝える。
  rest,
}

/// 子ども本人が見る、週のふりかえり。保護者向けの [WeeklyReport] と同じ材料から作るが、
/// 「できたこと」だけを前に出す（減った・少なかった・先週より劣るといった比べ方はしない）。
/// 自分の記録を自分で見るだけで、共有・送信しない。見せてよいか・範囲は `AgePolicy`（`ChildFeature.selfReview`）で決める。
class MyWeek {
  const MyWeek({
    required this.kind,
    required this.activeDays,
    required this.attemptCount,
    required this.newlyOvercome,
    required this.improvedTitles,
    required this.moreThanLastWeek,
  });

  final MyWeekKind kind;
  final int activeDays;
  final int attemptCount;

  /// 新しく克服できたつまずきの数（1 以上のときだけ見せる）。
  final int newlyOvercome;

  /// 伸びた単元の名前（伸びが大きい順、最大 [maxImproved] 個）。
  final List<String> improvedTitles;

  /// 先週より学習した日か回答が多い（多いときだけ見せる。少ないことは伝えない）。
  final bool moreThanLastWeek;

  static const maxImproved = 3;

  /// 見出し（数字を含まない短い文）。
  String headline(ChukoreStrings strings) => switch (kind) {
        MyWeekKind.grew => strings.myWeekGrew,
        MyWeekKind.overcame => strings.myWeekOvercame,
        MyWeekKind.kept => strings.myWeekKept,
        MyWeekKind.started => strings.myWeekStarted,
        MyWeekKind.rest => strings.myWeekRest,
      };

  /// 画面に出す文面。見出し →（学習した週だけ）日数と問題数 →（あれば）克服した数 →（あれば）伸びた単元。
  /// 数字を含む行は、保護者向けレポートと同じ文言（`reportHeader`・`statStamps`・`reportImprovedTitle`）を使う。
  String toText(ChukoreStrings strings) {
    final b = StringBuffer(headline(strings));
    if (kind != MyWeekKind.rest) {
      b.write('\n${strings.reportHeader(activeDays, attemptCount)}');
    }
    if (newlyOvercome > 0) b.write('\n${strings.statStamps}: $newlyOvercome');
    if (improvedTitles.isNotEmpty) {
      b.write('\n${strings.reportImprovedTitle}');
      for (final t in improvedTitles) {
        b.write('\n- $t');
      }
    }
    return b.toString();
  }
}

/// 週のレポートから、子ども本人向けのふりかえりを作る。同じ入力なら同じ結果。
MyWeek buildMyWeek(WeeklyReport report) {
  final MyWeekKind kind;
  if (report.improvements.isNotEmpty) {
    kind = MyWeekKind.grew;
  } else if (report.newlyOvercome > 0) {
    kind = MyWeekKind.overcame;
  } else if (report.activeDays >= 3) {
    kind = MyWeekKind.kept;
  } else if (report.activeDays >= 1) {
    kind = MyWeekKind.started;
  } else {
    kind = MyWeekKind.rest;
  }
  return MyWeek(
    kind: kind,
    activeDays: report.activeDays,
    attemptCount: report.attemptCount,
    newlyOvercome: report.newlyOvercome,
    improvedTitles: [for (final i in report.improvements.take(MyWeek.maxImproved)) i.title],
    moreThanLastWeek: report.activeDays > report.previousActiveDays || report.attemptCount > report.previousAttemptCount,
  );
}
