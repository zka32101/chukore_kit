import 'package:chukore_kit/chukore_kit.dart';
import 'package:chukore_kit/chukore_kit_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

GrowthCardData _data({double? delta, bool best = false, double? toNext = 5}) => GrowthCardData(
      subjectLabel: '英語',
      level: Level.b,
      pointsToNext: toNext,
      scoreDelta: delta,
      isPersonalBest: best,
      overcomeStamps: 12,
      nowSolvable: 34,
      streakDays: 7,
      stage: 2,
      radar: const [
        RadarAxis('文法', 0.7, 0.5),
        RadarAxis('語彙', 0.6, 0.55),
        RadarAxis('読解', 0.8, 0.6),
        RadarAxis('リスニング', 0.4, 0.4),
      ],
    );

void main() {
  fontTests();
  test('見出し: 前回からの変化が主役で、下がっても落ち込ませない', () {
    expect(_data(delta: 8).headline, '前回より +8点');
    expect(_data(delta: 2.5).headline, '前回より +2.5点');
    expect(_data(delta: 0).headline, contains('安定'));
    final down = _data(delta: -6).headline;
    expect(down, 'ここからまた伸ばそう');
    expect(down.contains('-') || down.contains('下'), isFalse);
    expect(_data().headline, 'はじめの一歩');
    expect(_data(delta: -3, best: true).headline, '自己ベスト更新！');
  });

  test('次のレベルの案内', () {
    expect(_data().nextLine, 'あと5点で次のレベル');
    expect(_data(toNext: null).nextLine, '最高レベルに到達！');
  });

  test('13歳未満はゲート通過後のみ共有できる', () {
    expect(canShareGrowthCard(isUnder13: true, gatePassed: false), isFalse);
    expect(canShareGrowthCard(isUnder13: true, gatePassed: true), isTrue);
    expect(canShareGrowthCard(isUnder13: false, gatePassed: false), isTrue);
  });

  test('レーダーは3〜6軸', () {
    expect(
      () => GrowthCardData(
        subjectLabel: '英語',
        level: Level.a,
        radar: const [RadarAxis('a', 0.5), RadarAxis('b', 0.5)],
      ),
      throwsA(isA<AssertionError>()),
    );
  });

  testWidgets('カードを画面に描画できる', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: GrowthCardView(data: _data(delta: 4)))));
    expect(find.byType(GrowthCardView), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('成長カード')), findsOneWidget);
  });

  testWidgets('PNG に画像化できる（端末内）', (tester) async {
    final bytes = await tester.runAsync(() => renderGrowthCardPng(_data(delta: 4), scale: 0.25));
    expect(bytes, isNotNull);
    // PNG シグネチャ
    expect(bytes!.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
    expect(bytes.length, greaterThan(500));
  });
}

void fontTests() {
  testWidgets('フォント指定つきでも画像化できる', (tester) async {
    final bytes = await tester.runAsync(() => renderGrowthCardPng(
          _data(delta: 4),
          scale: 0.25,
          fontFamily: 'Noto Sans',
          fontFamilyFallback: const ['Noto Sans CJK JP', 'Noto Sans Thai'],
        ));
    expect(bytes!.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
  });
}
