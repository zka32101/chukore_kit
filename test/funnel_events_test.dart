import 'package:chukore_kit/chukore_kit.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> base() => {'subject': 'math', 'region': 'BR', 'grade': 2};

void main() {
  test('イベント名は snake_case', () {
    expect(funnelEventLabel(FunnelEventName.ahaReached), 'aha_reached');
    expect(funnelEventLabel(FunnelEventName.postTestReviewReached), 'post_test_review_reached');
    expect(funnelEventLabel(FunnelEventName.scorePromptShown), 'score_prompt_shown');
  });

  group('許可リスト', () {
    test('持てる項目に、点・日付・名前などを思わせるものがない', () {
      const bad = ['score', 'date', 'name', 'email', 'school', 'device', 'answer', 'point', 'time', 'user'];
      for (final e in FunnelEventName.values) {
        final keys = funnelEventKeys(e);
        for (final k in keys) {
          for (final b in bad) {
            expect(k.toLowerCase().contains(b), false, reason: '${e.name} の項目 $k');
          }
        }
      }
    });

    test('共通の項目と、イベントごとの項目が決まっている（増えたら気づく）', () {
      expect(funnelEventKeys(FunnelEventName.ahaReached), {'subject', 'region', 'grade'});
      expect(funnelEventKeys(FunnelEventName.scoreEntered), {
        'subject',
        'region',
        'grade',
        'kind',
        'band',
        'usage',
        'baseline',
        'tuning',
      });
      expect(funnelEventKeys(FunnelEventName.scorePromptSkipped), {'subject', 'region', 'grade', 'kind'});
    });

    test('値はすべて文字列の決まった値・小さい整数・真偽値だけ（点や日時を入れられない）', () {
      final e = FunnelEvent(FunnelEventName.scoreEntered, {
        ...base(),
        'kind': 'regular',
        'band': 'up',
        'usage': 'mid',
        'baseline': false,
        'tuning': 1,
      });
      expect(e.props.values.every((v) => v is String || v is int || v is bool), true);
    });
  });

  group('FunnelEvent の検証', () {
    test('項目なしのイベントは共通の項目だけで作れる。grade は無くてもよい', () {
      final e = FunnelEvent(FunnelEventName.ahaReached, {'subject': 'math', 'region': 'JP'});
      expect(e.toJson(), {'event': 'aha_reached', 'subject': 'math', 'region': 'JP'});
      FunnelEvent(FunnelEventName.testDateRegistered, base());
      FunnelEvent(FunnelEventName.ahaReached, {...base(), 'grade': null});
    });

    test('許可されていない項目・必須の欠け・値の違いは拒否', () {
      expect(() => FunnelEvent(FunnelEventName.ahaReached, {...base(), 'score': 80}), throwsArgumentError);
      expect(() => FunnelEvent(FunnelEventName.ahaReached, {...base(), 'date': '2026-06-01'}), throwsArgumentError);
      expect(
        () => FunnelEvent(FunnelEventName.ahaReached, {'region': 'BR'}),
        throwsArgumentError,
        reason: 'subject 欠け',
      );
      expect(
        () => FunnelEvent(FunnelEventName.ahaReached, {'subject': 'math'}),
        throwsArgumentError,
        reason: 'region 欠け',
      );
      expect(() => FunnelEvent(FunnelEventName.ahaReached, {...base(), 'region': 'br'}), throwsArgumentError);
      expect(() => FunnelEvent(FunnelEventName.ahaReached, {...base(), 'region': 'BRA'}), throwsArgumentError);
      expect(() => FunnelEvent(FunnelEventName.ahaReached, {...base(), 'grade': 4}), throwsArgumentError);
      expect(() => FunnelEvent(FunnelEventName.ahaReached, {...base(), 'grade': 0}), throwsArgumentError);
      expect(() => FunnelEvent(FunnelEventName.ahaReached, {...base(), 'grade': 2.0}), throwsArgumentError);
      expect(() => FunnelEvent(FunnelEventName.ahaReached, {...base(), 'subject': 'Math Class'}), throwsArgumentError);
      expect(() => FunnelEvent(FunnelEventName.scorePromptShown, base()), throwsArgumentError, reason: 'kind 欠け');
      expect(() => FunnelEvent(FunnelEventName.scorePromptShown, {...base(), 'kind': 'later'}), throwsArgumentError);
      expect(
        FunnelEvent(FunnelEventName.scorePromptShown, {...base(), 'kind': 'afterTest'}).props['kind'],
        'afterTest',
      );
    });

    test('エラーの文に、問題のある項目名が出る', () {
      try {
        FunnelEvent(FunnelEventName.ahaReached, {...base(), 'score': 80});
        fail('拒否されるはず');
      } on ArgumentError catch (e) {
        expect(e.message.toString(), contains('score'));
      }
    });

    test('props は後から書き換えられない', () {
      final e = FunnelEvent(FunnelEventName.ahaReached, base());
      expect(() => e.props['score'] = 1, throwsUnsupportedError);
    });
  });

  group('scoreEntered', () {
    test('OutcomeReport から作ると、点を持たない区分だけで、キーが決まっている', () {
      const r = OutcomeReport(
        band: OutcomeBand.bigUp,
        hasBaseline: true,
        usage: UsageBand.high,
        kind: RealTestKind.regular,
        subject: 'math',
        region: 'BR',
        grade: 2,
      );
      final j = FunnelEvent.scoreEntered(r).toJson();
      expect(j, {
        'event': 'score_entered',
        'subject': 'math',
        'region': 'BR',
        'grade': 2,
        'kind': 'regular',
        'band': 'bigUp',
        'usage': 'high',
        'baseline': true,
        'tuning': 1,
      });
    });

    test('grade が無い報告でも作れる（grade の項目は出ない）', () {
      const r = OutcomeReport(
        band: OutcomeBand.same,
        hasBaseline: false,
        usage: UsageBand.low,
        kind: RealTestKind.mock,
        subject: 'english',
        region: 'JP',
      );
      expect(FunnelEvent.scoreEntered(r).toJson().containsKey('grade'), false);
    });

    test('報告に subject が日本語などの許可外の形だと拒否（外へ出す前に気づく）', () {
      const r = OutcomeReport(
        band: OutcomeBand.up,
        hasBaseline: false,
        usage: UsageBand.mid,
        kind: RealTestKind.regular,
        subject: '数学',
        region: 'JP',
      );
      expect(() => FunnelEvent.scoreEntered(r), throwsArgumentError);
    });
  });

  group('funnelRates', () {
    test('点の入力率と、振り返りの到達率。信頼区間が割合を含む', () {
      final r = funnelRates({'score_prompt_shown': 100, 'score_entered': 60, 'post_test_review_reached': 30});
      expect(r.scoreEntry!.n, 100);
      expect(r.scoreEntry!.rate, 0.6);
      expect(r.scoreEntry!.low, lessThan(0.6));
      expect(r.scoreEntry!.high, greaterThan(0.6));
      expect(r.reviewReach!.n, 60);
      expect(r.reviewReach!.rate, 0.5);
    });

    test('分母が minN 未満の割合は返さない（29は返さず、30は返す）', () {
      expect(funnelRates({'score_prompt_shown': 29, 'score_entered': 20}).scoreEntry, isNull);
      expect(funnelRates({'score_prompt_shown': 30, 'score_entered': 20}).scoreEntry, isNotNull);
      expect(
        funnelRates({'score_prompt_shown': 100, 'score_entered': 29, 'post_test_review_reached': 10}).reviewReach,
        isNull,
      );
      expect(funnelRates({'score_prompt_shown': 10, 'score_entered': 8}, minN: 10).scoreEntry!.rate, 0.8);
    });

    test('件数が無い・分子が分母を超える（重複送信など）でも壊れない。割合は1を超えない', () {
      final empty = funnelRates(const {});
      expect(empty.scoreEntry, isNull);
      expect(empty.reviewReach, isNull);
      final over = funnelRates({'score_prompt_shown': 40, 'score_entered': 50});
      expect(over.scoreEntry!.rate, 1.0);
      expect(over.scoreEntry!.hits, 40);
    });

    test('minN が1未満ならエラー', () {
      expect(() => funnelRates(const {}, minN: 0), throwsArgumentError);
    });
  });
}
