import '../models/models.dart';
import '../weak/weak_notes.dart';

/// 先生役モード（まちがいキャラ）の1問。キャラが典型的な誤解をそのまま言い、
/// 学習者が「どこが違う？」を直す。誤解の型（[tag]）と元の問題（[questionId]）につながっていて、
/// 直せたかどうかが弱点ノートの克服判定に反映される。
///
/// 文言（[statement]・[fixChoices]・[explanation]）は問題データとして教科アプリ側が持つ（多言語化もアプリ側）。
class MistakeLine {
  const MistakeLine({
    required this.id,
    required this.tag,
    required this.questionId,
    required this.sourceChoiceId,
    required this.statement,
    required this.fixChoices,
    required this.correctChoice,
    required this.explanation,
  });

  factory MistakeLine.fromJson(Map<String, dynamic> j) => MistakeLine(
        id: j['id'] as String,
        tag: j['tag'] as String,
        questionId: j['questionId'] as String,
        sourceChoiceId: j['sourceChoiceId'] as String,
        statement: j['statement'] as String,
        fixChoices: [for (final c in j['fixChoices'] as List) c as String],
        correctChoice: j['correctChoice'] as String,
        explanation: j['explanation'] as String,
      );

  final String id;

  /// 誤解の型（例: third_person_s）。
  final String tag;

  /// 元の問題。この問題の誤答選択肢にも [tag] が付いている。
  final String questionId;

  /// 元の問題で [tag] が付いている誤答選択肢のID。間違えたとき弱点ノートに型として記録するために使う。
  final String sourceChoiceId;

  /// キャラのセリフ（誤解をそのまま言う）。
  final String statement;
  final List<String> fixChoices;
  final String correctChoice;

  /// 直したあとに出す説明。
  final String explanation;

  Map<String, dynamic> toJson() => {
        'id': id,
        'tag': tag,
        'questionId': questionId,
        'sourceChoiceId': sourceChoiceId,
        'statement': statement,
        'fixChoices': fixChoices,
        'correctChoice': correctChoice,
        'explanation': explanation,
      };
}

/// 今日の先生役モードで出す問題を選ぶ。決まった入力なら同じ結果。
///
/// 優先順: ①未克服の弱点の型（最近間違えた順）→ ②克服済みの型（復習）→ ③その他。
/// 各グループで、まだ出していないものを先に。まず1つの型から1問ずつ選んで偏らせず、足りなければ同じ型からも足す。
List<MistakeLine> pickMistakeLines({
  required Iterable<MistakeLine> lines,
  required List<WeakEntry> weakNotes,
  Set<String> shownIds = const {},
  int count = 5,
}) {
  final unresolved = <String, DateTime>{};
  final overcome = <String>{};
  for (final w in weakNotes) {
    final tag = w.tag;
    if (tag == null) continue;
    if (w.overcome) {
      overcome.add(tag);
    } else {
      final prev = unresolved[tag];
      if (prev == null || w.lastWrongAt.isAfter(prev)) unresolved[tag] = w.lastWrongAt;
    }
  }
  // 未克服が残る型は、克服済みの記録より優先する。
  overcome.removeAll(unresolved.keys);

  int group(MistakeLine l) => unresolved.containsKey(l.tag) ? 0 : (overcome.contains(l.tag) ? 1 : 2);
  final sorted = lines.toList()
    ..sort((a, b) {
      var c = (shownIds.contains(a.id) ? 1 : 0).compareTo(shownIds.contains(b.id) ? 1 : 0);
      if (c != 0) return c;
      c = group(a).compareTo(group(b));
      if (c != 0) return c;
      if (group(a) == 0) {
        c = unresolved[b.tag]!.compareTo(unresolved[a.tag]!); // 最近間違えた型が先
        if (c != 0) return c;
      }
      return a.id.compareTo(b.id);
    });

  final picked = <MistakeLine>[];
  final tags = <String>{};
  for (final l in sorted) {
    if (picked.length >= count) break;
    if (tags.add(l.tag)) picked.add(l);
  }
  for (final l in sorted) {
    if (picked.length >= count) break;
    if (!picked.contains(l)) picked.add(l);
  }
  return picked;
}

class TeacherFeedback {
  const TeacherFeedback({required this.correct, required this.explanation, required this.correctChoice});

  final bool correct;
  final String explanation;
  final String correctChoice;
}

/// 先生役モード1回分の進行。回答すると判定して次の問題へ進む。
class TeacherSession {
  TeacherSession(List<MistakeLine> lines) : lines = List.unmodifiable(lines);

  final List<MistakeLine> lines;
  int _index = 0;
  int _correct = 0;

  MistakeLine? get current => _index < lines.length ? lines[_index] : null;
  bool get isFinished => _index >= lines.length;
  int get answered => _index;
  int get correctCount => _correct;

  /// 現在の問題に [choice] で答える。終わっていれば null。
  TeacherFeedback? answer(String choice) {
    final line = current;
    if (line == null) return null;
    final ok = choice == line.correctChoice;
    if (ok) _correct++;
    _index++;
    return TeacherFeedback(correct: ok, explanation: line.explanation, correctChoice: line.correctChoice);
  }
}

/// 回答を履歴に残す形にする（弱点ノートの克服判定に効く）。
/// 間違えたときは元の問題の誤答選択肢（[MistakeLine.sourceChoiceId]）を選んだことにして、型として記録する。
Attempt teacherAttempt(
  MistakeLine line, {
  required String chosen,
  required String unitId,
  required DateTime now,
  int elapsedMs = 0,
}) {
  final ok = chosen == line.correctChoice;
  return Attempt(
    questionId: line.questionId,
    unitId: unitId,
    correct: ok,
    chosenId: ok ? null : line.sourceChoiceId,
    answeredAt: now,
    elapsedMs: elapsedMs,
    mode: 'teacher',
  );
}
